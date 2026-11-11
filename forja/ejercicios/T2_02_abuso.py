"""Ejercicio T2-02 · Un detector de clientes que abusan del chatbot.

En el Dojo usaste `split`, `normalize`, `model` y escribiste la accuracy. Aquí construyes el
detector entero como lo haría un equipo de seguridad: lees el registro con el módulo csv, separas
un test que conserva la proporción de cada clase, metes el k-NN (k-Nearest Neighbors) en una
CLASE que recuerda cómo normalizar, lo comparas con una línea base y sacas la lista de abusadores
que se le escapan, para que un analista los revise.
Python que practicas: csv.DictReader, random.Random, clases (__init__, self, métodos),
sorted() con key y diccionarios. Ver PYTHON.md §7, §8, §10, §11 y §15.

Por qué: así se construye y se audita cualquier detector que aprende de casos revisados por
personas (abuso de una API, fraude, prompt injection). La línea base y la lista de fallos son lo
que separa «el modelo saca buena nota» de «sabemos qué ataques pasan y por qué».

Ejecuta los tests desde forja/ejercicios:
    python -m unittest -v test_T2_02_abuso
"""

import csv
import random

FEATURES = ["peticiones_hora", "tokens_medios", "rechazos"]


def cargar_peticiones(ruta):
    """Lee el CSV del registro de clientes y devuelve la tupla (ids, X, y).

    - ids: lista con la columna "id" (texto), por ejemplo "cli-001".
    - X: una fila por cliente con las columnas de FEATURES, EN ESE ORDEN y como float.
    - y: lista con la columna "tipo" ("abuso" o "normal").

    Usa csv.DictReader: cada fila llega como un diccionario {nombre de columna: texto}.
    Abre el fichero con encoding="utf-8" y newline="" (lo que recomienda el módulo csv).
    Ejemplo: la primera fila de peticiones.csv da "cli-001", [14.0, 120.0, 2.0] y "normal".
    """
    raise NotImplementedError("Tu turno: implementa cargar_peticiones")


def dividir_estratificado(y, proporcion_test, semilla):
    """Divide los índices 0..len(y)-1 en (indices_train, indices_test), ambos ORDENADOS,
    conservando en el test la misma proporción de cada clase que en todo el dataset.

    Pasos:
    1. rng = random.Random(semilla), UN solo generador para todo.
    2. Recorre las clases en orden alfabético: sorted(set(y)).
    3. Para cada clase: lista de sus índices, rng.shuffle(lista) y
       n_test = round(len(lista) * proporcion_test). Los n_test primeros van al test y el resto al train.
    4. Devuelve (sorted(train), sorted(test)).

    Por qué: con pocas muestras de una clase (los abusadores suelen ser pocos), un reparto al azar
    puede dejar el test casi sin ellos, y la nota no diría nada. scikit-learn lo llama stratify.
    """
    raise NotImplementedError("Tu turno: implementa dividir_estratificado")


class DetectorKNN:
    """k-NN con normalización min-max aprendida SOLO de los datos de entrenamiento.

    El objeto guarda lo que aprendió (mínimos, máximos y los ejemplos ya normalizados), así que
    cualquier cliente nuevo se normaliza con los números del train, nunca con los suyos.
    """

    def __init__(self, k):
        """Guarda k en self.k (si k < 1, lanza ValueError). El detector empieza sin entrenar:
        self.minimos = None, self.maximos = None, self.X = [] y self.y = []."""
        raise NotImplementedError("Tu turno: implementa __init__")

    def normalizar(self, x):
        """Normaliza un cliente x (lista de 3 floats) con los mínimos y máximos del train:
        (valor - mínimo) / (máximo - mínimo) en cada columna, o 0.0 si máximo == mínimo.

        No recortes: un cliente del test con más peticiones que nadie del train da un valor > 1.
        Si el detector no está entrenado (self.minimos is None), lanza RuntimeError.
        """
        raise NotImplementedError("Tu turno: implementa normalizar")

    def entrenar(self, X, y):
        """Aprende los mínimos y máximos de cada columna de X, guarda en self.X los ejemplos ya
        normalizados con self.normalizar y en self.y una copia de las etiquetas.
        Devuelve self, para poder escribir DetectorKNN(5).entrenar(X, y)."""
        raise NotImplementedError("Tu turno: implementa entrenar")

    def vecinos(self, x):
        """Los k ejemplos del train más cercanos a x (x SIN normalizar: normalízalo tú dentro).

        Devuelve una lista de tuplas (indice, distancia, etiqueta) ordenada por distancia
        euclídea ascendente; a igual distancia, va antes el índice menor (como en T2-01).
        """
        raise NotImplementedError("Tu turno: implementa vecinos")

    def predecir(self, x):
        """Clase de x por votación de sus k vecinos. Si varias clases empatan en votos, gana la
        del vecino que aparece ANTES en la lista de vecinos (la misma regla de T2-01)."""
        raise NotImplementedError("Tu turno: implementa predecir")

    def puntuacion(self, x, positiva):
        """Fracción de los k vecinos de x cuya etiqueta es `positiva`, entre 0.0 y 1.0.
        Con k=9 y 3 vecinos «abuso», puntuacion(x, "abuso") = 3/9. La usarás en T3-03."""
        raise NotImplementedError("Tu turno: implementa puntuacion")


def linea_base(y_train, y_test):
    """El «detector» que no mira nada: predice siempre la clase más frecuente del TRAIN.

    Devuelve la tupla (clase, accuracy de esa estrategia en y_test). Si dos clases empatan en el
    train, elige la primera en orden alfabético.
    Ejemplo: linea_base(["a", "b", "b"], ["a", "b", "b", "b"]) → ("b", 0.75)
    """
    raise NotImplementedError("Tu turno: implementa linea_base")


def se_escapan(ids, y_true, y_pred, positiva):
    """Lista ORDENADA de los ids cuya clase real es `positiva` y el detector no marcó como tal:
    los falsos negativos (FN, False Negatives), los abusadores que pasan.

    Ejemplo: se_escapan(["c1", "c2", "c3"], ["abuso", "abuso", "normal"],
                        ["normal", "abuso", "normal"], "abuso") → ["c1"]
    """
    raise NotImplementedError("Tu turno: implementa se_escapan")
