"""Tests del ejercicio C1–C3: la matriz del agente del taller (medida en el Dojo), con TU código."""

import unittest

from C1_01_matriz import bloqueado_por, cobertura_minima, puntos_unicos, resiliencia

ATAQUES = ["correo-reembolso", "correo-exfiltracion", "diputado-confundido", "memoria-envenenada", "bucle"]
MATRIZ = {
    "spotlight": {"correo-reembolso", "correo-exfiltracion", "memoria-envenenada", "bucle"},
    "least-privilege": {"correo-reembolso", "correo-exfiltracion", "memoria-envenenada"},
    "arg-validation": {"correo-reembolso", "correo-exfiltracion"},
    "user-authz": {"diputado-confundido"},
    "hitl": {"correo-reembolso", "correo-exfiltracion", "memoria-envenenada", "bucle"},
    "memory-hygiene": {"memoria-envenenada"},
    "step-budget": {"bucle"},
}


class TestBloqueadoPor(unittest.TestCase):
    def test_bucle(self):
        self.assertEqual(bloqueado_por(MATRIZ, "bucle"), ["hitl", "spotlight", "step-budget"])

    def test_desconocido(self):
        self.assertEqual(bloqueado_por(MATRIZ, "otro"), [])


class TestPuntosUnicos(unittest.TestCase):
    def test_agente(self):
        self.assertEqual(puntos_unicos(MATRIZ, ATAQUES), ["diputado-confundido"])


class TestCobertura(unittest.TestCase):
    def test_minima_sin_restricciones(self):
        self.assertEqual(cobertura_minima(MATRIZ, ATAQUES, ["hitl"]), ("spotlight", "user-authz"))

    def test_sin_la_defensa_esquivable(self):
        c = cobertura_minima(MATRIZ, ATAQUES, ["hitl", "spotlight"])
        self.assertEqual(c, ("least-privilege", "step-budget", "user-authz"))

    def test_imposible(self):
        self.assertIsNone(cobertura_minima(MATRIZ, ATAQUES, ["user-authz"]))

    def test_nada_que_cubrir(self):
        self.assertEqual(cobertura_minima(MATRIZ, []), ())


class TestResiliencia(unittest.TestCase):
    def test_cobertura_minima_es_fragil(self):
        r = resiliencia(MATRIZ, ["spotlight", "user-authz"], ATAQUES)
        self.assertEqual(r["pasan"], [])
        self.assertEqual(r["robustos"], 0)
        self.assertEqual(len(r["fragiles"]), 5)

    def test_dos_cerraduras(self):
        r = resiliencia(MATRIZ, ["spotlight", "least-privilege", "user-authz", "step-budget"], ATAQUES)
        self.assertEqual((r["pasan"], r["fragiles"], r["robustos"]), ([], ["diputado-confundido"], 4))

    def test_huecos(self):
        r = resiliencia(MATRIZ, ["memory-hygiene"], ATAQUES)
        self.assertEqual(r["pasan"], ["bucle", "correo-exfiltracion", "correo-reembolso", "diputado-confundido"])


if __name__ == "__main__":
    unittest.main()
