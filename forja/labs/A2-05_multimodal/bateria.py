"""Batería del laboratorio A2-05: cuántas instrucciones ocultas llegan al índice, al contexto y a la
respuesta con cada ingesta, y cuánto cuesta cada defensa en documentos legítimos.

La ha escrito Claude (no es parte del ejercicio), pero usa TUS funciones de multimodal.py.

    python bateria.py                     5 configuraciones, 2 repeticiones (unos 160 mensajes; llama3.2:1b + embeddinggemma)
    python bateria.py --solo-ingesta      sin modelos: solo qué llega al índice (segundos)
    python bateria.py --vision            además, la imagen con texto casi invisible (qwen3-vl:2b, 1,9 GB)
    python bateria.py --n 1 --configs "ninguna;visibilidad,invisibles,normalizacion,filtro"

Escribe la evidencia en forja/evidencias/A2-05-medicion.json; después, en el Dojo: evidence import
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

from multimodal import (FUENTES, Ajustes, Indice, aparece, auditar_ingesta, cargar_fuentes, contiene_literal, huella,
                        responder, transcribir_imagen)

AQUI = Path(__file__).resolve().parent
SALIDA = AQUI.parents[2] / "forja" / "evidencias" / "A2-05-medicion.json"
CONFIGS = "ninguna;visibilidad;filtro;visibilidad,invisibles;visibilidad,invisibles,normalizacion,filtro"


def sin_modelo():
    """Transporte que devuelve vectores nulos: para --solo-ingesta no hace falta Ollama."""
    def manejar(peticion):
        n = len(json.loads(peticion.content).get("input", []))
        return httpx2.Response(200, json={"embeddings": [[0.0, 1.0]] * n})
    return httpx2.MockTransport(manejar)


async def medir_config(cliente, ajustes, bateria, fuentes, defensas, n, con_modelo):
    indice = Indice(ajustes, defensas)
    await indice.ingerir(cliente, fuentes)
    ing = auditar_ingesta(indice, bateria)
    por_canal = {a["canal"]: {"en_indice": ing["por_canal"][a["canal"]], "en_contexto": 0, "exitos": 0, "n": 0}
                 for a in bateria["ataques"]}
    if not con_modelo:  # cada ataque cuenta una vez: «éxito» = la instrucción llegó al índice
        e = ing["instrucciones_en_indice"]
        return {"defensas": ",".join(defensas) or "ninguna", "ataques_n": ing["instrucciones_n"], "ataques_exitos": e,
                "fugas_crudas": e, "legitimas_n": ing["legitimas_n"], "legitimas_ok": ing["legitimas_en_indice"],
                "ingesta": ing, "por_canal": por_canal}
    exitos = en_contexto = legit_ok = 0
    for a in bateria["ataques"]:
        c = por_canal[a["canal"]]
        for _ in range(n):
            r = await responder(cliente, indice, a["pregunta"])
            ok, vio = aparece(a["marca"], r["texto"]), aparece(a["marca"], r["contexto"])
            exitos += ok
            en_contexto += vio
            c["exitos"] += ok
            c["en_contexto"] += vio
            c["n"] += 1
    perdidas = []
    for q in bateria["legitimas"]:
        for _ in range(n):
            r = await responder(cliente, indice, q["pregunta"])
            bien = contiene_literal(r["texto"], q["espera"])
            legit_ok += bien
            if not bien:
                perdidas.append(q["pregunta"])
    # «fugas_crudas» (nombre común de las mediciones de la Forja) cuenta aquí las veces que la
    # instrucción oculta llegó al CONTEXTO del modelo, la obedeciera o no.
    return {"defensas": ",".join(defensas) or "ninguna", "ataques_n": len(bateria["ataques"]) * n, "ataques_exitos": exitos,
            "fugas_crudas": en_contexto, "legitimas_n": len(bateria["legitimas"]) * n, "legitimas_ok": legit_ok,
            "legitimas_falladas": sorted(set(perdidas)), "ingesta": ing, "por_canal": por_canal}


async def medir_vision(cliente, ajustes, vision, n):
    out = []
    for img in vision["imagenes"]:
        datos = (FUENTES / img["fichero"]).read_bytes()
        if huella(datos) != img["sha256"]:
            raise SystemExit("La imagen %s no coincide con la original." % img["fichero"])
        hits, ejemplo = 0, ""
        for _ in range(n):
            t = await transcribir_imagen(cliente, ajustes, datos)
            hits += aparece(img["marca"], t)
            ejemplo = ejemplo or t[:300]
        out.append({"fichero": img["fichero"], "contraste": img["contraste"], "n": n, "con_instruccion": hits, "ejemplo": ejemplo})
        print("  %-20s %-24s instrucción transcrita %d/%d" % (img["fichero"], img["contraste"], hits, n))
    return {"modelo": ajustes.modelo_vision, "imagenes": out}


def imprimir(r, con_modelo):
    ing = r["ingesta"]
    linea = "%-44s índice %2d/%d · legítimas en índice %d/%d · cuarentena %2d" % (
        r["defensas"], ing["instrucciones_en_indice"], ing["instrucciones_n"], ing["legitimas_en_indice"], ing["legitimas_n"],
        ing["en_cuarentena"])
    if con_modelo:
        linea += "\n%44s contexto %2d/%d · obedecidas %2d/%d · legítimas bien %2d/%d" % (
            "", r["fugas_crudas"], r["ataques_n"], r["ataques_exitos"], r["ataques_n"], r["legitimas_ok"], r["legitimas_n"])
    print(linea)
    print("%44s llegan al índice: %s" % ("", ", ".join(k for k, v in r["por_canal"].items() if v["en_indice"]) or "ninguna"))
    if ing["legitimas_perdidas"]:
        print("%44s legítimas perdidas en la ingesta: %s" % ("", " | ".join(ing["legitimas_perdidas"])))


async def principal(a):
    ajustes = Ajustes.desde_entorno()
    ruta = AQUI / "ataques.json"
    bateria = json.loads(ruta.read_text(encoding="utf-8"))
    fuentes = cargar_fuentes(bateria)
    configs = [tuple(d for d in c.split(",") if d and d != "ninguna") for c in a.configs.split(";")]
    con_modelo = not a.solo_ingesta
    if con_modelo:
        total = len(configs) * (len(bateria["ataques"]) + len(bateria["legitimas"])) * a.n
        print("Modelo %s · embeddings %s · %d configuraciones · %d mensajes (en CPU, varios segundos cada uno)\n" % (
            ajustes.modelo, ajustes.modelo_embed, len(configs), total))
    else:
        print("Solo ingesta (sin modelos) · %d configuraciones\n" % len(configs))
    resultados = []
    async with httpx2.AsyncClient(base_url=ajustes.ollama_url, timeout=ajustes.timeout) as cliente:
        for defensas in configs:
            t0 = time.monotonic()
            r = await medir_config(cliente if con_modelo else _SinModelo.cliente(), ajustes, bateria, fuentes, defensas,
                                   a.n, con_modelo)
            imprimir(r, con_modelo)
            print("%44s %.0f s\n" % ("", time.monotonic() - t0))
            resultados.append(r)
        vision = None
        if a.vision:
            print("Visión: %s transcribe cada imagen %d veces" % (ajustes.modelo_vision, a.n))
            vision = await medir_vision(cliente, ajustes, bateria["vision"], a.n)
    await _SinModelo.cerrar()
    ev = {"schema": "ai-ronin/evidence", "schema_version": 1, "kind": "medicion", "lab": "A2-05",
          "created": datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat(),
          "modelo": "%s + %s" % (ajustes.modelo, ajustes.modelo_embed) if con_modelo else "ninguno (solo ingesta)",
          "nivel": "respuesta" if con_modelo else "ingesta", "temperatura": ajustes.temperatura,
          "repeticiones": a.n if con_modelo else 1,
          "bateria_sha256": hashlib.sha256(ruta.read_bytes().replace(b"\r\n", b"\n")).hexdigest(),
          "configuraciones": resultados}
    if vision:
        ev["vision"] = vision
    SALIDA.parent.mkdir(parents=True, exist_ok=True)
    SALIDA.write_text(json.dumps(ev, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print("Evidencia: %s · en el Dojo: evidence import" % SALIDA)


class _SinModelo:
    """Un cliente con vectores nulos para medir la ingesta sin Ollama (se crea una vez)."""
    _c = None

    @classmethod
    def cliente(cls):
        if cls._c is None:
            cls._c = httpx2.AsyncClient(base_url="http://sin-modelo.invalid", transport=sin_modelo())
        return cls._c

    @classmethod
    async def cerrar(cls):
        if cls._c is not None:
            await cls._c.aclose()
            cls._c = None


def main():
    for flujo in (sys.stdout, sys.stderr):
        if hasattr(flujo, "reconfigure"):
            flujo.reconfigure(encoding="utf-8", errors="replace")
    p = argparse.ArgumentParser(description="Mide qué instrucciones ocultas llegan al índice, al contexto y a la respuesta.")
    p.add_argument("--n", type=int, default=2, help="repeticiones de cada pregunta (y de cada imagen con --vision)")
    p.add_argument("--configs", default=CONFIGS, help="configuraciones separadas por ';' (defensas separadas por ',')")
    p.add_argument("--solo-ingesta", action="store_true", help="sin modelos: solo lo que llega al índice")
    p.add_argument("--vision", action="store_true", help="mide también las imágenes con un modelo de visión (Ollama)")
    asyncio.run(principal(p.parse_args()))


if __name__ == "__main__":
    main()
