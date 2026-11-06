"""Ejercicio T6-02 · Self-attention desde cero.

Reproduces `attention` del Dojo: puntuaciones Q·Kᵀ/√d, softmax por filas y máscara causal.
(Aquí, como en el Dojo, Q = K = V = los vectores de entrada.)

Ejecuta los tests desde forja/ejercicios:
    python -m unittest -v test_T6_02_atencion
"""

import math


def softmax(fila):
    """exp(x − máx) / Σ exp(x − máx). Los valores float("-inf") deben dar peso 0.

    Restar el máximo no cambia el resultado pero evita desbordamientos con números grandes.
    Ejemplo: softmax([0, 0]) → [0.5, 0.5]
    """
    raise NotImplementedError("Tu turno: implementa softmax")


def pesos_atencion(vectores, causal=False, escalar=True):
    """Matriz n×n de pesos. Puntuación (i, j) = (vectores[i]·vectores[j]) / √d (si escalar).
    Con causal=True, las puntuaciones con j > i valen -inf. Después, softmax por filas."""
    raise NotImplementedError("Tu turno: implementa pesos_atencion")


def salida_atencion(vectores, pesos):
    """Nueva representación de cada posición: Σ_j pesos[i][j] · vectores[j]."""
    raise NotImplementedError("Tu turno: implementa salida_atencion")
