"""Laboratorio E2-01 · Ejemplos adversarios: engañar a tu propio clasificador de dígitos.

Entrenas un clasificador de dígitos manuscritos (regresión logística multiclase, en NumPy) y lo
atacas con FGSM (Fast Gradient Sign Method, Goodfellow et al. 2014): cambias cada píxel un poco,
como mucho `epsilon`, en la dirección que más aumenta la pérdida. La imagen casi no cambia para
una persona; para el modelo, sí. Después mides dos defensas y su coste:

  - entrenamiento adversario: entrenar también con ejemplos atacados;
  - detección por compresión de la entrada (feature squeezing, Xu et al. 2018): si la predicción
    cambia mucho al reducir la profundidad de color de la imagen, la entrada es sospechosa.

Tú implementas las funciones marcadas con «Tu turno». Claude ha escrito el resto (la carga de
datos, la clase Clasificador, el Detector y bateria.py).

Todo es local y en CPU: los datos son los dígitos 8×8 que trae scikit-learn (no se descarga nada).
Tests:
    python -m unittest -v test_evasion
"""

import math

import numpy as np
from sklearn.datasets import load_digits
from sklearn.model_selection import train_test_split

CLASES = 10
DIMENSION = 64  # imágenes de 8×8 píxeles, aplanadas


# ─────────────────────────────── Tu turno ───────────────────────────────

def softmax(Z):
    """Softmax por filas de una matriz Z (n × k) de logits: cada fila pasa a ser una distribución
    de probabilidad (valores en [0, 1] que suman 1).
    Estable numéricamente: resta a cada fila su máximo antes de exponenciar, para que
    softmax([[1000, 1000]]) dé [[0.5, 0.5]] y no nan. Devuelve un array nuevo de la misma forma.
    """
    raise NotImplementedError("Tu turno: implementa softmax")


def gradiente_entrada(W, b, X, y):
    """Gradiente de la pérdida de entropía cruzada respecto a la ENTRADA X (no a los pesos).
    El modelo es P = softmax(X @ W + b), con W de forma (d, k), b de forma (k,), X de forma (n, d)
    e y un array de n etiquetas enteras en [0, k).
    Para cada ejemplo, la pérdida es -ln P[i, y_i] y su gradiente respecto a la fila X[i] es
        (P[i] - onehot(y_i)) @ W.T
    Devuelve un array (n, d). Es la PÉRDIDA DE CADA EJEMPLO, sin dividir entre n: a FGSM solo le
    importa el signo, pero así el valor coincide con el de los tests.
    """
    raise NotImplementedError("Tu turno: implementa gradiente_entrada")


def fgsm(X, gradiente, epsilon, bajo=0.0, alto=1.0):
    """Ejemplos adversarios con FGSM: X + epsilon * signo(gradiente), recortado a [bajo, alto]
    (los píxeles válidos). Donde el gradiente es 0, el píxel no cambia (np.sign(0) es 0).
    No modifica X: devuelve un array nuevo de la misma forma.
    ValueError si epsilon < 0. Con epsilon = 0 devuelve una copia de X (recortada).
    """
    raise NotImplementedError("Tu turno: implementa fgsm")


def curva_epsilon(modelo, X, y, epsilons):
    """Precisión (accuracy) del modelo frente a FGSM para cada epsilon de la lista, en el mismo
    orden. Para cada epsilon: calcula el gradiente respecto a la entrada con los pesos ACTUALES
    del modelo (modelo.W, modelo.b) y las etiquetas verdaderas y, genera los ejemplos con fgsm
    (entre 0 y 1) y mide la fracción de ellos que modelo.predecir(...) clasifica bien.
    Devuelve una lista de floats en [0, 1]. Con epsilon 0, es la precisión normal.
    """
    raise NotImplementedError("Tu turno: implementa curva_epsilon")


def gradiente_adversario(W, b, X, y, epsilon, alfa=0.5):
    """Gradiente (gW, gb) de la pérdida del ENTRENAMIENTO ADVERSARIO (Goodfellow et al. 2014):
        alfa * L(X) + (1 - alfa) * L(X_adv)
    donde X_adv = fgsm(X, gradiente_entrada(W, b, X, y), epsilon) se calcula con los pesos
    actuales, y L es la entropía cruzada MEDIA del lote. Usa gradiente_pesos(W, b, X, y) (ya
    escrita) para el gradiente de cada término y combínalos con los mismos pesos alfa y 1 - alfa.
    Con epsilon = 0 el resultado es el gradiente normal, gradiente_pesos(W, b, X, y).
    ValueError si alfa no está en [0, 1].
    """
    raise NotImplementedError("Tu turno: implementa gradiente_adversario")


def reducir_bits(X, bits):
    """Compresión de la entrada para el detector: reduce cada píxel (en [0, 1]) a `bits` bits de
    profundidad de color. Con L = 2**bits - 1 niveles por encima de 0, el resultado es
        round(X * L) / L
    (np.round, que redondea .5 al par). bits = 1 deja solo 0 y 1. ValueError si bits < 1.
    """
    raise NotImplementedError("Tu turno: implementa reducir_bits")


def puntuacion_squeezing(P, P_reducida):
    """Puntuación del detector para cada fila: la distancia L1 entre la distribución que da el
    modelo con la entrada original (P) y con la entrada comprimida (P_reducida), es decir, la suma
    de los valores absolutos de las diferencias en cada fila. Devuelve un array de n floats en
    [0, 2]. Cuanto más alta, más sospechosa la entrada. ValueError si las formas no coinciden.
    """
    raise NotImplementedError("Tu turno: implementa puntuacion_squeezing")


def umbral_para_fpr(puntuaciones_limpias, fpr):
    """Umbral del detector para una tasa de falsos positivos objetivo, calibrado con entradas
    LIMPIAS (sin ataque). El detector marca una entrada si su puntuación es > umbral.
    Devuelve el MENOR valor t de entre las puntuaciones_limpias tal que la fracción de
    puntuaciones limpias estrictamente mayores que t sea <= fpr.
    Ejemplo: [0.1, 0.2, 0.3, 0.4] con fpr=0.25 → 0.3 (solo 0.4 queda por encima: 1/4).
    ValueError si la lista está vacía o fpr no está en [0, 1].
    """
    raise NotImplementedError("Tu turno: implementa umbral_para_fpr")


# ──────────────────────── Datos, modelo y detector (Claude) ────────────────────────

def cargar_datos(semilla=0):
    """Dígitos 8×8 de scikit-learn (1797 imágenes, píxeles de 0 a 16) escalados a [0, 1].
    Devuelve (X_ent, y_ent, X_val, y_val, X_test, y_test): 60 %, 10 % y 30 %, estratificados."""
    X, y = load_digits(return_X_y=True)
    X = X / 16.0
    X_ent, X_resto, y_ent, y_resto = train_test_split(X, y, test_size=0.4, random_state=semilla, stratify=y)
    X_val, X_test, y_val, y_test = train_test_split(X_resto, y_resto, test_size=0.75, random_state=semilla, stratify=y_resto)
    return X_ent, y_ent, X_val, y_val, X_test, y_test


def gradiente_pesos(W, b, X, y):
    """Gradiente de la entropía cruzada MEDIA del lote respecto a W y b (como en T3 y T4)."""
    D = softmax(X @ W + b)
    D[np.arange(len(y)), y] -= 1.0
    D /= len(y)
    return X.T @ D, D.sum(axis=0)


class Clasificador:
    """Regresión logística multiclase (softmax) entrenada por descenso por gradiente, lote completo.
    Con epsilon_adv > 0, cada paso usa gradiente_adversario (entrenamiento adversario)."""

    def __init__(self, d=DIMENSION, k=CLASES):
        self.W = np.zeros((d, k))
        self.b = np.zeros(k)

    def entrenar(self, X, y, epocas=300, lr=0.5, l2=1e-3, epsilon_adv=0.0, alfa=0.5):
        for _ in range(epocas):
            if epsilon_adv > 0:
                gW, gb = gradiente_adversario(self.W, self.b, X, y, epsilon_adv, alfa)
            else:
                gW, gb = gradiente_pesos(self.W, self.b, X, y)
            self.W -= lr * (gW + l2 * self.W)
            self.b -= lr * gb
        return self

    def probabilidades(self, X):
        return softmax(np.asarray(X, dtype=float) @ self.W + self.b)

    def predecir(self, X):
        return self.probabilidades(X).argmax(axis=1)


class Detector:
    """Feature squeezing: marca una entrada si la predicción cambia demasiado al comprimirla."""

    def __init__(self, modelo, bits=2, fpr=0.05):
        self.modelo, self.bits, self.fpr = modelo, bits, fpr
        self.umbral = math.inf

    def puntuar(self, X):
        return puntuacion_squeezing(self.modelo.probabilidades(X), self.modelo.probabilidades(reducir_bits(X, self.bits)))

    def calibrar(self, X_limpias):
        """Fija el umbral con entradas limpias de validación (nunca con las de test)."""
        self.umbral = float(umbral_para_fpr(list(self.puntuar(X_limpias)), self.fpr))
        return self

    def marcar(self, X):
        return self.puntuar(X) > self.umbral
