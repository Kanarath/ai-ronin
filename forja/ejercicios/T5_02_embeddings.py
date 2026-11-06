"""Ejercicio T5-02 · Embeddings: similitud coseno, vecinos y analogías.

Reproduces `embed compare`, `embed similar` y `embed analogy` del Dojo.
La tabla es un diccionario: {"katana": [1.0, 0.8, 0.0, 0.0, 0.05, 0.3], ...}

Ejecuta los tests desde forja/ejercicios:
    python -m unittest -v test_T5_02_embeddings
"""


def coseno(a, b):
    """(a·b) / (|a|·|b|). Si algún vector tiene longitud 0, devuelve 0.0.

    Ejemplo: coseno([1, 0], [0, 1]) → 0.0 · coseno([2, 2], [1, 1]) → 1.0
    """
    raise NotImplementedError("Tu turno: implementa coseno")


def vecinos(tabla, vector, k, excluir=()):
    """Las k palabras cuyo vector tiene MAYOR coseno con `vector`, sin las de `excluir`.

    Devuelve una lista de tuplas (palabra, coseno) ordenada de mayor a menor coseno;
    en caso de empate, por orden alfabético.
    """
    raise NotImplementedError("Tu turno: implementa vecinos")


def analogia(tabla, a, b, c):
    """Palabra más cercana (coseno) a  tabla[a] − tabla[b] + tabla[c], excluyendo a, b y c.

    Ejemplo: analogia(tabla, "maestro", "hombre", "mujer") → "maestra"
    """
    raise NotImplementedError("Tu turno: implementa analogia")
