"""Batería del laboratorio A2-06: calidad, latencia y manipulación de la recuperación con y sin
reordenador, contra los modelos REALES.

La ha escrito Claude (no es parte del ejercicio), pero usa TUS funciones de reranking.py. Necesita
Ollama con embeddinggemma (y llama3.2:1b para la configuración «llm»). El cross-encoder se descarga
solo la primera vez (unos 135 MB desde Hugging Face) y después funciona sin red.

    python bateria.py                       5 configuraciones (la de «llm» son 230 peticiones: varios minutos)
    python bateria.py --configs "ninguna;cross-encoder;procedencia;cross-encoder,procedencia"

Escribe la evidencia en forja/evidencias/A2-06-medicion.json; después, en el Dojo: evidence import
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

from reranking import (CE_REPO, Ajustes, Biblioteca, CrossEncoderONNX, ReordenadorLLM, buscar, cargar_documentos,
                       docs_unicos, ndcg_en_k, percentil, rango_reciproco, recall_en_k)

AQUI = Path(__file__).resolve().parent
SALIDA = AQUI.parents[2] / "forja" / "evidencias" / "A2-06-medicion.json"
CONFIGS = "ninguna;cross-encoder;llm;procedencia;cross-encoder,procedencia"


def interpretar(config):
    partes = {p for p in config.split(",") if p and p != "ninguna"}
    desconocidas = partes - {"cross-encoder", "llm", "procedencia"}
    if desconocidas or {"cross-encoder", "llm"} <= partes:
        raise SystemExit("configuración no válida: %s" % config)
    reord = "cross-encoder" if "cross-encoder" in partes else ("llm" if "llm" in partes else None)
    return reord, ("procedencia",) if "procedencia" in partes else ()


async def medir_config(cliente, biblioteca, reordenador, defensas, bateria, nombre):
    k, cand = bateria["k"], bateria["candidatos"]
    recall, mrr, ndcg, ms, top1_ok = [], [], [], [], 0
    for q in bateria["recuperacion"]["preguntas"]:
        frags, t = await buscar(cliente, biblioteca, reordenador, q["pregunta"], defensas, k=cand, candidatos=cand)
        docs = docs_unicos(frags)
        recall.append(recall_en_k(docs, q["relevancia"], k, umbral=2))
        mrr.append(rango_reciproco(docs, q["relevancia"], umbral=2))
        ndcg.append(ndcg_en_k(docs, q["relevancia"], k))
        ms.append(t)
        top1_ok += bool(docs) and q["relevancia"].get(docs[0], 0) == 2
    exitos = en_topk = 0
    posiciones = {}
    for a in bateria["ataques"]:
        frags, t = await buscar(cliente, biblioteca, reordenador, a["pregunta"], defensas, k=cand, candidatos=cand)
        docs = docs_unicos(frags)
        pos = docs.index(a["doc"]) + 1 if a["doc"] in docs else None
        posiciones[a["id"]] = pos
        exitos += pos == 1
        en_topk += pos is not None and pos <= k
        ms.append(t)
    n = len(recall)
    calidad = {"recall_en_k": round(sum(recall) / n, 3), "mrr": round(sum(mrr) / n, 3), "ndcg_en_k": round(sum(ndcg) / n, 3),
               "latencia_ms_p50": round(percentil(ms, 50), 1), "latencia_ms_p95": round(percentil(ms, 95), 1)}
    # Esquema común de las mediciones de la Forja: «ataques_exitos» = el documento del tercero quedó
    # el PRIMERO; «fugas_crudas» = entró en los k que verá el modelo; «legítimas» = preguntas en las
    # que el primer documento es el que responde (grado 2).
    return {"defensas": nombre, "ataques_n": len(bateria["ataques"]), "ataques_exitos": exitos, "fugas_crudas": en_topk,
            "legitimas_n": n, "legitimas_ok": top1_ok, "calidad": calidad, "posiciones": posiciones}


async def principal(a):
    ajustes = Ajustes.desde_entorno()
    ruta = AQUI / "ataques.json"
    bateria = json.loads(ruta.read_text(encoding="utf-8"))
    configs = [(c, *interpretar(c)) for c in a.configs.split(";")]
    print("Embeddings %s · puntuador LLM %s · cross-encoder %s" % (ajustes.modelo_embed, ajustes.modelo, CE_REPO))
    print("k = %d de %d candidatos · %d preguntas de calidad · %d documentos de terceros\n" % (
        bateria["k"], bateria["candidatos"], len(bateria["recuperacion"]["preguntas"]), len(bateria["ataques"])))
    resultados = []
    async with httpx2.AsyncClient(base_url=ajustes.ollama_url, timeout=ajustes.timeout) as cliente:
        biblioteca = Biblioteca(ajustes)
        t0 = time.monotonic()
        nf = await biblioteca.ingerir(cliente, cargar_documentos())
        print("Indexados %d fragmentos en %.0f s" % (nf, time.monotonic() - t0))
        reordenadores = {None: None, "cross-encoder": CrossEncoderONNX(), "llm": ReordenadorLLM(cliente, ajustes)}
        if any(r == "cross-encoder" for _, r, _ in configs):
            t0 = time.monotonic()
            await reordenadores["cross-encoder"]("calentamiento", ["carga el modelo antes de medir la latencia"])
            print("Cross-encoder cargado en %.0f s\n" % (time.monotonic() - t0))
        for nombre, reord, defensas in configs:
            t0 = time.monotonic()
            r = await medir_config(cliente, biblioteca, reordenadores[reord], defensas, bateria, nombre)
            c = r["calidad"]
            print("%-26s recall@%d %.2f · MRR %.2f · nDCG@%d %.2f · p50 %6.0f ms · p95 %6.0f ms · %4.0f s" % (
                nombre, bateria["k"], c["recall_en_k"], c["mrr"], bateria["k"], c["ndcg_en_k"], c["latencia_ms_p50"],
                c["latencia_ms_p95"], time.monotonic() - t0))
            print("%26s terceros: primeros %d/%d · en el top-%d %d/%d · posiciones %s" % (
                "", r["ataques_exitos"], r["ataques_n"], bateria["k"], r["fugas_crudas"], r["ataques_n"],
                " ".join("%s=%s" % (i.removeprefix("posicionar-"), p or "-") for i, p in r["posiciones"].items())))
            resultados.append(r)
    ev = {"schema": "ai-ronin/evidence", "schema_version": 1, "kind": "medicion", "lab": "A2-06",
          "created": datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat(),
          "modelo": "%s + %s + %s" % (ajustes.modelo_embed, CE_REPO, ajustes.modelo), "temperatura": 0.0, "repeticiones": 1,
          "bateria_sha256": hashlib.sha256(ruta.read_bytes().replace(b"\r\n", b"\n")).hexdigest(),
          "k": bateria["k"], "candidatos": bateria["candidatos"], "configuraciones": resultados}
    SALIDA.parent.mkdir(parents=True, exist_ok=True)
    SALIDA.write_text(json.dumps(ev, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print("\nEvidencia: %s · en el Dojo: evidence import" % SALIDA)


def main():
    for flujo in (sys.stdout, sys.stderr):
        if hasattr(flujo, "reconfigure"):
            flujo.reconfigure(encoding="utf-8", errors="replace")
    p = argparse.ArgumentParser(description="Mide la reordenación: calidad, latencia y documentos que se posicionan.")
    p.add_argument("--configs", default=CONFIGS, help="configuraciones separadas por ';' (piezas separadas por ',')")
    asyncio.run(principal(p.parse_args()))


if __name__ == "__main__":
    main()
