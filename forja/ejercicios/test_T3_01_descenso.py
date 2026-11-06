"""Tests del ejercicio T3-01. Los valores con el dataset temple son los mismos que calcula el Dojo."""

import statistics
import unittest

from apoyo import cargar_temple
from T3_01_descenso import entrenar, gradientes, ha_divergido, mse


class TestPiezas(unittest.TestCase):
    def test_mse(self):
        self.assertAlmostEqual(mse(2, 1, [0, 1], [1, 4]), 0.5)

    def test_gradientes(self):
        dw, db = gradientes(0, 0, [1, 2], [2, 4])
        self.assertAlmostEqual(dw, -10.0)
        self.assertAlmostEqual(db, -6.0)

    def test_gradiente_cero_en_el_optimo(self):
        dw, db = gradientes(2, 0, [1, 2, 3], [2, 4, 6])
        self.assertAlmostEqual(dw, 0.0)
        self.assertAlmostEqual(db, 0.0)

    def test_historial_incluye_estado_inicial(self):
        w, b, h = entrenar([1, 2], [2, 4], 0.1, 5)
        self.assertEqual(len(h), 6)
        self.assertAlmostEqual(h[0], mse(0, 0, [1, 2], [2, 4]))
        self.assertLess(h[-1], h[0])

    def test_ha_divergido(self):
        self.assertTrue(ha_divergido([1.0, float("inf")]))
        self.assertTrue(ha_divergido([1.0, 2e12]))
        self.assertFalse(ha_divergido([10.0, 1.0]))


class TestComoElDojo(unittest.TestCase):
    """Los mismos experimentos de la misión T3-01."""

    @classmethod
    def setUpClass(cls):
        cls.xs, cls.ys = cargar_temple()

    def test_lr_pequeno_es_lento(self):
        w, b, h = entrenar(self.xs, self.ys, 0.001, 100)
        self.assertAlmostEqual(h[-1], 435.7998, delta=0.001)

    def test_lr_grande_diverge_y_para(self):
        w, b, h = entrenar(self.xs, self.ys, 0.03, 100)
        self.assertTrue(ha_divergido(h))
        self.assertLess(len(h), 101, "debe parar en cuanto diverge")

    def test_lr_bueno_converge(self):
        w, b, h = entrenar(self.xs, self.ys, 0.02, 500)
        self.assertAlmostEqual(h[-1], 1.1728, delta=0.001)

    def test_normalizar_x_acelera(self):
        media = statistics.fmean(self.xs)
        desv = statistics.pstdev(self.xs)
        xs_n = [(x - media) / desv for x in self.xs]
        w, b, h = entrenar(xs_n, self.ys, 0.5, 20)
        self.assertAlmostEqual(h[-1], 0.9777, delta=0.001)
        self.assertAlmostEqual(w / desv, 1.508, delta=0.01, msg="≈1,5 HRC por minuto")


if __name__ == "__main__":
    unittest.main()
