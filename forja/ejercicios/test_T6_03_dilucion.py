"""Tests del ejercicio T6-03 (los valores con embeddings son los del Dojo)."""

import unittest

from apoyo import cargar_embeddings
from T6_03_dilucion import fila_atencion, parecido_necesario, peso_entre, peso_oculto, relleno_para_ahogar

RELLENO = ["fuego", "agua", "hielo", "brasa", "horno"]


class TestCuentas(unittest.TestCase):
    def test_peso_oculto(self):
        self.assertAlmostEqual(peso_oculto(0, 0, 4), 0.2)
        self.assertAlmostEqual(peso_oculto(2, 0, 10), 0.424926, places=5)
        self.assertEqual(peso_oculto(3, 0, 0), 1.0, "sin relleno, toda la atención es suya")

    def test_estable_con_puntuaciones_enormes(self):
        self.assertAlmostEqual(peso_oculto(1000, 1000, 1), 0.5)
        self.assertAlmostEqual(peso_oculto(1000, 999, 3), 0.475367, places=5)

    def test_relleno_para_ahogar(self):
        self.assertEqual(relleno_para_ahogar(0, 0, 0.5), 2)
        n = relleno_para_ahogar(2, 0, 0.1)
        self.assertEqual(n, 67)
        self.assertLess(peso_oculto(2, 0, n), 0.1)
        self.assertGreaterEqual(peso_oculto(2, 0, n - 1), 0.1, "es el MENOR n")
        with self.assertRaises(ValueError):
            relleno_para_ahogar(0, 0, 0)

    def test_parecido_necesario(self):
        self.assertAlmostEqual(parecido_necesario(0, 1, 0.5), 0.0)
        s = parecido_necesario(0, 1000, 0.5)
        self.assertAlmostEqual(peso_oculto(s, 0, 1000), 0.5, msg="con ese parecido recupera justo el objetivo")
        with self.assertRaises(ValueError):
            parecido_necesario(0, 10, 1.0)

    def test_el_parecido_crece_despacio(self):
        extra_10 = parecido_necesario(0, 10, 0.5)
        extra_1000 = parecido_necesario(0, 1000, 0.5)
        self.assertAlmostEqual(extra_1000 - extra_10, 2 * 2.302585, places=4,
                               msg="100 veces más relleno solo pide ln(100) ≈ 4,6 puntos más de parecido")


class TestAtencionDelDojo(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.t = cargar_embeddings()

    def test_fila_suma_uno_y_mascara(self):
        palabras = ["katana", "espada", "fuego"]
        fila = fila_atencion(palabras, self.t, 1, causal=True)
        self.assertAlmostEqual(sum(fila), 1.0)
        self.assertEqual(fila[2], 0.0, "con máscara causal no se ve lo que viene después")

    def test_cerca_o_lejos_da_igual(self):
        cerca = ["katana", "espada"] + RELLENO
        lejos = ["katana"] + RELLENO + ["espada"]
        self.assertAlmostEqual(peso_entre(cerca, self.t, "katana", "espada"), 0.22, delta=0.005)
        self.assertAlmostEqual(peso_entre(lejos, self.t, "katana", "espada"),
                               peso_entre(cerca, self.t, "katana", "espada"))

    def test_la_respuesta_al_final_lo_ve_todo(self):
        doc = RELLENO + ["espada", "katana"]
        self.assertAlmostEqual(peso_entre(doc, self.t, "katana", "espada", causal=True), 0.22, delta=0.005)
        self.assertEqual(peso_entre(doc, self.t, "espada", "katana", causal=True), 0.0)

    def test_el_relleno_diluye_pero_no_iguala(self):
        anterior = 1.0
        for n in (1, 5, 20, 100):
            doc = ["katana"] + RELLENO * n + ["espada"]
            fila = fila_atencion(doc, self.t, 0)
            self.assertLess(fila[-1], anterior, "más relleno, menos peso para la instrucción")
            self.assertGreater(fila[-1], max(fila[1:-1]), "pero sigue llevándose más que cualquier relleno")
            anterior = fila[-1]
        self.assertLess(anterior, 0.01)


if __name__ == "__main__":
    unittest.main()
