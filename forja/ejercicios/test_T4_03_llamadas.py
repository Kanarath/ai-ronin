"""Tests del ejercicio T4-03: el clasificador de llamadas del agente, con TU código."""

import unittest

from apoyo import RUTA_LLAMADAS
from T4_03_llamadas import (accuracy, cargar_llamadas, con_cruce, entrenar_logistica, explicar, motivo,
                            predecir, sigmoide)

NOMBRES = ["origen", "destino", "cruce"]
MARGEN_ANALISTA = 0.4  # la regla legible del Dojo: peligrosa si |origen − destino| > 0,4


class TestPiezas(unittest.TestCase):
    def test_cargar(self):
        ids, X, y = cargar_llamadas(RUTA_LLAMADAS)
        self.assertEqual(len(X), 60)
        self.assertEqual((ids[0], X[0], y[0]), ("call-001", [0.2, 0.93], 1))
        self.assertEqual(y[1], 0)
        self.assertEqual(sum(y), 30)

    def test_motivo(self):
        self.assertEqual(motivo(0.9, 0.1), "fuga")
        self.assertEqual(motivo(0.1, 0.9), "entrada no fiable")
        self.assertEqual(motivo(0.9, 0.85), "")
        self.assertEqual(motivo(0.1, 0.12), "")
        self.assertEqual(motivo(0.9, 0.6, margen=0.2), "fuga")

    def test_con_cruce(self):
        X = [[0.9, 0.1], [0.2, 0.2]]
        Xc = con_cruce(X)
        self.assertAlmostEqual(Xc[0][2], 0.8)
        self.assertEqual(Xc[1], [0.2, 0.2, 0.0])
        self.assertEqual(X[0], [0.9, 0.1], "no modifiques X")

    def test_sigmoide(self):
        self.assertEqual(sigmoide(0), 0.5)
        self.assertAlmostEqual(sigmoide(-1000), 0.0)
        self.assertAlmostEqual(sigmoide(1000), 1.0)

    def test_un_paso_de_entrenamiento(self):
        pesos, sesgo = entrenar_logistica([[1.0], [-1.0]], [1, 0], 1, 1.0)
        self.assertAlmostEqual(pesos[0], 0.5, msg="con pesos 0, err = 0.5 − y: gradiente medio −0.5")
        self.assertAlmostEqual(sesgo, 0.0)

    def test_predecir_y_accuracy(self):
        self.assertEqual(predecir([[1, 0], [0, 1]], [1.0, -1.0], 0.0), [1, 0])
        self.assertEqual(predecir([[0, 0]], [1.0, 1.0], 0.0), [1], "z = 0 → probabilidad 0,5 → clase 1")
        self.assertAlmostEqual(accuracy([1, 0, 1, 1], [1, 1, 1, 1]), 0.75)

    def test_explicar(self):
        self.assertEqual(explicar([1, 2], [0.5, -2], 0.1, ["a", "b"]), [("b", -4), ("a", 0.5), ("sesgo", 0.1)])


class TestExperimentoLlamadas(unittest.TestCase):
    """La misión T4-03 con tu código: 1000 épocas, lr 1."""

    @classmethod
    def setUpClass(cls):
        _, cls.X, cls.y = cargar_llamadas(RUTA_LLAMADAS)
        cls.Xc = con_cruce(cls.X)
        cls.pesos, cls.sesgo = entrenar_logistica(cls.Xc, cls.y, 1000, 1.0)

    def test_la_regla_del_analista_acierta(self):
        pred = [1 if motivo(o, d) else 0 for o, d in self.X]
        self.assertEqual(accuracy(self.y, pred), 1.0)

    def test_una_neurona_con_dos_features_falla(self):
        pesos, sesgo = entrenar_logistica(self.X, self.y, 1000, 1.0)
        self.assertLessEqual(accuracy(self.y, predecir(self.X, pesos, sesgo)), 0.7,
                             "con forma de XOR, una recta no separa las clases")

    def test_con_el_cruce_acierta(self):
        self.assertEqual(accuracy(self.y, predecir(self.Xc, self.pesos, self.sesgo)), 1.0)

    def test_redescubre_la_regla(self):
        self.assertGreater(abs(self.pesos[2]), 10 * max(abs(self.pesos[0]), abs(self.pesos[1])),
                           "casi todo el peso va a la feature del cruce")
        frontera = -self.sesgo / self.pesos[2]
        self.assertAlmostEqual(frontera, MARGEN_ANALISTA, delta=0.1,
                               msg="la neurona bloquea cuando el cruce pasa de ≈0,4: la regla del analista")

    def test_cada_decision_se_explica(self):
        fuga = explicar([0.9, 0.1, 0.8], self.pesos, self.sesgo, NOMBRES)
        self.assertEqual(fuga[0][0], "cruce", "lo que más empuja a bloquear una fuga es el cruce")
        self.assertGreater(fuga[0][1], 0)
        segura = explicar([0.85, 0.8, 0.05], self.pesos, self.sesgo, NOMBRES)
        self.assertEqual(segura[0][0], "sesgo", "sin cruce, gana el sesgo, que empuja a «segura»")
        self.assertLess(sum(c for _, c in segura), 0)


if __name__ == "__main__":
    unittest.main()
