"""Ejercicio O6 · Detección y respuesta sobre las trazas de un agente.

En el Dojo activaste la redacción, las reglas y la búsqueda con comandos. Aquí escribes cinco
piezas de ese registro: redactar datos personales, sacar el dominio de destino de una llamada a
una herramienta, la regla de correlación, las métricas de una regla y el alcance de un incidente.
Python que practicas: re, sets, diccionarios, comprensiones y división segura (PYTHON.md §3, §4, §8).

Las sesiones de los tests son ficticias (dominios .example). Ejecuta los tests desde forja/ejercicios:
    python -m unittest -v test_O6_01_trazas
"""

import re

HERRAMIENTAS_SALIDA = {"http_get", "enviar_correo"}
MARCA_INSTRUCCION = "nota para el asistente"

PATRON_CORREO = r"[\w.+-]+@([\w-]+\.[\w.-]+)"
PATRON_TELEFONO = r"\b\d{3} \d{3} \d{3}\b"
PATRON_DOMINIO = r"(?:https?://|@)([\w-]+(?:\.[\w-]+)+)"


def redactar(texto):
    """Enmascara los datos personales de un texto antes de guardarlo:
    - cada correo «usuario@dominio» pasa a «***@dominio» (se conserva el dominio, útil para investigar);
    - cada teléfono con el formato de PATRON_TELEFONO pasa a «[teléfono]».
    """
    raise NotImplementedError("Tu turno: implementa redactar")


def dominio_destino(argumentos):
    """Dominio al que apuntan los argumentos de una herramienta (una URL o un correo), o "" si no hay.
    Ejemplos: "url=https://cdn.example/c?d=1" → "cdn.example"; "para=ana@forja.example" → "forja.example".
    Usa PATRON_DOMINIO y devuelve el PRIMER dominio que encuentre.
    """
    raise NotImplementedError("Tu turno: implementa dominio_destino")


def regla_correlacion(sesion, permitidos):
    """sesion = lista de eventos, cada uno un diccionario con "tipo":
      {"tipo": "recuperacion", "contenido": "..."}  (documento que leyó el agente)
      {"tipo": "herramienta", "nombre": "http_get", "args": "..."}
      (puede haber otros tipos, como "mensaje" o "respuesta", que esta regla ignora)
    Devuelve True solo si en la MISMA sesión:
      - algún documento recuperado contiene MARCA_INSTRUCCION (sin distinguir mayúsculas), y
      - alguna herramienta de HERRAMIENTAS_SALIDA va a un dominio que no está en permitidos
        (si sus args no tienen dominio, dominio_destino da "" y eso cuenta como no permitido).
    """
    raise NotImplementedError("Tu turno: implementa regla_correlacion")


def metricas(alertas, maliciosas):
    """alertas = ids de las sesiones con alerta; maliciosas = ids etiquetados como maliciosos (conjuntos).
    Devuelve (precision, recall) como floats. Si un denominador es 0, esa métrica vale 0.0.
    """
    raise NotImplementedError("Tu turno: implementa metricas")


def alcance(sesiones, fuente):
    """sesiones = {id_sesion: lista de eventos (como en regla_correlacion)}.
    Devuelve la lista ORDENADA de ids de las sesiones en las que el agente recuperó un documento
    cuyo campo "fuente" es exactamente `fuente`.
    """
    raise NotImplementedError("Tu turno: implementa alcance")
