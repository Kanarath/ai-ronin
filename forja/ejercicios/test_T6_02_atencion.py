"""Tests del ejercicio T6-02 (los valores con embeddings son los del Dojo)."""

import math
import unittest

from apoyo import cargar_embeddings
from T6_02_atencion import pesos_atencion, salida_atencion, softmax


class TestPiezas(unittest.TestCase):
    def test_softmax(self):
        self.assertEqual(softmax([0, 0]), [0.5, 0.5])
        self.assertAlmostEqual(sum(softmax([1000, 1001, 999])), 1.0, msg="estable con números grandes")
        self.assertEqual(softmax([0, float("-inf")]), [1.0, 0.0])

    def test_filas_suman_uno_y_mascara(self):
        v = [[1, 0], [0, 1], [1, 1]]
        w = pesos_atencion(v, causal=True)
        for fila in w:
            self.assertAlmostEqual(sum(fila), 1.0)
        self.assertEqual(w[0], [1.0, 0.0, 0.0])
        self.assertEqual(w[1][2], 0.0)

    def test_sin_escalar(self):
        w = pesos_atencion([[1, 0], [0, 1], [1, 1]], escalar=False)
        self.assertAlmostEqual(w[0][1], 1 / (math.e + 1 + math.e))

    def test_salida(self):
        out = salida_atencion([[1, 0], [0, 1]], [[0.5, 0.5], [0.0, 1.0]])
        self.assertEqual(out, [[0.5, 0.5], [0.0, 1.0]])


class TestComoElDojo(unittest.TestCase):
    def test_frase(self):
        t = cargar_embeddings()
        palabras = ["herrera", "martillo", "katana", "fuego", "agua"]
        w = pesos_atencion([t[p] for p in palabras])
        self.assertAlmostEqual(w[2][1], 0.22, delta=0.005, msg="katana → martillo")
        wc = pesos_atencion([t[p] for p in palabras], causal=True)
        self.assertAlmostEqual(wc[0][0], 1.0)
        self.assertAlmostEqual(wc[2][1], 0.31, delta=0.005)


if __name__ == "__main__":
    unittest.main()
