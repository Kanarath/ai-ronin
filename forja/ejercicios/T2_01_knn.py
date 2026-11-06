"""Ejercicio T2-01 · k vecinos más cercanos (k-NN) desde cero.

Vas a reproducir `dataset split`, `model predict` y `model evaluate` del Dojo.
Python que practicas: random, sorted() con key, tuplas y diccionarios.

Puedes (¡y deberías!) reutilizar tu código del ejercicio anterior:
    from T1_02_distancia import distancia_euclidea

Ejecuta los tests desde forja/ejercicios:
    python -m unittest -v test_T2_01_knn
"""


def dividir(n, proporcion_test, semilla):
    """Divide los índices 0..n-1 en (indices_train, indices_test), ambos ORDENADOS.

    - Baraja los índices con random.Random(semilla).shuffle(...): misma semilla → misma división.
    - Tamaño del test = int(n * proporcion_test), como mínimo 1 y como máximo n - 1.
    - Los primeros n_test índices barajados van al test; el resto, al train.

    Ejemplo: dividir(10, 0.3, 42) → (7 índices, 3 índices), sin repetidos entre ambos.
    Nota: el Dojo usa otro generador aleatorio, así que tus índices no coincidirán con los
    suyos; lo que importa son las propiedades (tamaño, reproducible, sin solapamiento).
    """
    raise NotImplementedError("Tu turno: implementa dividir")


def vecinos(X_train, y_train, x, k):
    """Los k ejemplos de entrenamiento más cercanos a x.

    Devuelve una lista de tuplas (indice, distancia, etiqueta) ordenada por distancia
    ascendente; a igual distancia, va antes el índice menor (como en el Dojo).

    Pista: construye todas las tuplas y ordénalas con sorted(..., key=lambda t: (t[1], t[0])).
    """
    raise NotImplementedError("Tu turno: implementa vecinos")


def predecir(X_train, y_train, x, k):
    """Clase de x por votación de sus k vecinos.

    Regla de desempate (la misma del Dojo): si varias clases empatan en votos, gana la
    del vecino que aparece ANTES en la lista de vecinos (el más cercano).
    """
    raise NotImplementedError("Tu turno: implementa predecir")


def predecir_todos(X_train, y_train, X, k):
    """Predice cada fila de X. Devuelve una lista de etiquetas."""
    raise NotImplementedError("Tu turno: implementa predecir_todos")


def accuracy(y_true, y_pred):
    """Proporción de aciertos. Si las listas tienen distinta longitud, lanza ValueError.

    Ejemplo: accuracy(["a", "b", "b", "a"], ["a", "b", "a", "a"]) → 0.75
    """
    raise NotImplementedError("Tu turno: implementa accuracy")


def matriz_confusion(y_true, y_pred, clases):
    """Matriz de confusión: filas = clase real, columnas = clase predicha, en el orden de `clases`.

    Ejemplo: matriz_confusion(["a", "a", "b"], ["a", "b", "b"], ["a", "b"]) → [[1, 1], [0, 1]]
    """
    raise NotImplementedError("Tu turno: implementa matriz_confusion")
