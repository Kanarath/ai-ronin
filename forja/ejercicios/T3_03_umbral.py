"""Ejercicio T3-03 · ¿Bloquear o dejar pasar? El umbral que cuesta menos.

En el Dojo leíste la curva de umbrales y escribiste el coste de un umbral. Aquí escribes la
herramienta completa: cuentas los errores de cada umbral, construyes la tabla de costes, eliges el
umbral más barato y pruebas el esquema que se usa en producción, con dos umbrales y una franja
intermedia que revisa una persona.
Python que practicas: zip(), contadores, tuplas, float("inf") y diccionarios como ficha.
Ver PYTHON.md §3, §4, §6, §8 y §11.

Convención (la misma de T3-02): el detector BLOQUEA cuando la puntuación es ≥ umbral.
FP (False Positive): un cliente normal bloqueado. FN (False Negative): un abusador que pasa.

Por qué: todo guardrail (filtro de seguridad) de un LLM (Large Language Model) tiene un umbral.
Ponerle precio a cada error convierte la discusión entre seguridad y negocio en una cuenta que se
puede revisar, y la franja de revisión humana es como se trabaja de verdad en fraude o en un SOC
(Security Operations Center).

El último bloque de tests usa tu DetectorKNN de T2_02_abuso.py: hazlo pasar primero.
Ejecuta los tests desde forja/ejercicios:
    python -m unittest -v test_T3_03_umbral
"""


def errores(puntuaciones, y_true, umbral, positiva):
    """Devuelve la tupla (fp, fn) que comete el detector con este umbral.

    - Se bloquea un caso si su puntuación es ≥ umbral.
    - fp: casos bloqueados cuya clase real NO es `positiva`.
    - fn: casos NO bloqueados cuya clase real es `positiva`.

    Ejemplo: errores([0.1, 0.6, 0.9], ["abuso", "normal", "abuso"], 0.5, "abuso") → (1, 1)
    """
    raise NotImplementedError("Tu turno: implementa errores")


def coste(fp, fn, coste_fp, coste_fn):
    """Lo que cuesta un umbral: fp · coste_fp + fn · coste_fn (es el py del Dojo)."""
    raise NotImplementedError("Tu turno: implementa coste")


def umbrales_candidatos(puntuaciones):
    """Los umbrales que merece la pena probar: cada puntuación distinta, de menor a mayor, y al
    final float("inf"), que significa «no bloquear a nadie».

    Entre dos puntuaciones seguidas, cualquier umbral bloquea a los mismos casos: no hace falta
    probar más.
    Ejemplo: umbrales_candidatos([0.5, 0.0, 0.5, 1.0]) → [0.0, 0.5, 1.0, inf]
    """
    raise NotImplementedError("Tu turno: implementa umbrales_candidatos")


def tabla_costes(puntuaciones, y_true, positiva, coste_fp, coste_fn):
    """Para cada umbral candidato, en orden, la tupla (umbral, fp, fn, coste).
    Es la tabla que se pone sobre la mesa para negociar un umbral."""
    raise NotImplementedError("Tu turno: implementa tabla_costes")


def mejor_umbral(puntuaciones, y_true, positiva, coste_fp, coste_fn):
    """La tupla (umbral, coste) del umbral candidato más barato.

    Si varios empatan en coste, elige el MAYOR: a igual coste, mejor molestar a menos clientes.
    """
    raise NotImplementedError("Tu turno: implementa mejor_umbral")


def triaje(puntuaciones, y_true, positiva, bajo, alto):
    """Dos umbrales en lugar de uno. Para cada caso:
    - puntuación ≥ alto → se bloquea (si no era `positiva`, es un FP);
    - bajo ≤ puntuación < alto → pasa a revisión humana (una persona decide: ni FP ni FN);
    - puntuación < bajo → pasa sin más (si era `positiva`, es un FN).

    Devuelve {"bloqueados": n, "revision": n, "pasan": n, "fp": n, "fn": n}.
    Si bajo > alto, lanza ValueError.
    """
    raise NotImplementedError("Tu turno: implementa triaje")


def coste_triaje(t, coste_fp, coste_fn, coste_revision):
    """Coste del triaje t (el diccionario de triaje): fp · coste_fp + fn · coste_fn +
    revision · coste_revision. Revisar no es gratis: es el tiempo de una persona."""
    raise NotImplementedError("Tu turno: implementa coste_triaje")
