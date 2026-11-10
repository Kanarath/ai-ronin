"""Tests del laboratorio E4-03. No necesitan red, ni Docker, ni modelo."""

import tempfile
import unittest
from pathlib import Path

from politica import (decidir_canary, desde_compose, despliegues_de_compose, evaluar, puerto_expuesto, regla_imagen,
                      regla_modelo, regla_puertos, regla_recursos, regla_usuario, repartir)

DIGEST = "baf6a787fdffd633537aa2eb51cfd54cb93ff08e28040095462bb63daf552878"
PERMITIDOS = {"llama3.2:1b": DIGEST}
TODAS = ["modelo", "usuario", "recursos", "puertos", "imagen"]


def bueno(**cambios):
    d = {"nombre": "carga", "imagen": "python:3.13-slim", "usuario": "10001", "privilegiado": False,
         "puertos": ["127.0.0.1:8000:8000"], "recursos": {"cpus": "1", "memoria": "512m"},
         "modelo": {"nombre": "llama3.2:1b", "digest": "sha256:" + DIGEST}}
    d.update(cambios)
    return d


class TestModelo(unittest.TestCase):
    def test_permitido(self):
        self.assertEqual(regla_modelo(bueno(), PERMITIDOS), [])
        self.assertEqual(regla_modelo(bueno(modelo={"nombre": "llama3.2:1b", "digest": DIGEST.upper()}), PERMITIDOS), [])
        self.assertEqual(regla_modelo(bueno(modelo=None), PERMITIDOS), [], "sin modelo, la regla no aplica")

    def test_no_permitido_y_huella(self):
        self.assertEqual(regla_modelo(bueno(modelo={"nombre": "llama3.2:1b-uncensored", "digest": DIGEST}), PERMITIDOS),
                         ["modelo-no-permitido"])
        otro = "sha256:" + "0" * 64
        self.assertEqual(regla_modelo(bueno(modelo={"nombre": "llama3.2:1b", "digest": otro}), PERMITIDOS), ["modelo-huella"])
        self.assertEqual(regla_modelo(bueno(modelo={"nombre": "llama3.2:1b", "digest": None}), PERMITIDOS), ["modelo-huella"])


class TestUsuario(unittest.TestCase):
    def test_no_root(self):
        for u in ["10001", "forja", "10001:10001"]:
            self.assertEqual(regla_usuario(bueno(usuario=u)), [], u)

    def test_root_y_sin_declarar(self):
        for u in ["0", "root", "0:0", "root:root"]:
            self.assertEqual(regla_usuario(bueno(usuario=u)), ["usuario-root"], u)
        for u in [None, ""]:
            self.assertEqual(regla_usuario(bueno(usuario=u)), ["usuario-sin-declarar"])

    def test_privilegiado(self):
        self.assertEqual(regla_usuario(bueno(usuario="0", privilegiado=True)), ["usuario-root", "privilegiado"])
        d = bueno()
        del d["privilegiado"]
        self.assertEqual(regla_usuario(d), [])


class TestRecursos(unittest.TestCase):
    def test_limites(self):
        self.assertEqual(regla_recursos(bueno()), [])
        self.assertEqual(regla_recursos(bueno(recursos={})), ["sin-limite-cpu", "sin-limite-memoria"])
        self.assertEqual(regla_recursos(bueno(recursos={"cpus": "2", "memoria": ""})), ["sin-limite-memoria"])
        d = bueno()
        del d["recursos"]
        self.assertEqual(regla_recursos(d), ["sin-limite-cpu", "sin-limite-memoria"])


class TestPuertos(unittest.TestCase):
    def test_corta(self):
        casos = {"8000": True, "8000:8000": True, "127.0.0.1:8000:8000": False, "0.0.0.0:8000:8000": True,
                 "127.0.0.1:8000:8000/tcp": False, "192.168.1.20:8000:8000": True, "[::1]:8000:8000": False,
                 "[::]:8000:8000": True, "127.0.0.2:53:53/udp": False, "localhost:8000:8000": True,
                 "::1:8000:8000": True}
        for p, esperado in casos.items():
            self.assertEqual(puerto_expuesto(p), esperado, p)

    def test_larga(self):
        self.assertFalse(puerto_expuesto({"target": 8000, "published": 8000, "host_ip": "127.0.0.1"}))
        self.assertTrue(puerto_expuesto({"target": 8000, "published": 8000}))
        self.assertTrue(puerto_expuesto({"target": 8000, "host_ip": "0.0.0.0"}))

    def test_regla(self):
        self.assertEqual(regla_puertos(bueno()), [])
        self.assertEqual(regla_puertos(bueno(puertos=["127.0.0.1:8000:8000", "11434:11434"])), ["puerto-expuesto"])
        d = bueno()
        del d["puertos"]
        self.assertEqual(regla_puertos(d), [])


class TestImagen(unittest.TestCase):
    def test_fijadas(self):
        for img in ["python:3.13-slim", "ollama/ollama:0.40.16", "python@sha256:" + "a" * 64,
                    "localhost:5000/forja:1.2", "qdrant/qdrant:v1.20.0"]:
            self.assertEqual(regla_imagen(bueno(imagen=img)), [], img)

    def test_sin_fijar(self):
        for img in ["python", "python:latest", "localhost:5000/forja", "ollama/ollama:latest", ""]:
            self.assertEqual(regla_imagen(bueno(imagen=img)), ["imagen-sin-fijar"], img)


class TestEvaluar(unittest.TestCase):
    def test_pasa(self):
        self.assertEqual(evaluar(bueno(), TODAS, PERMITIDOS), {"permitido": True, "violaciones": []})

    def test_varias_violaciones_ordenadas(self):
        d = bueno(usuario="0", imagen="python:latest", puertos=["8000:8000", "0.0.0.0:9000:9000"])
        self.assertEqual(evaluar(d, TODAS, PERMITIDOS),
                         {"permitido": False, "violaciones": ["imagen-sin-fijar", "puerto-expuesto", "usuario-root"]})

    def test_solo_las_reglas_pedidas(self):
        d = bueno(usuario="0", recursos={})
        self.assertTrue(evaluar(d, ["modelo", "imagen"], PERMITIDOS)["permitido"])
        self.assertEqual(evaluar(d, [], PERMITIDOS), {"permitido": True, "violaciones": []})
        with self.assertRaises(ValueError):
            evaluar(d, ["modelo", "intuicion"], PERMITIDOS)


class TestCanary(unittest.TestCase):
    def test_repartir_determinista(self):
        self.assertEqual(repartir("peticion-7", 25), repartir("peticion-7", 25))
        self.assertEqual(repartir("cualquiera", 0), "estable")
        self.assertEqual(repartir("cualquiera", 100), "canary")
        lados = [repartir("p%d" % i, 25) for i in range(2000)]
        self.assertAlmostEqual(lados.count("canary") / 2000, 0.25, delta=0.04)
        for p in [-1, 101]:
            with self.assertRaises(ValueError):
                repartir("x", p)

    def test_repartir_valor_exacto(self):
        import hashlib
        h = int(hashlib.sha256("req-0".encode("utf-8")).hexdigest(), 16) % 100
        self.assertEqual(repartir("req-0", h), "estable")
        self.assertEqual(repartir("req-0", h + 1), "canary")

    def test_decidir(self):
        u = {"min_muestras": 5, "margen_errores": 0.05, "factor_latencia": 1.5}
        estable = {"n": 30, "errores": 0, "p95": 4.0}
        self.assertEqual(decidir_canary(estable, {"n": 4, "errores": 4, "p95": 99.0}, u), "continuar")
        self.assertEqual(decidir_canary(estable, {"n": 10, "errores": 1, "p95": 4.1}, u), "revertir")
        self.assertEqual(decidir_canary(estable, {"n": 10, "errores": 0, "p95": 6.1}, u), "revertir")
        self.assertEqual(decidir_canary(estable, {"n": 10, "errores": 0, "p95": 6.0}, u), "promover")
        self.assertEqual(decidir_canary({"n": 0, "errores": 0, "p95": 4.0}, {"n": 20, "errores": 1, "p95": 3.0}, u), "promover",
                         "1/20 = 0,05 no supera 0 + 0,05")


class TestCompose(unittest.TestCase):
    def test_traduce_compose_y_dockerfile(self):
        with tempfile.TemporaryDirectory() as d:
            (Path(d) / "Dockerfile").write_text("FROM python:3.13-slim\nRUN useradd forja\nUSER forja\n", encoding="utf-8")
            (Path(d) / "compose.yaml").write_text(
                "services:\n"
                "  ollama:\n    image: ollama/ollama:0.40.16\n    ports: ['127.0.0.1:11434:11434']\n"
                "  app:\n    build: .\n    ports: ['8000:8000']\n    deploy:\n      resources:\n        limits: {cpus: '1', memory: 512m}\n",
                encoding="utf-8")
            ollama, app = despliegues_de_compose(Path(d) / "compose.yaml")
        self.assertEqual(evaluar(ollama, TODAS, PERMITIDOS)["violaciones"],
                         ["sin-limite-cpu", "sin-limite-memoria", "usuario-sin-declarar"])
        self.assertEqual((app["imagen"], app["usuario"]), ("python:3.13-slim", "forja"))
        self.assertEqual(evaluar(app, TODAS, PERMITIDOS)["violaciones"], ["puerto-expuesto"])
        self.assertEqual(desde_compose("x", {"image": "a:1", "user": "0"})["usuario"], "0")


if __name__ == "__main__":
    unittest.main()
