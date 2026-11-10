"""Ejercicio P0-03 · El MLP de T4-02 en matrices.

En T4-02 escribiste backpropagation ejemplo a ejemplo, con listas y bucles. Así se entiende;
así NO se entrena una red de verdad. Hoy la misma red (entradas → H ocultas → 1 salida, sigmoide
en las dos capas, entropía cruzada media) procesa TODO el lote a la vez con productos de matrices.
Es lo que hacen PyTorch o JAX por debajo.
Python que practicas: una clase con estado (los pesos son atributos), arrays 2D, @, .T,
broadcasting de los sesgos, sum(axis=0) y np.random.default_rng. Ver PYTHON.md §15 y §16.

Convención de formas (n ejemplos, d entradas, H ocultas):
    X  (n, d)     W1 (d, H)     b1 (H,)      A1 (n, H)
    Y  (n, 1)     W2 (H, 1)     b2 (1,)      P  (n, 1)
Ojo: W1 está traspuesta respecto a T4-02 (allí W1[j][k]; aquí W1[k, j]), para escribir X @ W1.

Desde forja/ejercicios, con el entorno de P0-02:
    .\\.venv\\Scripts\\python.exe -m unittest -v test_P0_03_mlp
"""

import numpy as np


def sigmoide(Z):
    """Sigmoide elemento a elemento de un array (la escribe Claude: ya la hiciste en T4-01)."""
    return 1.0 / (1.0 + np.exp(-Z))


class MLP:
    def __init__(self, entradas, ocultas, semilla=0):
        """Crea los pesos con rng = np.random.default_rng(semilla):
            self.W1 = rng.uniform(−1, 1, size=(entradas, ocultas))   ← primero W1
            self.W2 = rng.uniform(−1, 1, size=(ocultas, 1))          ← después W2
            self.b1 = np.zeros(ocultas)      self.b2 = np.zeros(1)
        Misma semilla → misma red."""
        raise NotImplementedError("Tu turno: implementa __init__")

    def forward(self, X):
        """Devuelve (A1, P) para todo el lote, sin bucles:
            A1 = sigmoide(X @ W1 + b1)       P = sigmoide(A1 @ W2 + b2)
        Sumar b1 (forma (H,)) a una matriz (n, H) suma el sesgo a cada fila: broadcasting.
        Acepta listas: empieza con X = np.asarray(X, dtype=float)."""
        raise NotImplementedError("Tu turno: implementa forward")

    def perdida(self, X, Y):
        """Entropía cruzada media (float de Python), con P recortada a [1e-12, 1 − 1e-12]."""
        raise NotImplementedError("Tu turno: implementa perdida")

    def gradientes(self, X, Y):
        """Backpropagation en matrices. Devuelve {"W1", "b1", "W2", "b2"}, cada gradiente con la
        MISMA FORMA que su parámetro, y la media del lote ya incluida:
            D2  = (P − Y) / n                         (n, 1)
            ∂W2 = A1.T @ D2      ∂b2 = D2.sum(axis=0)
            D1  = (D2 @ W2.T) · A1 · (1 − A1)         (n, H)   ← producto elemento a elemento
            ∂W1 = X.T @ D1       ∂b1 = D1.sum(axis=0)
        Compara con T4-02: el bucle «para cada ejemplo» ha desaparecido dentro de los @.
        No modifica la red."""
        raise NotImplementedError("Tu turno: implementa gradientes")

    def paso(self, grads, lr):
        """Actualiza la red EN EL SITIO (a diferencia de T4-02): self.W1 −= lr · grads["W1"], etc.
        No devuelve nada."""
        raise NotImplementedError("Tu turno: implementa paso")

    def entrenar(self, X, Y, lr, epocas):
        """`epocas` pasos de descenso por gradiente con todo el lote. Devuelve el historial de
        pérdidas (lista de floats) con la inicial incluida: epocas + 1 valores."""
        raise NotImplementedError("Tu turno: implementa entrenar")

    def predecir(self, X):
        """Array de enteros de forma (n,): 1 si P >= 0.5, si no 0. Pista: P[:, 0] y .astype(int)."""
        raise NotImplementedError("Tu turno: implementa predecir")
