"""Ejercicio O5 · Gobernanza en código: clasificar según el AI Act y llevar un registro de riesgos.

En el Dojo clasificaste sistemas y trataste riesgos con comandos. Aquí escribes esas reglas:
un clasificador (muy simplificado) de niveles del AI Act, el riesgo residual de cada tratamiento,
la comprobación de si un tratamiento se permite y el resumen del registro frente al apetito.
Python que practicas: diccionarios, conjuntos, condiciones encadenadas y comprensiones (PYTHON.md §3, §4).

AVISO: es un ejercicio de lógica, no una herramienta jurídica. El AI Act tiene matices y excepciones
que aquí no están. Ejecuta los tests desde forja/ejercicios:
    python -m unittest -v test_O5_01_riesgos
"""

# Algunos usos del anexo III (simplificado; la lista real es más larga y tiene matices).
USOS_ANEXO_III = {"seleccion-personal", "evaluacion-trabajadores", "acceso-educacion", "solvencia-credito", "biometria-remota"}
CONTEXTOS_PROHIBIDOS_EMOCIONES = {"trabajo", "educacion"}
MOTIVOS_EXCEPCION_EMOCIONES = {"medico", "seguridad"}


def clasificar_ai_act(sistema):
    """sistema = {"infiere_emociones": bool, "contexto": "trabajo"|"educacion"|"otro",
                  "motivo": "medico"|"seguridad"|"productividad"|..., "uso": "seleccion-personal"|...,
                  "interactua_con_personas": bool}

    Devuelve el nivel, comprobando EN ESTE ORDEN:
      "prohibido"     si infiere emociones en un contexto prohibido y su motivo no es una excepción;
      "alto"          si su uso está en USOS_ANEXO_III;
      "transparencia" si interactúa directamente con personas;
      "minimo"        en cualquier otro caso.
    """
    raise NotImplementedError("Tu turno: implementa clasificar_ai_act")


def riesgo(probabilidad, impacto):
    """Producto probabilidad × impacto. Ambos deben ser enteros de 1 a 5: si no, lanza ValueError."""
    raise NotImplementedError("Tu turno: implementa riesgo")


def residual(r, tratamiento):
    """r = {"id": "R1", "p": 4, "i": 2, "p_mitigada": 1}  (p_mitigada = None si no se puede mitigar)
    tratamiento: "mitigar" → riesgo(p_mitigada, i) · "evitar" → 0 · "aceptar" o None → riesgo(p, i).
    """
    raise NotImplementedError("Tu turno: implementa residual")


def tratamiento_permitido(r, tratamiento, apetito):
    """Devuelve (permitido, motivo):
      (False, "no-mitigable") si se pide mitigar y p_mitigada es None (por ejemplo, un uso prohibido);
      (False, "fuera-del-apetito") si se pide aceptar y el riesgo inherente supera el apetito;
      (True, "ok") en otro caso.
    """
    raise NotImplementedError("Tu turno: implementa tratamiento_permitido")


def resumen_registro(riesgos, tratamientos, apetito):
    """riesgos = lista de r (como en residual); tratamientos = {"R1": "mitigar", ...} (puede faltar alguno).
    Devuelve {"dentro": n.º de riesgos con residual <= apetito,
              "fuera": lista ORDENADA de ids con residual > apetito,
              "evitados_innecesarios": lista ORDENADA de ids evitados que sí se podían mitigar}.
    """
    raise NotImplementedError("Tu turno: implementa resumen_registro")
