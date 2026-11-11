"""Ejercicio T6-03 · La instrucción escondida: cuánta atención recibe y cuánto relleno la ahoga.

En el Dojo comprobaste que la atención da el mismo peso a una palabra cerca o lejos y escribiste
el peso de una instrucción entre n palabras de relleno. Aquí vas más allá: haces esa cuenta
estable con puntuaciones enormes, calculas cuánto relleno hace falta para ahogar una instrucción
y cuánto parecido necesita el atacante para salvarla, y lo compruebas con la atención de verdad
sobre los embeddings del Dojo.
Python que practicas: math.exp, math.log, while, float("-inf") y list.index.
Ver PYTHON.md §3, §5, §11 y §12.

Por qué: es la base técnica de la inyección de instrucciones indirecta. Un RAG
(Retrieval-Augmented Generation) o un agente meten en el contexto webs, correos y documentos
enteros. Con estas cuentas ves que el relleno diluye una instrucción, pero que el atacante la
salva escribiéndola parecida a lo que el usuario pregunta. Por eso la defensa no puede ser
«el modelo ya la ignorará».

Ejecuta los tests desde forja/ejercicios:
    python -m unittest -v test_T6_03_dilucion
"""

import math


def peso_oculto(s_oculta, s_relleno, n):
    """Peso de softmax de la instrucción entre n palabras de relleno iguales:
    e^s_oculta / (e^s_oculta + n · e^s_relleno).

    Tiene que funcionar con puntuaciones enormes: math.exp(1000) lanza OverflowError. Divide
    arriba y abajo entre e^s_oculta y te queda 1 / (1 + n · e^(s_relleno − s_oculta)).
    Ejemplos: peso_oculto(0, 0, 4) → 0.2; peso_oculto(1000, 1000, 1) → 0.5
    """
    raise NotImplementedError("Tu turno: implementa peso_oculto")


def relleno_para_ahogar(s_oculta, s_relleno, objetivo):
    """El MENOR número de palabras de relleno n con el que peso_oculto(s_oculta, s_relleno, n)
    queda por DEBAJO de objetivo (estrictamente menor).

    Empieza en n = 0 y súmale 1 con un while mientras el peso siga ≥ objetivo.
    Si objetivo no está entre 0 y 1 (sin incluirlos), lanza ValueError: con objetivo ≤ 0 el
    bucle no terminaría nunca.
    Ejemplo: relleno_para_ahogar(0, 0, 0.5) → 2 (con 1 palabra el peso es justo 0.5).
    """
    raise NotImplementedError("Tu turno: implementa relleno_para_ahogar")


def parecido_necesario(s_relleno, n, objetivo):
    """La puntuación que necesita la instrucción para llevarse justo `objetivo` del peso entre
    n palabras de relleno. Despejando de peso_oculto:
        s_oculta = s_relleno + ln(objetivo · n / (1 − objetivo))
    Usa math.log. Si objetivo no está entre 0 y 1 (sin incluirlos) o n < 1, lanza ValueError.
    Ejemplo: parecido_necesario(0, 1, 0.5) → 0.0
    """
    raise NotImplementedError("Tu turno: implementa parecido_necesario")


def fila_atencion(palabras, tabla, i, causal=False):
    """Pesos de atención de la palabra i sobre todas las palabras (como attention en el Dojo,
    con Q = K = V = los embeddings de `tabla`).

    - Puntuación con j: (tabla[palabras[i]] · tabla[palabras[j]]) / √d, con d la longitud del vector.
    - Con causal=True, las j > i valen float("-inf") (la palabra i no ve las de después).
    - Softmax estable de la fila: resta el máximo antes de math.exp (como en T6-02).
    Devuelve una lista de len(palabras) pesos que suman 1.
    """
    raise NotImplementedError("Tu turno: implementa fila_atencion")


def peso_entre(palabras, tabla, desde, hacia, causal=False):
    """Peso que la palabra `desde` da a la palabra `hacia` (su PRIMERA aparición en palabras).
    Usa palabras.index() y fila_atencion.
    Ejemplo: peso_entre("katana espada fuego".split(), tabla, "katana", "espada")
    """
    raise NotImplementedError("Tu turno: implementa peso_entre")
