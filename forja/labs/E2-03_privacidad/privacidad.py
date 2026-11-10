"""Laboratorio E2-03 · ¿Estaba este ejemplo en el entrenamiento? Membership inference y privacidad diferencial.

Entrenas una red pequeña (un MLP de una capa oculta, en NumPy) con unos pocos cientos de dígitos
y la atacas: a partir solo de la pérdida que da el modelo con un ejemplo, adivinas si ese ejemplo
estaba en su conjunto de entrenamiento (membership inference, Shokri et al. 2017; el ataque por
umbral de pérdida es el de Yeom et al. 2018). Un modelo sobreajustado tiene pérdidas mucho más
bajas con lo que ha visto que con lo que no: eso es lo que se filtra.

El atacante fija su umbral con un MODELO SOMBRA: entrena él mismo un modelo con la misma receta
sobre datos suyos, de los que sí sabe cuáles usó, y elige el umbral que mejor separa en la sombra.

Después mides tres modelos (sobreajustado, regularizado y entrenado con DP-SGD) y la ventaja del
atacante (TPR - FPR) frente a su utilidad, y practicas la privacidad diferencial en lo más
sencillo: publicar la media de un conjunto con ruido de Laplace o gaussiano (Dwork y Roth 2014).

Tú implementas las funciones marcadas con «Tu turno». Claude ha escrito el resto (datos, el MLP
con gradientes por ejemplo, el modelo sombra y bateria.py). Todo es ficticio y local, en CPU.
Tests (sin red):
    python -m unittest -v test_privacidad
"""

import math

import numpy as np
from sklearn.datasets import load_digits

CLASES = 10
DIMENSION = 64


# ─────────────────────────────── Tu turno ───────────────────────────────

def perdida_por_ejemplo(P, y, minimo=1e-12):
    """Entropía cruzada de cada ejemplo: -ln P[i, y_i], con la probabilidad recortada a
    [minimo, 1] antes del logaritmo (para que una probabilidad 0 no dé infinito).
    P es un array (n × k) de probabilidades e y, n etiquetas enteras. Devuelve un array de n floats."""
    raise NotImplementedError("Tu turno: implementa perdida_por_ejemplo")


def curva_roc(puntuaciones, es_miembro):
    """Curva ROC del ataque. Puntuación más alta = más probable que sea miembro (el ataque usa
    menos la pérdida). `es_miembro` es una lista de booleanos de la misma longitud.
    Para cada umbral t de entre los valores DISTINTOS de las puntuaciones, de mayor a menor, el
    ataque dice «miembro» si puntuación >= t, y:
        tpr = miembros con puntuación >= t / total de miembros
        fpr = no miembros con puntuación >= t / total de no miembros
    Devuelve una lista de tuplas (fpr, tpr), que empieza por (0.0, 0.0) y sigue con un punto por
    umbral, en ese orden (el último es siempre (1.0, 1.0)).
    ValueError si las longitudes no coinciden o si no hay al menos un miembro y un no miembro.
    """
    raise NotImplementedError("Tu turno: implementa curva_roc")


def area_bajo_curva(curva):
    """Área bajo una curva ROC (lista de (fpr, tpr) con fpr creciente) por la regla del trapecio:
    suma de (fpr_i - fpr_{i-1}) * (tpr_i + tpr_{i-1}) / 2. Un ataque que adivina al azar da 0.5;
    uno perfecto, 1.0."""
    raise NotImplementedError("Tu turno: implementa area_bajo_curva")


def mejor_umbral(puntuaciones, es_miembro):
    """Umbral que maximiza la ventaja del atacante, tpr - fpr, entre los valores distintos de las
    puntuaciones (con la misma regla que curva_roc: «miembro» si puntuación >= t).
    Devuelve (umbral, ventaja). En caso de empate, el umbral MÁS ALTO.
    Mismos errores que curva_roc."""
    raise NotImplementedError("Tu turno: implementa mejor_umbral")


def media_laplace(valores, bajo, alto, epsilon, rng):
    """Media con privacidad diferencial ε (mecanismo de Laplace, Dwork y Roth 2014, §3.3).
      1. Recorta cada valor a [bajo, alto]: así un solo individuo no puede mover la media más que
         la sensibilidad Δ = (alto - bajo) / n.
      2. Devuelve la media de los recortados + rng.laplace(0.0, Δ / epsilon) (UNA llamada a rng).
    Devuelve un float. ValueError si no hay valores, si epsilon <= 0 o si bajo >= alto.
    """
    raise NotImplementedError("Tu turno: implementa media_laplace")


def media_gaussiana(valores, bajo, alto, epsilon, delta, rng):
    """Media con privacidad diferencial (ε, δ) (mecanismo gaussiano, Dwork y Roth 2014, teorema A.1).
    Recorta como media_laplace y suma rng.normal(0.0, sigma) (UNA llamada a rng) con
        sigma = Δ * sqrt(2 * ln(1.25 / delta)) / epsilon,   Δ = (alto - bajo) / n
    El teorema solo vale para 0 < epsilon < 1: ValueError fuera de ese rango, si delta no está en
    (0, 1), si no hay valores o si bajo >= alto.
    """
    raise NotImplementedError("Tu turno: implementa media_gaussiana")


def recortar_y_ruido(gradientes, recorte, ruido, rng):
    """El paso que distingue a DP-SGD (Abadi et al. 2016) del descenso por gradiente normal.
    `gradientes` es una lista de arrays, uno por parámetro, cada uno con forma (B, ...): el
    gradiente de CADA ejemplo del lote por separado.
      1. Norma L2 de cada ejemplo, sobre TODOS sus parámetros juntos:
         norma_i = sqrt(suma sobre parámetros de la suma de cuadrados de la fila i).
      2. Escala cada ejemplo por min(1, recorte / norma_i) (si la norma es 0, no lo toques):
         ningún ejemplo aporta más de `recorte`.
      3. Suma sobre el lote y añade a cada parámetro, en el orden de la lista, ruido
         rng.normal(0.0, ruido * recorte, size=forma_del_parámetro_sin_B) (una llamada por parámetro).
      4. Divide entre B.
    Devuelve una lista de arrays (sin la dimensión B). Haz las llamadas a rng también con
    ruido = 0 (rng.normal con desviación 0 devuelve ceros): así el resultado es el mismo y el
    generador avanza igual. ValueError si recorte <= 0 o ruido < 0.
    """
    raise NotImplementedError("Tu turno: implementa recortar_y_ruido")


# ──────────────────────────── Datos y modelo (Claude) ────────────────────────────

def cargar_particiones(semilla=0, n=300):
    """Dígitos 8×8 escalados a [0, 1], barajados con la semilla y repartidos en cinco grupos:
      miembros (entrenan a la víctima), no_miembros (nunca los ve), sombra_dentro y sombra_fuera
      (del atacante, para su modelo sombra) y test (el resto, para medir la utilidad).
    Cada grupo de los cuatro primeros tiene n ejemplos. Devuelve un dict nombre → (X, y)."""
    X, y = load_digits(return_X_y=True)
    X = X / 16.0
    orden = np.random.default_rng(semilla).permutation(len(X))
    nombres = ["miembros", "no_miembros", "sombra_dentro", "sombra_fuera"]
    out = {nombre: (X[orden[i * n:(i + 1) * n]], y[orden[i * n:(i + 1) * n]]) for i, nombre in enumerate(nombres)}
    out["test"] = (X[orden[4 * n:]], y[orden[4 * n:]])
    return out


def _softmax(Z):
    Z = Z - Z.max(axis=1, keepdims=True)
    E = np.exp(Z)
    return E / E.sum(axis=1, keepdims=True)


class Red:
    """MLP 64 → oculta (ReLU) → 10 (softmax), entrenado con descenso por gradiente estocástico.
    Calcula el gradiente de CADA ejemplo por separado: lo necesita DP-SGD para recortarlo."""

    def __init__(self, oculta=32, semilla=0):
        r = np.random.default_rng(semilla)
        self.p = [r.normal(0, 1 / math.sqrt(DIMENSION), (DIMENSION, oculta)), np.zeros(oculta),
                  r.normal(0, 1 / math.sqrt(oculta), (oculta, CLASES)), np.zeros(CLASES)]
        self.rng = r

    def _adelante(self, X):
        H = np.maximum(0.0, X @ self.p[0] + self.p[1])
        return H, _softmax(H @ self.p[2] + self.p[3])

    def probabilidades(self, X):
        return self._adelante(np.asarray(X, dtype=float))[1]

    def predecir(self, X):
        return self.probabilidades(X).argmax(axis=1)

    def gradientes_por_ejemplo(self, X, y):
        """Lista [dW1, db1, dW2, db2], cada uno con forma (B, ...): un gradiente por ejemplo."""
        H, P = self._adelante(X)
        D = P.copy()
        D[np.arange(len(y)), y] -= 1.0
        DH = (D @ self.p[2].T) * (H > 0)
        return [np.einsum("nd,nh->ndh", X, DH), DH, np.einsum("nh,nk->nhk", H, D), D]

    def entrenar(self, X, y, epocas=200, lr=0.5, lote=50, l2=0.0, recorte=None, ruido=0.0):
        """SGD normal; con l2 > 0, decaimiento de pesos; con `recorte`, DP-SGD (tu recortar_y_ruido)."""
        n = len(X)
        for _ in range(epocas):
            orden = self.rng.permutation(n)
            for i in range(0, n, lote):
                idx = orden[i:i + lote]
                g = self.gradientes_por_ejemplo(X[idx], y[idx])
                g = recortar_y_ruido(g, recorte, ruido, self.rng) if recorte is not None else [gi.mean(axis=0) for gi in g]
                for j in range(4):
                    self.p[j] -= lr * (g[j] + (l2 * self.p[j] if j in (0, 2) else 0.0))
        return self


RECETAS = {
    # Lo que el atacante también sabe: la receta de entrenamiento (supuesto de Shokri et al.).
    "ninguna": {"epocas": 200, "lr": 0.5},
    "regularizado": {"epocas": 60, "lr": 0.3, "l2": 0.02},
    "dp-sgd": {"epocas": 60, "lr": 0.3, "lote": 30, "recorte": 1.0, "ruido": 1.0},
    "dp-sgd-fuerte": {"epocas": 60, "lr": 0.3, "lote": 30, "recorte": 1.0, "ruido": 4.0},
}


def entrenar_con_receta(X, y, receta, semilla):
    return Red(semilla=semilla).entrenar(X, y, **receta)


def puntuaciones(modelo, X, y):
    """Puntuación de pertenencia: menos la pérdida (pérdida baja → probablemente miembro)."""
    return -perdida_por_ejemplo(modelo.probabilidades(X), y)


def atacar_con_sombra(victima, sombra, partes):
    """Ataque por umbral de pérdida. El umbral se elige en la SOMBRA (donde el atacante sabe quién
    es miembro) y se aplica a la VÍCTIMA. Devuelve las métricas del ataque."""
    s_in, s_out = puntuaciones(sombra, *partes["sombra_dentro"]), puntuaciones(sombra, *partes["sombra_fuera"])
    umbral, _ = mejor_umbral(list(np.r_[s_in, s_out]), [True] * len(s_in) + [False] * len(s_out))
    v_in, v_out = puntuaciones(victima, *partes["miembros"]), puntuaciones(victima, *partes["no_miembros"])
    curva = curva_roc(list(np.r_[v_in, v_out]), [True] * len(v_in) + [False] * len(v_out))
    tp, fp = int(np.sum(v_in >= umbral)), int(np.sum(v_out >= umbral))
    return {"umbral": float(umbral), "tp": tp, "fp": fp, "n_miembros": len(v_in), "n_no_miembros": len(v_out),
            "tpr": tp / len(v_in), "fpr": fp / len(v_out), "ventaja": tp / len(v_in) - fp / len(v_out),
            "auc": area_bajo_curva(curva), "ventaja_oraculo": max(t - f for f, t in curva),
            "tpr_a_fpr_5": max(t for f, t in curva if f <= 0.05)}


def edades_ficticias(n=1000, semilla=0):
    """Edades de los clientes ficticios de la forja (entre 18 y 90), para practicar la media privada."""
    r = np.random.default_rng(semilla)
    return np.clip(np.round(r.normal(45, 14, n)), 18, 90)
