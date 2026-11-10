"""Ejercicio P0-05 · Un generador de tokens con muestreo.

En T6-01 calculaste la distribución del siguiente token y la retocaste con temperatura y top-p.
Faltaba la última pieza: elegir un token al azar según esa distribución, una y otra vez, y
entregarlo EN CUANTO existe, sin esperar a tener la frase entera. Eso es lo que ves cuando un LLM
«escribe» en pantalla (la opción stream de la API de Ollama, que en P0-01 dejaste en false) y es, literalmente, un generador de Python.
Python que practicas: yield y return dentro de un generador, generadores encadenados,
random.Random con semilla y la suma acumulada. Ver PYTHON.md §17 y §18. Solo Python estándar.

El modelo es una función `siguiente(token) → [(token, probabilidad), ...]` (lista vacía si no
sabe continuar). Los tests la construyen con los bigramas del corpus de la forja.

Ejecuta los tests desde forja/ejercicios:
    python -m unittest -v test_P0_05_generacion
"""

PUNTUACION = set(".,;:!?)")


def muestrear(dist, rng):
    """Elige un token de dist = [(token, p), ...] (las p suman 1) con UNA llamada a rng.random().

    Método de la suma acumulada: u = rng.random() (en [0, 1)); recorre dist sumando p y devuelve
    el primer token en el que u < suma. Si por redondeo ninguno cumple, devuelve el último.
    Ejemplo: con dist = [("a", 0.5), ("b", 0.3), ("c", 0.2)], u = 0.65 → "b" (0.5 ≤ 0.65 < 0.8)
    """
    raise NotImplementedError("Tu turno: implementa muestrear")


def generar(siguiente, inicio, rng, max_tokens=50, fin="."):
    """GENERADOR. Produce (yield) tokens uno a uno, empezando DESPUÉS de `inicio` (que no se produce):

        actual = inicio; en cada vuelta: dist = siguiente(actual); si está vacía, termina;
        si no, actual = muestrear(dist, rng) y produce actual.

    Termina (return) también tras producir el token `fin` o al llegar a `max_tokens` tokens.
    Llama a siguiente() solo cuando haga falta el próximo token: si quien consume para,
    el modelo no trabaja de más.
    """
    raise NotImplementedError("Tu turno: implementa generar")


def en_streaming(tokens):
    """GENERADOR. Convierte tokens en los trozos de texto que se pintan en pantalla: cada token
    va precedido de un espacio, salvo el primero y los signos de PUNTUACION.

    Ejemplo: list(en_streaming(["la", "hoja", ",", "templada", "."])) → ["la", " hoja", ",", " templada", "."]
    """
    raise NotImplementedError("Tu turno: implementa en_streaming")


def con_presupuesto(piezas, max_bytes):
    """GENERADOR. Deja pasar las piezas mientras el total en bytes UTF-8 de lo ya entregado más
    la pieza siguiente no supere max_bytes; en cuanto una no cabe, termina (y no la entrega).

    Es el límite de salida de un servicio: sin él, una petición puede pedir un texto infinito
    (OWASP LLM10, consumo sin límites). Se cuenta en bytes, no en caracteres: «🔥» son 4.
    """
    raise NotImplementedError("Tu turno: implementa con_presupuesto")


def frecuencias(dist, rng, n):
    """Muestrea n veces con muestrear y devuelve {token: veces / n} (solo los que han salido).
    Con n grande, debe parecerse a dist: así se comprueba un muestreador."""
    raise NotImplementedError("Tu turno: implementa frecuencias")


# ----- Lo de abajo lo ha escrito Claude: escribe en pantalla, token a token, como un LLM. -----

def _demo(semilla=7):
    import random
    import re
    import sys
    import time
    from apoyo import cargar_corpus

    toks = re.findall(r"\w+|[^\w\s]", cargar_corpus().lower())
    cuentas = {}
    for a, b in zip(toks, toks[1:]):
        cuentas.setdefault(a, {})
        cuentas[a][b] = cuentas[a].get(b, 0) + 1

    def siguiente(token):
        c = cuentas.get(token, {})
        total = sum(c.values())
        return sorted(((t, v / total) for t, v in c.items()), key=lambda tp: (-tp[1], tp[0]))

    for pieza in con_presupuesto(en_streaming(generar(siguiente, ".", random.Random(semilla), 40)), 200):
        sys.stdout.write(pieza)
        sys.stdout.flush()
        time.sleep(0.08)
    print()


if __name__ == "__main__":
    _demo()
