"""Tests del ejercicio T5-02 (misma tabla de embeddings que el Dojo)."""

import unittest

from apoyo import cargar_embeddings
from T5_02_embeddings import analogia, coseno, vecinos


class TestEmbeddings(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.t = cargar_embeddings()

    def test_coseno(self):
        self.assertAlmostEqual(coseno([1, 0], [0, 1]), 0.0)
        self.assertAlmostEqual(coseno([2, 2], [1, 1]), 1.0)
        self.assertAlmostEqual(coseno([0, 0], [1, 1]), 0.0)

    def test_como_el_dojo(self):
        self.assertAlmostEqual(coseno(self.t["fuego"], self.t["hielo"]), -1.0)
        self.assertAlmostEqual(coseno(self.t["katana"], self.t["espada"]), 0.999, delta=0.001)

    def test_vecinos(self):
        top = vecinos(self.t, self.t["katana"], 4, excluir=("katana",))
        self.assertEqual([p for p, _ in top], ["espada", "daga", "escudo", "lanza"])

    def test_analogias(self):
        self.assertEqual(analogia(self.t, "maestro", "hombre", "mujer"), "maestra")
        self.assertEqual(analogia(self.t, "herrero", "hombre", "mujer"), "herrera")

    def test_sesgo_de_aprendiz(self):
        top = vecinos(self.t, self.t["aprendiz"], 2, excluir=("aprendiz",))
        self.assertEqual({p for p, _ in top}, {"herrera", "maestra"}, "el sesgo que encontraste en la misión")


if __name__ == "__main__":
    unittest.main()
