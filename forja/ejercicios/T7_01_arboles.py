"""Ejercicio T7-01…T7-04 · Árboles, bosques y k-means, en Python puro.

Vas a reproducir lo que hacen por dentro `tree train`, `forest train`, `kmeans` y
`kmeans outliers` del Dojo.
Python que practicas: diccionarios de conteo, ordenar con key, random.Random y listas de listas.

Ejecuta los tests desde forja/ejercicios:
    python -m unittest -v test_T7_01_arboles

Extra opcional con scikit-learn de verdad: extras/sklearn_T7_T10.py (lee su cabecera).
"""

import math
import random


def gini(etiquetas):
    """Impureza de Gini: 1 − suma de (veces de cada clase / n) al cuadrado. 0.0 si la lista está vacía.

    Ejemplo: gini(["abuso", "abuso", "normal", "normal"]) → 0.5
    """
    raise NotImplementedError("Tu turno: implementa gini")


def mejor_corte(valores, etiquetas):
    """El mejor umbral para una sola feature: el que deja las dos ramas más puras.

    Prueba como umbral el punto medio entre cada par de valores distintos consecutivos (ordenados).
    Rama izquierda: valor <= umbral; derecha: el resto.
    Gini ponderado = (n_izq / n) · gini(izq) + (n_der / n) · gini(der).
    Devuelve (umbral, gini_ponderado) con el gini ponderado más bajo; en un empate, el umbral más pequeño.
    Si todos los valores son iguales, no hay corte posible: devuelve (None, gini(etiquetas)).

    Ejemplo: mejor_corte([1, 2, 10, 11], ["a", "a", "b", "b"]) → (6.0, 0.0)
    """
    raise NotImplementedError("Tu turno: implementa mejor_corte")


def predecir(nodo, fila):
    """Recorre el árbol hasta una hoja.

    Un nodo interno es {"f": índice de la feature, "t": umbral, "izq": nodo, "der": nodo};
    una hoja es {"hoja": clase}. Se va a la izquierda si fila[f] <= t.
    """
    raise NotImplementedError("Tu turno: implementa predecir")


def muestra_bootstrap(n, semilla):
    """n índices entre 0 y n − 1 elegidos al azar CON repetición, con random.Random(semilla).randrange(n).

    Es la muestra que ve cada árbol de un bosque aleatorio.
    """
    raise NotImplementedError("Tu turno: implementa muestra_bootstrap")


def votar(predicciones):
    """La clase más votada. En un empate, la primera en orden alfabético.

    Ejemplo: votar(["abuso", "normal", "abuso"]) → "abuso"
    """
    raise NotImplementedError("Tu turno: implementa votar")


def asignar(puntos, centros):
    """Para cada punto, el índice del centro más cercano (distancia euclídea). En un empate, el de índice menor."""
    raise NotImplementedError("Tu turno: implementa asignar")


def mover_centros(puntos, asignacion, centros):
    """Cada centro pasa a ser la media de sus puntos (coordenada a coordenada).

    Si un centro se queda sin puntos, conserva su posición anterior. Devuelve una lista nueva.
    """
    raise NotImplementedError("Tu turno: implementa mover_centros")


def mas_raros(puntos, centro, n):
    """Índices de los n puntos más lejos del centro, de mayor a menor distancia (empates: índice menor primero)."""
    raise NotImplementedError("Tu turno: implementa mas_raros")
