"""Host MCP del laboratorio A4-04 (lo escribe Claude; usa TUS funciones de servidor.py).

Un host MCP es quien conecta con los servidores, decide qué herramientas y qué descripciones ve el
modelo y con qué token se llama a cada servidor. Aquí se conecta a los servidores reales (almacén y
clima-samurai) con el cliente oficial `mcp` por Streamable HTTP, aplica los controles del host
(pinning y revisión de descripciones, que son TUS funciones) y llama a las herramientas.

Sobre el modelo: llama3.2:1b en CPU no llama a herramientas de forma fiable, así que el «modelo» de
este laboratorio es DETERMINISTA y crédulo a propósito (`modelo_credulo`): obedece al pie de la letra
las instrucciones que encuentre en las descripciones que el host le deja ver. Es el peor caso realista
y hace que la medición sea repetible. Lo que te protege no es el modelo, sino lo que el host le deja
ver (revisión, pinning) y lo que el servidor deja hacer (scopes, validación, rutas, audiencia).
"""

import re
from contextlib import AsyncExitStack, asynccontextmanager

import httpx2

from mcp import Client
from mcp.client.streamable_http import streamable_http_client

from servidor import (DESCRIPCIONES, RECURSO_ALMACEN, RECURSO_CLIMA, app_http, crear_almacen, crear_clima,
                      huella_definicion, revisar_definiciones, senales_sospechosas)

# Token que el host repartiría a cada servidor (en producción, uno por servidor, con la audiencia y
# los scopes de ese servidor). Aquí son los valores de laboratorio por defecto.
TOKEN = {"almacen": "lab-lector", "almacen-gestor": "lab-gestor", "clima": "lab-clima"}


def definicion(herramienta):
    """La definición de una herramienta MCP como dict {"name", "description", "inputSchema"}."""
    return {"name": herramienta.name, "description": herramienta.description or "",
            "inputSchema": herramienta.input_schema or {}}


class Conexion:
    """Una conexión abierta a un servidor MCP y sus herramientas ya listadas."""

    def __init__(self, cliente, herramientas):
        self.cliente = cliente
        self.definiciones = [definicion(t) for t in herramientas]

    async def llamar(self, nombre, argumentos):
        r = await self.cliente.call_tool(nombre, argumentos)
        texto = "".join(getattr(c, "text", "") for c in r.content)
        return {"ok": not r.is_error, "texto": texto}


class Host:
    """El host MCP: conexiones a los servidores, controles del host y registro de lo que pasa.

    defensas_host: subconjunto de ("pinning", "revision").
    - revision: una descripción con señales sospechosas (senales_sospechosas) NO se le enseña al
      modelo (se reemplaza por una versión neutra); el modelo no puede obedecer lo que no ve.
    - pinning: se guarda la huella de las definiciones aprobadas; si una cambia o aparece una nueva,
      la herramienta queda BLOQUEADA hasta que una persona la apruebe (aprobar()).
    """

    def __init__(self, defensas_host=()):
        self.defensas = set(defensas_host)
        self.conexiones = {}
        self.fijadas = {}       # servidor → {nombre: huella aprobada}
        self.bloqueadas = {}    # servidor → set de nombres bloqueados por el pinning
        self.registro = []      # (servidor, herramienta, argumentos)
        self._stack = AsyncExitStack()

    async def conectar(self, nombre, url, http_client, aprobar_todo=True):
        cliente = await self._stack.enter_async_context(Client(streamable_http_client(url, http_client=http_client)))
        tl = await cliente.list_tools()
        con = Conexion(cliente, tl.tools)
        self.conexiones[nombre] = con
        if "pinning" in self.defensas and aprobar_todo:
            self.fijar(nombre)      # al conectar por primera vez se aprueba lo que hay
        self._revisar_pinning(nombre)
        return con

    def fijar(self, servidor):
        """Aprueba (fija) las definiciones actuales del servidor como la versión de confianza."""
        con = self.conexiones[servidor]
        self.fijadas[servidor] = {d["name"]: huella_definicion(d) for d in con.definiciones}

    aprobar = fijar  # «aprobar la actualización» tras revisarla (mcp approve del Dojo)

    def _revisar_pinning(self, servidor):
        if "pinning" not in self.defensas or servidor not in self.fijadas:
            self.bloqueadas[servidor] = set()
            return
        con = self.conexiones[servidor]
        cambios = revisar_definiciones(self.fijadas[servidor], con.definiciones)
        self.bloqueadas[servidor] = set(cambios["nuevas"]) | set(cambios["cambiadas"])

    def actualizacion_del_servidor(self, servidor, nuevas_definiciones):
        """Simula que un servidor ya conectado anuncia otras definiciones (un rug pull: cambia la
        herramienta DESPUÉS de haber sido aprobada). El host vuelve a listar y NO reaprueba, así que
        el pinning puede detectar el cambio. nuevas_definiciones: lista de dicts como en definicion()."""
        self.conexiones[servidor].definiciones = [dict(d) for d in nuevas_definiciones]
        self._revisar_pinning(servidor)

    def _todas_las_herramientas(self):
        """Nombres de herramientas de TODOS los servidores conectados (para detectar una descripción
        que nombra a otra herramienta, aunque sea de otro servidor: shadowing y rug pull cruzados)."""
        return [d["name"] for con in self.conexiones.values() for d in con.definiciones]

    def descripcion_para_el_modelo(self, servidor, nombre):
        """La descripción que el host le deja ver al modelo. Si la herramienta está en cuarentena por
        el pinning, o —con «revision»— su descripción tiene señales sospechosas, se sustituye por una
        neutra: el modelo no puede obedecer un texto que no ve."""
        d = next(x for x in self.conexiones[servidor].definiciones if x["name"] == nombre)
        neutra = "[descripción retenida por el host] %s." % nombre
        if nombre in self.bloqueadas.get(servidor, set()):
            return neutra
        otras = [n for n in self._todas_las_herramientas() if n != nombre]
        if "revision" in self.defensas and senales_sospechosas(d["description"], otras):
            return neutra
        return d["description"]

    def herramientas_visibles(self, servidor):
        """Nombres de herramientas que el modelo puede usar: todas menos las bloqueadas por pinning."""
        return [d["name"] for d in self.conexiones[servidor].definiciones
                if d["name"] not in self.bloqueadas.get(servidor, set())]

    async def invocar(self, servidor, nombre, argumentos):
        """El host llama a una herramienta en nombre del modelo. Si el pinning la tiene bloqueada,
        no se llama (como haría el host real: herramienta en cuarentena hasta aprobarla)."""
        self.registro.append((servidor, nombre, dict(argumentos)))
        if nombre in self.bloqueadas.get(servidor, set()):
            return {"ok": False, "texto": "BLOQUEADA por pinning: %s (aprueba la nueva versión tras revisarla)" % nombre}
        return await self.conexiones[servidor].llamar(nombre, argumentos)

    async def cerrar(self):
        await self._stack.aclose()


# ─────────────── Conectar a los servidores reales dentro del proceso (para tests y batería) ───────────────

class _ServidorEnProceso:
    """Sirve una app MCP por HTTP dentro del propio proceso (httpx2.ASGITransport): sin red ni puertos.
    Da un httpx2.AsyncClient con el token Bearer ya puesto, listo para el cliente MCP."""

    def __init__(self, servidor, url, token):
        self.app = app_http(servidor)
        self.url, self.token = url, token
        self._stack = AsyncExitStack()

    async def cliente_http(self):
        await self._stack.enter_async_context(self.app.router.lifespan_context(self.app))
        tr = httpx2.ASGITransport(app=self.app)
        origen = re.match(r"^(https?://[^/]+)", self.url).group(1)
        return await self._stack.enter_async_context(
            httpx2.AsyncClient(transport=tr, base_url=origen,
                               headers={"Authorization": "Bearer %s" % self.token} if self.token else {}))

    async def cerrar(self):
        await self._stack.aclose()


@asynccontextmanager
async def escenario(defensas_servidor=(), defensas_host=(), clima_version=1,
                    token_almacen="lab-lector", token_clima="lab-clima", planos=None):
    """Monta, dentro del proceso y sin red, el almacén y clima-samurai reales y un host conectado a
    los dos. Devuelve (host, ctx_almacen, ctx_clima). Úsalo con `async with`; se cierra todo solo.
    Driva el conjunto con anyio.run (los servidores MCP usan anyio)."""
    from servidor import PLANOS, RECURSO_ALMACEN, RECURSO_CLIMA, crear_almacen, crear_clima
    planos = planos if planos is not None else PLANOS
    async with AsyncExitStack() as stack:
        alm, ca = crear_almacen(defensas_servidor, planos=planos)
        cli, cc = crear_clima(version=clima_version)
        sa = _ServidorEnProceso(alm, RECURSO_ALMACEN, token_almacen)
        sc = _ServidorEnProceso(cli, RECURSO_CLIMA, token_clima)
        stack.push_async_callback(sa.cerrar)
        stack.push_async_callback(sc.cerrar)
        ha = await sa.cliente_http()
        hc = await sc.cliente_http()
        h = Host(defensas_host)
        stack.push_async_callback(h.cerrar)
        h._servidores = {"almacen": sa, "clima": sc}   # para reconectar tras una actualización
        await h.conectar("almacen", RECURSO_ALMACEN, ha)
        await h.conectar("clima", RECURSO_CLIMA, hc)
        yield h, ca, cc


# ─────────────── El modelo crédulo determinista ───────────────

_RE_LEER = re.compile(r"leer_plano con nombre '([^']+)'")
_RE_REEMBOLSO = re.compile(r"aplicar_reembolso,?\s*pedido\s+(P-\d{3})\s*e\s*importe\s+(\d+)", re.IGNORECASE)


def ordenes_ocultas(descripcion):
    """Instrucciones que un modelo crédulo sacaría de la descripción de una herramienta. Devuelve una
    lista de (herramienta, argumentos). Es la parte «el modelo obedece la descripción»: si el host no
    le enseña la descripción envenenada, esta función no ve nada que obedecer."""
    ordenes = []
    m = _RE_LEER.search(descripcion or "")
    if m:
        ordenes.append(("leer_plano", {"nombre": m.group(1)}))
    m = _RE_REEMBOLSO.search(descripcion or "")
    if m:
        ordenes.append(("aplicar_reembolso", {"pedido": m.group(1), "importe": int(m.group(2))}))
    return ordenes
