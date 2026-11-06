"""Tests del ejercicio T5-01. Los resultados con el corpus de la forja son los del Dojo (misión T5-01)."""

import unittest

from apoyo import cargar_corpus
from T5_01_bpe import aplicar_fusion, codificar, entrenar_bpe, pre_tokenizar, simbolos


class TestPiezas(unittest.TestCase):
    def test_pre_tokenizar(self):
        self.assertEqual(pre_tokenizar("Hola, katana."), ["Hola", ",", "katana", "."])

    def test_simbolos(self):
        self.assertEqual(simbolos("ab"), ["▁", "a", "b"])

    def test_aplicar_fusion(self):
        self.assertEqual(aplicar_fusion(["▁", "a", "b", "a", "b"], "a", "b"), ["▁", "ab", "ab"])
        self.assertEqual(aplicar_fusion(["a", "a", "a"], "a", "a"), ["aa", "a"], "de izquierda a derecha, sin solapar")

    def test_entrenar_pequeno(self):
        fusiones, base = entrenar_bpe("ab ab ab ac", 2)
        self.assertEqual(fusiones, [("▁", "a"), ("▁a", "b")])
        self.assertEqual(base, {"▁", "a", "b", "c"})
        self.assertEqual(codificar("ab ac", fusiones, base), ["▁ab", "▁a", "c"])

    def test_desconocidos(self):
        fusiones, base = entrenar_bpe("aaa", 0)
        self.assertIn("<?>", codificar("ab", fusiones, base))


class TestComoElDojo(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.corpus = cargar_corpus()

    def test_sin_fusiones(self):
        f, base = entrenar_bpe(self.corpus, 0)
        self.assertEqual(len(codificar("la katana del maestro", f, base)), 22)

    def test_50_fusiones(self):
        f, base = entrenar_bpe(self.corpus, 50)
        self.assertEqual(codificar("la katana del maestro", f, base), ["▁la", "▁", "k", "atana", "▁de", "l", "▁maestro"])

    def test_200_fusiones(self):
        f, base = entrenar_bpe(self.corpus, 200)
        self.assertEqual(codificar("la katana del maestro", f, base), ["▁la", "▁katana", "▁del", "▁maestro"])
        self.assertEqual(len(codificar("the sword of the master", f, base)), 19)
        self.assertEqual(codificar("katanaforjada", f, base), ["▁katana", "f", "orja", "da"])


if __name__ == "__main__":
    unittest.main()
