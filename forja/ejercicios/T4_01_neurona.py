"""Ejercicio T4-01 · Una neurona desde cero.

Vas a programar la neurona de la misión T4-01: suma ponderada, sigmoide, entropía cruzada,
y un entrenamiento con descenso por gradiente.
Python que practicas: math.exp, math.log, zip() y funciones que devuelven varias cosas.

Ejecuta los tests desde forja/ejercicios:
    python -m unittest -v test_T4_01_neurona
"""

import math


def sigmoide(z):
    """1 / (1 + e^(−z)).

    Ejemplos: sigmoide(0) → 0.5 · sigmoide(10) ≈ 0.99995 · sigmoide(-10) ≈ 0.0000454
    """
    raise NotImplementedError("Tu turno: implementa sigmoide")


def neurona(x, pesos, sesgo):
    """Salida de la neurona: sigmoide(Σ pesos[i]·x[i] + sesgo).

    Ejemplo: neurona([1, 0], [10, 10], -5) ≈ 0.9933
    """
    raise NotImplementedError("Tu turno: implementa neurona")


def entropia_cruzada(p, y):
    """−[y·ln p + (1−y)·ln(1−p)], recortando p a [1e-12, 1 − 1e-12] para evitar ln(0).

    Ejemplo: entropia_cruzada(0.5, 1) = ln 2 ≈ 0.6931
    """
    raise NotImplementedError("Tu turno: implementa entropia_cruzada")


def entrenar_neurona(X, Y, lr, epocas, pesos_iniciales, sesgo_inicial=0.0):
    """Descenso por gradiente con todo el lote. Devuelve (pesos, sesgo, historial_de_perdidas).

    Con sigmoide + entropía cruzada, la derivada respecto a z es simplemente (p − y). Así:
        ∂pesos[i] = media de (p − y)·x[i]      ∂sesgo = media de (p − y)
    El historial empieza con la pérdida media INICIAL y añade la pérdida tras cada época.
    No modifiques la lista pesos_iniciales: trabaja sobre una copia.
    """
    raise NotImplementedError("Tu turno: implementa entrenar_neurona")
