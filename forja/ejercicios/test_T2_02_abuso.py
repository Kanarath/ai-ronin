"""Tests del ejercicio T2-02: el detector de abuso del chatbot, con TU código de principio a fin."""

import unittest

from apoyo import RUTA_PETICIONES
from T2_02_abuso import DetectorKNN, cargar_peticiones, dividir_estratificado, linea_base, se_escapan

# Mini registro: tres clientes tranquilos y dos bots (peticiones_hora, tokens_medios, rechazos).
X_MINI = [[10, 100, 0], [20, 300, 2], [15, 200, 1], [300, 900, 30], [250, 1000, 25]]
Y_MINI = ["normal", "normal", "normal", "abuso", "abuso"]


class TestCargar(unittest.TestCase):
    def test_registro(self):
        ids, X, y = cargar_peticiones(RUTA_PETICIONES)
        self.assertEqual(len(ids), 120)
        self.assertEqual((ids[0], X[0], y[0]), ("cli-001", [14.0, 120.0, 2.0], "normal"))
        self.assertEqual(X[1], [49.0, 1011.0, 38.0], "columnas en el orden de FEATURES y como float")
        self.assertEqual((y.count("abuso"), y.count("normal")), (50, 70))


class TestDividir(unittest.TestCase):
    def test_proporciones_por_clase(self):
        y = ["a"] * 10 + ["b"] * 20
        tr, te = dividir_estratificado(y, 0.3, 7)
        self.assertEqual(sorted(tr + te), list(range(30)))
        self.assertEqual(set(tr) & set(te), set(), "train y test no pueden compartir clientes")
        self.assertEqual([y[i] for i in te].count("a"), 3)
        self.assertEqual([y[i] for i in te].count("b"), 6)
        self.assertEqual(tr, sorted(tr))
        self.assertEqual(te, sorted(te))

    def test_reproducible(self):
        y = ["a", "b"] * 20
        self.assertEqual(dividir_estratificado(y, 0.25, 1), dividir_estratificado(y, 0.25, 1))
        self.assertNotEqual(dividir_estratificado(y, 0.25, 1), dividir_estratificado(y, 0.25, 2))


class TestDetector(unittest.TestCase):
    def test_sin_entrenar(self):
        with self.assertRaises(ValueError):
            DetectorKNN(0)
        with self.assertRaises(RuntimeError):
            DetectorKNN(3).normalizar([1, 2, 3])

    def test_normaliza_con_el_train(self):
        d = DetectorKNN(1).entrenar(X_MINI, Y_MINI)
        self.assertEqual(d.minimos, [10, 100, 0])
        self.assertEqual(d.maximos, [300, 1000, 30])
        self.assertEqual(d.X[0], [0.0, 0.0, 0.0])
        self.assertAlmostEqual(d.normalizar([590, 100, 0])[0], 2.0, msg="sin recortar: más que el máximo da > 1")
        self.assertIsNot(d.y, Y_MINI, "guarda una copia de las etiquetas")

    def test_vecinos_y_votos(self):
        d = DetectorKNN(3).entrenar(X_MINI, Y_MINI)
        v = d.vecinos([12, 150, 0])
        self.assertEqual([t[0] for t in v], [0, 2, 1])
        self.assertEqual(v[0][2], "normal")
        self.assertEqual(d.predecir([280, 950, 28]), "abuso")
        self.assertEqual(d.predecir([12, 150, 0]), "normal")

    def test_puntuacion(self):
        d = DetectorKNN(5).entrenar(X_MINI, Y_MINI)
        self.assertAlmostEqual(d.puntuacion([100, 500, 10], "abuso"), 2 / 5)
        self.assertAlmostEqual(DetectorKNN(1).entrenar(X_MINI, Y_MINI).puntuacion([280, 950, 28], "abuso"), 1.0)

    def test_desempate(self):
        d = DetectorKNN(2).entrenar([[0, 0, 0], [2, 2, 2]], ["normal", "abuso"])
        self.assertEqual(d.predecir([0.5, 0.5, 0.5]), "normal", "empate a votos: gana el vecino más cercano")
        self.assertEqual(d.predecir([1.5, 1.5, 1.5]), "abuso")


class TestBaseYFallos(unittest.TestCase):
    def test_linea_base(self):
        self.assertEqual(linea_base(["a", "b", "b"], ["a", "b", "b", "b"]), ("b", 0.75))
        self.assertEqual(linea_base(["b", "a"], ["a", "a", "b"])[0], "a", "empate: orden alfabético")

    def test_se_escapan(self):
        ids = ["c3", "c1", "c2", "c4"]
        reales = ["abuso", "abuso", "normal", "abuso"]
        pred = ["normal", "normal", "abuso", "abuso"]
        self.assertEqual(se_escapan(ids, reales, pred, "abuso"), ["c1", "c3"])


class TestExperimentoAbuso(unittest.TestCase):
    """El experimento de la misión T2-02 con un reparto estratificado (test 0.3, semilla 42)."""

    @classmethod
    def setUpClass(cls):
        ids, X, y = cargar_peticiones(RUTA_PETICIONES)
        tr, te = dividir_estratificado(y, 0.3, 42)
        cls.X_tr = [X[i] for i in tr]
        cls.y_tr = [y[i] for i in tr]
        cls.X_te = [X[i] for i in te]
        cls.y_te = [y[i] for i in te]
        cls.ids_te = [ids[i] for i in te]
        cls.detector = DetectorKNN(5).entrenar(cls.X_tr, cls.y_tr)
        cls.pred = [cls.detector.predecir(x) for x in cls.X_te]

    def test_reparto(self):
        self.assertEqual(len(self.y_te), 36)
        self.assertEqual(self.y_te.count("abuso"), 15, "30 % de los 50 abusadores")

    def test_gana_a_la_linea_base(self):
        clase, base = linea_base(self.y_tr, self.y_te)
        self.assertEqual(clase, "normal")
        self.assertAlmostEqual(base, 21 / 36, msg="con estratificación, la línea base es la proporción de normales")
        acc = sum(1 for r, p in zip(self.y_te, self.pred) if r == p) / len(self.y_te)
        self.assertGreater(acc, base + 0.2, "el detector debe ganar con claridad a «siempre normal»")

    def test_los_que_se_escapan_son_lentos(self):
        escapan = se_escapan(self.ids_te, self.y_te, self.pred, "abuso")
        self.assertTrue(0 < len(escapan) < 15)
        media_abuso = sum(x[0] for x, e in zip(self.X_tr, self.y_tr) if e == "abuso") / self.y_tr.count("abuso")
        for cid in escapan:
            peticiones = self.X_te[self.ids_te.index(cid)][0]
            self.assertLess(peticiones, media_abuso,
                            "%s: los abusadores que pasan hacen menos peticiones de lo normal en un bot" % cid)


if __name__ == "__main__":
    unittest.main()
