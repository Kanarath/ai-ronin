"""Batería del laboratorio A1-06: mide el juez contra etiquetas humanas y contra sus sesgos.

Lo ha escrito Claude (no es parte del ejercicio), pero usa TUS funciones de juez.py.
Necesita Ollama en marcha con llama3.2:1b. No necesita el servicio FastAPI.

    python bateria.py                         4 configuraciones, 2 repeticiones (unas 250 llamadas)
    python bateria.py --n 3 --configs "ninguna;intercambio,rubrica"

Configuraciones (mitigaciones del juez, separadas por comas):
    ninguna       rúbrica básica, cada par se juzga en un solo orden (alternando cuál va primero)
    rubrica       rúbrica detallada (criterios explícitos, «la longitud no es un mérito»…)
    intercambio   cada par se juzga en los dos órdenes y se combina con veredicto_equilibrado

Qué se mide (con el esquema común de las mediciones de la Forja):
    ataques  = pares de sesgo × repeticiones; éxito = el juez eligió la respuesta peor
    crudas   = pares en que el juez cambió de veredicto al cambiar el orden (sesgo de posición),
               aunque la mitigación lo tape después
    legítimas = respuestas con etiqueta humana × repeticiones; ok = el juez coincide con el humano
    Además: kappa de Cohen con su intervalo bootstrap, empates y respuestas sin formato válido.

Escribe la evidencia en forja/evidencias/A1-06-medicion.json; después, en el Dojo: evidence import
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

from juez import (RUBRICAS, UMBRAL_APROBADO, Ajustes, intervalo_bootstrap, intervalo_wilson, juzgar_par, juzgar_puntual,
                  kappa_cohen, porcentaje_acuerdo, veredicto_equilibrado)

AQUI = Path(__file__).resolve().parent
SALIDA = AQUI.parents[2] / "forja" / "evidencias" / "A1-06-medicion.json"
CONFIGS = "ninguna;rubrica;intercambio;intercambio,rubrica"
MITIGACIONES = ("rubrica", "intercambio")
INVERTIR = {"A": "B", "B": "A"}


def etiqueta(nota):
    return "nulo" if nota is None else ("bien" if nota >= UMBRAL_APROBADO else "mal")


async def medir_config(cliente, ajustes, bateria, mitigaciones, n):
    rubrica = RUBRICAS["detallada" if "rubrica" in mitigaciones else "basica"]
    equilibrado = "intercambio" in mitigaciones
    exitos = crudas = empates = nulos = 0
    tipos = {}
    for rep in range(n):
        for i, s in enumerate(bateria["sesgos"]):
            # Siempre se juzgan los dos órdenes: así se mide el sesgo de posición en todas las configuraciones.
            v1, _ = await juzgar_par(cliente, ajustes, s["pregunta"], s["mejor"], s["peor"], rubrica)  # A = mejor
            v2, _ = await juzgar_par(cliente, ajustes, s["pregunta"], s["peor"], s["mejor"], rubrica)  # A = peor
            crudas += v1 != INVERTIR.get(v2, v2)
            if equilibrado:
                final = veredicto_equilibrado(v1, v2)
            else:  # un solo orden, alternando, como haría un evaluador que no conoce el sesgo
                final = v1 if (rep + i) % 2 == 0 else INVERTIR.get(v2, v2)
            elige_peor = final == "B"
            exitos += elige_peor
            empates += final == "empate"
            nulos += final is None
            t = tipos.setdefault(s["tipo"], [0, 0])
            t[0] += elige_peor
            t[1] += 1
    humano, juez = [], []
    for _ in range(n):
        for p in bateria["puntuales"]:
            nota, _ = await juzgar_puntual(cliente, ajustes, p["pregunta"], p["respuesta"], rubrica)
            humano.append(p["humano"])
            juez.append(etiqueta(nota))
    legit_ok = sum(1 for h, j in zip(humano, juez) if h == j)
    return {"defensas": ",".join(mitigaciones) or "ninguna", "ataques_n": len(bateria["sesgos"]) * n, "ataques_exitos": exitos,
            "fugas_crudas": crudas, "legitimas_n": len(humano), "legitimas_ok": legit_ok,
            "sesgos_por_tipo": tipos, "empates": empates, "sin_formato_pares": nulos, "sin_formato_puntuales": juez.count("nulo"),
            "acuerdo": round(porcentaje_acuerdo(humano, juez), 3), "kappa": round(kappa_cohen(humano, juez), 3),
            "kappa_ic95": list(intervalo_bootstrap(humano, juez, kappa_cohen, 1000, semilla=0))}


async def principal(a):
    ajustes = Ajustes.desde_entorno()
    ruta = AQUI / "ataques.json"
    bateria = json.loads(ruta.read_text(encoding="utf-8"))
    configs = [tuple(d for d in c.split(",") if d and d != "ninguna") for c in a.configs.split(";")]
    for c in configs:
        if set(c) - set(MITIGACIONES):
            raise SystemExit("mitigación desconocida en %s (válidas: %s)" % (",".join(c), ", ".join(MITIGACIONES)))
    total = len(configs) * (2 * len(bateria["sesgos"]) + len(bateria["puntuales"])) * a.n
    print("Modelo %s · %d configuraciones · %d llamadas al juez (en CPU, unos segundos cada una)\n" % (ajustes.modelo, len(configs), total))
    resultados = []
    async with httpx2.AsyncClient(base_url=ajustes.ollama_url, timeout=ajustes.timeout) as cliente:
        for mitigaciones in configs:
            t0 = time.monotonic()
            r = await medir_config(cliente, ajustes, bateria, mitigaciones, a.n)
            bajo, alto = intervalo_wilson(r["ataques_exitos"], r["ataques_n"])
            print("%-22s engañado %2d/%-3d IC95 [%.2f, %.2f] · cambió con el orden %2d · acuerdo %2d/%-3d kappa %.2f IC95 [%.2f, %.2f] · %4.0f s" % (
                r["defensas"], r["ataques_exitos"], r["ataques_n"], bajo, alto, r["fugas_crudas"], r["legitimas_ok"], r["legitimas_n"],
                r["kappa"], r["kappa_ic95"][0], r["kappa_ic95"][1], time.monotonic() - t0))
            print("%-22s por tipo: %s · empates %d · sin formato %d+%d" % ("", ", ".join("%s %d/%d" % (k, v[0], v[1]) for k, v in r["sesgos_por_tipo"].items()),
                                                                          r["empates"], r["sin_formato_pares"], r["sin_formato_puntuales"]))
            resultados.append(r)
    ev = {"schema": "ai-ronin/evidence", "schema_version": 1, "kind": "medicion", "lab": "A1-06",
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
    p = argparse.ArgumentParser(description="Mide el juez contra etiquetas humanas y sus sesgos.")
    p.add_argument("--n", type=int, default=2, help="repeticiones de cada juicio")
    p.add_argument("--configs", default=CONFIGS, help="configuraciones separadas por ';' (mitigaciones separadas por ',')")
    asyncio.run(principal(p.parse_args()))


if __name__ == "__main__":
    main()
