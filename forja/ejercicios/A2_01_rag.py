r"""Ejercicio A2-01 · Tu propio motor de recuperación para un RAG.

Vas a programar la parte REAL del RAG del Dojo: troceo con solapamiento, vectores TF-IDF,
similitud coseno y búsqueda con control de acceso.
Python que practicas: diccionarios como vectores dispersos, math.log, sorted con clave,
y filtrar por permisos ANTES de devolver resultados (PYTHON.md §5, §7, §8, §11).

Ejecuta los tests desde forja/ejercicios:
    python -m unittest -v test_A2_01_rag
"""

import math
import re

STOPWORDS = {"el", "la", "los", "las", "un", "una", "unos", "unas", "de", "del", "al", "a", "en", "y", "o",
             "que", "es", "se", "su", "sus", "con", "por", "para", "lo", "le", "les", "no", "si", "mi", "tu",
             "me", "te", "nos", "como", "más", "mas", "pero", "hay", "son", "este", "esta", "eso", "esto",
             "cual", "cuál", "qué", "ser", "tiene", "tienen", "puedo", "hace", "hacéis"}


def terminos(texto):
    r"""Palabras significativas: minúsculas, re.findall(r"[\w%]+", ...), sin STOPWORDS y de más de 1 carácter.

    Ejemplo: terminos("La garantía es de 2 años") → ["garantía", "años"]   (el "2" mide 1 carácter)
    """
    raise NotImplementedError("Tu turno: implementa terminos")


def trocear(texto, tam, solape):
    """Parte el texto (separado por espacios) en fragmentos de `tam` palabras.

    Cada fragmento empieza `tam - solape` palabras después del anterior. Se para cuando un
    fragmento llega al final del texto. Devuelve la lista de fragmentos (cadenas).
    Ejemplo: trocear("a b c d e f g h i j", 4, 2) → ["a b c d", "c d e f", "e f g h", "g h i j"]
    """
    raise NotImplementedError("Tu turno: implementa trocear")


def construir_idf(fragmentos):
    """idf[término] = ln((N + 1) / (df + 1)) + 1, con N = número de fragmentos y
    df = en cuántos fragmentos aparece el término (cada fragmento cuenta una vez)."""
    raise NotImplementedError("Tu turno: implementa construir_idf")


def vectorizar(texto, idf):
    """Vector TF-IDF normalizado: diccionario {término: peso}.

    tf = veces que aparece / número total de términos del texto; peso = tf · idf.get(término, 1.0).
    Al final divide todos los pesos entre la norma (raíz de la suma de cuadrados) para que mida 1.
    """
    raise NotImplementedError("Tu turno: implementa vectorizar")


def coseno(a, b):
    """Producto escalar de dos vectores dispersos (ya normalizados): suma de a[t]·b[t] para los términos comunes."""
    raise NotImplementedError("Tu turno: implementa coseno")


def buscar(consulta, indice, idf, k, rol, acl):
    """Los k elementos del índice más parecidos a la consulta, como lista de (id, similitud).

    `indice` es una lista de diccionarios {"id", "acceso", "vector"}.
    Si acl es True y el rol no es "empleado", los elementos con acceso "interno" se descartan
    ANTES de ordenar (el permiso se aplica en la recuperación, no se le pide al modelo).
    Orden: similitud descendente y, en empate, id ascendente.
    """
    raise NotImplementedError("Tu turno: implementa buscar")
