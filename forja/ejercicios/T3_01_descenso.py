"""Ejercicio T3-01 · Descenso por gradiente desde cero.

Vas a entrenar una regresión lineal y = w·x + b exactamente como `regress train` del Dojo.
Python que practicas: funciones con varios retornos (tuplas), bucles con parada temprana
y math.isfinite.

Ejecuta los tests desde forja/ejercicios:
    python -m unittest -v test_T3_01_descenso
"""

LIMITE_DIVERGENCIA = 1e12


def mse(w, b, xs, ys):
    """Error cuadrático medio: media de (w·x + b − y)².

    Ejemplo: mse(2, 1, [0, 1], [1, 4]) → ((1−1)² + (3−4)²) / 2 = 0.5
    """
    raise NotImplementedError("Tu turno: implementa mse")


def gradientes(w, b, xs, ys):
    """Devuelve la tupla (dw, db) con las derivadas del MSE:

        dw = (2/n) · Σ (w·xᵢ + b − yᵢ) · xᵢ
        db = (2/n) · Σ (w·xᵢ + b − yᵢ)

    Ejemplo: gradientes(0, 0, [1, 2], [2, 4]) → (−10.0, −6.0)
    """
    raise NotImplementedError("Tu turno: implementa gradientes")


def entrenar(xs, ys, lr, epocas):
    """Descenso por gradiente partiendo de w = 0, b = 0.

    En cada época: calcula los gradientes, actualiza w ← w − lr·dw y b ← b − lr·db,
    y apunta la pérdida (MSE) DESPUÉS de actualizar.

    Devuelve (w, b, historial), donde historial es la lista de pérdidas empezando por la
    pérdida INICIAL (época 0, con w = b = 0). Con 100 épocas sin divergir tendrá 101 valores.

    PARADA TEMPRANA: si una pérdida no es finita o supera LIMITE_DIVERGENCIA, apúntala y
    detén el entrenamiento (como hace el Dojo). Pista: math.isfinite(x).
    Cuidado: x ** 2 con números enormes lanza OverflowError en Python; x * x no.
    """
    raise NotImplementedError("Tu turno: implementa entrenar")


def ha_divergido(historial):
    """True si la última pérdida no es finita o supera LIMITE_DIVERGENCIA."""
    raise NotImplementedError("Tu turno: implementa ha_divergido")
