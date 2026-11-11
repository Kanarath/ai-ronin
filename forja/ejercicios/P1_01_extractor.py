"""Ejercicio P1-01…P1-03 · Las piezas de código que hacen fiable un extractor con un LLM.

Vas a escribir lo que en el Dojo eran las técnicas `esquema`, `delimitar` y `validar_args` de
`app set`, y la métrica de `app eval`. El modelo nunca garantiza nada: tu código, sí.
Python que practicas: json.loads con try/except, isinstance, funciones que reciben funciones y str.

Ejecuta los tests desde forja/ejercicios:
    python -m unittest -v test_P1_01_extractor

Extra opcional con un modelo de verdad: extras/extractor_ollama.py usa estas funciones con
Ollama en tu equipo (lee su cabecera).
"""

import json

CAMPOS = ("pedido", "problema", "urgencia")
URGENCIAS = ("alta", "media", "baja")


def extraer_json(texto):
    """El diccionario JSON que hay en la respuesta del modelo, o None.

    1. Intenta json.loads(texto).
    2. Si falla, prueba con el trozo que va desde la primera «{» hasta la última «}».
    3. Si tampoco es JSON, o lo que sale no es un diccionario, devuelve None.

    Ejemplo: extraer_json('¡Claro! Aquí tienes: {"pedido": "P-101"} ¿Algo más?') → {"pedido": "P-101"}
    """
    raise NotImplementedError("Tu turno: implementa extraer_json")


def valida(salida):
    """True si salida es un diccionario con exactamente los CAMPOS, todos de texto (str), y la urgencia es una de URGENCIAS."""
    raise NotImplementedError("Tu turno: implementa valida")


def con_reintentos(llamar, prompt, intentos=3):
    """Llama a llamar(prompt) hasta que extraer_json + valida den una salida buena.

    Devuelve (salida, número de llamadas hechas), o (None, intentos) si ninguna vale.
    """
    raise NotImplementedError("Tu turno: implementa con_reintentos")


def delimitar(correo):
    """Envuelve el correo entre <correo> y </correo> para que el modelo lo trate como datos.

    Si el propio correo contiene «</correo>» (un atacante intentando cerrar la etiqueta antes de tiempo),
    sustitúyelo por «[/correo]». Formato: "<correo>\\n" + texto + "\\n</correo>"
    """
    raise NotImplementedError("Tu turno: implementa delimitar")


def id_valido(texto):
    """True si texto es «P-» seguido de exactamente tres cifras (P-109). Es la validación del argumento de buscar_pedido."""
    raise NotImplementedError("Tu turno: implementa id_valido")


def exactitud(salidas, oro):
    """Fracción de campos correctos entre todos los correos: {"total": fracción, campo: fracción, …}.

    salidas puede tener None (salida inválida): cuenta como 0 campos correctos.
    """
    raise NotImplementedError("Tu turno: implementa exactitud")
