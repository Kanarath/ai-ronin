"""Ejercicio T3-02 · Precision, recall, F1 y umbrales.

Vas a reproducir `metrics` y `metrics curve` del Dojo.
Python que practicas: zip(), conteos con condiciones y manejo de divisiones por cero.

Convención (la misma del Dojo y de scikit-learn con zero_division=0):
si un denominador es 0, la métrica vale 0.0.

Ejecuta los tests desde forja/ejercicios:
    python -m unittest -v test_T3_02_metricas
"""


def contar(y_true, y_pred, positiva):
    """Devuelve un diccionario {"tp", "fp", "fn", "tn"} respecto a la clase positiva.

    Ejemplo: contar(["d", "d", "a"], ["d", "a", "d"], "d") → {"tp": 1, "fp": 1, "fn": 1, "tn": 0}
    """
    raise NotImplementedError("Tu turno: implementa contar")


def precision(y_true, y_pred, positiva):
    """TP / (TP + FP)."""
    raise NotImplementedError("Tu turno: implementa precision")


def recall(y_true, y_pred, positiva):
    """TP / (TP + FN)."""
    raise NotImplementedError("Tu turno: implementa recall")


def f1(y_true, y_pred, positiva):
    """2·P·R / (P + R), o 0.0 si P + R = 0."""
    raise NotImplementedError("Tu turno: implementa f1")


def aplicar_umbral(puntuaciones, umbral, positiva, negativa):
    """Etiqueta positiva si puntuación ≥ umbral; si no, negativa.

    Ejemplo: aplicar_umbral([0.2, 0.5, 0.9], 0.5, "d", "a") → ["a", "d", "d"]
    """
    raise NotImplementedError("Tu turno: implementa aplicar_umbral")


def curva(puntuaciones, y_true, positiva, negativa, umbrales):
    """Para cada umbral, devuelve la tupla (umbral, precision, recall). Lista en el mismo orden."""
    raise NotImplementedError("Tu turno: implementa curva")
