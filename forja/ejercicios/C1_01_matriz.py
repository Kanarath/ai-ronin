"""Ejercicio C1–C3 · La matriz de defensas, en código.

En el Dojo, lab matrix medía qué bloquea cada defensa por sí sola y lab resilience medía la
configuración activa. Aquí escribes el razonamiento que hiciste a mano: puntos únicos, cobertura
mínima sin coste y ataques frágiles.
Python que practicas: conjuntos, comprensiones, sorted e itertools.combinations (PYTHON.md §3, §4).

OJO: aquí se SUPONE que las defensas suman (si una bloquea un ataque en solitario, lo sigue
bloqueando acompañada). En C3-02 mediste un caso en que no es así: el código da una hipótesis
que luego se comprueba midiendo la combinación.

Todo es ficticio. Ejecuta los tests desde forja/ejercicios:
    python -m unittest -v test_C1_01_matriz
"""

from itertools import combinations


def bloqueado_por(matriz, ataque):
    """matriz = {"spotlight": {"bucle", ...}, "user-authz": {"diputado-confundido"}, ...}
    Devuelve la lista ORDENADA de defensas que bloquean `ataque` por sí solas.
    """
    raise NotImplementedError("Tu turno: implementa bloqueado_por")


def puntos_unicos(matriz, ataques):
    """Lista ORDENADA de los ataques que bloquea exactamente UNA defensa."""
    raise NotImplementedError("Tu turno: implementa puntos_unicos")


def cobertura_minima(matriz, ataques, con_coste=()):
    """Busca el conjunto MÁS PEQUEÑO de defensas, sin usar ninguna de `con_coste`, que bloquea
    todos los `ataques`. Prueba los conjuntos por tamaño: 0 (si no hay ataques, la respuesta es ()),
    luego 1, luego 2, etc. (combinations sobre las defensas ordenadas). Si hay varios del mismo tamaño, devuelve el primero que encuentres.
    Devuelve una tupla ordenada de defensas, o None si no hay ninguna cobertura posible.
    """
    raise NotImplementedError("Tu turno: implementa cobertura_minima")


def resiliencia(matriz, activas, ataques):
    """Con las defensas `activas` (suponiendo que suman), devuelve:
      {"pasan": lista ORDENADA de ataques que no bloquea ninguna activa,
       "fragiles": lista ORDENADA de ataques que bloquea exactamente una activa,
       "robustos": número de ataques que bloquean dos o más activas}
    """
    raise NotImplementedError("Tu turno: implementa resiliencia")
