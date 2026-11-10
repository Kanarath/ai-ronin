"""Tests del ejercicio P0-03. Igual que en T4-02, el test clave es el GRADIENT CHECK, ahora con
todos los parámetros de las matrices a la vez. Y una comprobación nueva: procesar el lote entero
debe dar lo mismo que procesar los ejemplos de uno en uno."""

import unittest

import numpy as np

from P0_03_mlp import MLP, sigmoide

X_XOR = np.array([[0, 0], [0, 1], [1, 0], [1, 1]], dtype=float)
Y_XOR = np.array([[0], [1], [1], [0]], dtype=float)


def red_fija():
    """La red fija de T4-02 (2 entradas, 3 ocultas), con W1 traspuesta a la convención de aquí."""
    red = MLP(2, 3, semilla=0)
    red.W1 = np.array([[1.0, -2.0], [0.5, 0.3], [-1.2, 0.8]]).T
    red.b1 = np.array([0.5, -0.1, 0.2])
    red.W2 = np.array([[3.0], [-1.0], [0.7]])
    red.b2 = np.array([-1.0])
    return red


def gradiente_numerico(red, X, Y, nombre, eps=1e-5):
    """Diferencias finitas centradas para TODOS los elementos de un parámetro (lo escribe Claude)."""
    param = getattr(red, nombre)
    g = np.zeros_like(param)
    for idx in np.ndindex(param.shape):
        original = param[idx]
        param[idx] = original + eps
        mas = red.perdida(X, Y)
        param[idx] = original - eps
        menos = red.perdida(X, Y)
        param[idx] = original
        g[idx] = (mas - menos) / (2 * eps)
    return g


class TestEstructura(unittest.TestCase):
    def test_formas_y_semilla(self):
        red = MLP(3, 5, semilla=7)
        self.assertEqual((red.W1.shape, red.b1.shape, red.W2.shape, red.b2.shape), ((3, 5), (5,), (5, 1), (1,)))
        self.assertTrue(np.all(red.b1 == 0) and np.all(red.b2 == 0))
        self.assertTrue(np.all(np.abs(red.W1) <= 1) and np.all(np.abs(red.W2) <= 1))
        otra = MLP(3, 5, semilla=7)
        np.testing.assert_array_equal(red.W1, otra.W1)
        np.testing.assert_array_equal(red.W2, otra.W2)
        rng = np.random.default_rng(7)
        np.testing.assert_array_equal(red.W1, rng.uniform(-1, 1, size=(3, 5)), "primero W1, con default_rng")
        self.assertFalse(np.array_equal(MLP(3, 5, semilla=8).W1, red.W1))

    def test_forward_como_en_T4_02(self):
        """Mismos números que test_forward de T4-02, entrada [2, 1]."""
        A1, P = red_fija().forward([[2.0, 1.0]])
        self.assertEqual((A1.shape, P.shape), ((1, 3), (1, 1)))
        z1 = np.array([1.0 * 2 - 2.0 * 1 + 0.5, 0.5 * 2 + 0.3 * 1 - 0.1, -1.2 * 2 + 0.8 * 1 + 0.2])
        np.testing.assert_allclose(A1[0], sigmoide(z1))
        z2 = 3.0 * sigmoide(z1[0]) - 1.0 * sigmoide(z1[1]) + 0.7 * sigmoide(z1[2]) - 1.0
        self.assertAlmostEqual(P[0, 0], 1 / (1 + np.exp(-z2)))

    def test_lote_igual_que_uno_a_uno(self):
        red = MLP(4, 6, semilla=3)
        X = np.random.default_rng(0).normal(size=(10, 4))
        _, P = red.forward(X)
        for i in range(10):
            self.assertAlmostEqual(P[i, 0], red.forward(X[i:i + 1])[1][0, 0])


class TestGradientCheck(unittest.TestCase):
    def test_todos_los_parametros(self):
        for red, X, Y in [(red_fija(), X_XOR, Y_XOR), (MLP(3, 4, semilla=1), np.random.default_rng(2).normal(size=(7, 3)),
                                                       np.array([[1], [0], [0], [1], [1], [0], [1]], dtype=float))]:
            g = red.gradientes(X, Y)
            self.assertEqual(set(g), {"W1", "b1", "W2", "b2"})
            for nombre in ("W1", "b1", "W2", "b2"):
                self.assertEqual(g[nombre].shape, getattr(red, nombre).shape, "forma de ∂%s" % nombre)
                np.testing.assert_allclose(g[nombre], gradiente_numerico(red, X, Y, nombre), atol=1e-7,
                                           err_msg="gradiente de %s" % nombre)

    def test_gradientes_no_modifica_la_red(self):
        red = red_fija()
        red.gradientes(X_XOR, Y_XOR)
        np.testing.assert_array_equal(red.W1, red_fija().W1)
        np.testing.assert_array_equal(red.W2, red_fija().W2)

    def test_paso_en_el_sitio(self):
        red = red_fija()
        antes = red.perdida(X_XOR, Y_XOR)
        self.assertIsInstance(antes, float)
        W1 = red.W1
        self.assertIsNone(red.paso(red.gradientes(X_XOR, Y_XOR), 0.1))
        self.assertIs(red.W1, W1, "en el sitio: el mismo array, con otros valores (usa -=)")
        self.assertLess(red.perdida(X_XOR, Y_XOR), antes)


class TestXor(unittest.TestCase):
    def test_aprende_xor(self):
        resueltas = 0
        for semilla in range(5):
            red = MLP(2, 4, semilla=semilla)
            h = red.entrenar(X_XOR, Y_XOR, 1.0, 3000)
            self.assertEqual(len(h), 3001)
            self.assertLess(h[-1], h[0])
            pred = red.predecir(X_XOR)
            self.assertEqual(pred.shape, (4,))
            resueltas += bool(np.array_equal(pred, [0, 1, 1, 0]))
        self.assertGreaterEqual(resueltas, 4)


if __name__ == "__main__":
    unittest.main()
