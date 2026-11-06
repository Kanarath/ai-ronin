"""Utilidades de apoyo para los tests (las escribe Claude; no forman parte del ejercicio)."""

import csv
from pathlib import Path

RAIZ_REPO = Path(__file__).resolve().parents[2]
RUTA_KATANAS = RAIZ_REPO / "game" / "content" / "datasets" / "katanas.csv"
FEATURES = ["dureza_hrc", "flexibilidad", "temperatura_temple"]


RUTA_TEMPLE = RAIZ_REPO / "game" / "content" / "datasets" / "temple.csv"


def cargar_temple():
    """Devuelve (xs, ys): minutos de enfriado y dureza de cada hoja del dataset temple."""
    with open(RUTA_TEMPLE, encoding="utf-8", newline="") as f:
        filas = list(csv.DictReader(f))
    return [float(f["minutos_enfriado"]) for f in filas], [float(f["dureza_hrc"]) for f in filas]


RUTA_CORPUS = RAIZ_REPO / "game" / "content" / "corpus" / "forja.txt"
RUTA_EMBEDDINGS = RAIZ_REPO / "game" / "content" / "embeddings" / "forja_emb.json"


def cargar_corpus():
    """Texto completo del corpus de la forja (el mismo que usa el Dojo)."""
    return RUTA_CORPUS.read_text(encoding="utf-8")


def cargar_embeddings():
    """Diccionario palabra -> lista de 6 floats (tabla de embeddings del Dojo)."""
    import json
    datos = json.loads(RUTA_EMBEDDINGS.read_text(encoding="utf-8"))
    return {palabra: info["vector"] for palabra, info in datos["words"].items()}


RUTA_KB = RAIZ_REPO / "game" / "content" / "rag" / "kb_forja.json"


def cargar_kb():
    """Lista de documentos de la forja: diccionarios con id, title, source, access y text."""
    import json
    return json.loads(RUTA_KB.read_text(encoding="utf-8"))["documents"]


def cargar_katanas():
    """Devuelve (ids, X, y): ids de cada hoja, matriz de features (lista de listas) y etiquetas."""
    with open(RUTA_KATANAS, encoding="utf-8", newline="") as f:
        filas = list(csv.DictReader(f))
    ids = [fila["id"] for fila in filas]
    X = [[float(fila[c]) for c in FEATURES] for fila in filas]
    y = [fila["calidad"] for fila in filas]
    return ids, X, y
