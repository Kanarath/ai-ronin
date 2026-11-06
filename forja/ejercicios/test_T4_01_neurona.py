"""Tests del ejercicio T4-01."""

import math
import unittest

from T4_01_neurona import entrenar_neurona, entropia_cruzada, neurona, sigmoide

PUERTAS = {
    "and": [0, 0, 0, 1],
    "or": [0, 1, 1, 1],
    "xor": [0, 1, 1, 0],
}
X = [[0, 0], [0, 1], [1, 0], [1, 1]]


class TestPiezas(unittest.TestCase):
    def test_sigmoide(self):
        self.assertAlmostEqual(sigmoide(0), 0.5)
        self.assertAlmostEqual(sigmoide(10), 1 / (1 + math.exp(-10)))
        self.assertLess(sigmoide(-10), 0.001)

    def test_neurona(self):
        self.assertAlmostEqual(neurona([1, 0], [10, 10], -5), sigmoide(5))

    def test_entropia_cruzada(self):
        self.assertAlmostEqual(entropia_cruzada(0.5, 1), math.log(2))
        self.assertAlmostEqual(entropia_cruzada(0.9, 1), -math.log(0.9))
        self.assertLess(entropia_cruzada(1.0, 1), 1e-9, "no debe fallar con p = 1")
        self.assertGreater(entropia_cruzada(0.0, 1), 20, "estar seguro y equivocarse cuesta mucho")


class TestComoElDojo(unittest.TestCase):
    def test_or_a_mano(self):
        """Los pesos que pusiste a mano en la misión T4-01."""
        for x, y in zip(X, PUERTAS["or"]):
            self.assertEqual(neurona(x, [10, 10], -5) >= 0.5, y == 1, msg=f"entrada {x}")

    def test_aprende_and(self):
        pesos, sesgo, h = entrenar_neurona(X, PUERTAS["and"], 0.5, 2000, [0.1, -0.2])
        self.assertEqual(len(h), 2001)
        for x, y in zip(X, PUERTAS["and"]):
            self.assertEqual(neurona(x, pesos, sesgo) >= 0.5, y == 1, msg=f"entrada {x}")

    def test_no_modifica_pesos_iniciales(self):
        iniciales = [0.1, -0.2]
        entrenar_neurona(X, PUERTAS["and"], 0.5, 10, iniciales)
        self.assertEqual(iniciales, [0.1, -0.2])

    def test_xor_se_atasca_en_ln2(self):
        pesos, sesgo, h = entrenar_neurona(X, PUERTAS["xor"], 0.5, 3000, [0.1, -0.2])
        self.assertAlmostEqual(h[-1], math.log(2), delta=0.001)


if __name__ == "__main__":
    unittest.main()
