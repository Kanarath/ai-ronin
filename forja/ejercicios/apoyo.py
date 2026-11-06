"""Utilidades de apoyo para los tests (las escribe Claude; no forman parte del ejercicio)."""

import csv
from pathlib import Path

RAIZ_REPO = Path(__file__).resolve().parents[2]
RUTA_KATANAS = RAIZ_REPO / "game" / "content" / "datasets" / "katanas.csv"
FEATURES = ["dureza_hrc", "flexibilidad", "temperatura_temple"]


def cargar_katanas():
    """Devuelve (ids, X, y): ids de cada hoja, matriz de features (lista de listas) y etiquetas."""
    with open(RUTA_KATANAS, encoding="utf-8", newline="") as f:
        filas = list(csv.DictReader(f))
    ids = [fila["id"] for fila in filas]
    X = [[float(fila[c]) for c in FEATURES] for fila in filas]
    y = [fila["calidad"] for fila in filas]
    return ids, X, y
