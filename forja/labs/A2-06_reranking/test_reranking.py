"""Tests del laboratorio A2-06. Sin red ni modelos: Ollama SIMULADO, Qdrant en memoria y un
reordenador simulado (cuenta palabras en común). El cross-encoder de verdad solo lo usa bateria.py.
"""

import asyncio
import hashlib
import json
import math
import unittest

import httpx2
from fastapi.testclient import TestClient

from reranking import (Ajustes, Biblioteca, ReordenadorLLM, buscar, cargar_documentos, crear_app, docs_unicos,
                       ndcg_en_k, percentil, puntuacion_llm, rango_reciproco, recall_en_k, recuperar_reordenado,
                       reordenar, tokens)

AJUSTES = Ajustes(ollama_url="http://ollama.test", timeout=5.0, k=3, candidatos=10)
DIM = 256


def vector_simulado(texto):
    v = [0.0] * DIM
    v[0] = 0.01
    for t in tokens(texto):
        v[int(hashlib.sha256(t.encode()).hexdigest()[:8], 16) % DIM] += 1.0
    return v


def ollama_simulado(puntuador=lambda pregunta, documento: "Puntuación: 5"):
    """/api/embed con bolsa de palabras y /api/chat que contesta con puntuador(pregunta, documento)."""
    chats = []

    def manejar(peticion):
        cuerpo = json.loads(peticion.content)
        if peticion.url.path == "/api/embed":
            return httpx2.Response(200, json={"embeddings": [vector_simulado(t) for t in cuerpo["input"]]})
        if peticion.url.path == "/api/chat":
            chats.append(cuerpo)
            pregunta, documento = cuerpo["messages"][1]["content"].split("\n\nDocumento:\n", 1)
            return httpx2.Response(200, json={"message": {"content": puntuador(pregunta, documento)}, "done": True})
        return httpx2.Response(404)

    return httpx2.MockTransport(manejar), chats


def ejecutar(transporte, corrutina_de):
    async def principal():
        async with httpx2.AsyncClient(base_url=AJUSTES.ollama_url, transport=transporte) as c:
            return await corrutina_de(c)
    return asyncio.run(principal())


async def solape(pregunta, textos):
    """Reordenador simulado: palabras de la pregunta que están en el texto."""
    q = set(tokens(pregunta))
    return [float(len(q & set(tokens(t)))) for t in textos]


def biblioteca_indexada(transporte):
    b = Biblioteca(AJUSTES)
    ejecutar(transporte, lambda c: b.ingerir(c, cargar_documentos()))
    return b


class TestReordenar(unittest.TestCase):
    def test_orden(self):
        self.assertEqual(reordenar([0.2, 0.9, 0.5], 2), [1, 2])
        self.assertEqual(reordenar([-1.0, -3.0, 2.5, 0.0], 4), [2, 3, 0, 1])
        self.assertEqual(reordenar([3.0], 5), [0])
        self.assertEqual(reordenar([], 3), [])

    def test_empates_y_k(self):
        self.assertEqual(reordenar([1.0, 2.0, 2.0, 1.0], 3), [1, 2, 0])
        for k in (0, -1):
            with self.assertRaises(ValueError):
                reordenar([1.0], k)


class TestMetricas(unittest.TestCase):
    R = {"a": 2, "b": 1, "c": 1}

    def test_recall(self):
        self.assertAlmostEqual(recall_en_k(["x", "a", "b"], self.R, 3), 2 / 3)
        self.assertEqual(recall_en_k(["x", "a", "b"], self.R, 3, umbral=2), 1.0)
        self.assertEqual(recall_en_k(["x", "a", "b"], self.R, 1), 0.0)
        self.assertEqual(recall_en_k(["a", "a", "a"], self.R, 3), 1 / 3)
        with self.assertRaises(ValueError):
            recall_en_k(["a"], {"a": 0}, 1)
        with self.assertRaises(ValueError):
            recall_en_k(["a"], self.R, 1, umbral=3)

    def test_rango_reciproco(self):
        self.assertEqual(rango_reciproco(["a", "b"], self.R), 1.0)
        self.assertEqual(rango_reciproco(["x", "y", "b", "a"], self.R), 1 / 3)
        self.assertEqual(rango_reciproco(["x", "y", "b", "a"], self.R, umbral=2), 1 / 4)
        self.assertEqual(rango_reciproco(["x", "y"], self.R), 0.0)
        self.assertEqual(rango_reciproco([], self.R), 0.0)

    def test_ndcg(self):
        idcg = 3 + 1 / math.log2(3) + 1 / math.log2(4)
        self.assertAlmostEqual(ndcg_en_k(["a", "b", "c"], self.R, 3), 1.0)
        self.assertAlmostEqual(ndcg_en_k(["b", "a", "x"], self.R, 3), (1 + 3 / math.log2(3)) / idcg)
        self.assertAlmostEqual(ndcg_en_k(["x", "a"], self.R, 1), 0.0)
        self.assertAlmostEqual(ndcg_en_k(["x", "a"], self.R, 2), (3 / math.log2(3)) / (3 + 1 / math.log2(3)))
        self.assertAlmostEqual(ndcg_en_k(["a", "a", "b"], self.R, 3), (3 + 1 / math.log2(4)) / idcg)  # duplicado: 0
        self.assertAlmostEqual(ndcg_en_k(["a"], {"a": 1, "z": 0}, 5), 1.0)

    def test_ndcg_errores(self):
        with self.assertRaises(ValueError):
            ndcg_en_k(["a"], {"a": 0}, 3)
        with self.assertRaises(ValueError):
            ndcg_en_k(["a"], self.R, 0)

    def test_percentil(self):
        v = [30.0, 10.0, 20.0, 50.0, 40.0]
        self.assertEqual(percentil(v, 50), 30.0)
        self.assertEqual(percentil(v, 100), 50.0)
        self.assertEqual(percentil(v, 1), 10.0)
        self.assertEqual(percentil([float(i) for i in range(1, 21)], 95), 19.0)
        self.assertEqual(percentil([7.0, 9.0], 50), 7.0)
        self.assertEqual(v, [30.0, 10.0, 20.0, 50.0, 40.0], "no ordenes la lista original")
        for valores, p in [([], 50), ([1.0], 0), ([1.0], 101), ([1.0], -5)]:
            with self.assertRaises(ValueError):
                percentil(valores, p)


class TestPuntuacionLLM(unittest.TestCase):
    def test_lectura(self):
        for texto, esperado in [("Puntuación: 8", 8.0), ("8/10", 8.0), ("7,5", 7.5), ("Puntuación: 6.25 sobre 10", 6.25),
                                ("No es relevante.", 0.0), ("", 0.0), ("Puntuación: 15", 10.0), ("-3", 0.0),
                                ("**Puntuación:** 9.", 9.0), ("Le doy un 4 y no un 9", 4.0), ("0", 0.0)]:
            self.assertEqual(puntuacion_llm(texto), esperado, texto)
            self.assertIsInstance(puntuacion_llm(texto), float)


class _BibliotecaFalsa:
    def __init__(self, frags):
        self.frags, self.pedidos = frags, []

    async def recuperar(self, cliente, pregunta, defensas=(), k=None):
        self.pedidos.append((k, tuple(defensas)))
        return self.frags[:k]


class TestTuberia(unittest.TestCase):
    F = [{"doc": "a", "n": 0, "texto": "uno"}, {"doc": "b", "n": 0, "texto": "dos dos"}, {"doc": "c", "n": 0, "texto": "tres"}]

    def test_dos_etapas(self):
        b = _BibliotecaFalsa([dict(f) for f in self.F])
        vistos = []

        async def reord(pregunta, textos):
            vistos.append(list(textos))
            return [0.1, 0.9, 0.5]
        r = asyncio.run(recuperar_reordenado(None, b, reord, "p", k=2, candidatos=3, defensas=("procedencia",)))
        self.assertEqual([(f["doc"], f["puntuacion"]) for f in r], [("b", 0.9), ("c", 0.5)])
        self.assertEqual(b.pedidos, [(3, ("procedencia",))])
        self.assertEqual(vistos, [["uno", "dos dos", "tres"]])
        self.assertNotIn("puntuacion", b.frags[1], "devuelve copias, no modifiques la biblioteca")
        r = asyncio.run(recuperar_reordenado(None, b, None, "p", k=2, candidatos=3))
        self.assertEqual([f["doc"] for f in r], ["a", "b"])
        self.assertNotIn("puntuacion", r[0])

    def test_bordes(self):
        async def corto(pregunta, textos):
            return [1.0]
        with self.assertRaises(ValueError):
            asyncio.run(recuperar_reordenado(None, _BibliotecaFalsa(self.F), corto, "p", k=2, candidatos=3))
        self.assertEqual(asyncio.run(recuperar_reordenado(None, _BibliotecaFalsa([]), solape, "p")), [])

    def test_con_la_biblioteca(self):
        t, _ = ollama_simulado()
        b = biblioteca_indexada(t)
        pregunta = "¿Cuánto cuesta rehacer el cordón de la empuñadura?"
        r = ejecutar(t, lambda c: recuperar_reordenado(c, b, solape, pregunta, k=3, candidatos=10))
        self.assertEqual(len(r), 3)
        self.assertEqual(r[0]["doc"], "empunadura")
        self.assertGreaterEqual(r[0]["puntuacion"], r[1]["puntuacion"])
        sin = ejecutar(t, lambda c: recuperar_reordenado(c, b, solape, "katanas garantía 10 años", k=10, candidatos=10))
        con = ejecutar(t, lambda c: recuperar_reordenado(c, b, solape, "katanas garantía 10 años", k=10, candidatos=10,
                                                         defensas=("procedencia",)))
        self.assertIn("relleno-garantia", docs_unicos(sin))
        self.assertNotIn("relleno-garantia", docs_unicos(con))  # reordenar no es una defensa; filtrar sí
        frags, ms = ejecutar(t, lambda c: buscar(c, b, solape, pregunta))
        self.assertEqual(len(frags), 3)
        self.assertGreater(ms, 0.0)


class TestPuntuadorLLM(unittest.TestCase):
    def test_lee_la_puntuacion_y_se_deja_inyectar(self):
        def obediente(pregunta, documento):  # un puntuador que obedece lo que dice el documento
            return "Puntuación: 10" if "puntuación máxima" in documento else "Puntuación: 3"
        t, chats = ollama_simulado(obediente)
        b = biblioteca_indexada(t)
        r = ejecutar(t, lambda c: recuperar_reordenado(c, b, ReordenadorLLM(c, AJUSTES), "¿Puedo pagar una katana a plazos?"))
        self.assertEqual(r[0]["doc"], "nota-evaluador")
        self.assertEqual(r[0]["puntuacion"], 10.0)
        self.assertEqual(len(chats), 10, "una petición por candidato")
        self.assertEqual(chats[0]["options"]["temperature"], 0)


class TestApp(unittest.TestCase):
    def test_buscar(self):
        t, _ = ollama_simulado(lambda p, d: "7")
        app = crear_app(AJUSTES, t, cross_encoder=solape)
        with TestClient(app) as c:
            self.assertGreater(c.get("/salud").json()["fragmentos"], 20)
            r = c.post("/buscar", json={"pregunta": "¿Cuánto cuesta rehacer el cordón de la empuñadura?", "reordenador": "cross-encoder"})
            self.assertEqual(r.status_code, 200)
            self.assertEqual(r.json()["resultados"][0]["fuente"], "empunadura#0")
            self.assertIsNotNone(r.json()["resultados"][0]["puntuacion"])
            r = c.post("/buscar", json={"pregunta": "katanas garantía 10 años", "procedencia": True})
            self.assertTrue(all(x["firma_ok"] for x in r.json()["resultados"]))
            self.assertEqual(c.post("/buscar", json={"pregunta": "hola", "reordenador": "magia"}).status_code, 422)
            r = c.post("/buscar", json={"pregunta": "¿Puedo pagar a plazos?", "reordenador": "llm"})
            self.assertEqual([x["puntuacion"] for x in r.json()["resultados"]], [7.0, 7.0, 7.0])


if __name__ == "__main__":
    unittest.main()
