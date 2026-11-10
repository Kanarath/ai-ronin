"""Tests del laboratorio E2-03. Sin red: los dígitos vienen dentro de scikit-learn.

Los tests pequeños usan datos escritos a mano; los de integración entrenan las redes de verdad
(unos segundos en CPU).
"""

import math
import unittest

import numpy as np

from privacidad import (RECETAS, Red, area_bajo_curva, atacar_con_sombra, cargar_particiones, curva_roc,
                        edades_ficticias, entrenar_con_receta, media_gaussiana, media_laplace, mejor_umbral,
                        perdida_por_ejemplo, recortar_y_ruido)


class TestPerdida(unittest.TestCase):
    def test_valores_y_recorte(self):
        P = np.array([[0.5, 0.5], [0.9, 0.1], [1.0, 0.0]])
        np.testing.assert_allclose(perdida_por_ejemplo(P, np.array([0, 1, 0])), [math.log(2), -math.log(0.1), 0.0], atol=1e-12)
        self.assertAlmostEqual(perdida_por_ejemplo(P, np.array([0, 0, 1]))[2], -math.log(1e-12))


class TestRoc(unittest.TestCase):
    PUNT = [0.9, 0.8, 0.8, 0.3, 0.1]
    MIEM = [True, True, False, False, True]

    def test_curva(self):
        self.assertEqual(curva_roc(self.PUNT, self.MIEM),
                         [(0.0, 0.0), (0.0, 1 / 3), (0.5, 2 / 3), (1.0, 2 / 3), (1.0, 1.0)])

    def test_area(self):
        self.assertAlmostEqual(area_bajo_curva([(0.0, 0.0), (1.0, 1.0)]), 0.5)
        self.assertAlmostEqual(area_bajo_curva([(0.0, 0.0), (0.0, 1.0), (1.0, 1.0)]), 1.0)
        self.assertAlmostEqual(area_bajo_curva(curva_roc(self.PUNT, self.MIEM)), 7 / 12)

    def test_mejor_umbral_y_empates(self):
        self.assertEqual(mejor_umbral(self.PUNT, self.MIEM), (0.9, 1 / 3))
        u, v = mejor_umbral([3.0, 2.0, 1.0, 0.0], [True, False, True, False])
        self.assertEqual((u, v), (3.0, 0.5), "empate entre 3.0 y 1.0: el más alto")

    def test_errores(self):
        for p, m in [([1.0, 2.0], [True]), ([1.0, 2.0], [True, True]), ([1.0], [False])]:
            with self.assertRaises(ValueError):
                curva_roc(p, m)
            with self.assertRaises(ValueError):
                mejor_umbral(p, m)


class TestPrivacidadDiferencial(unittest.TestCase):
    def test_laplace_recorta_y_usa_la_escala(self):
        valores = [0.0, 10.0, 200.0, -5.0]  # recortados a [0, 10]: 0, 10, 10, 0 → media 5
        esperado = 5.0 + np.random.default_rng(7).laplace(0.0, (10 - 0) / 4 / 0.5)
        self.assertAlmostEqual(media_laplace(valores, 0.0, 10.0, 0.5, np.random.default_rng(7)), esperado)
        for args in [([], 0, 1, 1.0), ([1.0], 0, 1, 0.0), ([1.0], 1, 1, 1.0)]:
            with self.assertRaises(ValueError):
                media_laplace(*args, np.random.default_rng(0))

    def test_gaussiana_sigma_del_teorema(self):
        sigma = (90 - 18) / 3 * math.sqrt(2 * math.log(1.25 / 1e-5)) / 0.5
        esperado = 30.0 + np.random.default_rng(3).normal(0.0, sigma)
        self.assertAlmostEqual(media_gaussiana([20.0, 30.0, 40.0], 18, 90, 0.5, 1e-5, np.random.default_rng(3)), esperado)
        for eps, delta in [(1.0, 1e-5), (0.0, 1e-5), (0.5, 0.0), (0.5, 1.0)]:
            with self.assertRaises(ValueError):
                media_gaussiana([20.0], 18, 90, eps, delta, np.random.default_rng(0))

    def test_mas_epsilon_menos_error(self):
        edades = edades_ficticias(1000, 0)
        rng = np.random.default_rng(0)
        error = {e: np.mean([abs(media_laplace(edades, 18, 90, e, rng) - edades.mean()) for _ in range(300)]) for e in (0.05, 5.0)}
        self.assertGreater(error[0.05], 10 * error[5.0])
        self.assertLess(error[5.0], 0.1, "con ε = 5 y 1000 personas, el ruido apenas cambia la media")


class TestDpSgd(unittest.TestCase):
    def test_recorte_por_ejemplo_sin_ruido(self):
        # Ejemplo 0: norma 5 (3, 4) → se escala a 1 → (0.6, 0.8); ejemplo 1: norma 0.5 → se queda.
        g = [np.array([[3.0], [0.3]]), np.array([[4.0], [0.4]])]
        out = recortar_y_ruido(g, 1.0, 0.0, np.random.default_rng(0))
        np.testing.assert_allclose(out[0], [(0.6 + 0.3) / 2])
        np.testing.assert_allclose(out[1], [(0.8 + 0.4) / 2])
        np.testing.assert_allclose(g[0], [[3.0], [0.3]], err_msg="no modifica los gradientes")

    def test_ruido_en_orden_y_con_su_escala(self):
        g = [np.zeros((4, 2, 3)), np.zeros((4, 3)), np.array([[0.0], [0.0], [0.0], [0.0]])]
        out = recortar_y_ruido(g, 2.0, 1.5, np.random.default_rng(11))
        r = np.random.default_rng(11)
        esperado = [r.normal(0.0, 3.0, size=(2, 3)) / 4, r.normal(0.0, 3.0, size=(3,)) / 4, r.normal(0.0, 3.0, size=(1,)) / 4]
        for o, e in zip(out, esperado):
            np.testing.assert_allclose(o, e)

    def test_errores(self):
        g = [np.ones((2, 3))]
        for recorte, ruido in [(0.0, 1.0), (1.0, -0.1)]:
            with self.assertRaises(ValueError):
                recortar_y_ruido(g, recorte, ruido, np.random.default_rng(0))


class TestIntegracion(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.partes = cargar_particiones(0, n=200)
        X, y = cls.partes["miembros"]
        Xs, ys = cls.partes["sombra_dentro"]
        cls.receta = dict(RECETAS["ninguna"], epocas=120)
        cls.victima = entrenar_con_receta(X, y, cls.receta, 0)
        cls.sombra = entrenar_con_receta(Xs, ys, cls.receta, 1)

    def test_el_sobreajuste_filtra_la_pertenencia(self):
        r = atacar_con_sombra(self.victima, self.sombra, self.partes)
        self.assertGreater(r["ventaja"], 0.08, "TPR %.2f · FPR %.2f" % (r["tpr"], r["fpr"]))
        self.assertGreater(r["auc"], 0.55)
        self.assertGreaterEqual(r["ventaja_oraculo"], r["ventaja"] - 1e-12, "el oráculo nunca lo hace peor")

    def test_dp_sgd_entrena_y_reduce_la_ventaja(self):
        X, y = self.partes["miembros"]
        Xs, ys = self.partes["sombra_dentro"]
        receta = RECETAS["dp-sgd-fuerte"]
        privada = entrenar_con_receta(X, y, receta, 0)
        sombra = entrenar_con_receta(Xs, ys, receta, 1)
        Xt, yt = self.partes["test"]
        self.assertGreater(np.mean(privada.predecir(Xt) == yt), 0.5, "DP-SGD sigue aprendiendo algo")
        r_dp = atacar_con_sombra(privada, sombra, self.partes)
        r = atacar_con_sombra(self.victima, self.sombra, self.partes)
        self.assertLess(r_dp["ventaja"], r["ventaja"], "DP-SGD %.3f frente a %.3f" % (r_dp["ventaja"], r["ventaja"]))

    def test_red_tiene_gradientes_por_ejemplo(self):
        g = Red().gradientes_por_ejemplo(*[a[:5] for a in self.partes["test"]])
        self.assertEqual([x.shape for x in g], [(5, 64, 32), (5, 32), (5, 32, 10), (5, 10)])
        out = recortar_y_ruido(g, 1.0, 0.0, np.random.default_rng(0))
        self.assertEqual([x.shape for x in out], [(64, 32), (32,), (32, 10), (10,)])


if __name__ == "__main__":
    unittest.main()
