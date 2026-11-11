"""Tests del ejercicio T7-01…T7-04."""

import random
import unittest

from T7_01_arboles import asignar, gini, mas_raros, mejor_corte, mover_centros, muestra_bootstrap, predecir, votar


class TestGini(unittest.TestCase):
    def test_puro_y_mitad(self):
        self.assertEqual(gini(["a", "a", "a"]), 0.0)
        self.assertAlmostEqual(gini(["abuso", "abuso", "normal", "normal"]), 0.5)

    def test_tres_clases_y_vacio(self):
        self.assertAlmostEqual(gini(["a", "b", "c"]), 2 / 3)
        self.assertAlmostEqual(gini(["a", "a", "a", "b"]), 0.375)
        self.assertEqual(gini([]), 0.0)


class TestMejorCorte(unittest.TestCase):
    def test_separa_perfecto(self):
        self.assertEqual(mejor_corte([1, 2, 10, 11], ["a", "a", "b", "b"]), (6.0, 0.0))

    def test_desordenado(self):
        u, g = mejor_corte([10, 1, 11, 2], ["b", "a", "b", "a"])
        self.assertEqual(u, 6.0)
        self.assertEqual(g, 0.0)

    def test_no_perfecto(self):
        u, g = mejor_corte([1, 2, 3, 4], ["a", "a", "b", "a"])
        self.assertEqual(u, 2.5)
        self.assertAlmostEqual(g, 0.25)

    def test_empate_umbral_menor(self):
        u, _ = mejor_corte([1, 2, 3], ["a", "b", "a"])
        self.assertEqual(u, 1.5)

    def test_sin_corte(self):
        u, g = mejor_corte([5, 5, 5], ["a", "b", "b"])
        self.assertIsNone(u)
        self.assertAlmostEqual(g, 4 / 9)


class TestPredecir(unittest.TestCase):
    ARBOL = {"f": 0, "t": 61.9,
             "izq": {"f": 1, "t": 820.0, "izq": {"hoja": "defectuosa"}, "der": {"hoja": "apta"}},
             "der": {"hoja": "defectuosa"}}

    def test_ramas(self):
        self.assertEqual(predecir(self.ARBOL, [60.0, 850.0]), "apta")
        self.assertEqual(predecir(self.ARBOL, [60.0, 700.0]), "defectuosa")
        self.assertEqual(predecir(self.ARBOL, [63.0, 850.0]), "defectuosa")

    def test_igual_va_a_la_izquierda(self):
        self.assertEqual(predecir(self.ARBOL, [61.9, 820.0]), "defectuosa")
        self.assertEqual(predecir({"hoja": "x"}, [1]), "x")


class TestBosque(unittest.TestCase):
    def test_bootstrap(self):
        r = random.Random(7)
        self.assertEqual(muestra_bootstrap(5, 7), [r.randrange(5) for _ in range(5)])
        m = muestra_bootstrap(200, 1)
        self.assertEqual(len(m), 200)
        self.assertTrue(all(0 <= i < 200 for i in m))
        self.assertLess(len(set(m)), 200, "con repetición: algunos índices salen varias veces")

    def test_votar(self):
        self.assertEqual(votar(["abuso", "normal", "abuso"]), "abuso")
        self.assertEqual(votar(["normal", "abuso"]), "abuso", "empate: orden alfabético")
        self.assertEqual(votar(["b"]), "b")


class TestKMeans(unittest.TestCase):
    PUNTOS = [[0.0, 0.0], [0.1, 0.0], [1.0, 1.0], [0.9, 1.0]]

    def test_asignar(self):
        self.assertEqual(asignar(self.PUNTOS, [[0.0, 0.0], [1.0, 1.0]]), [0, 0, 1, 1])
        self.assertEqual(asignar([[0.5, 0.5]], [[0.0, 0.0], [1.0, 1.0]]), [0], "empate: índice menor")

    def test_mover(self):
        nuevos = mover_centros(self.PUNTOS, [0, 0, 1, 1], [[0.0, 0.0], [1.0, 1.0]])
        self.assertAlmostEqual(nuevos[0][0], 0.05)
        self.assertAlmostEqual(nuevos[1][0], 0.95)
        self.assertAlmostEqual(nuevos[1][1], 1.0)

    def test_centro_vacio(self):
        viejos = [[0.0, 0.0], [5.0, 5.0]]
        nuevos = mover_centros(self.PUNTOS, [0, 0, 0, 0], viejos)
        self.assertEqual(nuevos[1], [5.0, 5.0])
        self.assertEqual(viejos[1], [5.0, 5.0], "no modifiques la lista original")

    def test_mas_raros(self):
        self.assertEqual(mas_raros(self.PUNTOS, [0.0, 0.0], 2), [2, 3])
        self.assertEqual(mas_raros([[1.0], [-1.0], [0.0]], [0.0], 2), [0, 1], "empate: índice menor primero")


if __name__ == "__main__":
    unittest.main()
