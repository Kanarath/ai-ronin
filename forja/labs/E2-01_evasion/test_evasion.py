"""Tests del laboratorio E2-01. Sin red: los dígitos vienen dentro de scikit-learn.

Los tests pequeños usan matrices escritas a mano; los de integración entrenan el clasificador de
verdad (un par de segundos en CPU).
"""

import unittest

import numpy as np

from evasion import (Clasificador, Detector, cargar_datos, curva_epsilon, fgsm, gradiente_adversario, gradiente_entrada,
                     gradiente_pesos, puntuacion_squeezing, reducir_bits, softmax, umbral_para_fpr)


def perdida_media(W, b, X, y):
    P = softmax(X @ W + b)
    return float(-np.mean(np.log(P[np.arange(len(y)), y])))


class TestSoftmax(unittest.TestCase):
    def test_filas_suman_uno_y_orden(self):
        P = softmax(np.array([[1.0, 2.0, 3.0], [0.0, 0.0, 0.0]]))
        np.testing.assert_allclose(P.sum(axis=1), [1.0, 1.0])
        np.testing.assert_allclose(P[1], [1 / 3] * 3)
        self.assertTrue(P[0, 2] > P[0, 1] > P[0, 0])

    def test_estable_con_logits_grandes(self):
        P = softmax(np.array([[1000.0, 1000.0], [-1000.0, 0.0]]))
        self.assertFalse(np.isnan(P).any())
        np.testing.assert_allclose(P[0], [0.5, 0.5])
        np.testing.assert_allclose(P[1], [0.0, 1.0], atol=1e-12)


class TestGradienteEntrada(unittest.TestCase):
    def test_formula_a_mano(self):
        W = np.array([[1.0, -1.0], [0.0, 2.0]])
        b = np.zeros(2)
        X = np.array([[0.0, 0.0]])
        g = gradiente_entrada(W, b, X, np.array([0]))
        # P = [0.5, 0.5]; P - onehot(0) = [-0.5, 0.5]; @ W.T = [-1.0, 1.0]
        np.testing.assert_allclose(g, [[-1.0, 1.0]])

    def test_coincide_con_diferencias_finitas(self):
        rng = np.random.default_rng(3)
        W, b = rng.normal(size=(5, 3)), rng.normal(size=3)
        X, y = rng.uniform(size=(4, 5)), np.array([0, 2, 1, 2])
        g = gradiente_entrada(W, b, X, y)
        self.assertEqual(g.shape, (4, 5))
        h = 1e-6
        for i, j in [(0, 0), (1, 3), (3, 4)]:
            Xp, Xm = X.copy(), X.copy()
            Xp[i, j] += h
            Xm[i, j] -= h
            # perdida_media divide entre n: la de cada ejemplo es n veces su contribución
            num = (perdida_media(W, b, Xp, y) - perdida_media(W, b, Xm, y)) / (2 * h) * len(y)
            self.assertAlmostEqual(g[i, j], num, places=5)


class TestFgsm(unittest.TestCase):
    def test_signo_recorte_y_sin_cambio_donde_el_gradiente_es_cero(self):
        X = np.array([[0.5, 0.95, 0.02, 0.4]])
        g = np.array([[2.0, 0.3, -5.0, 0.0]])
        Xa = fgsm(X, g, 0.1)
        np.testing.assert_allclose(Xa, [[0.6, 1.0, 0.0, 0.4]])
        np.testing.assert_allclose(X, [[0.5, 0.95, 0.02, 0.4]], err_msg="no debe modificar X")

    def test_epsilon_cero_y_negativo(self):
        X = np.array([[0.3, 0.7]])
        np.testing.assert_allclose(fgsm(X, np.ones_like(X), 0.0), X)
        with self.assertRaises(ValueError):
            fgsm(X, np.ones_like(X), -0.1)

    def test_aumenta_la_perdida(self):
        rng = np.random.default_rng(0)
        W, b = rng.normal(size=(6, 3)), np.zeros(3)
        X, y = rng.uniform(0.2, 0.8, size=(20, 6)), rng.integers(0, 3, size=20)
        Xa = fgsm(X, gradiente_entrada(W, b, X, y), 0.05)
        self.assertGreater(perdida_media(W, b, Xa, y), perdida_media(W, b, X, y))
        self.assertLessEqual(np.abs(Xa - X).max(), 0.05 + 1e-12)


class TestGradienteAdversario(unittest.TestCase):
    def setUp(self):
        rng = np.random.default_rng(1)
        self.W, self.b = rng.normal(size=(6, 3)), rng.normal(size=3)
        self.X, self.y = rng.uniform(size=(10, 6)), rng.integers(0, 3, size=10)

    def test_epsilon_cero_es_el_gradiente_normal(self):
        gW, gb = gradiente_adversario(self.W, self.b, self.X, self.y, 0.0, 0.5)
        rW, rb = gradiente_pesos(self.W, self.b, self.X, self.y)
        np.testing.assert_allclose(gW, rW)
        np.testing.assert_allclose(gb, rb)

    def test_mezcla_con_alfa(self):
        Xa = fgsm(self.X, gradiente_entrada(self.W, self.b, self.X, self.y), 0.1)
        lW, lb = gradiente_pesos(self.W, self.b, self.X, self.y)
        aW, ab = gradiente_pesos(self.W, self.b, Xa, self.y)
        gW, gb = gradiente_adversario(self.W, self.b, self.X, self.y, 0.1, 0.25)
        np.testing.assert_allclose(gW, 0.25 * lW + 0.75 * aW)
        np.testing.assert_allclose(gb, 0.25 * lb + 0.75 * ab)
        gW, _ = gradiente_adversario(self.W, self.b, self.X, self.y, 0.1, 0.0)
        np.testing.assert_allclose(gW, aW)

    def test_alfa_fuera_de_rango(self):
        with self.assertRaises(ValueError):
            gradiente_adversario(self.W, self.b, self.X, self.y, 0.1, 1.5)


class TestDetector(unittest.TestCase):
    def test_reducir_bits(self):
        X = np.array([[0.0, 0.2, 0.5, 0.6, 1.0]])
        np.testing.assert_allclose(reducir_bits(X, 1), [[0.0, 0.0, 0.0, 1.0, 1.0]])
        np.testing.assert_allclose(reducir_bits(X, 2), [[0.0, 1 / 3, 2 / 3, 2 / 3, 1.0]])
        with self.assertRaises(ValueError):
            reducir_bits(X, 0)

    def test_puntuacion_l1(self):
        P = np.array([[0.7, 0.2, 0.1], [0.5, 0.5, 0.0]])
        Q = np.array([[0.1, 0.2, 0.7], [0.5, 0.5, 0.0]])
        np.testing.assert_allclose(puntuacion_squeezing(P, Q), [1.2, 0.0])
        with self.assertRaises(ValueError):
            puntuacion_squeezing(P, Q[:, :2])

    def test_umbral_para_fpr(self):
        self.assertEqual(umbral_para_fpr([0.4, 0.1, 0.3, 0.2], 0.25), 0.3)
        self.assertEqual(umbral_para_fpr([0.4, 0.1, 0.3, 0.2], 0.0), 0.4)
        self.assertEqual(umbral_para_fpr([0.4, 0.1, 0.3, 0.2], 1.0), 0.1)
        self.assertEqual(umbral_para_fpr([0.2, 0.2, 0.2, 0.9], 0.25), 0.2)
        self.assertEqual(umbral_para_fpr([0.2, 0.2, 0.2, 0.9], 0.2), 0.9)
        for malo in [([], 0.1), ([0.1], -0.1), ([0.1], 1.5)]:
            with self.assertRaises(ValueError):
                umbral_para_fpr(*malo)


class TestIntegracion(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.datos = cargar_datos(0)
        X_ent, y_ent = cls.datos[0], cls.datos[1]
        cls.modelo = Clasificador().entrenar(X_ent, y_ent, epocas=150)

    def test_el_ataque_hace_caer_la_precision(self):
        X_test, y_test = self.datos[4], self.datos[5]
        curva = curva_epsilon(self.modelo, X_test, y_test, [0.0, 0.05, 0.1, 0.2])
        self.assertEqual(len(curva), 4)
        self.assertGreater(curva[0], 0.9, "sin ataque, el clasificador acierta más del 90 %")
        self.assertTrue(all(a >= c for a, c in zip(curva, curva[1:])), "más epsilon, menos precisión: %s" % curva)
        self.assertLess(curva[3], 0.5, "con epsilon 0.2 debería fallar más de la mitad: %s" % curva)

    def test_entrenamiento_adversario_aguanta_mas(self):
        X_ent, y_ent, _, _, X_test, y_test = self.datos
        robusto = Clasificador().entrenar(X_ent, y_ent, epocas=150, epsilon_adv=0.15, alfa=0.5)
        normal = curva_epsilon(self.modelo, X_test, y_test, [0.15])[0]
        adv = curva_epsilon(robusto, X_test, y_test, [0.15])[0]
        self.assertGreater(adv, normal)

    def test_detector_calibrado_marca_ataques(self):
        _, _, X_val, _, X_test, y_test = self.datos
        det = Detector(self.modelo, bits=2, fpr=0.05).calibrar(X_val)
        limpias = det.marcar(X_test).mean()
        self.assertLessEqual(limpias, 0.12, "con el umbral de validación, pocas limpias marcadas")
        Xa = fgsm(X_test, gradiente_entrada(self.modelo.W, self.modelo.b, X_test, y_test), 0.1)
        self.assertGreater(det.marcar(Xa).mean(), limpias, "marca más adversarios que limpias")


if __name__ == "__main__":
    unittest.main()
