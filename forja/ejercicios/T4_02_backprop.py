"""Ejercicio T4-02 · Backpropagation a mano (red 2-H-1) y gradient check.

Vas a escribir el corazón del deep learning: la pasada hacia delante, backpropagation
y la comprobación numérica de que tus gradientes son correctos.
Python que practicas: diccionarios como «estructuras», listas de listas, random.Random.

La red se guarda en un diccionario:
    red = {"W1": [[...], ...],  # H filas × 2 columnas (W1[j][k]: entrada k → oculta j)
           "b1": [...],         # H sesgos de la capa oculta
           "w2": [...],         # H pesos oculta → salida
           "b2": 0.0}           # sesgo de la salida
Activación oculta y de salida: sigmoide. Pérdida: entropía cruzada media.

Ejecuta los tests desde forja/ejercicios:
    python -m unittest -v test_T4_02_backprop
"""

import math
import random


def sigmoide(z):
    return 1.0 / (1.0 + math.exp(-z))


def crear_red(ocultas, semilla):
    """Pesos aleatorios uniformes en [−1, 1] con random.Random(semilla); sesgos a 0.0.

    Orden de generación: primero W1 fila a fila, después w2.
    """
    raise NotImplementedError("Tu turno: implementa crear_red")


def forward(red, x):
    """Devuelve (z1, a1, p): sumas de la capa oculta, sus activaciones y la probabilidad de salida.

        z1[j] = Σ_k W1[j][k]·x[k] + b1[j]     a1[j] = sigmoide(z1[j])
        p = sigmoide(Σ_j w2[j]·a1[j] + b2)
    """
    raise NotImplementedError("Tu turno: implementa forward")


def perdida(red, X, Y):
    """Entropía cruzada media sobre el lote (recorta p a [1e-12, 1 − 1e-12])."""
    raise NotImplementedError("Tu turno: implementa perdida")


def gradientes(red, X, Y):
    """Backpropagation. Devuelve un diccionario con la misma forma que la red
    ({"W1", "b1", "w2", "b2"}) que contiene la MEDIA de los gradientes del lote.

    Para cada ejemplo:
        d2 = p − y
        ∂w2[j] += d2·a1[j]          ∂b2 += d2
        d1[j] = d2·w2[j]·a1[j]·(1 − a1[j])        ← derivada de la sigmoide: σ·(1 − σ)
        ∂W1[j][k] += d1[j]·x[k]     ∂b1[j] += d1[j]
    Al final, divide todo entre el número de ejemplos.
    """
    raise NotImplementedError("Tu turno: implementa gradientes")


def paso(red, grads, lr):
    """Devuelve una red NUEVA con cada parámetro actualizado: parámetro − lr·gradiente."""
    raise NotImplementedError("Tu turno: implementa paso")


def gradiente_numerico(red, X, Y, ruta, eps=1e-5):
    """Gradiente por diferencias finitas centradas de UN parámetro:
        (pérdida(θ + eps) − pérdida(θ − eps)) / (2·eps)

    `ruta` identifica el parámetro: ("W1", j, k), ("b1", j), ("w2", j) o ("b2",).
    No modifiques `red`: trabaja sobre copias (copy.deepcopy te ayuda).
    """
    raise NotImplementedError("Tu turno: implementa gradiente_numerico")


def entrenar(X, Y, ocultas, lr, epocas, semilla):
    """Crea una red y la entrena. Devuelve (red, historial_de_perdidas) con la pérdida inicial incluida."""
    raise NotImplementedError("Tu turno: implementa entrenar")
