"""Ejercicio T5-01 · Tokenizador BPE desde cero.

El mismo algoritmo que `tokenizer train` y `tokenize` del Dojo, y que (a nivel de bytes) usan GPT y Llama.
Python que practicas: expresiones regulares (re), collections.Counter, tuplas como claves.

Ejecuta los tests desde forja/ejercicios:
    python -m unittest -v test_T5_01_bpe
"""

import re
from collections import Counter

INICIO = "▁"
DESCONOCIDO = "<?>"


def pre_tokenizar(texto):
    r"""Separa el texto en palabras (letras/números) y signos de puntuación sueltos.

    Usa re.findall(r"\w+|[^\w\s]", texto).
    Ejemplo: pre_tokenizar("Hola, katana.") → ["Hola", ",", "katana", "."]
    """
    raise NotImplementedError("Tu turno: implementa pre_tokenizar")


def simbolos(palabra):
    """La palabra como lista de símbolos: la marca de inicio y después cada carácter.

    Ejemplo: simbolos("ab") → ["▁", "a", "b"]
    """
    raise NotImplementedError("Tu turno: implementa simbolos")


def aplicar_fusion(syms, a, b):
    """Sustituye cada aparición consecutiva de (a, b) por a+b, de izquierda a derecha.

    Ejemplo: aplicar_fusion(["▁", "a", "b", "a", "b"], "a", "b") → ["▁", "ab", "ab"]
    """
    raise NotImplementedError("Tu turno: implementa aplicar_fusion")


def entrenar_bpe(texto, num_fusiones):
    """Devuelve (fusiones, base): la lista de pares fusionados en orden y el conjunto de símbolos base.

    1. Cuenta cuántas veces aparece cada palabra (Counter de pre_tokenizar).
    2. Repite num_fusiones veces:
       - cuenta los pares adyacentes de todas las palabras, ponderados por su frecuencia;
       - elige el par con MÁS apariciones; en caso de empate, el MENOR par (a, b) en orden
         alfabético de tuplas (así coincide con el Dojo);
       - aplícalo a todas las palabras y guárdalo en la lista de fusiones.
    Si no quedan pares, para antes.
    base = conjunto de todos los símbolos iniciales (incluida la marca ▁).
    """
    raise NotImplementedError("Tu turno: implementa entrenar_bpe")


def codificar(texto, fusiones, base):
    """Tokeniza: para cada palabra, simbolos(); sustituye por DESCONOCIDO los que no están en base;
    aplica las fusiones EN ORDEN; concatena los tokens de todas las palabras."""
    raise NotImplementedError("Tu turno: implementa codificar")
