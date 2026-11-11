"""Ejercicio T4-03 · Llamadas peligrosas de un agente, con un modelo que se puede auditar.

En el Dojo viste que una neurona sola falla con las llamadas (el riesgo tiene forma de XOR), que
una red con 4 ocultas acierta todo pero no se puede explicar, y escribiste una regla legible.
Aquí das el paso que da un equipo real: añades una feature que mide el CRUCE de la frontera de
confianza, |origen − destino|, y con ella una neurona sola (una regresión logística) acierta y,
además, cada decisión se explica con tres números.
Python que practicas: csv.DictReader, comprensiones, math.exp, descenso por gradiente (T3-01 y
T4-01) y sorted() con key. Ver PYTHON.md §5, §7, §10 y §11.

Por qué: delante de un agente (un LLM, Large Language Model, que llama a herramientas) se pone un
clasificador que frena las llamadas de riesgo. Si un auditor pregunta «¿por qué bloqueaste
esta?», tienes que poder contestar. Elegir bien las features es a menudo lo que permite usar un
modelo simple y explicable en lugar de una caja negra.

Ejecuta los tests desde forja/ejercicios:
    python -m unittest -v test_T4_03_llamadas
"""

import csv
import math

MARGEN = 0.4


def cargar_llamadas(ruta):
    """Lee llamadas.csv con csv.DictReader y devuelve la tupla (ids, X, y):
    - ids: la columna "id";
    - X: una fila [confianza_origen, confianza_destino] por llamada, como float;
    - y: 1 si la columna "riesgo" es "peligrosa" y 0 si es "segura".
    Ejemplo: la primera llamada da "call-001", [0.2, 0.93] y 1.
    """
    raise NotImplementedError("Tu turno: implementa cargar_llamadas")


def motivo(origen, destino, margen=MARGEN):
    """La regla del analista, con el motivo escrito para el registro:
    - "fuga" si origen − destino > margen (datos de confianza que salen hacia fuera);
    - "entrada no fiable" si destino − origen > margen (datos de fuera que entran);
    - "" (texto vacío) si la llamada no cruza la frontera.
    Ejemplos: motivo(0.9, 0.1) → "fuga"; motivo(0.1, 0.9) → "entrada no fiable"; motivo(0.9, 0.85) → "".
    """
    raise NotImplementedError("Tu turno: implementa motivo")


def con_cruce(X):
    """Devuelve una lista NUEVA en la que cada fila [o, d] pasa a ser [o, d, |o − d|].
    La tercera feature es el cruce de la frontera de confianza. Usa abs()."""
    raise NotImplementedError("Tu turno: implementa con_cruce")


def sigmoide(z):
    """1 / (1 + e^(−z)) sin desbordarse: si z < 0, calcula e^z / (1 + e^z), que da lo mismo.
    Ejemplo: sigmoide(0) → 0.5; sigmoide(-1000) → 0.0 sin OverflowError."""
    raise NotImplementedError("Tu turno: implementa sigmoide")


def entrenar_logistica(X, y, epocas, lr):
    """Regresión logística (una neurona) con descenso por gradiente por lotes. Devuelve (pesos, sesgo).

    - Empieza con pesos = [0.0] * número de columnas y sesgo = 0.0.
    - En cada época, recorre TODOS los ejemplos y acumula, con err = sigmoide(z) − y:
      err · x[j] para cada peso j, y err para el sesgo.
    - Al final de la época, divide cada acumulado entre n y actualiza: w = w − lr · gradiente.
    Es el mismo bucle que entrenar_neurona de T4-01.
    """
    raise NotImplementedError("Tu turno: implementa entrenar_logistica")


def predecir(X, pesos, sesgo):
    """Lista con 1 si Σ pesos[j]·x[j] + sesgo ≥ 0 (probabilidad ≥ 0,5) y 0 si no, para cada fila."""
    raise NotImplementedError("Tu turno: implementa predecir")


def accuracy(y_true, y_pred):
    """Proporción de aciertos (como en T2-01)."""
    raise NotImplementedError("Tu turno: implementa accuracy")


def explicar(x, pesos, sesgo, nombres):
    """Explica una decisión: cuánto empuja cada feature hacia «peligrosa».

    Construye una tupla (nombre, contribución) por feature, con contribución = pesos[j] · x[j], y
    añade la tupla ("sesgo", sesgo). Devuelve todas ORDENADAS de mayor a menor valor absoluto de la
    contribución (a igualdad, por nombre). La suma de todas las contribuciones es z.
    Ejemplo: explicar([1, 2], [0.5, -2], 0.1, ["a", "b"]) → [("b", -4), ("a", 0.5), ("sesgo", 0.1)]
    """
    raise NotImplementedError("Tu turno: implementa explicar")
