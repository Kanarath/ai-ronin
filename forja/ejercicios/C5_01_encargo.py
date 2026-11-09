"""Ejercicio C5 · El motor de un encargo de red team.

En el Dojo, el encargo rechazaba hallazgos sin evidencia y solo cerraba los que pasaban el retest.
Aquí escribes esas reglas: validar un hallazgo, decidir si el retest lo cierra, priorizar los
hallazgos y resumir el encargo.
Python que practicas: re, diccionarios, tuplas, sorted con key y reverse (PYTHON.md §3, §4, §8).

Todo es ficticio. Ejecuta los tests desde forja/ejercicios:
    python -m unittest -v test_C5_01_encargo
"""

import re

PATRON_OWASP = r"^(LLM(0[1-9]|10)|ASI(0[1-9]|10))$"
IMPACTO = {"bajo": 1, "medio": 2, "alto": 3, "critico": 4}
EXPOSICION = {"interno": 1, "publico": 2}


def validar_hallazgo(activo_id, categoria, activos, evidencias):
    """activos = {"A-01": {"en_alcance": True, "amenazas": ["LLM01", ...]}, ...}
    evidencias = {"A-01": 11, ...} (ataques con éxito en la última batería sobre la copia del activo;
    un activo sin batería no aparece).

    Devuelve (aceptado, motivo), comprobando EN ESTE ORDEN:
      1. (False, "activo-desconocido") si activo_id no está en activos.
      2. (False, "fuera-de-alcance") si el activo no está en alcance.
      3. (False, "categoria-invalida") si categoria no cumple PATRON_OWASP.
      4. (False, "no-encaja") si categoria no está en las amenazas del activo.
      5. (False, "sin-evidencia") si no hay batería o tuvo 0 éxitos.
      6. (True, "ok").
    """
    raise NotImplementedError("Tu turno: implementa validar_hallazgo")


def estado_retest(exitos_despues, tasa_tareas):
    """Estado de un hallazgo tras el retest. exitos_despues es None si no hubo batería posterior;
    tasa_tareas es None si no se evaluaron las tareas legítimas. Devuelve, EN ESTE ORDEN:
      "abierto: sin batería" · "abierto: siguen los ataques" (exitos_despues > 0) ·
      "abierto: sin evaluar tareas" · "abierto: rompe tareas" (tasa_tareas < 1.0) · "corregido".
    """
    raise NotImplementedError("Tu turno: implementa estado_retest")


def priorizar(hallazgos):
    """hallazgos = [{"id": "H1", "impacto": "alto", "exposicion": "publico", "exitos": 11, "total": 11}, ...]

    Puntuación = IMPACTO[impacto] * EXPOSICION[exposicion] + exitos / total.
    Devuelve la lista de ids ordenada de MAYOR a menor puntuación (si empatan, por id ascendente).
    Fíjate: el número de éxitos solo desempata entre hallazgos de impacto y exposición parecidos.
    """
    raise NotImplementedError("Tu turno: implementa priorizar")


def resumen(estados):
    """estados = {"H1": "corregido", "H2": "abierto: rompe tareas", ...}
    Devuelve {"total": n, "corregidos": c, "abiertos": n - c, "cerrable": c == n and n > 0}.
    """
    raise NotImplementedError("Tu turno: implementa resumen")
