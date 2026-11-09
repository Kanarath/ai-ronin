"""Tests del ejercicio C5: las reglas del encargo final, escritas por TI."""

import unittest

from C5_01_encargo import estado_retest, priorizar, resumen, validar_hallazgo

ACTIVOS = {
    "A-01": {"en_alcance": True, "amenazas": ["LLM01", "LLM02", "LLM05", "LLM07", "LLM10"]},
    "A-05": {"en_alcance": True, "amenazas": ["LLM03", "LLM04", "ASI04", "ASI05"]},
    "A-06": {"en_alcance": False, "amenazas": []},
}
EVIDENCIAS = {"A-01": 11, "A-05": 0}


class TestValidar(unittest.TestCase):
    def test_ok(self):
        self.assertEqual(validar_hallazgo("A-01", "LLM07", ACTIVOS, EVIDENCIAS), (True, "ok"))

    def test_motivos_en_orden(self):
        self.assertEqual(validar_hallazgo("A-09", "LLM07", ACTIVOS, EVIDENCIAS), (False, "activo-desconocido"))
        self.assertEqual(validar_hallazgo("A-06", "LLM99", ACTIVOS, EVIDENCIAS), (False, "fuera-de-alcance"))
        self.assertEqual(validar_hallazgo("A-01", "LLM11", ACTIVOS, EVIDENCIAS), (False, "categoria-invalida"))
        self.assertEqual(validar_hallazgo("A-05", "LLM09", ACTIVOS, EVIDENCIAS), (False, "no-encaja"))
        self.assertEqual(validar_hallazgo("A-05", "LLM03", ACTIVOS, EVIDENCIAS), (False, "sin-evidencia"), "0 éxitos")
        self.assertEqual(validar_hallazgo("A-05", "LLM03", ACTIVOS, {}), (False, "sin-evidencia"), "sin batería")


class TestRetest(unittest.TestCase):
    def test_estados(self):
        self.assertEqual(estado_retest(None, 1.0), "abierto: sin batería")
        self.assertEqual(estado_retest(2, 1.0), "abierto: siguen los ataques")
        self.assertEqual(estado_retest(0, None), "abierto: sin evaluar tareas")
        self.assertEqual(estado_retest(0, 0.75), "abierto: rompe tareas")
        self.assertEqual(estado_retest(0, 1.0), "corregido")


class TestPriorizar(unittest.TestCase):
    def test_impacto_antes_que_exitos(self):
        hallazgos = [
            {"id": "H1", "impacto": "medio", "exposicion": "publico", "exitos": 11, "total": 11},   # 4 + 1.0
            {"id": "H5", "impacto": "critico", "exposicion": "interno", "exitos": 7, "total": 7},   # 4 + 1.0
            {"id": "H3", "impacto": "alto", "exposicion": "interno", "exitos": 5, "total": 5},      # 3 + 1.0
            {"id": "H2", "impacto": "bajo", "exposicion": "interno", "exitos": 1, "total": 5},      # 1 + 0.2
            {"id": "H4", "impacto": "alto", "exposicion": "publico", "exitos": 1, "total": 5},      # 6 + 0.2
        ]
        self.assertEqual(priorizar(hallazgos), ["H4", "H1", "H5", "H3", "H2"])


class TestResumen(unittest.TestCase):
    def test_cerrable(self):
        self.assertEqual(resumen({"H1": "corregido", "H2": "corregido"}), {"total": 2, "corregidos": 2, "abiertos": 0, "cerrable": True})

    def test_abierto(self):
        self.assertEqual(resumen({"H1": "corregido", "H2": "abierto: rompe tareas"}), {"total": 2, "corregidos": 1, "abiertos": 1, "cerrable": False})
        self.assertEqual(resumen({})["cerrable"], False)


if __name__ == "__main__":
    unittest.main()
