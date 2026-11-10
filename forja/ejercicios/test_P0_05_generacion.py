"""Tests del ejercicio P0-05. El «modelo» son los bigramas del corpus de la forja (como en T6-01),
escritos aquí por Claude para no depender de tu solución de T6-01."""

import itertools
import random
import re
import types
import unittest

from apoyo import cargar_corpus
from P0_05_generacion import con_presupuesto, en_streaming, frecuencias, generar, muestrear

DIST = [("a", 0.5), ("b", 0.3), ("c", 0.2)]


class RngFijo:
    """Un rng de mentira que devuelve los valores que le digamos (y cuenta las llamadas)."""
    def __init__(self, *valores):
        self.valores = list(valores)
        self.llamadas = 0

    def random(self):
        self.llamadas += 1
        return self.valores.pop(0)


def modelo_bigramas():
    toks = re.findall(r"\w+|[^\w\s]", cargar_corpus().lower())
    cuentas = {}
    for a, b in zip(toks, toks[1:]):
        cuentas.setdefault(a, {})
        cuentas[a][b] = cuentas[a].get(b, 0) + 1

    def siguiente(token):
        c = cuentas.get(token, {})
        total = sum(c.values())
        return sorted(((t, v / total) for t, v in c.items()), key=lambda tp: (-tp[1], tp[0]))
    return siguiente, cuentas


class TestMuestrear(unittest.TestCase):
    def test_suma_acumulada(self):
        for u, esperado in [(0.0, "a"), (0.49, "a"), (0.5, "b"), (0.65, "b"), (0.8, "c"), (0.999, "c")]:
            rng = RngFijo(u)
            self.assertEqual(muestrear(DIST, rng), esperado, "u = %s" % u)
            self.assertEqual(rng.llamadas, 1, "una sola llamada a rng.random()")

    def test_redondeo(self):
        self.assertEqual(muestrear([("a", 0.3), ("b", 0.3), ("c", 0.3999999)], RngFijo(0.9999999)), "c")

    def test_frecuencias(self):
        f = frecuencias(DIST, random.Random(0), 20000)
        for t, p in DIST:
            self.assertAlmostEqual(f[t], p, delta=0.015)
        self.assertAlmostEqual(sum(f.values()), 1.0)
        self.assertEqual(frecuencias([("solo", 1.0)], random.Random(1), 10), {"solo": 1.0})


class TestGenerar(unittest.TestCase):
    def test_es_un_generador_perezoso(self):
        llamadas = []

        def siguiente(t):
            llamadas.append(t)
            return [("x", 1.0)]
        gen = generar(siguiente, "inicio", random.Random(0))
        self.assertIsInstance(gen, types.GeneratorType)
        self.assertEqual(llamadas, [], "crear el generador no ejecuta nada todavía")
        self.assertEqual(list(itertools.islice(gen, 3)), ["x", "x", "x"])
        self.assertEqual(llamadas, ["inicio", "x", "x"], "solo se pide al modelo lo que se consume")

    def test_paradas(self):
        self.assertEqual(len(list(generar(lambda t: [("x", 1.0)], "a", random.Random(0), max_tokens=5))), 5)
        self.assertEqual(list(generar(lambda t: [(".", 1.0)], "a", random.Random(0))), ["."], "fin se entrega y para")
        self.assertEqual(list(generar(lambda t: [], "a", random.Random(0))), [], "sin continuación, termina")
        cadena = {"a": [("b", 1.0)], "b": [("c", 1.0)]}
        self.assertEqual(list(generar(lambda t: cadena.get(t, []), "a", random.Random(0))), ["b", "c"])

    def test_con_el_corpus(self):
        siguiente, cuentas = modelo_bigramas()
        texto = list(generar(siguiente, "la", random.Random(42), max_tokens=30))
        self.assertGreater(len(texto), 0)
        self.assertLessEqual(len(texto), 30)
        for a, b in zip(["la"] + texto, texto):
            self.assertIn(b, cuentas[a], "«%s %s» no aparece en el corpus" % (a, b))
        self.assertEqual(texto, list(generar(siguiente, "la", random.Random(42), max_tokens=30)), "misma semilla, mismo texto")
        distintos = {tuple(generar(siguiente, "la", random.Random(s), max_tokens=30)) for s in range(10)}
        self.assertGreater(len(distintos), 5, "con semillas distintas salen textos distintos")


class TestStreaming(unittest.TestCase):
    def test_en_streaming(self):
        self.assertEqual(list(en_streaming(["la", "hoja", ",", "templada", "."])), ["la", " hoja", ",", " templada", "."])
        self.assertEqual(list(en_streaming([])), [])
        self.assertIsInstance(en_streaming(iter([])), types.GeneratorType)

    def test_presupuesto_en_bytes(self):
        piezas = ["la", " forja", " 🔥", " arde"]
        self.assertEqual(list(con_presupuesto(piezas, 100)), piezas)
        self.assertEqual(list(con_presupuesto(piezas, 8)), ["la", " forja"])
        self.assertEqual(list(con_presupuesto(piezas, 12)), ["la", " forja"], "« 🔥» ocupa 5 bytes, no 2")
        self.assertEqual(list(con_presupuesto(piezas, 13)), ["la", " forja", " 🔥"])
        self.assertEqual(list(con_presupuesto(piezas, 0)), [])

    def test_presupuesto_corta_un_generador_infinito(self):
        infinito = generar(lambda t: [("katana", 1.0)], ".", random.Random(0), max_tokens=10**9)
        texto = "".join(con_presupuesto(en_streaming(infinito), 50))
        self.assertTrue(texto.startswith("katana katana"))
        self.assertLessEqual(len(texto.encode("utf-8")), 50)
        self.assertGreater(len(texto.encode("utf-8")), 50 - len(" katana"))


if __name__ == "__main__":
    unittest.main()
