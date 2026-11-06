"""Tests del ejercicio T1-02. Los valores del dataset real son los mismos que calcula el Dojo."""

import unittest

from apoyo import cargar_katanas
from T1_02_distancia import (ajustar_minmax, ajustar_zscore, aplicar_minmax, aplicar_zscore,
                             contribuciones, distancia_euclidea, distancia_manhattan)


class TestDistancias(unittest.TestCase):
    def test_euclidea_3_4_5(self):
        self.assertAlmostEqual(distancia_euclidea([0, 0], [3, 4]), 5.0)

    def test_manhattan(self):
        self.assertAlmostEqual(distancia_manhattan([0, 0], [3, -4]), 7.0)

    def test_longitudes_distintas_lanzan_error(self):
        with self.assertRaises(ValueError):
            distancia_euclidea([1, 2], [1, 2, 3])
        with self.assertRaises(ValueError):
            distancia_manhattan([1], [1, 2])

    def test_contribuciones(self):
        c = contribuciones([0, 0], [3, 4])
        self.assertAlmostEqual(c[0], 0.36)
        self.assertAlmostEqual(c[1], 0.64)
        self.assertEqual(contribuciones([1, 1], [1, 1]), [0.0, 0.0])


class TestNormalizacion(unittest.TestCase):
    def test_minmax(self):
        params = ajustar_minmax([[1, 10], [3, 30]])
        self.assertEqual(params, [(1, 3), (10, 30)])
        self.assertEqual(aplicar_minmax([[2, 20]], params), [[0.5, 0.5]])

    def test_minmax_no_modifica_la_entrada(self):
        X = [[2.0, 20.0]]
        aplicar_minmax(X, [(1, 3), (10, 30)])
        self.assertEqual(X, [[2.0, 20.0]])

    def test_minmax_columna_constante(self):
        self.assertEqual(aplicar_minmax([[5, 1]], ajustar_minmax([[5, 0], [5, 2]])), [[0.0, 0.5]])

    def test_minmax_con_parametros_de_otros_datos_puede_salir_de_0_1(self):
        params = ajustar_minmax([[0], [10]])
        self.assertEqual(aplicar_minmax([[15]], params), [[1.5]])

    def test_zscore(self):
        params = ajustar_zscore([[1], [3]])
        self.assertAlmostEqual(params[0][0], 2.0)
        self.assertAlmostEqual(params[0][1], 1.0)
        self.assertEqual(aplicar_zscore([[1], [3]], params), [[-1.0], [1.0]])


class TestComoElDojo(unittest.TestCase):
    """Mismos resultados que `distance` en el Dojo (misión T1-02)."""

    @classmethod
    def setUpClass(cls):
        cls.ids, cls.X, cls.y = cargar_katanas()

    def fila(self, X, hoja):
        return X[self.ids.index(hoja)]

    def test_distancia_sin_normalizar(self):
        a, b = self.fila(self.X, "hoja-001"), self.fila(self.X, "hoja-002")
        self.assertAlmostEqual(distancia_euclidea(a, b), 69.068, delta=0.001)
        self.assertAlmostEqual(contribuciones(a, b)[2], 0.998, delta=0.001, msg="la temperatura domina")

    def test_distancia_minmax(self):
        Xn = aplicar_minmax(self.X, ajustar_minmax(self.X))
        a, b = self.fila(Xn, "hoja-001"), self.fila(Xn, "hoja-002")
        self.assertAlmostEqual(distancia_euclidea(a, b), 0.664, delta=0.001)
        self.assertAlmostEqual(contribuciones(a, b)[2], 0.763, delta=0.001, msg="sigue pesando: relevancia ≠ escala")

    def test_distancia_zscore(self):
        Xz = aplicar_zscore(self.X, ajustar_zscore(self.X))
        a, b = self.fila(Xz, "hoja-010"), self.fila(Xz, "hoja-020")
        self.assertAlmostEqual(distancia_euclidea(a, b), 2.82, delta=0.001)


if __name__ == "__main__":
    unittest.main()
