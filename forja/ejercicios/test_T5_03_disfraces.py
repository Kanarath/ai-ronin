"""Tests del ejercicio T5-03 (los embeddings son los del Dojo)."""

import unittest

from apoyo import cargar_embeddings
from T5_03_disfraces import (coseno, evaluar, filtro_exacto, filtro_normalizado, filtro_significado,
                             juntar_letras_sueltas, normalizar, quitar_invisibles)

PROHIBIDAS = ["katana"]

# Los disfraces se escriben con \u para que veas qué carácter es cada uno.
DISFRACES = [
    "quiero una KATANA",                                   # mayúsculas
    "quiero una k a t a n a",                              # letras separadas
    "quiero una k-a-t-a-n-a",                              # separadas con guiones
    "quiero una katána",                                   # una tilde
    "quiero una kat​ana",                             # espacio de anchura cero (invisible)
    "quiero una ｋａｔａｎａ",     # letras de anchura completa: ｋａｔａｎａ
    "quiero una kаtаnа",                    # «а» cirílica, igual a la vista que la latina
]
SINONIMO = "quiero una espada"
LEGITIMOS = ["quiero un martillo", "¿tenéis un yunque de acero?", "voy a y vuelvo", "Hola, ¿a qué hora abrís?"]


class TestCapas(unittest.TestCase):
    def test_filtro_exacto(self):
        self.assertTrue(filtro_exacto("quiero una katana", PROHIBIDAS))
        self.assertFalse(filtro_exacto("quiero una KATANA", PROHIBIDAS), "el filtro ingenuo se deja engañar")

    def test_invisibles(self):
        self.assertEqual(quitar_invisibles("ka​tana"), "katana")
        self.assertEqual(quitar_invisibles("sin trucos"), "sin trucos")

    def test_letras_sueltas(self):
        self.assertEqual(juntar_letras_sueltas(["una", "k", "a", "t", "a", "n", "a"]), ["una", "katana"])
        self.assertEqual(juntar_letras_sueltas(["voy", "a", "y", "vuelvo"]), ["voy", "a", "y", "vuelvo"])
        self.assertEqual(juntar_letras_sueltas(["k", "a", "t", "y", "o"]), ["katyo"])
        self.assertEqual(juntar_letras_sueltas([]), [])

    def test_normalizar(self):
        self.assertEqual(normalizar("Quiero una K-A-T-Á-N-A!"), "quiero una katana")
        for texto in DISFRACES:
            self.assertEqual(normalizar(texto), "quiero una katana", repr(texto))

    def test_coseno(self):
        self.assertAlmostEqual(coseno([1, 0], [0, 1]), 0.0)
        self.assertAlmostEqual(coseno([1, 2], [2, 4]), 1.0)
        self.assertEqual(coseno([0, 0], [1, 1]), 0.0)

    def test_evaluar(self):
        self.assertEqual(evaluar(lambda t: "x" in t, ["x1", "y"], ["x2", "z"]), (1, 1))


class TestComparar(unittest.TestCase):
    """Los tres filtros contra los mismos ataques y los mismos clientes legítimos."""

    @classmethod
    def setUpClass(cls):
        cls.tabla = cargar_embeddings()

    def test_el_exacto_se_deja_engañar(self):
        self.assertEqual(evaluar(lambda t: filtro_exacto(t, PROHIBIDAS), DISFRACES, LEGITIMOS), (0, 0))

    def test_normalizar_atrapa_los_disfraces(self):
        self.assertEqual(evaluar(lambda t: filtro_normalizado(t, PROHIBIDAS), DISFRACES, LEGITIMOS),
                         (len(DISFRACES), 0))
        self.assertFalse(filtro_normalizado(SINONIMO, PROHIBIDAS), "un sinónimo no es un disfraz de forma")

    def test_el_significado_atrapa_el_sinonimo(self):
        def f(t):
            return filtro_significado(t, PROHIBIDAS, self.tabla)
        self.assertTrue(f(SINONIMO))
        self.assertTrue(f("QUIERO UNA ESPADA"), "normaliza antes de buscar en la tabla")
        self.assertEqual(evaluar(f, DISFRACES + [SINONIMO], LEGITIMOS), (len(DISFRACES) + 1, 0))

    def test_el_umbral_decide_los_falsos_positivos(self):
        self.assertFalse(filtro_significado("quiero un martillo", PROHIBIDAS, self.tabla))
        self.assertTrue(filtro_significado("quiero un martillo", PROHIBIDAS, self.tabla, umbral=0.6),
                        "con un umbral demasiado bajo, el filtro echa a clientes legítimos")

    def test_palabras_fuera_de_la_tabla(self):
        self.assertFalse(filtro_significado("hola qué tal", PROHIBIDAS, self.tabla))
        self.assertFalse(filtro_significado("quiero una espada", ["palabra-que-no-existe"], self.tabla))


if __name__ == "__main__":
    unittest.main()
