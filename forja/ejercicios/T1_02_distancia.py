"""Ejercicio T1-02 · Distancias y normalización, sin librerías.

Vas a reproducir `distance` y `dataset normalize` del Dojo.
Python que practicas: zip(), comprensiones de listas, tuplas y excepciones.

Un vector es una lista de floats: [dureza, flexibilidad, temperatura].
Una matriz X es una lista de vectores (una fila por hoja).

Ejecuta los tests desde forja/ejercicios:
    python -m unittest -v test_T1_02_distancia
"""


def distancia_euclidea(a, b):
    """√(Σ (aᵢ − bᵢ)²). Si los vectores tienen distinta longitud, lanza ValueError.

    Ejemplo: distancia_euclidea([0, 0], [3, 4]) → 5.0
    """
    raise NotImplementedError("Tu turno: implementa distancia_euclidea")


def distancia_manhattan(a, b):
    """Σ |aᵢ − bᵢ|. Si los vectores tienen distinta longitud, lanza ValueError.

    Ejemplo: distancia_manhattan([0, 0], [3, -4]) → 7.0
    """
    raise NotImplementedError("Tu turno: implementa distancia_manhattan")


def contribuciones(a, b):
    """Peso de cada feature en la distancia euclídea AL CUADRADO, como fracción entre 0 y 1.

    Cada peso es (aᵢ − bᵢ)² / Σ (aⱼ − bⱼ)². Los pesos suman 1.
    Si los vectores son idénticos (suma 0), devuelve una lista de ceros.
    Ejemplo: contribuciones([0, 0], [3, 4]) → [0.36, 0.64]
    """
    raise NotImplementedError("Tu turno: implementa contribuciones")


def ajustar_minmax(X):
    """FIT: aprende el (mínimo, máximo) de cada columna de X.

    Ejemplo: ajustar_minmax([[1, 10], [3, 30]]) → [(1, 3), (10, 30)]
    """
    raise NotImplementedError("Tu turno: implementa ajustar_minmax")


def aplicar_minmax(X, parametros):
    """TRANSFORM: (x − mín) / (máx − mín) en cada columna, con los parámetros DADOS.

    Devuelve una matriz NUEVA (no modifiques X). Si máx == mín, el valor es 0.0.
    Ojo: con parámetros aprendidos de otros datos, el resultado puede salir de [0, 1].
    Ejemplo: aplicar_minmax([[2, 20]], [(1, 3), (10, 30)]) → [[0.5, 0.5]]
    """
    raise NotImplementedError("Tu turno: implementa aplicar_minmax")


def ajustar_zscore(X):
    """FIT: aprende la (media, desviación típica POBLACIONAL) de cada columna de X.

    Ejemplo: ajustar_zscore([[1], [3]]) → [(2.0, 1.0)]
    Puedes reutilizar tus funciones del ejercicio T1-01 si quieres (from T1_01_estadisticas import media).
    """
    raise NotImplementedError("Tu turno: implementa ajustar_zscore")


def aplicar_zscore(X, parametros):
    """TRANSFORM: (x − media) / desviación en cada columna. Si la desviación es 0, el valor es 0.0.

    Ejemplo: aplicar_zscore([[1], [3]], [(2.0, 1.0)]) → [[-1.0], [1.0]]
    """
    raise NotImplementedError("Tu turno: implementa aplicar_zscore")
