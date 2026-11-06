"""Tests del ejercicio A2-01 (los resultados con la base de la forja son los del Dojo)."""

import math
import unittest

from apoyo import cargar_kb
from A2_01_rag import buscar, construir_idf, coseno, terminos, trocear, vectorizar


def indexar(documentos, tam=40, solape=10):
    fragmentos = []
    for d in documentos:
        for i, f in enumerate(trocear(d["text"], tam, solape)):
            fragmentos.append({"id": f"{d['id']}#{i}", "acceso": d["access"], "texto": f})
    idf = construir_idf([f["texto"] for f in fragmentos])
    for f in fragmentos:
        f["vector"] = vectorizar(f["texto"], idf)
    return fragmentos, idf


class TestPiezas(unittest.TestCase):
    def test_terminos(self):
        self.assertEqual(terminos("La garantía es de 2 años"), ["garantía", "años"])

    def test_trocear(self):
        self.assertEqual(trocear("a b c d e f g h i j", 4, 2), ["a b c d", "c d e f", "e f g h", "g h i j"])
        self.assertEqual(trocear("a b c", 10, 2), ["a b c"])

    def test_idf(self):
        idf = construir_idf(["aceite hoja", "aceite envío"])
        self.assertAlmostEqual(idf["aceite"], math.log(3 / 3) + 1)
        self.assertAlmostEqual(idf["hoja"], math.log(3 / 2) + 1)

    def test_vector_normalizado(self):
        v = vectorizar("aceite aceite hoja", {"aceite": 1.0, "hoja": 2.0})
        self.assertAlmostEqual(sum(w * w for w in v.values()), 1.0)
        self.assertAlmostEqual(coseno(v, v), 1.0)


class TestComoElDojo(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.docs = cargar_kb()
        cls.indice, cls.idf = indexar(cls.docs)

    def test_trece_fragmentos(self):
        self.assertEqual(len(self.indice), 13)

    def test_recuperacion(self):
        top = buscar("aceite para proteger la hoja", self.indice, self.idf, 3, "cliente", False)
        self.assertTrue(top[0][0].startswith("cuidados"))

    def test_acl(self):
        sin_acl = buscar("precio de coste de una katana básica", self.indice, self.idf, 1, "cliente", False)
        self.assertTrue(sin_acl[0][0].startswith("costes"), "sin ACL, un cliente recupera costes internos")
        con_acl = buscar("precio de coste de una katana básica", self.indice, self.idf, 3, "cliente", True)
        self.assertFalse(any(i.startswith(("costes", "proveedores")) for i, _ in con_acl))
        empleado = buscar("precio de coste de una katana básica", self.indice, self.idf, 1, "empleado", True)
        self.assertTrue(empleado[0][0].startswith("costes"))


if __name__ == "__main__":
    unittest.main()
