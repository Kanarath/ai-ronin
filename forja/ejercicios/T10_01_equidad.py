"""Ejercicio T10-01…T10-03 · Medir la equidad de un sistema de decisión.

Vas a reproducir `fairness` y `fairness umbral` del Dojo con los mismos datos
(game/content/datasets/candidatos.csv y prestamos.csv).
Python que practicas: csv.DictReader, zip con filtros, diccionarios de diccionarios y None como «no hay».

Ejecuta los tests desde forja/ejercicios:
    python -m unittest -v test_T10_01_equidad

Extra opcional con scikit-learn de verdad: extras/sklearn_T7_T10.py (lee su cabecera).
"""

import csv


def cargar(ruta):
    """Lee un CSV con csv.DictReader y devuelve la lista de filas (diccionarios de texto)."""
    raise NotImplementedError("Tu turno: implementa cargar")


def tasa_seleccion(decisiones, grupos, g, favorable):
    """Fracción de las decisiones del grupo g que son la favorable. None si el grupo no tiene a nadie.

    Ejemplo: tasa_seleccion(["apta", "no_apta", "apta"], ["0", "0", "1"], "0", "apta") → 0.5
    """
    raise NotImplementedError("Tu turno: implementa tasa_seleccion")


def ratio_80(tasas):
    """La regla del 80 %: la tasa más baja dividida entre la más alta. 1.0 si la más alta es 0.

    tasas: {grupo: tasa}. Ejemplo: ratio_80({"0": 0.38, "1": 0.12}) → 0.3157…
    """
    raise NotImplementedError("Tu turno: implementa ratio_80")


def aprobar(puntuaciones, grupos, umbral, umbral1=None):
    """Lista de True/False: se aprueba si la puntuación llega al umbral (>=).

    Si umbral1 no es None, el grupo "1" usa umbral1 en lugar de umbral.
    """
    raise NotImplementedError("Tu turno: implementa aprobar")


def de_los_que_devuelven(aprobado, real_bueno):
    """Igualdad de oportunidades: de las posiciones con real_bueno True, la fracción aprobada. None si no hay ninguna."""
    raise NotImplementedError("Tu turno: implementa de_los_que_devuelven")


def precision(aprobado, real_bueno):
    """De los aprobados, la fracción con real_bueno True. None si no se aprueba a nadie."""
    raise NotImplementedError("Tu turno: implementa precision")


def informe_umbral(filas, umbral, umbral1=None, puntuacion="puntuacion", grupo="grupo", real="devuelve", bueno="si"):
    """El informe de `fairness umbral`.

    Devuelve {"grupos": {g: {"n", "base", "aprobados", "oportunidad", "precision"}}, "ratio": ratio_80 de las
    fracciones aprobadas, "diferencia_oportunidad": la mayor menos la menor}.
    "base" es la fracción del grupo con el resultado bueno y "aprobados" la fracción aprobada.
    Las puntuaciones vienen como texto en el CSV: conviértelas con float(). Los grupos son textos ("0", "1").
    """
    raise NotImplementedError("Tu turno: implementa informe_umbral")
