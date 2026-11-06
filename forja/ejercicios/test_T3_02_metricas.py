"""Tests del ejercicio T3-02."""

import unittest

from T3_02_metricas import aplicar_umbral, contar, curva, f1, precision, recall

# Mismo resultado que la misión T3-02 con k=9 y umbral 0,5: TP 30, FN 4, FP 7, TN 31.
Y_TRUE = ["d"] * 34 + ["a"] * 38
Y_PRED = ["d"] * 30 + ["a"] * 4 + ["d"] * 7 + ["a"] * 31


class TestConteos(unittest.TestCase):
    def test_contar(self):
        self.assertEqual(contar(["d", "d", "a"], ["d", "a", "d"], "d"), {"tp": 1, "fp": 1, "fn": 1, "tn": 0})

    def test_como_el_dojo(self):
        self.assertEqual(contar(Y_TRUE, Y_PRED, "d"), {"tp": 30, "fp": 7, "fn": 4, "tn": 31})
        self.assertAlmostEqual(precision(Y_TRUE, Y_PRED, "d"), 30 / 37)
        self.assertAlmostEqual(recall(Y_TRUE, Y_PRED, "d"), 30 / 34)
        self.assertAlmostEqual(f1(Y_TRUE, Y_PRED, "d"), 0.845, delta=0.001)

    def test_division_por_cero_vale_cero(self):
        self.assertEqual(precision(["d", "a"], ["a", "a"], "d"), 0.0, "sin positivos predichos")
        self.assertEqual(recall(["a", "a"], ["a", "d"], "d"), 0.0, "sin positivos reales")
        self.assertEqual(f1(["d"], ["a"], "d"), 0.0)

    def test_la_clase_positiva_importa(self):
        self.assertNotAlmostEqual(recall(Y_TRUE, Y_PRED, "d"), recall(Y_TRUE, Y_PRED, "a"))


class TestUmbrales(unittest.TestCase):
    def test_aplicar_umbral(self):
        self.assertEqual(aplicar_umbral([0.2, 0.5, 0.9], 0.5, "d", "a"), ["a", "d", "d"])

    def test_curva_compromiso(self):
        puntuaciones = [0.9, 0.7, 0.4, 0.3, 0.6, 0.1]
        reales = ["d", "d", "d", "a", "a", "a"]
        c = curva(puntuaciones, reales, "d", "a", [0.2, 0.5, 0.8])
        self.assertEqual([u for u, _, _ in c], [0.2, 0.5, 0.8])
        recalls = [r for _, _, r in c]
        self.assertEqual(recalls, sorted(recalls, reverse=True), "al subir el umbral, el recall no sube")
        self.assertAlmostEqual(c[0][2], 1.0)
        self.assertAlmostEqual(c[2][1], 1.0, msg="con umbral alto, las pocas alarmas son fiables")


if __name__ == "__main__":
    unittest.main()
