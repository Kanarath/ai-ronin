"""Ejercicio T5-03 · Disfraces de texto: un filtro por formas frente a uno por significado.

En el Dojo viste cómo «KATANA» y «k a t a n a» esquivan un filtro de tokens, cómo un filtro por
significado atrapa «espada», y escribiste la normalización a minúsculas. Aquí construyes un filtro
de verdad, capa a capa: quitas los caracteres invisibles, deshaces los caracteres Unicode que
imitan letras normales, quitas las tildes, juntas las letras sueltas, comparas por significado
con los embeddings del Dojo y mides cada filtro con ataques Y con mensajes legítimos.
Python que practicas: unicodedata (NFKC, NFD, categorías), re.findall, funciones como
parámetro y sorted(). Ver PYTHON.md §4, §11 y §17.

Por qué: los filtros de entrada de los chatbots con un LLM (Large Language Model) se esquivan con
disfraces que el LLM entiende y el filtro no. Normalizar antes de comprobar es la primera capa de
cualquier guardrail (filtro de seguridad) serio, y medir los falsos positivos es lo que evita que
el filtro espante a los clientes. Ningún filtro es completo: por eso hay más defensas detrás.

Ejecuta los tests desde forja/ejercicios:
    python -m unittest -v test_T5_03_disfraces
"""

import math
import re
import unicodedata

# Letras cirílicas que se ven igual que letras latinas (ya en minúsculas). Una lista real
# (Unicode «confusables») tiene miles de parejas: esta es una muestra para el ejercicio.
HOMOGLIFOS = {"а": "a", "е": "e", "о": "o", "р": "p", "с": "c", "х": "x", "к": "k", "т": "t", "і": "i"}


def filtro_exacto(texto, prohibidas):
    """El filtro ingenuo del Dojo: True si alguna palabra de texto.split() está, TAL CUAL, en
    prohibidas. «quiero una katana» → True; «quiero una KATANA» → False (se le escapa)."""
    raise NotImplementedError("Tu turno: implementa filtro_exacto")


def quitar_invisibles(texto):
    """Quita los caracteres de formato invisibles, los de categoría Unicode "Cf", como el espacio
    de anchura cero (U+200B). Usa unicodedata.category(c).
    Ejemplo: quitar_invisibles("ka\\u200btana") → "katana"
    """
    raise NotImplementedError("Tu turno: implementa quitar_invisibles")


def juntar_letras_sueltas(palabras):
    """Junta las rachas de 3 o más palabras de UNA letra seguidas en una sola palabra.
    Las rachas de 1 o 2 letras sueltas se quedan como están («a», «y» son palabras normales).

    Ejemplos: ["una", "k", "a", "t", "a", "n", "a"] → ["una", "katana"]
              ["voy", "a", "y", "vuelvo"] → ["voy", "a", "y", "vuelvo"]
    """
    raise NotImplementedError("Tu turno: implementa juntar_letras_sueltas")


def normalizar(texto):
    """Lleva el texto a una forma única antes de comprobarlo. En este orden:
    1. unicodedata.normalize("NFKC", texto): las letras de anchura completa («ｋ») pasan a normales.
    2. quitar_invisibles.
    3. .casefold(): minúsculas, también para letras de otros alfabetos.
    4. Cambia cada carácter que esté en HOMOGLIFOS por su letra latina.
    5. Quita las tildes: normaliza a "NFD" (la «á» se parte en «a» + tilde) y quita los caracteres
       de categoría "Mn" (las marcas, como la tilde).
    6. Palabras = re.findall(r"\\w+", texto): así los guiones y puntos también separan.
    7. juntar_letras_sueltas y únelas con un espacio.

    Ejemplo: normalizar("Quiero una K-A-T-Á-N-A!") → "quiero una katana"
    """
    raise NotImplementedError("Tu turno: implementa normalizar")


def filtro_normalizado(texto, prohibidas):
    """filtro_exacto aplicado al texto normalizado."""
    raise NotImplementedError("Tu turno: implementa filtro_normalizado")


def coseno(a, b):
    """Similitud coseno entre dos vectores (como en T5-02). Si alguno tiene longitud 0, 0.0."""
    raise NotImplementedError("Tu turno: implementa coseno")


def filtro_significado(texto, prohibidas, tabla, umbral=0.9):
    """True si alguna palabra del texto NORMALIZADO se parece a alguna prohibida:
    coseno(tabla[palabra], tabla[prohibida]) ≥ umbral.
    Las palabras (o prohibidas) que no estén en la tabla de embeddings se saltan.
    Con la tabla del Dojo: «espada» se bloquea (0,999 con katana) y «martillo» no (0,602).
    """
    raise NotImplementedError("Tu turno: implementa filtro_significado")


def evaluar(filtro, ataques, legitimos):
    """Mide un filtro. filtro es una FUNCIÓN que recibe un texto y devuelve True (bloquear) o False.
    Devuelve la tupla (ataques bloqueados, legítimos bloqueados), dos enteros.
    El segundo número son los falsos positivos: clientes buenos a los que el filtro echa.
    Ejemplo: evaluar(lambda t: "x" in t, ["x1", "y"], ["x2", "z"]) → (1, 1)
    """
    raise NotImplementedError("Tu turno: implementa evaluar")
