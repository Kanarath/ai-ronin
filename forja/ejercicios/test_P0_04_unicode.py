"""Tests del ejercicio P0-04. Los textos se escriben con escapes (\\u0301, \\U0001F525…) para que
veas exactamente qué puntos de código hay: en pantalla, NFC y NFD se ven iguales."""

import itertools
import types
import unicodedata
import unittest

from apoyo import cargar_corpus
from P0_04_unicode import decodificar, lineas, longitudes, recortar_bytes, tokens

FORJE_NFC = "forjé"            # é compuesta: 5 puntos de código
FORJE_NFD = "forjé"           # e + acento combinante: 6 puntos de código
FUEGO = "\U0001F525"                # 🔥 (4 bytes en UTF-8)
PULGAR_MORENO = "\U0001F44D\U0001F3FD"          # 👍🏽 pulgar + tono de piel
MECANICA = "\U0001F469‍\U0001F527"         # 👩‍🔧 mujer + ZWJ + llave inglesa
JAPON = "\U0001F1EF\U0001F1F5"                  # 🇯🇵 dos letras regionales


def en_trozos(datos, tam):
    """Generador de trozos de `tam` bytes (lo escribe Claude)."""
    for i in range(0, len(datos), tam):
        yield datos[i:i + tam]


class TestMedir(unittest.TestCase):
    def test_longitudes(self):
        self.assertEqual(longitudes("forjé " + FUEGO), {"caracteres": 7, "bytes": 11, "nfc": 7, "nfd": 8})
        self.assertEqual(longitudes(FORJE_NFD), {"caracteres": 6, "bytes": 7, "nfc": 5, "nfd": 6})
        self.assertEqual(longitudes(MECANICA)["caracteres"], 3, "un solo dibujo, tres puntos de código")
        self.assertEqual(longitudes(MECANICA)["bytes"], 11)
        self.assertEqual(longitudes(""), {"caracteres": 0, "bytes": 0, "nfc": 0, "nfd": 0})

    def test_recortar_bytes(self):
        self.assertEqual(recortar_bytes("año", 2), "a")
        self.assertEqual(recortar_bytes("año", 3), "añ")
        self.assertEqual(recortar_bytes("ok " + FUEGO, 6), "ok ")
        self.assertEqual(recortar_bytes("ok " + FUEGO, 7), "ok " + FUEGO)
        self.assertEqual(recortar_bytes("katana", 100), "katana")
        self.assertEqual(recortar_bytes("katana", 0), "")
        for n in range(12):
            r = recortar_bytes("forjé " + FUEGO, n)
            self.assertLessEqual(len(r.encode("utf-8")), n)
            self.assertTrue(("forjé " + FUEGO).startswith(r))
        with self.assertRaises(ValueError):
            recortar_bytes("a", -1)


class TestDecodificar(unittest.TestCase):
    def test_es_un_generador(self):
        self.assertIsInstance(decodificar([b"a"]), types.GeneratorType)

    def test_caracter_partido(self):
        self.assertEqual(list(decodificar([b"a\xc3", b"\xb1o"])), ["a", "ño"])
        bytes_fuego = FUEGO.encode("utf-8")
        self.assertEqual(list(decodificar([bytes_fuego[:1], bytes_fuego[1:3], bytes_fuego[3:]])), [FUEGO],
                         "sin cadenas vacías mientras el emoji está a medias")
        self.assertEqual(list(decodificar([])), [])

    def test_cualquier_tamano_de_trozo(self):
        texto = "La forja de Kurogane 🔥: año " + MECANICA + " " + PULGAR_MORENO
        datos = texto.encode("utf-8")
        for tam in range(1, 9):
            self.assertEqual("".join(decodificar(en_trozos(datos, tam))), texto, "trozos de %d bytes" % tam)

    def test_final_incompleto(self):
        with self.assertRaises(UnicodeDecodeError):
            list(decodificar([b"ok", FUEGO.encode("utf-8")[:2]]))


class TestLineas(unittest.TestCase):
    def test_lineas(self):
        self.assertIsInstance(lineas([]), types.GeneratorType)
        self.assertEqual(list(lineas(["ho", "la\r\nmun", "do"])), ["hola", "mundo"])
        self.assertEqual(list(lineas(["a\n\nb\n"])), ["a", "", "b"])
        self.assertEqual(list(lineas(["sin salto"])), ["sin salto"])
        self.assertEqual(list(lineas([])), [])

    def test_es_perezoso(self):
        """Un generador no lee más de lo necesario: aquí la fuente explota si se lee demasiado."""
        def fuente():
            yield "primera\nsegu"
            yield "nda\n"
            raise AssertionError("se ha leído más de lo necesario")
        self.assertEqual(list(itertools.islice(lineas(fuente()), 2)), ["primera", "segunda"])


class TestTokens(unittest.TestCase):
    def test_nfc_y_nfd_dan_lo_mismo(self):
        self.assertEqual(list(tokens([FORJE_NFD + " la hoja"])), ["forjé", "la", "hoja"])
        self.assertEqual(list(tokens([FORJE_NFD])), list(tokens([FORJE_NFC])))
        self.assertTrue(all(unicodedata.is_normalized("NFC", t) for t in tokens(["MAÑANA " + FORJE_NFD])))

    def test_emojis_enteros(self):
        texto = "¡Forjé " + PULGAR_MORENO + "! La " + MECANICA + " y " + JAPON + " " + FUEGO + FUEGO
        self.assertEqual(list(tokens([texto])),
                         ["¡", "forjé", PULGAR_MORENO, "!", "la", MECANICA, "y", JAPON, FUEGO, FUEGO])

    def test_casefold(self):
        self.assertEqual(list(tokens(["STRASSE Straße"])), ["strasse", "strasse"])

    def test_tuberia_completa_con_el_corpus(self):
        """Bytes en trozos de 7 → texto → líneas → tokens, perezoso de punta a punta, sobre el
        corpus de la forja: el resultado es el mismo que tokenizar el texto entero de golpe."""
        corpus = cargar_corpus()
        gen = tokens(lineas(decodificar(en_trozos(corpus.encode("utf-8"), 7))))
        self.assertIsInstance(gen, types.GeneratorType)
        self.assertEqual(list(itertools.islice(gen, 4)), ["el", "maestro", "herrero", "forja"])
        de_golpe = list(tokens(corpus.splitlines()))
        en_streaming = list(tokens(lineas(decodificar(en_trozos(corpus.encode("utf-8"), 7)))))
        self.assertEqual(en_streaming, de_golpe)
        self.assertGreater(len(de_golpe), 300)


if __name__ == "__main__":
    unittest.main()
