"""Tests del ejercicio T2-01. Necesita también tu T1_02_distancia (normalización)."""

import unittest

from apoyo import cargar_katanas
from T1_02_distancia import ajustar_minmax, aplicar_minmax
from T2_01_knn import accuracy, dividir, matriz_confusion, predecir, predecir_todos, vecinos

# Mini dataset: dos grupos bien separados.
X_MINI = [[0, 0], [3, 4], [10, 0], [10, 1], [1, 1]]
Y_MINI = ["apta", "apta", "defectuosa", "defectuosa", "apta"]


class TestDividir(unittest.TestCase):
    def test_tamanos_y_sin_solapamiento(self):
        tr, te = dividir(10, 0.3, 42)
        self.assertEqual(len(te), 3)
        self.assertEqual(len(tr), 7)
        self.assertEqual(set(tr) & set(te), set(), "train y test no pueden compartir ejemplos")
        self.assertEqual(sorted(tr + te), list(range(10)))
        self.assertEqual(tr, sorted(tr))

    def test_reproducible(self):
        self.assertEqual(dividir(50, 0.2, 7), dividir(50, 0.2, 7))
        self.assertNotEqual(dividir(50, 0.2, 7), dividir(50, 0.2, 8))

    def test_limites(self):
        tr, te = dividir(4, 0.01, 1)
        self.assertEqual(len(te), 1, "al menos 1 en test")
        tr, te = dividir(4, 0.99, 1)
        self.assertEqual(len(tr), 1, "al menos 1 en train")


class TestKnn(unittest.TestCase):
    def test_vecinos_ordenados(self):
        v = vecinos(X_MINI, Y_MINI, [0, 0], 3)
        self.assertEqual([t[0] for t in v], [0, 4, 1])
        self.assertAlmostEqual(v[0][1], 0.0)
        self.assertEqual(v[2][2], "apta")

    def test_k1(self):
        self.assertEqual(predecir(X_MINI, Y_MINI, [9, 0], 1), "defectuosa")
        self.assertEqual(predecir(X_MINI, Y_MINI, [2, 2], 1), "apta")

    def test_desempate_de_distancia_por_indice(self):
        X = [[0, 0], [2, 0]]
        self.assertEqual(vecinos(X, ["A", "B"], [1, 0], 2)[0][0], 0)
        self.assertEqual(predecir(X, ["A", "B"], [1, 0], 2), "A")
        self.assertEqual(predecir([[2, 0], [0, 0]], ["B", "A"], [1, 0], 2), "B")

    def test_mayoria(self):
        self.assertEqual(predecir(X_MINI, Y_MINI, [6, 0], 5), "apta", "3 aptas frente a 2 defectuosas")

    def test_predecir_todos(self):
        self.assertEqual(predecir_todos(X_MINI, Y_MINI, [[9, 0], [2, 2]], 1), ["defectuosa", "apta"])


class TestMetricas(unittest.TestCase):
    def test_accuracy(self):
        self.assertAlmostEqual(accuracy(["a", "b", "b", "a"], ["a", "b", "a", "a"]), 0.75)
        with self.assertRaises(ValueError):
            accuracy(["a"], ["a", "b"])

    def test_matriz_confusion(self):
        self.assertEqual(matriz_confusion(["a", "a", "b"], ["a", "b", "b"], ["a", "b"]), [[1, 1], [0, 1]])


class TestExperimentoKatanas(unittest.TestCase):
    """El experimento de la misión T2-01, con tu propio código de principio a fin."""

    @classmethod
    def setUpClass(cls):
        _, cls.X, cls.y = cargar_katanas()

    def test_k1_memoriza_su_entrenamiento(self):
        Xn = aplicar_minmax(self.X, ajustar_minmax(self.X))
        self.assertEqual(accuracy(self.y, predecir_todos(Xn, self.y, Xn, 1)), 1.0)

    def test_evaluacion_honesta(self):
        tr, te = dividir(len(self.X), 0.3, 42)
        X_tr = [self.X[i] for i in tr]
        X_te = [self.X[i] for i in te]
        y_tr = [self.y[i] for i in tr]
        y_te = [self.y[i] for i in te]
        params = ajustar_minmax(X_tr)  # ¡solo del train!
        X_tr_n = aplicar_minmax(X_tr, params)
        X_te_n = aplicar_minmax(X_te, params)
        acc_test_k1 = accuracy(y_te, predecir_todos(X_tr_n, y_tr, X_te_n, 1))
        acc_test_k9 = accuracy(y_te, predecir_todos(X_tr_n, y_tr, X_te_n, 9))
        self.assertLess(acc_test_k1, 1.0, "con datos nuevos, k=1 ya no es perfecto")
        self.assertGreater(acc_test_k9, 0.7, "con min-max y k=9 debería superar el 70 %")


if __name__ == "__main__":
    unittest.main()
