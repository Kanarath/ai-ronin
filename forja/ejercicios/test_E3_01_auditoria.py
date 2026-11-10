"""Tests del ejercicio E3: la auditoría de Ayuda-Valle, con TU código."""

import json
import random
import unittest

from apoyo import RAIZ_REPO
from E3_01_auditoria import clasificar_hallazgo, cobertura, intervalo_wilson, muestreo_por_riesgo, resumen_auditoria

RUTA_AUDITORIA = RAIZ_REPO / "game" / "content" / "audit" / "valle_auditoria.json"


def cargar_controles():
    """Los doce controles del Dojo, con las claves del ejercicio."""
    datos = json.loads(RUTA_AUDITORIA.read_text(encoding="utf-8"))
    return [{"id": c["id"], "funcion": c["function"], "riesgo": c["risk"]} for c in datos["controls"]]


CONTROLES = cargar_controles()
ALTA = ["C05", "C07", "C08", "C10"]


def ev(existe=True, muestra=0, fallos=0, futuro=False):
    return {"control_existe": existe, "muestra": muestra, "fallos": fallos, "riesgo_futuro": futuro}


class TestMuestreo(unittest.TestCase):
    def test_alta_y_todas_las_funciones(self):
        m = muestreo_por_riesgo(CONTROLES, 5, 42)
        self.assertEqual(m, ["C01", "C05", "C07", "C08", "C10"], "4 de riesgo alto + el GOVERN de más riesgo (C01, empate con C02: id menor)")

    def test_relleno_reproducible(self):
        m = muestreo_por_riesgo(CONTROLES, 7, 3)
        self.assertEqual(m, sorted(m), "la lista va ordenada")
        self.assertEqual(len(m), 7)
        self.assertTrue(set(ALTA + ["C01"]) <= set(m))
        self.assertEqual(m, muestreo_por_riesgo(CONTROLES, 7, 3), "misma semilla, misma muestra")
        restantes = sorted(set(c["id"] for c in CONTROLES) - set(ALTA + ["C01"]))
        esperados = sorted(ALTA + ["C01"] + random.Random(3).sample(restantes, 2))
        self.assertEqual(m, esperados, "relleno con random.Random(semilla).sample sobre los restantes ordenados")

    def test_no_cabe(self):
        with self.assertRaises(ValueError):
            muestreo_por_riesgo(CONTROLES, 3, 1)
        with self.assertRaises(ValueError):
            muestreo_por_riesgo(CONTROLES, 4, 1)

    def test_maximo_mayor_que_el_universo(self):
        self.assertEqual(muestreo_por_riesgo(CONTROLES, 50, 1), sorted(c["id"] for c in CONTROLES))

    def test_funcion_sin_alta_elige_por_riesgo(self):
        cs = [{"id": "X3", "funcion": "MAP", "riesgo": "baja"}, {"id": "X2", "funcion": "MAP", "riesgo": "media"},
              {"id": "X1", "funcion": "GOVERN", "riesgo": "baja"}]
        self.assertEqual(muestreo_por_riesgo(cs, 2, 0), ["X1", "X2"])


class TestCobertura(unittest.TestCase):
    def test_muestra_del_dojo(self):
        c = cobertura(CONTROLES, ["C01", "C05", "C07", "C08", "C10", "C99"])
        self.assertAlmostEqual(c["total"], 5 / 12)
        self.assertEqual(c["por_funcion"], {"GOVERN": 0.25, "MAP": 0.5, "MEASURE": 2 / 3, "MANAGE": 1 / 3})
        self.assertEqual(c["alta"], 1.0)

    def test_sin_alta(self):
        cs = [{"id": "X1", "funcion": "MAP", "riesgo": "baja"}]
        self.assertEqual(cobertura(cs, []), {"total": 0.0, "por_funcion": {"MAP": 0.0}, "alta": 1.0})


class TestClasificar(unittest.TestCase):
    def test_controles_de_ayuda_valle(self):
        self.assertEqual(clasificar_hallazgo(ev(existe=False)), "nc-mayor", "C08: no hay evaluación de sesgos")
        self.assertEqual(clasificar_hallazgo(ev(muestra=10, fallos=3)), "nc-mayor", "C10: 3 de 10 es sistemático")
        self.assertEqual(clasificar_hallazgo(ev(muestra=12, fallos=1)), "nc-menor", "C02: un sistema fuera del inventario")
        self.assertEqual(clasificar_hallazgo(ev(futuro=True)), "observacion", "C09: plan en plazo")
        self.assertEqual(clasificar_hallazgo(ev(muestra=5)), "conforme")

    def test_umbral_incluido(self):
        self.assertEqual(clasificar_hallazgo(ev(muestra=10, fallos=2)), "nc-mayor")
        self.assertEqual(clasificar_hallazgo(ev(muestra=11, fallos=2, futuro=True)), "nc-menor")

    def test_validacion(self):
        for mala in [ev(muestra=3, fallos=4), ev(muestra=-1), ev(muestra=2.5, fallos=1), ev(muestra=0, fallos=1)]:
            with self.assertRaises(ValueError):
                clasificar_hallazgo(mala)


class TestWilson(unittest.TestCase):
    def test_tres_de_diez(self):
        bajo, alto = intervalo_wilson(3, 10)
        self.assertAlmostEqual(bajo, 0.1078, places=3)
        self.assertAlmostEqual(alto, 0.6032, places=3)

    def test_extremos(self):
        bajo, alto = intervalo_wilson(0, 15)
        self.assertEqual(bajo, 0.0)
        self.assertAlmostEqual(alto, 0.2039, places=3)
        self.assertEqual(intervalo_wilson(10, 10)[1], 1.0)

    def test_errores(self):
        for f, n in [(1, 0), (-1, 5), (6, 5)]:
            with self.assertRaises(ValueError):
                intervalo_wilson(f, n)


class TestResumen(unittest.TestCase):
    def test_auditoria_de_ayuda_valle(self):
        r = resumen_auditoria({"C10": "nc-mayor", "C01": "conforme", "C05": "nc-menor", "C08": "nc-mayor", "C07": "conforme"})
        self.assertEqual(r["conteo"], {"nc-mayor": 2, "nc-menor": 1, "observacion": 0, "conforme": 2})
        self.assertEqual(r["orden"], ["C08", "C10", "C05", "C01", "C07"])
        self.assertEqual(r["conclusion"], "desfavorable")

    def test_conclusiones(self):
        self.assertEqual(resumen_auditoria({"C01": "nc-menor", "C02": "observacion"})["conclusion"], "con-reservas")
        self.assertEqual(resumen_auditoria({"C01": "observacion"})["conclusion"], "favorable")
        self.assertEqual(resumen_auditoria({})["conteo"], {"nc-mayor": 0, "nc-menor": 0, "observacion": 0, "conforme": 0})

    def test_clase_desconocida(self):
        with self.assertRaises(ValueError):
            resumen_auditoria({"C01": "grave"})


if __name__ == "__main__":
    unittest.main()
