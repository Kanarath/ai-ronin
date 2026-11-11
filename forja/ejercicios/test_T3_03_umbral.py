"""Tests del ejercicio T3-03. El último bloque necesita también tu T2_02_abuso (DetectorKNN)."""

import unittest

from apoyo import RUTA_PETICIONES
from T3_03_umbral import coste, coste_triaje, errores, mejor_umbral, tabla_costes, triaje, umbrales_candidatos

# Cinco clientes con su puntuación (fracción de vecinos «abuso») y su clase real.
S = [0.0, 0.2, 0.4, 0.4, 0.8]
Y = ["normal", "abuso", "normal", "abuso", "abuso"]


class TestPiezas(unittest.TestCase):
    def test_errores(self):
        self.assertEqual(errores([0.1, 0.6, 0.9], ["abuso", "normal", "abuso"], 0.5, "abuso"), (1, 1))
        self.assertEqual(errores(S, Y, 0.4, "abuso"), (1, 1), "≥ umbral se bloquea: 0.4 cuenta")
        self.assertEqual(errores(S, Y, float("inf"), "abuso"), (0, 3), "sin bloquear, pasan todos los abusadores")

    def test_coste(self):
        self.assertEqual(coste(0, 3, 1, 10), 30)
        self.assertEqual(coste(3, 1, 3, 10), 19)

    def test_candidatos(self):
        self.assertEqual(umbrales_candidatos([0.5, 0.0, 0.5, 1.0]), [0.0, 0.5, 1.0, float("inf")])

    def test_tabla(self):
        self.assertEqual(tabla_costes(S, Y, "abuso", 1, 10),
                         [(0.0, 2, 0, 2), (0.2, 1, 0, 1), (0.4, 1, 1, 11), (0.8, 0, 2, 20), (float("inf"), 0, 3, 30)])


class TestElegir(unittest.TestCase):
    def test_el_mas_barato(self):
        self.assertEqual(mejor_umbral(S, Y, "abuso", 1, 10), (0.2, 1))

    def test_cambian_los_costes(self):
        self.assertEqual(mejor_umbral(S, Y, "abuso", 10, 1), (0.8, 2),
                         "si bloquear sale caro, conviene subir el umbral")

    def test_empate_elige_el_mayor(self):
        self.assertEqual(mejor_umbral([0.1, 0.9], ["normal", "abuso"], "abuso", 1, 1), (0.9, 0))
        self.assertEqual(mejor_umbral([0.5, 0.5], ["normal", "abuso"], "abuso", 1, 1), (float("inf"), 1))


class TestTriaje(unittest.TestCase):
    def test_tres_franjas(self):
        t = triaje(S, Y, "abuso", 0.2, 0.8)
        self.assertEqual(t, {"bloqueados": 1, "revision": 3, "pasan": 1, "fp": 0, "fn": 0})
        self.assertEqual(coste_triaje(t, 1, 10, 0.5), 1.5)

    def test_igual_a_un_umbral(self):
        t = triaje(S, Y, "abuso", 0.4, 0.4)
        self.assertEqual((t["fp"], t["fn"], t["revision"]), errores(S, Y, 0.4, "abuso") + (0,),
                         "con bajo == alto, es un umbral normal")

    def test_umbrales_al_reves(self):
        with self.assertRaises(ValueError):
            triaje(S, Y, "abuso", 0.8, 0.2)


class TestExperimentoUmbral(unittest.TestCase):
    """El detector de T2-02 con k=9 (reparto estratificado, test 0.3, semilla 42)."""

    @classmethod
    def setUpClass(cls):
        from T2_02_abuso import DetectorKNN, cargar_peticiones, dividir_estratificado
        _, X, y = cargar_peticiones(RUTA_PETICIONES)
        tr, te = dividir_estratificado(y, 0.3, 42)
        d = DetectorKNN(9).entrenar([X[i] for i in tr], [y[i] for i in tr])
        cls.s = [d.puntuacion(X[i], "abuso") for i in te]
        cls.y = [y[i] for i in te]

    def test_si_cambian_los_costes_cambia_el_umbral(self):
        u1, c1 = mejor_umbral(self.s, self.y, "abuso", 1, 10)
        u3, c3 = mejor_umbral(self.s, self.y, "abuso", 3, 10)
        self.assertAlmostEqual(u1, 1 / 9, msg="un bloqueo cuesta 1 y un abusador, 10")
        self.assertEqual(c1, 7)
        self.assertAlmostEqual(u3, 3 / 9, msg="si el bloqueo cuesta 3, conviene subir el umbral")
        self.assertEqual(c3, 10)

    def test_el_por_defecto_no_es_el_mejor(self):
        fp, fn = errores(self.s, self.y, 0.5, "abuso")
        self.assertGreater(coste(fp, fn, 1, 10), mejor_umbral(self.s, self.y, "abuso", 1, 10)[1])

    def test_la_revision_humana_sale_mas_barata(self):
        t = triaje(self.s, self.y, "abuso", 1 / 9 - 1e-9, 3 / 9 - 1e-9)
        self.assertEqual((t["fp"], t["fn"]), (0, 0))
        mejor_un_umbral = mejor_umbral(self.s, self.y, "abuso", 3, 10)[1]
        self.assertLess(coste_triaje(t, 3, 10, 1), mejor_un_umbral,
                        "si revisar cuesta 1, dos umbrales ganan al mejor umbral único")


if __name__ == "__main__":
    unittest.main()
