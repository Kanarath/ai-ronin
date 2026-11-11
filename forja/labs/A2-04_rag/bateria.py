"""Batería del laboratorio A2-04: mide cada configuración de defensas contra los modelos REALES.

La ha escrito Claude (no es parte del ejercicio), pero usa TUS funciones de rag.py. Necesita
Ollama en marcha con llama3.2:1b y embeddinggemma descargados. No necesita el servicio FastAPI:
usa la Biblioteca y la tubería `responder` directamente. Qdrant: en memoria salvo que QDRANT_URL
apunte a un servidor (el de compose.yaml).

    python bateria.py                       5 configuraciones, 3 repeticiones (unos 165 mensajes)
    python bateria.py --n 2 --configs "ninguna;acl;acl,procedencia,spotlight"

Escribe la evidencia en forja/evidencias/A2-04-medicion.json; después, en el Dojo: evidence import
"""

import argparse
import asyncio
import datetime
import hashlib
import json
import math
import re
import sys
import time
from pathlib import Path

import httpx2

from rag import MODOS, Ajustes, Biblioteca, cargar_documentos, normalizar, recall_en_k, responder

AQUI = Path(__file__).resolve().parent
SALIDA = AQUI.parents[2] / "forja" / "evidencias" / "A2-04-medicion.json"
CONFIGS = "ninguna;acl;procedencia;spotlight;acl,procedencia,spotlight"


def sin_miles(texto):
    """«2.400», «2 400» y «2,400» cuentan como «2400»: el modelo escribe los números a su manera."""
    return re.sub(r"(?<=\d)[.\s,](?=\d{3}\b)", "", texto)


def contiene(texto, frases):
    t = normalizar(texto, espacios=False)
    return any(normalizar(f, espacios=False) in t for f in frases)


def wilson(exitos, n, z=1.96):
    """El intervalo que escribiste en A1-05 (aquí, copia de Claude para no depender de otro laboratorio)."""
    if n == 0:
        return 0.0, 1.0
    p = exitos / n
    d = 1 + z * z / n
    c = (p + z * z / (2 * n)) / d
    m = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / d
    return max(0.0, c - m), min(1.0, c + m)


async def medir_recuperacion(cliente, biblioteca, rec):
    """recall@k de cada modo de búsqueda, como empleado y sin defensas (calidad pura de la búsqueda)."""
    out = {}
    for modo in MODOS:
        valores = []
        for q in rec["preguntas"]:
            frags = await biblioteca.recuperar(cliente, q["pregunta"], "empleado", (), modo, k=rec["k"])
            docs = list(dict.fromkeys(f["doc"] for f in frags))
            valores.append(recall_en_k(docs, q["relevantes"], rec["k"]))
        out[modo] = round(sum(valores) / len(valores), 3)
    return out


async def medir_config(cliente, biblioteca, bateria, defensas, n):
    exitos = en_contexto = legit_ok = 0
    por_categoria = {}
    for atk in bateria["ataques"]:
        cat = por_categoria.setdefault(atk["categoria"], {"exitos": 0, "n": 0, "en_contexto": 0})
        for _ in range(n):
            r = await responder(cliente, biblioteca, atk["pregunta"], atk["rol"], defensas)
            ok = contiene(r["texto"], atk["exito_si"])
            vio = any(f.split("#")[0] == atk["doc"] for f in r["fuentes"])
            exitos += ok
            en_contexto += vio
            cat["exitos"] += ok
            cat["en_contexto"] += vio
            cat["n"] += 1
    for q in bateria["legitimas"]:
        for _ in range(n):
            r = await responder(cliente, biblioteca, q["pregunta"], q["rol"], defensas)
            t = sin_miles(normalizar(r["texto"], espacios=False))
            legit_ok += all(sin_miles(normalizar(e, espacios=False)) in t for e in q["espera"])
    # «fugas_crudas» es el nombre común de las mediciones de la Forja; en A2-04 cuenta las veces que
    # el documento del ataque llegó al contexto del modelo (lo que el modelo VIO, lo siguiera o no).
    return {"defensas": ",".join(sorted(defensas)) or "ninguna", "ataques_n": len(bateria["ataques"]) * n,
            "ataques_exitos": exitos, "fugas_crudas": en_contexto, "legitimas_n": len(bateria["legitimas"]) * n,
            "legitimas_ok": legit_ok, "por_categoria": por_categoria}


async def principal(a):
    ajustes = Ajustes.desde_entorno()
    ruta = AQUI / "ataques.json"
    bateria = json.loads(ruta.read_text(encoding="utf-8"))
    configs = [tuple(d for d in c.split(",") if d and d != "ninguna") for c in a.configs.split(";")]
    total = len(configs) * (len(bateria["ataques"]) + len(bateria["legitimas"])) * a.n
    print("Modelo %s · embeddings %s · Qdrant %s" % (ajustes.modelo, ajustes.modelo_embed, ajustes.qdrant_url or "en memoria"))
    async with httpx2.AsyncClient(base_url=ajustes.ollama_url, timeout=ajustes.timeout) as cliente:
        biblioteca = Biblioteca(ajustes)
        t0 = time.monotonic()
        nf = await biblioteca.ingerir(cliente, cargar_documentos())
        print("Indexados %d fragmentos en %.0f s" % (nf, time.monotonic() - t0))
        recuperacion = await medir_recuperacion(cliente, biblioteca, bateria["recuperacion"])
        print("recall@%d (empleado, sin defensas): %s\n" % (bateria["recuperacion"]["k"],
              " · ".join("%s %.2f" % kv for kv in recuperacion.items())))
        print("%d configuraciones · %d mensajes (en CPU, varios segundos cada uno)\n" % (len(configs), total))
        resultados = []
        for defensas in configs:
            t0 = time.monotonic()
            r = await medir_config(cliente, biblioteca, bateria, defensas, a.n)
            bajo, alto = wilson(r["ataques_exitos"], r["ataques_n"])
            print("%-28s éxito %2d/%-3d IC95 [%.2f, %.2f] · en contexto %2d · legítimas %2d/%-3d · %4.0f s" % (
                r["defensas"], r["ataques_exitos"], r["ataques_n"], bajo, alto, r["fugas_crudas"], r["legitimas_ok"],
                r["legitimas_n"], time.monotonic() - t0))
            print("%28s %s" % ("", " · ".join("%s %d/%d (en contexto %d)" % (k, v["exitos"], v["n"], v["en_contexto"])
                                                for k, v in r["por_categoria"].items())))
            resultados.append(r)
    ev = {"schema": "ai-ronin/evidence", "schema_version": 1, "kind": "medicion", "lab": "A2-04",
          "created": datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat(),
          "modelo": "%s + %s" % (ajustes.modelo, ajustes.modelo_embed), "temperatura": ajustes.temperatura,
          "repeticiones": a.n, "bateria_sha256": hashlib.sha256(ruta.read_bytes().replace(b"\r\n", b"\n")).hexdigest(),
          "recuperacion": recuperacion, "configuraciones": resultados}
    SALIDA.parent.mkdir(parents=True, exist_ok=True)
    SALIDA.write_text(json.dumps(ev, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print("\nEvidencia: %s · en el Dojo: evidence import" % SALIDA)


def main():
    for flujo in (sys.stdout, sys.stderr):
        if hasattr(flujo, "reconfigure"):
            flujo.reconfigure(encoding="utf-8", errors="replace")
    p = argparse.ArgumentParser(description="Mide las defensas de la biblioteca contra los modelos reales.")
    p.add_argument("--n", type=int, default=3, help="repeticiones de cada pregunta")
    p.add_argument("--configs", default=CONFIGS, help="configuraciones separadas por ';' (defensas separadas por ',')")
    asyncio.run(principal(p.parse_args()))


if __name__ == "__main__":
    main()
