"""Tests del ejercicio T6-01 (los valores con el corpus son los del Dojo)."""

import unittest

from apoyo import cargar_corpus
from T6_01_sampling import con_temperatura, contar_bigramas, distribucion, tokenizar, top_p


class TestPiezas(unittest.TestCase):
    def test_tokenizar(self):
        self.assertEqual(tokenizar("La Katana."), ["la", "katana", "."])

    def test_contar(self):
        self.assertEqual(contar_bigramas(["a", "b", "a", "c"]), {"a": {"b": 1, "c": 1}, "b": {"a": 1}})

    def test_temperatura(self):
        d = [("a", 0.5), ("b", 0.3), ("c", 0.2)]
        self.assertEqual(con_temperatura(d, 0), [("a", 1.0)])
        frio = dict(con_temperatura(d, 0.5))
        self.assertAlmostEqual(frio["a"], 0.25 / (0.25 + 0.09 + 0.04))
        self.assertAlmostEqual(sum(p for _, p in con_temperatura(d, 3)), 1.0)

    def test_top_p(self):
        d = [("a", 0.5), ("b", 0.3), ("c", 0.2)]
        self.assertEqual([t for t, _ in top_p(d, 0.6)], ["a", "b"])
        self.assertAlmostEqual(sum(p for _, p in top_p(d, 0.6)), 1.0)


class TestComoElDojo(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.cuentas = contar_bigramas(tokenizar(cargar_corpus()))

    def test_tras_la(self):
        d = distribucion(self.cuentas, "la")
        self.assertEqual(d[0][0], "forja")
        self.assertAlmostEqual(d[0][1], 7 / 30)
        self.assertEqual(d[1][0], "hoja")

    def test_temperaturas(self):
        d = distribucion(self.cuentas, "la")
        self.assertAlmostEqual(dict(con_temperatura(d, 0.1))["forja"], 0.824, delta=0.001)
        self.assertAlmostEqual(dict(con_temperatura(d, 2))["hoja"], 0.124, delta=0.001)

    def test_top_p(self):
        self.assertEqual(len(top_p(distribucion(self.cuentas, "la"), 0.5)), 3)


if __name__ == "__main__":
    unittest.main()
