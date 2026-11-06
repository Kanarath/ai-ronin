"""Tests del ejercicio T4-02. El test clave es el GRADIENT CHECK: tus gradientes de backprop
deben coincidir con el gradiente numérico. Así se verifica cualquier implementación de backprop."""

import math
import unittest

from T4_02_backprop import crear_red, entrenar, forward, gradiente_numerico, gradientes, paso, perdida

X_XOR = [[0, 0], [0, 1], [1, 0], [1, 1]]
Y_XOR = [0, 1, 1, 0]


def red_fija():
    return {"W1": [[1.0, -2.0], [0.5, 0.3], [-1.2, 0.8]], "b1": [0.5, -0.1, 0.2], "w2": [3.0, -1.0, 0.7], "b2": -1.0}


class TestEstructura(unittest.TestCase):
    def test_crear_red(self):
        red = crear_red(3, 42)
        self.assertEqual(len(red["W1"]), 3)
        self.assertEqual(len(red["W1"][0]), 2)
        self.assertEqual(red["b1"], [0.0, 0.0, 0.0])
        self.assertEqual(len(red["w2"]), 3)
        self.assertEqual(red["b2"], 0.0)
        self.assertEqual(crear_red(3, 42), crear_red(3, 42), "misma semilla → misma red")
        for fila in red["W1"]:
            for w in fila:
                self.assertTrue(-1 <= w <= 1)

    def test_forward(self):
        z1, a1, p = forward(red_fija(), [2.0, 1.0])
        self.assertAlmostEqual(z1[0], 1.0 * 2 - 2.0 * 1 + 0.5)
        h = [1 / (1 + math.exp(-z)) for z in z1]
        self.assertAlmostEqual(a1[1], h[1])
        z2 = 3.0 * h[0] - 1.0 * h[1] + 0.7 * h[2] - 1.0
        self.assertAlmostEqual(p, 1 / (1 + math.exp(-z2)))


class TestGradientCheck(unittest.TestCase):
    def test_todos_los_parametros(self):
        red = red_fija()
        g = gradientes(red, X_XOR, Y_XOR)
        rutas = [("b2",)]
        for j in range(3):
            rutas += [("W1", j, 0), ("W1", j, 1), ("b1", j), ("w2", j)]
        for ruta in rutas:
            analitico = g[ruta[0]]
            for idx in ruta[1:]:
                analitico = analitico[idx]
            numerico = gradiente_numerico(red, X_XOR, Y_XOR, ruta)
            self.assertAlmostEqual(analitico, numerico, delta=1e-6, msg=f"parámetro {ruta}")

    def test_gradiente_numerico_no_modifica_la_red(self):
        red = red_fija()
        gradiente_numerico(red, X_XOR, Y_XOR, ("W1", 0, 1))
        self.assertEqual(red, red_fija())

    def test_paso_reduce_la_perdida(self):
        red = red_fija()
        nueva = paso(red, gradientes(red, X_XOR, Y_XOR), 0.1)
        self.assertLess(perdida(nueva, X_XOR, Y_XOR), perdida(red, X_XOR, Y_XOR))
        self.assertEqual(red, red_fija(), "paso devuelve una red nueva")


class TestXor(unittest.TestCase):
    def test_capa_oculta_resuelve_xor(self):
        """Con 4 ocultas la mayoría de semillas resuelven XOR (como viste en el Dojo)."""
        resueltas = 0
        for semilla in range(5):
            red, h = entrenar(X_XOR, Y_XOR, 4, 1.0, 3000, semilla)
            aciertos = sum((forward(red, x)[2] >= 0.5) == (y == 1) for x, y in zip(X_XOR, Y_XOR))
            resueltas += aciertos == 4
            self.assertEqual(len(h), 3001)
        # Tu generador aleatorio no es el del Dojo: se exige una mayoría clara, no todas.
        self.assertGreaterEqual(resueltas, 3)


if __name__ == "__main__":
    unittest.main()
