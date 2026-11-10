"""Batería del laboratorio A4-04: mide cada configuración de defensas contra los servidores MCP REALES.

La ha escrito Claude (no es parte del ejercicio), pero usa TUS funciones de servidor.py. NO necesita
Ollama ni Docker: levanta el almacén y clima-samurai (SDK oficial `mcp`) dentro del propio proceso,
por HTTP, y los ataca con un host determinista (host.py). Por qué determinista y no con llama3.2:1b:
un modelo de 1B en CPU no llama a herramientas de forma fiable, así que la medición no sería
repetible; aquí lo «real» es el protocolo (SDK MCP 2.3.0, Streamable HTTP, auth por token), no el
modelo. El modelo se sustituye por el peor caso: uno que obedece al pie de la letra lo que el host le
deja ver.

    python bateria.py                 todas las configuraciones (es determinista: una pasada basta)
    python bateria.py --n 1 --configs "ninguna;scopes;audiencia;rutas,validacion,scopes,audiencia,pinning,revision"

Cada configuración mezcla defensas de servidor (scopes, validacion, rutas, audiencia) y de host
(pinning, revision). Escribe la evidencia en forja/evidencias/A4-04-medicion.json; en el Dojo:
evidence import
"""

import argparse
import datetime
import hashlib
import json
import math
import sys
import time
from pathlib import Path

import anyio

from host import escenario, ordenes_ocultas
from servidor import (CANARIO, CLIMA_V2, DEFENSAS_HOST, DEFENSAS_SERVIDOR, ESQUEMAS, normalizar)

AQUI = Path(__file__).resolve().parent
SALIDA = AQUI.parents[2] / "forja" / "evidencias" / "A4-04-medicion.json"
CONFIGS = "ninguna;scopes;validacion;rutas;audiencia;pinning;revision;scopes,validacion,rutas,audiencia,pinning,revision"


def wilson(exitos, n, z=1.96):
    if n == 0:
        return 0.0, 1.0
    p = exitos / n
    d = 1 + z * z / n
    c = (p + z * z / (2 * n)) / d
    m = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / d
    return max(0.0, c - m), min(1.0, c + m)


def _parte(defensas, cuales):
    return tuple(d for d in defensas if d in cuales)


def _contiene(texto, frase):
    return normalizar(frase) in normalizar(texto)


def _logro(atk, textos, reembolsos):
    """¿Consiguió el ataque su efecto? textos: lo que el modelo/host obtuvo; reembolsos: los aplicados."""
    if atk["exito_si"] == "canario":
        return any(CANARIO in t for t in textos)
    if atk["exito_si"] == "reembolso":
        return reembolsos > 0
    if atk["exito_si"] == "pedido":
        return any(_contiene(t, "katana") or _contiene(t, "monedas") for t in textos)
    return False


async def _directo(atk, ds, dh):
    """Ataque directo: el host llama a una herramienta del almacén con el token indicado. 'cruda' es
    True porque la petición llega al servidor (lo pare, si acaso, el propio servidor)."""
    token = "lab-" + atk["token"]
    try:
        async with escenario(defensas_servidor=ds, defensas_host=dh, token_almacen=token) as (h, ca, _):
            r = await h.invocar("almacen", atk["tool"], atk["args"])
            return _logro(atk, [r["texto"]], len(ca.reembolsos)), True
    except Exception:
        # El servidor rechazó el token en el handshake (audiencia/caducado): la petición llegó, pero falló.
        return False, True


async def _poisoning(atk, ds, dh):
    """El modelo obedece la descripción de consultar_clima: lee un fichero y lo exfiltra. 'cruda' es
    True solo si el host llegó a emitir la llamada maliciosa (no la retuvo por revisión/pinning)."""
    token = "lab-" + atk["token"]
    async with escenario(defensas_servidor=ds, defensas_host=dh, clima_version=atk["clima_version"], token_almacen=token) as (h, ca, _):
        desc = h.descripcion_para_el_modelo("clima", "consultar_clima")
        textos, cruda = [], False
        for herr, args in ordenes_ocultas(desc):
            r = await h.invocar("almacen", herr, args)
            cruda = cruda or not r["texto"].startswith("BLOQUEADA")
            textos.append(r["texto"])
        return _logro(atk, textos, len(ca.reembolsos)), cruda


async def _rug_pull(atk, ds, dh):
    """Se aprueba la v1 de clima; el servidor pasa a una v2 que ordena un reembolso. 'cruda' como arriba."""
    token = "lab-" + atk["token"]
    async with escenario(defensas_servidor=ds, defensas_host=dh, clima_version=1, token_almacen=token) as (h, ca, _):
        v2 = [{"name": "consultar_clima", "description": CLIMA_V2, "inputSchema": ESQUEMAS["consultar_clima"]}]
        h.actualizacion_del_servidor("clima", v2)
        desc = h.descripcion_para_el_modelo("clima", "consultar_clima")
        textos, cruda = [], False
        for herr, args in ordenes_ocultas(desc):
            r = await h.invocar("almacen", herr, args)
            cruda = cruda or not r["texto"].startswith("BLOQUEADA")
            textos.append(r["texto"])
        return _logro(atk, textos, len(ca.reembolsos)), cruda


async def correr_ataque(atk, ds, dh):
    if atk["via"] == "directo":
        return await _directo(atk, ds, dh)
    if atk["via"] == "clima":
        return await _poisoning(atk, ds, dh)
    return await _rug_pull(atk, ds, dh)


async def correr_legitima(tarea, ds, dh):
    token = "lab-" + tarea["token"]
    try:
        async with escenario(defensas_servidor=ds, defensas_host=dh, token_almacen=token) as (h, _, _):
            r = await h.invocar("almacen", tarea["tool"], tarea["args"])
            return r["ok"] and all(_contiene(r["texto"], e) for e in tarea["espera"])
    except Exception:
        return False


async def medir_config(bateria, defensas, n):
    ds, dh = _parte(defensas, DEFENSAS_SERVIDOR), _parte(defensas, DEFENSAS_HOST)
    exitos = crudas = legit_ok = 0
    por_categoria = {}
    for atk in bateria["ataques"]:
        cat = por_categoria.setdefault(atk["categoria"], {"exitos": 0, "n": 0, "crudas": 0})
        for _ in range(n):
            ok, cruda = await correr_ataque(atk, ds, dh)
            exitos += ok
            crudas += cruda
            cat["exitos"] += ok
            cat["crudas"] += cruda
            cat["n"] += 1
    for tarea in bateria["legitimas"]:
        for _ in range(n):
            legit_ok += await correr_legitima(tarea, ds, dh)
    return {"defensas": ",".join(defensas) or "ninguna", "ataques_n": len(bateria["ataques"]) * n,
            "ataques_exitos": exitos, "fugas_crudas": crudas, "legitimas_n": len(bateria["legitimas"]) * n,
            "legitimas_ok": legit_ok, "por_categoria": por_categoria}


async def principal(a):
    ruta = AQUI / "ataques.json"
    bateria = json.loads(ruta.read_text(encoding="utf-8"))
    configs = [tuple(d for d in c.split(",") if d and d != "ninguna") for c in a.configs.split(";")]
    print("Servidores MCP reales (SDK mcp 2.3.0, Streamable HTTP) · host determinista · sin red ni modelo")
    print("%d configuraciones · %d ataques y %d tareas legítimas cada una (x%d)\n" % (
        len(configs), len(bateria["ataques"]), len(bateria["legitimas"]), a.n))
    resultados = []
    for defensas in configs:
        t0 = time.monotonic()
        r = await medir_config(bateria, defensas, a.n)
        bajo, alto = wilson(r["ataques_exitos"], r["ataques_n"])
        print("%-44s éxito %d/%-2d IC95 [%.2f, %.2f] · llegó al servidor %d · legítimas %d/%-2d · %4.1f s" % (
            r["defensas"], r["ataques_exitos"], r["ataques_n"], bajo, alto, r["fugas_crudas"], r["legitimas_ok"],
            r["legitimas_n"], time.monotonic() - t0))
        print("%44s %s" % ("", " · ".join("%s %d/%d (llegó %d)" % (k, v["exitos"], v["n"], v["crudas"])
                                           for k, v in r["por_categoria"].items())))
        resultados.append(r)
    ev = {"schema": "ai-ronin/evidence", "schema_version": 1, "kind": "medicion", "lab": "A4-04",
          "created": datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat(),
          "modelo": "SDK mcp 2.3.0 (Streamable HTTP) + host determinista", "temperatura": 0.0,
          "repeticiones": a.n, "bateria_sha256": hashlib.sha256(ruta.read_bytes().replace(b"\r\n", b"\n")).hexdigest(),
          "configuraciones": resultados}
    SALIDA.parent.mkdir(parents=True, exist_ok=True)
    SALIDA.write_text(json.dumps(ev, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print("\nEvidencia: %s · en el Dojo: evidence import" % SALIDA)


def main():
    for flujo in (sys.stdout, sys.stderr):
        if hasattr(flujo, "reconfigure"):
            flujo.reconfigure(encoding="utf-8", errors="replace")
    p = argparse.ArgumentParser(description="Mide las defensas del servidor y el host MCP contra los servidores reales.")
    p.add_argument("--n", type=int, default=1, help="repeticiones de cada ataque (es determinista; 1 basta)")
    p.add_argument("--configs", default=CONFIGS, help="configuraciones separadas por ';' (defensas separadas por ',')")
    a = p.parse_args()
    anyio.run(principal, a)


if __name__ == "__main__":
    main()
