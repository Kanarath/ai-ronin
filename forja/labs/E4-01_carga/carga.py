"""Laboratorio E4-01 · La forja bajo carga.

Tu servicio de P0-01 atendía a una persona cada vez. Aquí llegan muchas a la vez, y una de ellas
abusa: manda ráfagas de peticiones caras (OWASP LLM10, consumo sin límite). En una CPU el modelo
genera una respuesta cada vez, así que cada petición abusiva que llega al modelo es tiempo que
esperan los demás.

Tú implementas las piezas marcadas con «Tu turno»: medir la latencia (percentiles y throughput),
limitar por cliente (token bucket), una caché con clave normalizada y la tubería `atender`, que
las combina con una cola acotada, un plazo máximo y una respuesta degradada. El resto (la
configuración, la aplicación FastAPI y la conexión con tu servicio de P0-01) lo ha escrito Claude.

Python que practicas: clases, OrderedDict, hashlib, unicodedata y asyncio (Semaphore, wait_for,
gather). Ver PYTHON.md, anexo E4. Tests (sin red, con un modelo simulado):
    python -m unittest -v test_carga
"""

import asyncio
import hashlib
import os
import sys
import time
import unicodedata
from collections import OrderedDict
from contextlib import asynccontextmanager
from dataclasses import dataclass
from pathlib import Path

from fastapi import FastAPI, Header
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

RESPUESTA_DEGRADADA = "La forja está muy ocupada ahora mismo. Vuelve a intentarlo en unos minutos."
SIGNOS_BORDE = "¿?¡!.,;: "
MAX_CARACTERES = 2000


# ─────────────────────────────── Tu turno ───────────────────────────────

def percentil(valores, p):
    """Percentil p (de 0 a 100) de una lista de números, con interpolación lineal (el método por
    defecto de NumPy):
        1. v = los valores ordenados de menor a mayor (sin modificar la lista original); n = len(v)
        2. posicion = (n - 1) * p / 100; i = int(posicion); f = posicion - i
        3. si i + 1 < n, devuelve v[i] + (v[i + 1] - v[i]) * f; si no, devuelve v[i]
    Lanza ValueError si la lista está vacía o si p no está entre 0 y 100 (ambos incluidos).
    Ejemplos: percentil([4, 1, 3, 2], 50) == 2.5 · percentil([5], 95) == 5 · percentil([1, 2, 3, 4, 5], 95) == 4.8
    """
    raise NotImplementedError("Tu turno: implementa percentil")


def resumen_latencias(latencias, segundos_totales):
    """Resumen de una prueba de carga. latencias = segundos que tardó cada petición atendida;
    segundos_totales = lo que duró la prueba entera. Devuelve:
        {"n": número de latencias,
         "p50": percentil 50, "p95": percentil 95, "max": la mayor latencia,
         "throughput": n / segundos_totales}          ← peticiones atendidas por segundo
    con p50, p95, max y throughput redondeados a 3 decimales.
    Si latencias está vacía: {"n": 0, "p50": 0.0, "p95": 0.0, "max": 0.0, "throughput": 0.0}.
    Lanza ValueError si segundos_totales <= 0 (antes de mirar las latencias).
    """
    raise NotImplementedError("Tu turno: implementa resumen_latencias")


class CuboDeTokens:
    """Límite por cliente con un cubo de tokens (token bucket).

    El cubo guarda como mucho `capacidad` tokens y se rellena a `recarga_por_segundo`. Cada
    petición gasta `coste` tokens: si no quedan, se rechaza. Permite ráfagas cortas (hasta la
    capacidad) pero limita el ritmo sostenido a la recarga.
    """

    def __init__(self, capacidad, recarga_por_segundo, reloj=time.monotonic):
        """Lanza ValueError si capacidad <= 0 o si recarga_por_segundo < 0.
        Guarda self.capacidad, self.recarga (= recarga_por_segundo) y self.reloj (una función sin
        argumentos que devuelve segundos; los tests pasan un reloj falso).
        El cubo empieza LLENO: self.tokens = float(capacidad). Y self.ultimo = reloj().
        """
        raise NotImplementedError("Tu turno: implementa CuboDeTokens.__init__")

    def permitir(self, coste=1):
        """1. ahora = self.reloj(); suma a self.tokens (ahora - self.ultimo) * self.recarga, sin pasar
              de self.capacidad; y self.ultimo = ahora.
        2. Si self.tokens >= coste: resta coste y devuelve True. Si no: devuelve False sin restar nada.
        """
        raise NotImplementedError("Tu turno: implementa CuboDeTokens.permitir")


def normalizar_pregunta(texto):
    """Forma canónica de una pregunta, para que variantes triviales compartan entrada en la caché:
        1. unicodedata.normalize("NFKC", texto)        (unifica caracteres equivalentes)
        2. .casefold()                                   (mayúsculas y minúsculas, también «ß» → «ss»)
        3. espacios colapsados: " ".join(texto.split())
        4. sin los caracteres de SIGNOS_BORDE al principio ni al final: .strip(SIGNOS_BORDE)
    Ejemplo: "  ¿Qué   GARANTÍA tienen?? " → "qué garantía tienen"
    """
    raise NotImplementedError("Tu turno: implementa normalizar_pregunta")


def clave_cache(ambito, modelo, temperatura, pregunta):
    """Clave de la caché: el SHA-256 en hexadecimal (64 caracteres) del texto
        "\\n".join([ambito, modelo, str(float(temperatura)), normalizar_pregunta(pregunta)])
    codificado en UTF-8. El ámbito separa a quién se le puede servir una respuesta guardada: si las
    respuestas dependen del usuario, el ámbito es el usuario; si son públicas, "publico".
    """
    raise NotImplementedError("Tu turno: implementa clave_cache")


class CacheRespuestas:
    """Caché de respuestas con caducidad (TTL) y un máximo de entradas (se expulsa la usada hace más tiempo, LRU)."""

    def __init__(self, max_entradas, ttl_segundos, reloj=time.monotonic):
        """Guarda self.max_entradas, self.ttl (= ttl_segundos) y self.reloj.
        self.datos = OrderedDict(): clave → (valor, caduca_en). El orden es el de uso: la primera
        clave es la usada hace más tiempo.
        """
        raise NotImplementedError("Tu turno: implementa CacheRespuestas.__init__")

    def obtener(self, clave):
        """Devuelve el valor guardado o None.
        - Si la clave no está: None.
        - Si está pero ha caducado (self.reloj() >= caduca_en): la borra y devuelve None.
        - Si está y vale: la marca como la más reciente (self.datos.move_to_end(clave)) y devuelve el valor.
        """
        raise NotImplementedError("Tu turno: implementa CacheRespuestas.obtener")

    def guardar(self, clave, valor):
        """Guarda (valor, self.reloj() + self.ttl) en self.datos[clave] y la marca como la más reciente.
        Después, mientras haya más de self.max_entradas, borra la más antigua: self.datos.popitem(last=False).
        """
        raise NotImplementedError("Tu turno: implementa CacheRespuestas.guardar")


async def atender(estado, cliente, pregunta, llamar_modelo, ambito="publico"):
    """Atiende una petición aplicando las defensas de estado.politica, EN ESTE ORDEN:

    1. Límite (si estado.politica.limite): si estado.cubo(cliente).permitir() es False, devuelve
           {"estado": 429, "motivo": "limite"}                      ← el modelo no llega a ejecutarse
    2. Caché (si estado.cache no es None):
           clave = clave_cache(ambito, estado.modelo, estado.temperatura, pregunta)
           si estado.cache.obtener(clave) no es None → {"estado": 200, "texto": ese valor, "cache": True}
    3. Cola (si estado.semaforo no es None):
           si estado.admitidas >= estado.politica.concurrencia + estado.politica.max_cola, devuelve
           {"estado": 503, "motivo": "cola llena"}
           si no, suma 1 a estado.admitidas y espera su turno con `async with estado.semaforo:`.
           Al terminar, PASE LO QUE PASE (try/finally), resta 1 a estado.admitidas.
    4. Modelo: texto = await llamar_modelo(pregunta). Si estado.politica.timeout no es None, la llamada
           va dentro de asyncio.wait_for(..., estado.politica.timeout) (el plazo cuenta solo la llamada
           al modelo, no la espera en la cola). Si vence (TimeoutError), devuelve la respuesta degradada:
           {"estado": 504, "motivo": "timeout", "texto": RESPUESTA_DEGRADADA}      ← y no se guarda en caché
       Cualquier otra excepción de llamar_modelo se deja pasar (sin capturarla).
    5. Si hay caché, guarda texto con la clave del paso 2. Devuelve {"estado": 200, "texto": texto, "cache": False}.
    """
    raise NotImplementedError("Tu turno: implementa atender")


# ──────────────────── Configuración y servicio (escritos por Claude) ────────────────────

DEFENSAS = ("limite", "cache", "cola", "timeout")


@dataclass
class Politica:
    """Qué defensas están activas y con qué números."""
    limite: bool = False
    capacidad: int = 3              # ráfaga máxima por cliente
    recarga: float = 0.05           # tokens por segundo: 1 petición cada 20 s sostenida
    cache: bool = False
    cache_max: int = 256
    cache_ttl: float = 600.0
    cola: bool = False
    concurrencia: int = 1           # en CPU, Ollama genera una respuesta cada vez
    max_cola: int = 3
    timeout: float | None = None

    @staticmethod
    def desde_defensas(defensas, **numeros):
        """defensas: iterable con nombres de DEFENSAS. Los números (capacidad, timeout...) llegan en `numeros`."""
        defensas = set(defensas)
        desconocidas = defensas - set(DEFENSAS)
        if desconocidas:
            raise ValueError("defensas desconocidas: %s" % ", ".join(sorted(desconocidas)))
        plazo = numeros.pop("timeout", 45.0)
        p = Politica(limite="limite" in defensas, cache="cache" in defensas, cola="cola" in defensas,
                     timeout=float(plazo) if "timeout" in defensas else None)
        for k, v in numeros.items():
            if not hasattr(p, k):
                raise ValueError("ajuste desconocido: %s" % k)
            setattr(p, k, v)
        return p


class Estado:
    """Estado compartido del servicio: un cubo por cliente, la caché, el semáforo y el contador de la cola."""

    def __init__(self, politica, modelo="llama3.2:1b", temperatura=0.0, reloj=time.monotonic):
        self.politica = politica
        self.modelo = modelo
        self.temperatura = temperatura
        self.reloj = reloj
        self.cubos = {}
        self.cache = CacheRespuestas(politica.cache_max, politica.cache_ttl, reloj) if politica.cache else None
        self.semaforo = asyncio.Semaphore(politica.concurrencia) if politica.cola else None
        self.admitidas = 0          # peticiones dentro del servicio: esperando turno o con el modelo

    def cubo(self, cliente):
        if cliente not in self.cubos:
            self.cubos[cliente] = CuboDeTokens(self.politica.capacidad, self.politica.recarga, self.reloj)
        return self.cubos[cliente]


def servicio_p0():
    """Tu servicio de P0-01 (forja/labs/P0-01_servicio_llm/servicio.py): este laboratorio lo reutiliza."""
    try:
        import servicio
    except ModuleNotFoundError:
        sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "P0-01_servicio_llm"))
        import servicio
    return servicio


async def llamar_ollama(cliente, ajustes, pregunta, max_tokens=None):
    """Una llamada a Ollama con TUS funciones de P0-01. Devuelve el diccionario de extraer_respuesta.
    max_tokens limita la longitud de la respuesta (opción num_predict de Ollama): otra forma de acotar el consumo."""
    s = servicio_p0()
    cuerpo = s.construir_peticion(pregunta, ajustes.modelo, ajustes.temperatura)
    if max_tokens:
        cuerpo["options"]["num_predict"] = int(max_tokens)
    r = await cliente.post("/api/chat", json=cuerpo)
    r.raise_for_status()
    return s.extraer_respuesta(r.json())


TOKENS_LAB = "token-ana-lab:ana,token-luis-lab:luis,token-abusador-lab:abusador"


def tokens_desde_entorno():
    """TOKENS="token1:cliente1,token2:cliente2". El cliente sale del token, nunca del cuerpo de la petición."""
    pares = [t.split(":", 1) for t in os.environ.get("TOKENS", TOKENS_LAB).split(",") if ":" in t]
    return {tok.strip(): cli.strip() for tok, cli in pares}


class PeticionChat(BaseModel):
    pregunta: str = Field(min_length=1, max_length=MAX_CARACTERES)


def crear_app(defensas=None, llamar_modelo=None, tokens=None, politica=None):
    """Servicio con las defensas de la variable DEFENSAS (por ejemplo "limite,cache,cola,timeout").
    Los tests pasan `llamar_modelo` (un modelo simulado); si no, se usa Ollama con tu servicio de P0-01."""
    if defensas is None:
        defensas = [d for d in os.environ.get("DEFENSAS", "").split(",") if d.strip()]
    politica = politica or Politica.desde_defensas(defensas)
    tokens = tokens if tokens is not None else tokens_desde_entorno()
    recuento = {}

    @asynccontextmanager
    async def ciclo_de_vida(app):
        app.state.estado = Estado(politica)
        if llamar_modelo is not None:
            app.state.llamar = llamar_modelo
            yield
            return
        import httpx2
        ajustes = servicio_p0().Ajustes.desde_entorno()
        app.state.estado.modelo, app.state.estado.temperatura = ajustes.modelo, ajustes.temperatura
        async with httpx2.AsyncClient(base_url=ajustes.ollama_url, timeout=ajustes.timeout) as cliente:
            async def llamar(pregunta):
                return (await llamar_ollama(cliente, ajustes, pregunta, int(os.environ.get("MAX_TOKENS", "256"))))["texto"]
            app.state.llamar = llamar
            yield

    app = FastAPI(title="Forja · servicio bajo carga", lifespan=ciclo_de_vida)

    @app.get("/salud")
    async def salud():
        return {"ok": True, "defensas": sorted(d for d in DEFENSAS if d in defensas)}

    @app.get("/recuento")
    async def ver_recuento():
        return {"respuestas": recuento, "en_cola": app.state.estado.admitidas}

    @app.post("/chat")
    async def chat(peticion: PeticionChat, authorization: str = Header(default="")):
        cliente = tokens.get(authorization.removeprefix("Bearer ").strip())
        if cliente is None:
            return JSONResponse({"detail": "token no válido"}, status_code=401)
        try:
            r = await atender(app.state.estado, cliente, peticion.pregunta, app.state.llamar)
        except NotImplementedError:
            raise                   # te falta una función «Tu turno»: mejor verlo que recibir un 502
        except Exception as e:  # el error interno no se devuelve tal cual: puede revelar el despliegue
            r = {"estado": 502, "motivo": "error del modelo (%s)" % type(e).__name__}
        recuento[str(r["estado"])] = recuento.get(str(r["estado"]), 0) + 1
        cabeceras = {}
        if r["estado"] in (429, 503):
            # Retry-After le dice al cliente cuándo volver; un cliente educado espera en lugar de insistir.
            cabeceras["Retry-After"] = str(max(1, round(1 / politica.recarga))) if r["estado"] == 429 and politica.recarga > 0 else "5"
        return JSONResponse(r, status_code=r["estado"], headers=cabeceras)

    return app


app = crear_app()
