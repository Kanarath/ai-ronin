"""Ejercicio E3 · Auditoría en código: muestreo de controles, cobertura y severidad de los hallazgos.

En el Dojo elegiste a mano qué controles auditar, miraste expedientes al azar y clasificaste lo que
encontraste. Aquí escribes esas reglas: una muestra basada en el riesgo (con azar reproducible para
completarla), su cobertura, la clasificación de un hallazgo, la incertidumbre de una muestra de
expedientes (intervalo de Wilson) y el resumen ordenado por severidad.
Python que practicas: diccionarios, conjuntos, sorted con clave, random con semilla, math y excepciones
(PYTHON.md §3, §7, §8, §9, §11, §12).

AVISO: la clasificación (mayor, menor, observación) es una práctica de la industria simplificada; en una
auditoría real decide el juicio del auditor, documentado. Ejecuta los tests desde forja/ejercicios:
    python -m unittest -v test_E3_01_auditoria
"""

import math
import random

FUNCIONES = ["GOVERN", "MAP", "MEASURE", "MANAGE"]
ORDEN_RIESGO = {"alta": 0, "media": 1, "baja": 2}
SEVERIDAD = ["nc-mayor", "nc-menor", "observacion", "conforme"]
UMBRAL_SISTEMATICO = 0.2


def muestreo_por_riesgo(controles, maximo, semilla):
    """controles = [{"id": "C01", "funcion": "GOVERN", "riesgo": "media"}, ...]  (riesgo: alta|media|baja)

    Devuelve la lista ORDENADA de ids de la muestra, construida EN ESTE ORDEN:
      1. Todos los controles de riesgo "alta". Si son más que `maximo`, lanza ValueError.
      2. Para cada función de FUNCIONES (en ese orden) que exista en `controles` y no tenga todavía ningún
         control en la muestra, añade el de mayor riesgo de esa función (alta > media > baja; empate: el id
         menor). Si ya no cabe (la muestra ha llegado a `maximo`), lanza ValueError.
      3. Rellena hasta `maximo` con controles al azar de entre los que quedan fuera:
         random.Random(semilla).sample(restantes, k), con `restantes` = ids que faltan, ORDENADOS.
         Si quedan menos que los huecos, entran todos.
    """
    raise NotImplementedError("Tu turno: implementa muestreo_por_riesgo")


def cobertura(controles, muestra):
    """Devuelve {"total": fracción de controles en la muestra,
                 "por_funcion": {función: fracción de los controles de esa función que están en la muestra},
                 "alta": fracción de los controles de riesgo alta que están en la muestra (1.0 si no hay ninguno)}.
    "por_funcion" solo tiene las funciones que aparecen en `controles`. Los ids de `muestra` que no estén en
    `controles` se ignoran. Las fracciones son floats sin redondear.
    """
    raise NotImplementedError("Tu turno: implementa cobertura")


def clasificar_hallazgo(evaluacion):
    """evaluacion = {"control_existe": bool, "muestra": int, "fallos": int, "riesgo_futuro": bool}

    Primero valida: muestra y fallos son enteros >= 0 y fallos <= muestra; si no, ValueError.
    Después devuelve, comprobando EN ESTE ORDEN:
      "nc-mayor"    si el control no existe, o si muestra > 0 y fallos / muestra >= UMBRAL_SISTEMATICO;
      "nc-menor"    si hay algún fallo;
      "observacion" si no hay fallos pero sí riesgo_futuro;
      "conforme"    en otro caso.
    """
    raise NotImplementedError("Tu turno: implementa clasificar_hallazgo")


def intervalo_wilson(fallos, n, z=1.96):
    """Intervalo de Wilson de la tasa real de fallos a partir de una muestra: devuelve (bajo, alto).

    Con p = fallos / n:
        centro = (p + z² / (2n)) / (1 + z² / n)
        margen = z · sqrt(p(1 − p) / n + z² / (4n²)) / (1 + z² / n)
        (bajo, alto) = (max(0.0, centro − margen), min(1.0, centro + margen))
    Lanza ValueError si n <= 0 o si fallos no está entre 0 y n.
    Ejemplo: intervalo_wilson(3, 10) ≈ (0.108, 0.603).
    """
    raise NotImplementedError("Tu turno: implementa intervalo_wilson")


def resumen_auditoria(clasificaciones):
    """clasificaciones = {"C05": "nc-menor", "C08": "nc-mayor", ...}  (valores de SEVERIDAD)

    Lanza ValueError si algún valor no está en SEVERIDAD. Devuelve:
      {"conteo": {clase: n.º de controles, para LAS CUATRO clases de SEVERIDAD, aunque sea 0},
       "orden": ids ordenados por severidad (el orden de SEVERIDAD) y, a igual severidad, por id,
       "conclusion": "desfavorable" si hay alguna nc-mayor, "con-reservas" si hay alguna nc-menor,
                     "favorable" en otro caso}
    """
    raise NotImplementedError("Tu turno: implementa resumen_auditoria")
