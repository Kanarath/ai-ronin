"""Ejercicio P0-04 · Texto en streaming con cuidado de Unicode.

En T5-01 el tokenizador recibía un texto limpio y entero. En la realidad el texto llega:
  · en TROZOS DE BYTES (un fichero grande, una respuesta HTTP en streaming, un LLM que escribe
    poco a poco), y un trozo puede cortar una letra por la mitad: «é» son 2 bytes; «🔥», 4;
  · con la misma palabra escrita de dos formas: «forjé» compuesta (NFC, é = U+00E9) o
    descompuesta (NFD, e + U+0301, el acento suelto);
  · con «caracteres» que son varios puntos de código: 👍🏽 (pulgar + tono de piel),
    👩‍🔧 (mujer + unión ZWJ + llave inglesa), 🇯🇵 (dos letras regionales).
Python que practicas: str frente a bytes, .encode/.decode, unicodedata, codecs y GENERADORES
(yield) encadenados. Ver PYTHON.md §17 y §18. Solo Python estándar.

Ejecuta los tests desde forja/ejercicios:
    python -m unittest -v test_P0_04_unicode
"""

import codecs
import re
import unicodedata

# Lo escribe Claude. Un token es: una palabra (\w+), una bandera (dos letras regionales) o un
# símbolo seguido de sus modificadores (acentos combinantes, selector de variación U+FE0F, tono
# de piel), con más símbolos unidos por ZWJ (U+200D). Es una versión simplificada de los
# «grapheme clusters» de Unicode (UAX #29): suficiente para el texto de la forja, no para todo.
MODIFICADOR = r"[̀-ͯ️\U0001F3FB-\U0001F3FF]*"
SIMBOLO = r"[^\w\s]" + MODIFICADOR
PATRON = re.compile(r"\w+|[\U0001F1E6-\U0001F1FF]{2}|" + SIMBOLO + r"(?:‍" + SIMBOLO + r")*")


def longitudes(texto):
    """Cuatro formas de medir «lo largo» que es un texto. Devuelve un diccionario:
        {"caracteres": puntos de código (len), "bytes": bytes en UTF-8,
         "nfc": puntos de código tras normalizar a NFC, "nfd": ídem a NFD}

    Ejemplo: longitudes("forjé 🔥") → {"caracteres": 7, "bytes": 11, "nfc": 7, "nfd": 8}
    """
    raise NotImplementedError("Tu turno: implementa longitudes")


def recortar_bytes(texto, max_bytes):
    """El prefijo más largo de `texto` que ocupa como mucho `max_bytes` bytes en UTF-8, sin
    partir ningún carácter por la mitad. ValueError si max_bytes < 0.

    Pista de diseño: codifica, corta los bytes y decodifica descartando el resto incompleto
    (.decode("utf-8", errors="ignore")).
    Ejemplo: recortar_bytes("año", 2) → "a" (la «ñ» necesita 2 bytes y solo queda 1)
    """
    raise NotImplementedError("Tu turno: implementa recortar_bytes")


def decodificar(trozos):
    """GENERADOR. Recibe un iterable de trozos de bytes en UTF-8 y produce (yield) el texto
    de cada uno, aunque un carácter quede partido entre dos trozos.

    Usa un decodificador incremental: dec = codecs.getincrementaldecoder("utf-8")(). Con
    dec.decode(b) obtienes lo que ya está completo (guarda por dentro los bytes a medias). Al
    acabar, dec.decode(b"", final=True) da lo pendiente o lanza UnicodeDecodeError si el texto
    termina con un carácter incompleto. No produzcas cadenas vacías.

    Ejemplo: list(decodificar([b"a\\xc3", b"\\xb1o"])) → ["a", "ño"]
    """
    raise NotImplementedError("Tu turno: implementa decodificar")


def lineas(textos):
    """GENERADOR. Recibe trozos de texto (str) y produce líneas completas, sin el "\\n" final.

    Acumula en un búfer y, cada vez que haya un "\\n", produce lo que va antes. Quita también
    un "\\r" final (finales de línea de Windows). Al terminar, si queda texto en el búfer, es la
    última línea: prodúcela. Una línea vacía entre dos "\\n" sí se produce ("").

    Ejemplo: list(lineas(["ho", "la\\r\\nmun", "do"])) → ["hola", "mundo"]
    """
    raise NotImplementedError("Tu turno: implementa lineas")


def tokens(lineas_):
    """GENERADOR. Para cada línea: pásala a minúsculas con .casefold(), normalízala a NFC
    (unicodedata.normalize) y produce, uno a uno, los tokens de PATRON.findall.

    El orden importa: casefold() puede producir caracteres descompuestos, así que se normaliza
    DESPUÉS. Sin NFC, la «é» descompuesta de «forjé» (NFD) parte la palabra en dos.
    Ejemplo: list(tokens(["¡Forjé 👍🏽!"])) → ["¡", "forjé", "👍🏽", "!"]
    """
    raise NotImplementedError("Tu turno: implementa tokens")


# ----- Lo de abajo lo ha escrito Claude: la tubería completa sobre el corpus de la forja. -----

def _demo():
    import itertools
    from apoyo import RUTA_CORPUS

    def trozos_del_fichero(tam=7):  # trozos de 7 bytes: muchos cortan una letra por la mitad
        with open(RUTA_CORPUS, "rb") as f:
            while bloque := f.read(tam):
                yield bloque

    primeros = itertools.islice(tokens(lineas(decodificar(trozos_del_fichero()))), 15)
    print(" · ".join(primeros))


if __name__ == "__main__":
    _demo()
