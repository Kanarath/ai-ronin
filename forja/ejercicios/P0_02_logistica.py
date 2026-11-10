"""Ejercicio P0-02 · Clases y NumPy: una regresión logística dos veces.

La regresión logística es la neurona de T4-01 con el descenso por gradiente de T3-01: una suma
ponderada, una sigmoide y la entropía cruzada. Hoy la escribes como una CLASE, primero en Python
puro y después vectorizada con NumPy, y mides cuánto ganas.
Python que practicas: clases (__init__, self, métodos), herencia, NumPy (arrays, @, axis,
broadcasting) y time.perf_counter. Ver PYTHON.md §15 y §16.

Necesitas NumPy 2.5.4 (versión fijada en requirements.txt). Desde forja/ejercicios:
    python -m venv .venv
    .\\.venv\\Scripts\\python.exe -m pip install -r requirements.txt
    .\\.venv\\Scripts\\python.exe -m unittest -v test_P0_02_logistica

Y para ver la comparación de tiempos cuando todo pase:
    .\\.venv\\Scripts\\python.exe P0_02_logistica.py
"""

import math
import time

import numpy as np


def estandarizar(X):
    """Z-score por columnas con NumPy. Devuelve la tupla (Xs, medias, desviaciones).

    X es una lista de listas o un array de forma (n, d). Usa np.asarray(X, dtype=float),
    .mean(axis=0) y .std(axis=0) (desviación poblacional, como en T1-02). Si una columna tiene
    desviación 0, divide entre 1.0 en su lugar (np.where te ayuda). Sin bucles.

    Ejemplo: estandarizar([[1, 5], [3, 5]]) → (array([[-1., 0.], [1., 0.]]), array([2., 5.]), array([1., 1.]))
    """
    raise NotImplementedError("Tu turno: implementa estandarizar")


def ampliar_cuadrados(Xs):
    """Devuelve un array (n, 2·d): las columnas de Xs seguidas de sus cuadrados.

    Una frontera recta no separa «demasiado duro O demasiado blando». Con la columna z² la
    regresión logística puede decir «lejos del centro → defectuosa». Usa np.hstack y Xs ** 2.

    Ejemplo: ampliar_cuadrados(np.array([[1., -2.]])) → array([[ 1., -2., 1., 4.]])
    """
    raise NotImplementedError("Tu turno: implementa ampliar_cuadrados")


class RegresionLogistica:
    """Regresión logística en Python puro (listas y bucles). X: lista de filas; y: lista de 0/1."""

    def __init__(self, lr=0.1, epocas=1000):
        """Guarda lr y epocas como atributos con el mismo nombre. El modelo empieza sin ajustar:
        self.pesos = None, self.sesgo = 0.0 y self.historial = [] (lista vacía)."""
        raise NotImplementedError("Tu turno: implementa __init__")

    def probabilidades(self, X):
        """Lista con sigmoide(Σ pesos[j]·x[j] + sesgo) para cada fila x de X.

        Si el modelo no está ajustado (self.pesos is None), lanza RuntimeError.
        """
        raise NotImplementedError("Tu turno: implementa probabilidades")

    def perdida(self, X, y):
        """Entropía cruzada media (como en T4-01), recortando p a [1e-12, 1 − 1e-12]."""
        raise NotImplementedError("Tu turno: implementa perdida")

    def ajustar(self, X, y):
        """Descenso por gradiente con todo el lote. Devuelve self (así se puede encadenar:
        modelo = RegresionLogistica().ajustar(X, y)).

        1. self.pesos = [0.0] * d (d = columnas) y self.sesgo = 0.0. Ajustar otra vez reinicia.
        2. self.historial empieza con la pérdida inicial.
        3. En cada una de las self.epocas épocas, con p calculadas ANTES de actualizar:
               pesos[j] −= lr · media de (p − y)·x[j]       sesgo −= lr · media de (p − y)
           y añade la pérdida tras la actualización. Al final, len(historial) == epocas + 1.
        """
        raise NotImplementedError("Tu turno: implementa ajustar")

    def predecir(self, X, umbral=0.5):
        """Lista de 1 (p >= umbral) o 0. Usa self.probabilidades: así la clase hija la hereda
        sin reescribirla."""
        raise NotImplementedError("Tu turno: implementa predecir")


class RegresionLogisticaNumPy(RegresionLogistica):
    """La misma regresión, vectorizada. Hereda __init__ y predecir: NO los reescribas.

    Aquí self.pesos es un array de forma (d,). Ningún método lleva bucles sobre los ejemplos
    (el bucle de las épocas sí es necesario).
    """

    def probabilidades(self, X):
        """Array (n,) con 1 / (1 + np.exp(−(X @ pesos + sesgo))). RuntimeError si no está ajustado."""
        raise NotImplementedError("Tu turno: implementa probabilidades (NumPy)")

    def perdida(self, X, y):
        """Entropía cruzada media con np.clip, np.log y np.mean. Devuelve un float de Python."""
        raise NotImplementedError("Tu turno: implementa perdida (NumPy)")

    def ajustar(self, X, y):
        """Igual que la versión pura, en matrices: con e = p − y (forma (n,)),
            gradiente de los pesos = X.T @ e / n        gradiente del sesgo = e.mean()
        Convierte X e y con np.asarray(..., dtype=float). Devuelve self."""
        raise NotImplementedError("Tu turno: implementa ajustar (NumPy)")


def cronometrar(modelo, X, y):
    """Segundos (float) que tarda modelo.ajustar(X, y), medidos con time.perf_counter()."""
    raise NotImplementedError("Tu turno: implementa cronometrar")


# ----- Lo de abajo lo ha escrito Claude: compara los tiempos cuando tus tests pasen. -----

def _comparar():
    from apoyo import cargar_katanas
    _, X, calidad = cargar_katanas()
    y = [1 if c == "defectuosa" else 0 for c in calidad]
    Xa = ampliar_cuadrados(estandarizar(X)[0])
    print("NumPy", np.__version__, "·", len(y), "katanas ·", Xa.shape[1], "columnas")
    for repeticiones in (1, 10, 50):
        Xg, yg = np.tile(Xa, (repeticiones, 1)), y * repeticiones
        puro = cronometrar(RegresionLogistica(0.5, 100), Xg.tolist(), yg)
        vect = cronometrar(RegresionLogisticaNumPy(0.5, 100), Xg, yg)
        print("%6d filas · Python puro %.3f s · NumPy %.4f s · ×%.0f" % (len(yg), puro, vect, puro / vect))


if __name__ == "__main__":
    _comparar()
