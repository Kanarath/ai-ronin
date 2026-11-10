"""Generador de carga del laboratorio E4-01: mide cada configuración de defensas contra el modelo REAL.

Lo ha escrito Claude (no es parte del ejercicio), pero usa TUS funciones de carga.py y de P0-01.
Necesita Ollama en marcha con llama3.2:1b. No necesita el servicio FastAPI: llama a la tubería
`atender` directamente, con un cliente abusivo y tres legítimos a la vez (ataques.json).

    python bateria.py                         4 configuraciones, 1 repetición (unos 10-20 minutos en CPU)
    python bateria.py --n 2 --configs "ninguna;limite,cache,cola,timeout"

Escribe la evidencia en forja/evidencias/E4-01-medicion.json; después, en el Dojo: evidence import
"""

import argparse
import asyncio
import datetime
import hashlib
import json
import sys
import time
from pathlib import Path

import httpx2

from carga import Estado, Politica, atender, llamar_ollama, resumen_latencias, servicio_p0

AQUI = Path(__file__).resolve().parent
SALIDA = AQUI.parents[2] / "forja" / "evidencias" / "E4-01-medicion.json"
CONFIGS = "ninguna;limite;limite,cache;limite,cache,cola,timeout"


async def una_ronda(cliente, ajustes, bateria, defensas):
    """Lanza el escenario una vez: la ráfaga abusiva en t=0 y las legítimas escalonadas."""
    esc = bateria["escenario"]
    numeros = {k: esc[k] for k in ("capacidad", "recarga", "concurrencia", "max_cola", "timeout")}
    estado = Estado(Politica.desde_defensas(defensas, **numeros), modelo=ajustes.modelo, temperatura=ajustes.temperatura)
    t0 = time.monotonic()

    async def peticion(item, tipo, retraso):
        await asyncio.sleep(retraso)
        fila = {"id": item["id"], "tipo": tipo, "cliente": item["cliente"], "modelo": False, "tokens": 0}

        async def llamar(pregunta):
            fila["modelo"] = True                 # la petición ha llegado al modelo: ya gasta CPU
            r = await llamar_ollama(cliente, ajustes, pregunta, esc["max_tokens"])
            fila["tokens"] = r["tokens"]
            return r["texto"]

        inicio = time.monotonic()
        try:
            r = await atender(estado, item["cliente"], item["mensaje"], llamar)
        except httpx2.HTTPError as e:
            r = {"estado": 502, "motivo": type(e).__name__}
        fila.update(estado=r["estado"], cache=r.get("cache", False), segundos=time.monotonic() - inicio,
                    fin=time.monotonic() - t0)
        return fila

    tareas = [peticion(a, "ataque", 0.0) for a in bateria["ataques"]]
    tareas += [peticion(q, "legitima", esc["retraso_legitimas"] + i * esc["separacion_legitimas"])
               for i, q in enumerate(bateria["legitimas"])]
    filas = await asyncio.gather(*tareas)
    return filas, time.monotonic() - t0


async def medir_config(cliente, ajustes, bateria, defensas, n):
    slo = bateria["escenario"]["slo_segundos"]
    filas, duracion = [], 0.0
    for _ in range(n):
        f, d = await una_ronda(cliente, ajustes, bateria, defensas)
        filas += f
        duracion += d
    ataques = [f for f in filas if f["tipo"] == "ataque"]
    legit = [f for f in filas if f["tipo"] == "legitima"]
    servidas = [f for f in filas if f["estado"] == 200]
    lat_legit = [f["segundos"] for f in legit if f["estado"] == 200]
    return {"defensas": ",".join(defensas) or "ninguna",
            "ataques_n": len(ataques),
            "ataques_exitos": sum(f["modelo"] for f in ataques),                       # abuso que gastó CPU
            "fugas_crudas": sum(f["estado"] == 200 and not f["cache"] for f in ataques),  # abuso servido entero
            "legitimas_n": len(legit),
            "legitimas_ok": sum(f["estado"] == 200 and f["segundos"] <= slo for f in legit),
            "legitimas_cache": sum(f["cache"] for f in legit),
            "tokens_abuso": sum(f["tokens"] for f in ataques),
            "tokens_legitimas": sum(f["tokens"] for f in legit),
            "estados": {str(k): sum(f["estado"] == k for f in filas) for k in sorted({f["estado"] for f in filas})},
            "latencia_legitimas": resumen_latencias(lat_legit, duracion),
            "global": resumen_latencias([f["segundos"] for f in servidas], duracion),
            "segundos": round(duracion, 1)}


async def principal(a):
    ajustes = servicio_p0().Ajustes.desde_entorno()
    ruta = AQUI / "ataques.json"
    bateria = json.loads(ruta.read_text(encoding="utf-8"))
    configs = [tuple(d for d in c.split(",") if d and d != "ninguna") for c in a.configs.split(";")]
    print("Modelo %s · %d configuraciones · %d peticiones por ronda · %d rondas por configuración\n" % (
        ajustes.modelo, len(configs), len(bateria["ataques"]) + len(bateria["legitimas"]), a.n))
    resultados = []
    async with httpx2.AsyncClient(base_url=ajustes.ollama_url, timeout=300.0) as cliente:
        print("Calentando el modelo (la primera respuesta carga los pesos en memoria)...")
        await llamar_ollama(cliente, ajustes, "Hola", 8)
        for defensas in configs:
            r = await medir_config(cliente, ajustes, bateria, defensas, a.n)
            lg, gl = r["latencia_legitimas"], r["global"]
            print("%-28s abuso al modelo %2d/%-2d · legítimas a tiempo %d/%d (caché %d) · p50 %5.1f s · p95 %5.1f s"
                  " · %.3f resp/s · tokens abuso %d · %.0f s · %s" % (
                      r["defensas"], r["ataques_exitos"], r["ataques_n"], r["legitimas_ok"], r["legitimas_n"],
                      r["legitimas_cache"], lg["p50"], lg["p95"], gl["throughput"], r["tokens_abuso"], r["segundos"], r["estados"]))
            resultados.append(r)
    ev = {"schema": "ai-ronin/evidence", "schema_version": 1, "kind": "medicion", "lab": "E4-01",
          "created": datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat(),
          "modelo": ajustes.modelo, "temperatura": ajustes.temperatura, "repeticiones": a.n,
          "bateria_sha256": hashlib.sha256(ruta.read_bytes().replace(b"\r\n", b"\n")).hexdigest(),
          "configuraciones": resultados}
    SALIDA.parent.mkdir(parents=True, exist_ok=True)
    SALIDA.write_text(json.dumps(ev, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print("\nEvidencia: %s · en el Dojo: evidence import" % SALIDA)


def main():
    for flujo in (sys.stdout, sys.stderr):
        if hasattr(flujo, "reconfigure"):
            flujo.reconfigure(encoding="utf-8", errors="replace")
    p = argparse.ArgumentParser(description="Mide las defensas del servicio bajo carga contra el modelo real.")
    p.add_argument("--n", type=int, default=1, help="rondas del escenario por configuración")
    p.add_argument("--configs", default=CONFIGS, help="configuraciones separadas por ';' (defensas separadas por ',')")
    asyncio.run(principal(p.parse_args()))


if __name__ == "__main__":
    main()
