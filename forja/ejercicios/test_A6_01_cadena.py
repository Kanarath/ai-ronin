"""Tests del ejercicio A6: los eslabones del Dojo, sellados por TU código."""

import hashlib
import json
import unittest

from A6_01_cadena import formato_artefacto, huella_fichero, revisar_dependencias, secretos_en_capas, verificar_artefacto


def safetensors_minimo():
    """Bytes con la forma de un fichero safetensors: longitud (8 bytes LE) + cabecera JSON."""
    cabecera = json.dumps({"__metadata__": {"autor": "forja"}}).encode("utf-8")
    return len(cabecera).to_bytes(8, "little") + cabecera


ADAPTER = b"adaptador-estilo:v0.8:pesos"
MANIFIESTO = {
    "adaptador-estilo": {"sha256": hashlib.sha256(ADAPTER).hexdigest(), "firmante": "lora-labs"},
    "detector-grietas": {"sha256": hashlib.sha256(b"detector").hexdigest(), "firmante": "visiontek"},
    "modelo-raro": {"sha256": "00", "firmante": "desconocido"},
}
CLAVES = {"forja", "visiontek", "lora-labs"}


class TestHuella(unittest.TestCase):
    def test_abc(self):
        self.assertEqual(huella_fichero(b"abc"), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")

    def test_un_byte_cambia_todo(self):
        self.assertNotEqual(huella_fichero(b"pesos"), huella_fichero(b"pesoz"))


class TestFormato(unittest.TestCase):
    def test_pickle(self):
        self.assertEqual(formato_artefacto(b"\x80\x04\x95"), "pickle")

    def test_safetensors(self):
        self.assertEqual(formato_artefacto(safetensors_minimo()), "safetensors")

    def test_desconocido(self):
        self.assertEqual(formato_artefacto(b""), "desconocido")
        self.assertEqual(formato_artefacto(b"PK\x03\x04"), "desconocido")
        self.assertEqual(formato_artefacto((0).to_bytes(8, "little") + b"{"), "desconocido", "N debe ser > 0")


class TestVerificacion(unittest.TestCase):
    def test_correcto(self):
        self.assertEqual(verificar_artefacto(MANIFIESTO, "adaptador-estilo", ADAPTER, CLAVES), (True, "ok"))

    def test_adapter_manipulado(self):
        self.assertEqual(verificar_artefacto(MANIFIESTO, "adaptador-estilo", ADAPTER + b"!", CLAVES), (False, "huella"))

    def test_sin_firma_y_clave(self):
        self.assertEqual(verificar_artefacto(MANIFIESTO, "otro", b"x", CLAVES), (False, "sin-firma"))
        self.assertEqual(verificar_artefacto(MANIFIESTO, "modelo-raro", b"x", CLAVES), (False, "clave-desconocida"))

    def test_firma_no_es_seguridad(self):
        # Íntegro y de un autor de confianza... y aun así podría ser un pickle: por eso existe safe-formats.
        self.assertEqual(verificar_artefacto(MANIFIESTO, "detector-grietas", b"detector", CLAVES), (True, "ok"))


class TestDependencias(unittest.TestCase):
    LOCK = {"numpy": {"version": "2.3.4", "sha256": "aa"}, "safetensors": {"version": "0.6.2", "sha256": "bb"},
            "forja-metrics": {"version": "1.1.0", "sha256": "cc"}}

    def test_todo_bien(self):
        req = [{"nombre": "numpy", "version": "2.3.4", "sha256": "aa"}, {"nombre": "safetensors", "version": "0.6.2", "sha256": "bb"}]
        self.assertEqual(revisar_dependencias(req, self.LOCK, {"numpy": 7000, "safetensors": 1500}), [])

    def test_problemas(self):
        req = [
            {"nombre": "forja-metricas-pro", "version": "0.0.1", "sha256": "dd"},
            {"nombre": "safetensors", "version": "0.6.3", "sha256": "bb"},
            {"nombre": "numpy", "version": "2.3.4", "sha256": "zz"},
            {"nombre": "forja-metrics", "version": "1.1.0", "sha256": "cc"},
        ]
        edades = {"numpy": 7000, "safetensors": 1500, "forja-metricas-pro": 3}
        self.assertEqual(revisar_dependencias(req, self.LOCK, edades), [
            ("forja-metricas-pro", "fuera-del-lock"),
            ("forja-metrics", "reciente"),
            ("numpy", "huella"),
            ("safetensors", "version"),
        ])


class TestSecretos(unittest.TestCase):
    def test_capas(self):
        capas = [
            "FROM python:3.12-slim",
            "RUN pip install -r requirements.txt",
            "ENV REGISTRY_TOKEN=tok_registro_forja_7c1e",
            "ENV PORT=8080",
            "arg db_password=hunter2",
            "CMD [\"serve\"]",
        ]
        self.assertEqual(secretos_en_capas(capas), [2, 4])

    def test_sin_secretos(self):
        self.assertEqual(secretos_en_capas(["FROM python:3.12-slim", "USER forja"]), [])


if __name__ == "__main__":
    unittest.main()
