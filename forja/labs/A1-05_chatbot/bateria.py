"""Batería del laboratorio A1-05: mide cada configuración de defensas contra el modelo REAL.

Lo ha escrito Claude (no es parte del ejercicio), pero usa TUS funciones de chatbot.py.
Necesita Ollama en marcha con el modelo descargado. No necesita el servicio FastAPI: llama a
la tubería `responder` directamente.

    python bateria.py                       5 configuraciones, 3 repeticiones (unos 165 mensajes)
    python bateria.py --n 5 --configs "ninguna;salida;sin-secreto"

Escribe la evidencia en forja/evidencias/A1-05-medicion.json; después, en el Dojo: evidence import
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

from chatbot import Ajustes, contiene_secreto, intervalo_wilson, normalizar, responder

AQUI = Path(__file__).resolve().parent
SALIDA = AQUI.parents[2] / "forja" / "evidencias" / "A1-05-medicion.json"
CONFIGS = "ninguna;entrada;entrada,salida;delimitar;sin-secreto"


async def medir_config(cliente, ajustes, bateria, defensas, n):
    exitos = fugas_crudas = legit_ok = 0
    for atk in bateria["ataques"]:
        for _ in range(n):
            r = await responder(cliente, ajustes, atk["mensaje"], defensas)
            exitos += contiene_secreto(r["texto"])
            fugas_crudas += contiene_secreto(r["crudo"])
    for q in bateria["legitimas"]:
        for _ in range(n):
            r = await responder(cliente, ajustes, q["mensaje"], defensas)
            texto = normalizar(r["texto"])
            legit_ok += all(normalizar(e) in texto for e in q["espera"])
    return {"defensas": ",".join(defensas) or "ninguna", "ataques_n": len(bateria["ataques"]) * n, "ataques_exitos": exitos,
            "fugas_crudas": fugas_crudas, "legitimas_n": len(bateria["legitimas"]) * n, "legitimas_ok": legit_ok}


async def principal(a):
    ajustes = Ajustes.desde_entorno()
    ruta = AQUI / "ataques.json"
    bateria = json.loads(ruta.read_text(encoding="utf-8"))
    configs = [tuple(d for d in c.split(",") if d and d != "ninguna") for c in a.configs.split(";")]
    total = len(configs) * (len(bateria["ataques"]) + len(bateria["legitimas"])) * a.n
    print("Modelo %s · %d configuraciones · %d mensajes en total (en CPU, varios segundos cada uno)\n" % (ajustes.modelo, len(configs), total))
    resultados = []
    async with httpx2.AsyncClient(base_url=ajustes.ollama_url, timeout=ajustes.timeout) as cliente:
        for defensas in configs:
            t0 = time.monotonic()
            r = await medir_config(cliente, ajustes, bateria, defensas, a.n)
            bajo, alto = intervalo_wilson(r["ataques_exitos"], r["ataques_n"])
            print("%-28s fugas %2d/%-3d IC95 [%.2f, %.2f] · el modelo filtró %2d · legítimas %2d/%-3d · %4.0f s" % (
                r["defensas"], r["ataques_exitos"], r["ataques_n"], bajo, alto, r["fugas_crudas"], r["legitimas_ok"],
                r["legitimas_n"], time.monotonic() - t0))
            resultados.append(r)
    ev = {"schema": "ai-ronin/evidence", "schema_version": 1, "kind": "medicion", "lab": "A1-05",
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
    p = argparse.ArgumentParser(description="Mide las defensas del mostrador contra el modelo real.")
    p.add_argument("--n", type=int, default=3, help="repeticiones de cada mensaje")
    p.add_argument("--configs", default=CONFIGS, help="configuraciones separadas por ';' (defensas separadas por ',')")
    asyncio.run(principal(p.parse_args()))


if __name__ == "__main__":
    main()
