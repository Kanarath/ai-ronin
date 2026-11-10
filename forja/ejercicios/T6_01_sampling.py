"""Ejercicio T6-01 · Modelo de bigramas y estrategias de muestreo.

Reproduces `lm train --order 2`, `lm next` y sus opciones --temperature y --top-p.

Ejecuta los tests desde forja/ejercicios:
    python -m unittest -v test_T6_01_sampling
"""

import re


def tokenizar(texto):
    r"""Minúsculas + re.findall(r"\w+|[^\w\s]", ...). Igual que el Dojo."""
    raise NotImplementedError("Tu turno: implementa tokenizar")


def contar_bigramas(tokens):
    """Diccionario {palabra: {siguiente: veces}} recorriendo pares consecutivos.

    Ejemplo: contar_bigramas(["a", "b", "a", "c"]) → {"a": {"b": 1, "c": 1}, "b": {"a": 1}}
    """
    raise NotImplementedError("Tu turno: implementa contar_bigramas")


def distribucion(cuentas, palabra):
    """Lista de (token, probabilidad) para lo que sigue a `palabra`, ordenada por probabilidad
    descendente y, en empate, alfabéticamente. Las probabilidades suman 1."""
    raise NotImplementedError("Tu turno: implementa distribucion")


def con_temperatura(dist, t):
    """Eleva cada probabilidad a 1/t y renormaliza. Si t == 0, devuelve [(mejor_token, 1.0)]."""
    raise NotImplementedError("Tu turno: implementa con_temperatura")


def top_p(dist, p):
    """Conserva los tokens más probables (dist ya ordenada) hasta que su suma sea >= p, y renormaliza."""
    raise NotImplementedError("Tu turno: implementa top_p")
