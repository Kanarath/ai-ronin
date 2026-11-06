"""Tests del ejercicio T1-01. Los valores del dataset real son los mismos que calcula el Dojo."""

import os
import tempfile
import unittest

from apoyo import RUTA_KATANAS
from T1_01_estadisticas import cargar_csv, columna, desviacion_tipica, media, rango, recuento


class TestCargarCsv(unittest.TestCase):
    def test_csv_pequeno(self):
        contenido = "id,dureza_hrc,calidad\nhoja-1,59.7,apta\nhoja-2,63.1,defectuosa\n\n"
        with tempfile.NamedTemporaryFile("w", suffix=".csv", delete=False, encoding="utf-8") as f:
            f.write(contenido)
            ruta = f.name
        try:
            filas = cargar_csv(ruta)
        finally:
            os.remove(ruta)
        self.assertEqual(len(filas), 2, "dos filas de datos (la línea vacía se ignora)")
        self.assertEqual(filas[0], {"id": "hoja-1", "dureza_hrc": "59.7", "calidad": "apta"})
        self.assertEqual(filas[1]["calidad"], "defectuosa")

    def test_dataset_katanas(self):
        filas = cargar_csv(RUTA_KATANAS)
        self.assertEqual(len(filas), 240)
        self.assertEqual(set(filas[0].keys()), {"id", "dureza_hrc", "flexibilidad", "temperatura_temple", "calidad"})


class TestEstadisticas(unittest.TestCase):
    def test_columna_convierte_a_float(self):
        self.assertEqual(columna([{"a": "1.5"}, {"a": "2"}], "a"), [1.5, 2.0])

    def test_media(self):
        self.assertAlmostEqual(media([1, 2, 3, 6]), 3.0)

    def test_desviacion_tipica_poblacional(self):
        self.assertAlmostEqual(desviacion_tipica([2, 4, 4, 4, 5, 5, 7, 9]), 2.0)

    def test_rango(self):
        self.assertEqual(rango([3, 10, 7]), 7)

    def test_recuento(self):
        self.assertEqual(recuento(["apta", "defectuosa", "apta"]), {"apta": 2, "defectuosa": 1})


class TestComoElDojo(unittest.TestCase):
    """Tu implementación debe dar lo mismo que `dataset stats katanas` en el Dojo."""

    @classmethod
    def setUpClass(cls):
        cls.filas = cargar_csv(RUTA_KATANAS)

    def test_dureza(self):
        v = columna(self.filas, "dureza_hrc")
        self.assertAlmostEqual(media(v), 60.103, delta=0.001)
        self.assertAlmostEqual(desviacion_tipica(v), 2.713, delta=0.001)
        self.assertAlmostEqual(rango(v), 13.6, delta=0.001)

    def test_temperatura(self):
        v = columna(self.filas, "temperatura_temple")
        self.assertAlmostEqual(media(v), 821.229, delta=0.001)
        self.assertAlmostEqual(desviacion_tipica(v), 33.721, delta=0.001)
        self.assertAlmostEqual(rango(v), 119.0, delta=0.001)

    def test_clases(self):
        etiquetas = [f["calidad"] for f in self.filas]
        self.assertEqual(recuento(etiquetas), {"apta": 116, "defectuosa": 124})


if __name__ == "__main__":
    unittest.main()
