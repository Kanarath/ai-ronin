"""Tests del ejercicio T10-01…T10-03. Los valores de los datos reales son los mismos que da el Dojo."""

import unittest
from pathlib import Path

from T10_01_equidad import aprobar, cargar, de_los_que_devuelven, informe_umbral, precision, ratio_80, tasa_seleccion

DATOS = Path(__file__).resolve().parents[2] / "game" / "content" / "datasets"


class TestBasicas(unittest.TestCase):
    def test_tasa_seleccion(self):
        self.assertEqual(tasa_seleccion(["apta", "no_apta", "apta"], ["0", "0", "1"], "0", "apta"), 0.5)
        self.assertEqual(tasa_seleccion(["apta"], ["1"], "1", "apta"), 1.0)
        self.assertIsNone(tasa_seleccion(["apta"], ["0"], "1", "apta"), "grupo vacío: None, no división por cero")

    def test_ratio(self):
        self.assertAlmostEqual(ratio_80({"0": 0.38, "1": 0.12}), 0.12 / 0.38)
        self.assertEqual(ratio_80({"0": 0.5, "1": 0.5}), 1.0)
        self.assertEqual(ratio_80({"0": 0.0, "1": 0.0}), 1.0)

    def test_aprobar(self):
        self.assertEqual(aprobar([0.5, 0.4, 0.4], ["0", "0", "1"], 0.5), [True, False, False])
        self.assertEqual(aprobar([0.5, 0.4, 0.4], ["0", "0", "1"], 0.5, 0.35), [True, False, True])

    def test_oportunidad_y_precision(self):
        self.assertAlmostEqual(de_los_que_devuelven([True, False, True, True], [True, True, False, True]), 2 / 3)
        self.assertAlmostEqual(precision([True, False, True, True], [True, True, False, True]), 2 / 3)
        self.assertIsNone(de_los_que_devuelven([True], [False]))
        self.assertIsNone(precision([False], [True]))


class TestComoElDojo(unittest.TestCase):
    def test_candidatos_historico(self):
        filas = cargar(DATOS / "candidatos.csv")
        self.assertEqual(len(filas), 200)
        dec = [f["decision"] for f in filas]
        grp = [f["grupo"] for f in filas]
        tasas = {g: tasa_seleccion(dec, grp, g, "apta") for g in ("0", "1")}
        self.assertAlmostEqual(tasas["0"], 0.38, places=3)
        self.assertAlmostEqual(tasas["1"], 0.12, places=3)
        self.assertAlmostEqual(ratio_80(tasas), 0.32, delta=0.005)

    def test_prestamos_un_umbral(self):
        inf = informe_umbral(cargar(DATOS / "prestamos.csv"), 0.5)
        self.assertEqual(inf["grupos"]["0"]["n"], 140)
        self.assertAlmostEqual(inf["grupos"]["1"]["base"], 0.433, delta=0.001)
        self.assertAlmostEqual(inf["ratio"], 0.59, delta=0.005)
        self.assertAlmostEqual(inf["grupos"]["0"]["precision"], 0.901, delta=0.001)

    def test_prestamos_igualar_oportunidades(self):
        inf = informe_umbral(cargar(DATOS / "prestamos.csv"), 0.5, 0.45)
        self.assertAlmostEqual(inf["diferencia_oportunidad"], 0.003, delta=0.0005)
        self.assertLess(inf["ratio"], 0.8)

    def test_prestamos_igualar_aprobaciones(self):
        inf = informe_umbral(cargar(DATOS / "prestamos.csv"), 0.5, 0.35)
        self.assertGreaterEqual(inf["ratio"], 0.8)
        self.assertAlmostEqual(inf["grupos"]["1"]["precision"], 0.641, delta=0.001)
        self.assertAlmostEqual(inf["grupos"]["1"]["oportunidad"], 0.962, delta=0.001)


if __name__ == "__main__":
    unittest.main()
