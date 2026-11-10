"""Tests del ejercicio P0-02. Las dos clases deben dar EXACTAMENTE el mismo modelo: la
vectorización cambia la velocidad, no las matemáticas."""

import re
import unittest
from pathlib import Path

import numpy as np

from apoyo import cargar_katanas
from P0_02_logistica import (RegresionLogistica, RegresionLogisticaNumPy, ampliar_cuadrados, cronometrar,
                             estandarizar)

X_MINI = [[0.0, 1.0], [1.0, 0.0], [2.0, 1.0], [3.0, 3.0]]
Y_MINI = [0, 0, 1, 1]


def katanas():
    _, X, calidad = cargar_katanas()
    return X, [1 if c == "defectuosa" else 0 for c in calidad]


def accuracy(pred, y):
    return sum(int(p) == t for p, t in zip(pred, y)) / len(y)


def sin_ajustar_lanza(test, modelo):
    """Llamar a probabilidades antes de ajustar debe lanzar RuntimeError (no un NotImplementedError)."""
    try:
        modelo.probabilidades(X_MINI)
    except NotImplementedError:
        raise
    except RuntimeError:
        return
    test.fail("probabilidades sin ajustar debe lanzar RuntimeError")


class TestNumPy(unittest.TestCase):
    def test_estandarizar(self):
        Xs, medias, desv = estandarizar([[1, 5], [3, 5]])
        # Fijar versiones: lo que pasa hoy debe pasar mañana. Si falla, instala requirements.txt.
        texto = (Path(__file__).parent / "requirements.txt").read_text(encoding="utf-8")
        self.assertEqual(np.__version__, re.search(r"^numpy==([\d.]+)$", texto, re.M).group(1), "versión de NumPy")
        np.testing.assert_allclose(Xs, [[-1.0, 0.0], [1.0, 0.0]])
        np.testing.assert_allclose(medias, [2.0, 5.0])
        np.testing.assert_allclose(desv, [1.0, 1.0], err_msg="una columna constante divide entre 1")
        X, _ = katanas()
        Xs, _, _ = estandarizar(X)
        self.assertEqual(Xs.shape, (240, 3))
        np.testing.assert_allclose(Xs.mean(axis=0), 0.0, atol=1e-12)
        np.testing.assert_allclose(Xs.std(axis=0), 1.0)

    def test_ampliar_cuadrados(self):
        np.testing.assert_allclose(ampliar_cuadrados(np.array([[1.0, -2.0], [0.5, 3.0]])),
                                   [[1.0, -2.0, 1.0, 4.0], [0.5, 3.0, 0.25, 9.0]])


class TestClasePura(unittest.TestCase):
    def test_estado_inicial(self):
        m = RegresionLogistica(lr=0.3, epocas=7)
        self.assertEqual((m.lr, m.epocas, m.pesos, m.sesgo, m.historial), (0.3, 7, None, 0.0, []))
        self.assertEqual((RegresionLogistica().lr, RegresionLogistica().epocas), (0.1, 1000))
        sin_ajustar_lanza(self, m)

    def test_una_epoca_a_mano(self):
        m = RegresionLogistica(lr=1.0, epocas=1)
        self.assertIs(m.ajustar(X_MINI, Y_MINI), m, "ajustar devuelve self")
        # Con pesos 0, p = 0.5 para todos: e = [0.5, 0.5, −0.5, −0.5].
        self.assertAlmostEqual(m.pesos[0], -(0.5 * 0 + 0.5 * 1 - 0.5 * 2 - 0.5 * 3) / 4)
        self.assertAlmostEqual(m.pesos[1], -(0.5 * 1 + 0.5 * 0 - 0.5 * 1 - 0.5 * 3) / 4)
        self.assertAlmostEqual(m.sesgo, 0.0)
        self.assertEqual(len(m.historial), 2)
        self.assertAlmostEqual(m.historial[0], 0.6931471805599453)

    def test_aprende_y_predice(self):
        m = RegresionLogistica(lr=0.5, epocas=200).ajustar(X_MINI, Y_MINI)
        self.assertEqual(len(m.historial), 201)
        self.assertTrue(all(b <= a + 1e-12 for a, b in zip(m.historial, m.historial[1:])), "la pérdida no sube")
        self.assertEqual(m.predecir(X_MINI), [0, 0, 1, 1])
        self.assertEqual(m.predecir(X_MINI, umbral=0.0), [1, 1, 1, 1])
        self.assertIsInstance(m.probabilidades(X_MINI), list)

    def test_ajustar_otra_vez_reinicia(self):
        m = RegresionLogistica(lr=0.5, epocas=20)
        primera = list(m.ajustar(X_MINI, Y_MINI).pesos)
        self.assertEqual(list(m.ajustar(X_MINI, Y_MINI).pesos), primera)


class TestVectorizada(unittest.TestCase):
    def test_hereda(self):
        self.assertTrue(issubclass(RegresionLogisticaNumPy, RegresionLogistica))
        for metodo in ("__init__", "predecir"):
            self.assertNotIn(metodo, RegresionLogisticaNumPy.__dict__, "%s se hereda, no se reescribe" % metodo)
        sin_ajustar_lanza(self, RegresionLogisticaNumPy())

    def test_mismo_modelo_que_la_pura(self):
        Xa = ampliar_cuadrados(estandarizar(katanas()[0])[0])
        y = katanas()[1]
        pura = RegresionLogistica(0.5, 60).ajustar(Xa.tolist(), y)
        vect = RegresionLogisticaNumPy(0.5, 60).ajustar(Xa, y)
        self.assertIsInstance(vect.pesos, np.ndarray)
        self.assertIsInstance(vect.perdida(Xa, y), float)
        np.testing.assert_allclose(vect.pesos, pura.pesos, atol=1e-9)
        self.assertAlmostEqual(vect.sesgo, pura.sesgo, delta=1e-9)
        np.testing.assert_allclose(vect.historial, pura.historial, atol=1e-9)
        np.testing.assert_allclose(vect.probabilidades(Xa), pura.probabilidades(Xa.tolist()), atol=1e-9)
        self.assertEqual(list(vect.predecir(Xa)), pura.predecir(Xa.tolist()))


class TestKatanas(unittest.TestCase):
    def test_una_recta_no_basta(self):
        """Las defectuosas están en los EXTREMOS (muy duras o muy blandas): ninguna recta las separa."""
        X, y = katanas()
        Xs = estandarizar(X)[0]
        recta = RegresionLogisticaNumPy(0.5, 300).ajustar(Xs, y)
        self.assertLess(accuracy(recta.predecir(Xs), y), 0.65)
        Xa = ampliar_cuadrados(Xs)
        curva = RegresionLogisticaNumPy(0.5, 300).ajustar(Xa, y)
        self.assertGreaterEqual(accuracy(curva.predecir(Xa), y), 0.85)
        self.assertLess(curva.historial[-1], recta.historial[-1])


class TestTiempo(unittest.TestCase):
    def test_numpy_es_mas_rapido(self):
        Xa = ampliar_cuadrados(estandarizar(katanas()[0])[0])
        Xg, yg = np.tile(Xa, (5, 1)), katanas()[1] * 5
        puro = cronometrar(RegresionLogistica(0.5, 30), Xg.tolist(), yg)
        vect = cronometrar(RegresionLogisticaNumPy(0.5, 30), Xg, yg)
        self.assertIsInstance(puro, float)
        self.assertGreater(puro, 0.0)
        self.assertGreater(vect, 0.0)
        # En tu máquina la diferencia será mucho mayor: aquí solo se exige que NumPy gane.
        self.assertLess(vect, puro)


if __name__ == "__main__":
    unittest.main()
