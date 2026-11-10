"""Tests del laboratorio E2-02. Sin red: la API se prueba con el TestClient de FastAPI, dentro del
propio proceso, y los dígitos vienen dentro de scikit-learn."""

import unittest

import numpy as np
from fastapi.testclient import TestClient

from extraccion import (Ajustes, Regresion, acuerdo, atacar, cargar_datos, crear_app, entrenar_victima,
                        etiquetas_de_respuesta, permitir_consulta, redondear_probabilidades, resolver_ecuaciones)

ATACANTE = {"Authorization": "Bearer clave-atacante-lab"}
CLIENTE = {"Authorization": "Bearer clave-cliente-lab"}
CLAVES = {"clave-atacante-lab", "clave-cliente-lab"}


class TestDefensas(unittest.TestCase):
    def test_redondear(self):
        P = np.array([[0.123456, 0.876544], [0.004, 0.996]])
        np.testing.assert_allclose(redondear_probabilidades(P, 2), [[0.12, 0.88], [0.0, 1.0]])
        np.testing.assert_allclose(redondear_probabilidades(P, 0), [[0.0, 1.0], [0.0, 1.0]])
        np.testing.assert_allclose(P, [[0.123456, 0.876544], [0.004, 0.996]], err_msg="no modifica P")
        with self.assertRaises(ValueError):
            redondear_probabilidades(P, -1)

    def test_limite_ventana_deslizante(self):
        h = {}
        self.assertTrue(permitir_consulta(h, "a", 3, 0.0, 5, 10.0))
        self.assertEqual(h["a"], [0.0, 0.0, 0.0])
        self.assertTrue(permitir_consulta(h, "a", 2, 4.0, 5, 10.0))
        self.assertFalse(permitir_consulta(h, "a", 1, 9.0, 5, 10.0), "6 > 5 dentro de la ventana")
        self.assertEqual(len(h["a"]), 5, "una petición rechazada no se anota")
        self.assertTrue(permitir_consulta(h, "b", 5, 9.0, 5, 10.0), "cada clave tiene su cuenta")
        self.assertTrue(permitir_consulta(h, "a", 3, 10.0, 5, 10.0), "a los 10 s caducan las 3 del instante 0")
        self.assertEqual(sorted(h["a"]), [4.0, 4.0, 10.0, 10.0, 10.0])
        self.assertFalse(permitir_consulta(h, "c", 6, 0.0, 5, 10.0), "una sola petición más grande que el máximo")
        with self.assertRaises(ValueError):
            permitir_consulta(h, "a", 0, 11.0, 5, 10.0)


class TestAtaque(unittest.TestCase):
    def test_etiquetas_de_respuesta(self):
        np.testing.assert_array_equal(etiquetas_de_respuesta({"clases": [3, 1]}), [3, 1])
        np.testing.assert_array_equal(etiquetas_de_respuesta({"probabilidades": [[0.1, 0.9], [0.5, 0.5]]}), [1, 0])
        with self.assertRaises(ValueError):
            etiquetas_de_respuesta({"detail": "límite de consultas superado"})

    def test_acuerdo(self):
        self.assertEqual(acuerdo([1, 2, 3, 4], np.array([1, 2, 0, 4])), 0.75)
        for malo in [([], []), ([1, 2], [1])]:
            with self.assertRaises(ValueError):
                acuerdo(*malo)

    def test_ecuaciones_recuperan_un_modelo_pequeno(self):
        rng = np.random.default_rng(0)
        W, b = rng.normal(size=(3, 4)), rng.normal(size=4)
        Q = rng.uniform(size=(6, 3))  # d + 1 = 4 consultas bastarían
        Z = Q @ W + b
        P = np.exp(Z - Z.max(axis=1, keepdims=True))
        P /= P.sum(axis=1, keepdims=True)
        Wc, bc = resolver_ecuaciones(Q, P)
        self.assertEqual(Wc.shape, (3, 4))
        self.assertEqual(bc.shape, (4,))
        np.testing.assert_allclose(Wc, W - W[:, :1], atol=1e-8)
        np.testing.assert_allclose(bc, b - b[0], atol=1e-8)

    def test_ecuaciones_aguantan_ceros(self):
        Wc, bc = resolver_ecuaciones(np.array([[0.0], [1.0]]), np.array([[1.0, 0.0], [0.5, 0.5]]))
        self.assertTrue(np.isfinite(Wc).all() and np.isfinite(bc).all(), "recorta antes del logaritmo")


class TestApi(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.victima = entrenar_victima(0)
        cls.X_eval = cargar_datos(0)[3]

    def cliente(self, defensas=(), **kw):
        return TestClient(crear_app(defensas, Ajustes(**kw), self.victima, CLAVES))

    def test_clave_y_validacion(self):
        with self.cliente() as c:
            fila = self.X_eval[0].tolist()
            self.assertEqual(c.post("/predecir", json={"x": [fila]}).status_code, 401)
            self.assertEqual(c.post("/predecir", json={"x": [fila]}, headers={"Authorization": "Bearer otra"}).status_code, 401)
            self.assertEqual(c.post("/predecir", json={"x": [fila[:10]]}, headers=CLIENTE).status_code, 422)
            self.assertEqual(c.post("/predecir", json={"x": [[2.0] * 64]}, headers=CLIENTE).status_code, 422)
            r = c.post("/predecir", json={"x": [fila]}, headers=CLIENTE).json()
            np.testing.assert_allclose(r["probabilidades"], self.victima.probabilidades([fila]))
            np.testing.assert_array_equal(etiquetas_de_respuesta(r), self.victima.predecir([fila]))

    def test_redondeo_y_solo_etiqueta(self):
        fila = [self.X_eval[0].tolist()]
        with self.cliente(("redondeo",), decimales=1) as c:
            P = np.array(c.post("/predecir", json={"x": fila}, headers=CLIENTE).json()["probabilidades"])
            np.testing.assert_allclose(P, np.round(P, 1))
        with self.cliente(("etiqueta",)) as c:
            r = c.post("/predecir", json={"x": fila}, headers=CLIENTE).json()
            self.assertEqual(set(r), {"clases"})
            self.assertEqual(r["clases"], self.victima.predecir(fila).tolist())

    def test_limite_por_clave(self):
        filas = self.X_eval[:30].tolist()
        with self.cliente(("limite",), maximo=50) as c:
            self.assertEqual(c.post("/predecir", json={"x": filas}, headers=ATACANTE).status_code, 200)
            self.assertEqual(c.post("/predecir", json={"x": filas}, headers=ATACANTE).status_code, 429)
            self.assertEqual(c.post("/predecir", json={"x": filas}, headers=CLIENTE).status_code, 200)


class TestExtraccion(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.victima = entrenar_victima(0)
        _, _, cls.grupo, cls.X_eval, _ = cargar_datos(0)
        cls.original = cls.victima.predecir(cls.X_eval)

    def robar(self, defensas, presupuestos, **kw):
        with TestClient(crear_app(defensas, Ajustes(**kw), self.victima, CLAVES)) as c:
            def consultar(X):
                r = c.post("/predecir", json={"x": np.asarray(X).tolist()}, headers=ATACANTE)
                return r.json() if r.status_code == 200 else None
            return atacar(consultar, self.grupo, presupuestos)

    def test_con_probabilidades_exactas_la_copia_es_exacta(self):
        r = self.robar((), [100])[-1]
        self.assertEqual(r["consultas"], 100)
        self.assertEqual(acuerdo(r["ecuaciones"].predecir(self.X_eval), self.original), 1.0, "65 = d + 1 consultas bastan")

    def test_solo_etiqueta_obliga_a_entrenar_un_sustituto(self):
        r = self.robar(("etiqueta",), [200])[-1]
        self.assertIsNone(r["ecuaciones"])
        a = acuerdo(r["etiquetas"].predecir(self.X_eval), self.original)
        self.assertGreater(a, 0.8, "con 200 etiquetas, el sustituto ya se parece mucho: %.2f" % a)
        self.assertLess(a, 1.0)

    def test_el_limite_corta_el_presupuesto(self):
        r = self.robar(("limite",), [20, 50, 200], maximo=50)
        self.assertEqual([x["consultas"] for x in r], [20, 50, 50])


class TestRegresion(unittest.TestCase):
    def test_victima_util(self):
        _, _, _, X_eval, y_eval = cargar_datos(0)
        self.assertGreater(acuerdo(entrenar_victima(0).predecir(X_eval), y_eval), 0.9)
        self.assertEqual(Regresion().predecir(X_eval[:2]).shape, (2,))


if __name__ == "__main__":
    unittest.main()
