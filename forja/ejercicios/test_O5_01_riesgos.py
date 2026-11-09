"""Tests del ejercicio O5: la carpeta de gobernanza de la forja, con TU código."""

import unittest

from O5_01_riesgos import clasificar_ai_act, residual, resumen_registro, riesgo, tratamiento_permitido

BASE = {"infiere_emociones": False, "contexto": "otro", "motivo": "", "uso": "", "interactua_con_personas": False}


def sistema(**cambios):
    s = dict(BASE)
    s.update(cambios)
    return s


RIESGOS = [
    {"id": "R1", "p": 4, "i": 2, "p_mitigada": 1},
    {"id": "R2", "p": 5, "i": 2, "p_mitigada": 1},
    {"id": "R3", "p": 4, "i": 5, "p_mitigada": 1},
    {"id": "R4", "p": 3, "i": 5, "p_mitigada": 1},
    {"id": "R5", "p": 3, "i": 4, "p_mitigada": 1},
    {"id": "R6", "p": 5, "i": 5, "p_mitigada": None},
]


class TestClasificar(unittest.TestCase):
    def test_los_cuatro_de_la_forja(self):
        self.assertEqual(clasificar_ai_act(sistema(infiere_emociones=True, contexto="trabajo", motivo="productividad")), "prohibido")
        self.assertEqual(clasificar_ai_act(sistema(uso="seleccion-personal")), "alto")
        self.assertEqual(clasificar_ai_act(sistema(interactua_con_personas=True)), "transparencia")
        self.assertEqual(clasificar_ai_act(sistema()), "minimo")

    def test_excepcion_de_seguridad(self):
        s = sistema(infiere_emociones=True, contexto="trabajo", motivo="seguridad", interactua_con_personas=True)
        self.assertEqual(clasificar_ai_act(s), "transparencia", "la excepción no la hace prohibida; sigue el resto de reglas")

    def test_emociones_fuera_del_trabajo(self):
        self.assertEqual(clasificar_ai_act(sistema(infiere_emociones=True, contexto="otro")), "minimo")

    def test_orden(self):
        s = sistema(uso="seleccion-personal", interactua_con_personas=True)
        self.assertEqual(clasificar_ai_act(s), "alto")


class TestRiesgo(unittest.TestCase):
    def test_producto(self):
        self.assertEqual(riesgo(4, 5), 20)

    def test_rango(self):
        for p, i in [(0, 3), (6, 1), (3, 2.5)]:
            with self.assertRaises(ValueError):
                riesgo(p, i)


class TestResidual(unittest.TestCase):
    def test_tratamientos(self):
        r3 = RIESGOS[2]
        self.assertEqual(residual(r3, "mitigar"), 5)
        self.assertEqual(residual(r3, "evitar"), 0)
        self.assertEqual(residual(r3, "aceptar"), 20)
        self.assertEqual(residual(r3, None), 20)


class TestPermitido(unittest.TestCase):
    def test_motivos(self):
        self.assertEqual(tratamiento_permitido(RIESGOS[5], "mitigar", 6), (False, "no-mitigable"))
        self.assertEqual(tratamiento_permitido(RIESGOS[0], "aceptar", 6), (False, "fuera-del-apetito"))
        self.assertEqual(tratamiento_permitido(RIESGOS[0], "aceptar", 8), (True, "ok"))
        self.assertEqual(tratamiento_permitido(RIESGOS[5], "evitar", 6), (True, "ok"))


class TestResumen(unittest.TestCase):
    def test_sin_tratar(self):
        res = resumen_registro(RIESGOS, {}, 6)
        self.assertEqual(res["dentro"], 0)
        self.assertEqual(res["fuera"], ["R1", "R2", "R3", "R4", "R5", "R6"])

    def test_bien_tratado(self):
        t = {"R1": "mitigar", "R2": "mitigar", "R3": "mitigar", "R4": "mitigar", "R5": "mitigar", "R6": "evitar"}
        self.assertEqual(resumen_registro(RIESGOS, t, 6), {"dentro": 6, "fuera": [], "evitados_innecesarios": []})

    def test_evitar_de_mas(self):
        t = {"R1": "evitar", "R6": "evitar"}
        res = resumen_registro(RIESGOS, t, 6)
        self.assertEqual(res["evitados_innecesarios"], ["R1"])
        self.assertEqual(res["dentro"], 2)


if __name__ == "__main__":
    unittest.main()
