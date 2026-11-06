"""Ejercicio A4 · Los sellos de un host MCP.

En el Dojo activaste los controles del host con interruptores. Aquí escribes cuatro de ellos:
la revisión de descripciones, la huella de las definiciones aprobadas (pinning), la tabla de
herramientas con espacios de nombres (contra el shadowing) y la validación de tokens con
destinatario y permisos (contra el token passthrough).
Python que practicas: json, hashlib, re, diccionarios y conjuntos (PYTHON.md §3, §4, §8).

Ejecuta los tests desde forja/ejercicios:
    python -m unittest -v test_A4_01_mcp
"""

import hashlib
import json
import re

# Patrones que delatan instrucciones dirigidas al modelo dentro de una descripción.
PATRONES_SOSPECHOSOS = [
    r"<important>",
    r"no lo menciones",
    r"pásalo",
    r"llama también a",
    r"\btoken\b",
]


def descripcion_sospechosa(descripcion):
    """Devuelve la lista de patrones de PATRONES_SOSPECHOSOS que aparecen en la descripción
    (sin distinguir mayúsculas de minúsculas), en el mismo orden que en la lista.
    Una lista vacía significa «no se ha encontrado nada».
    """
    raise NotImplementedError("Tu turno: implementa descripcion_sospechosa")


def huella(herramientas):
    """Huella de una lista de definiciones de herramientas (lo que devuelve tools/list).

    Serializa con json.dumps(herramientas, sort_keys=True, ensure_ascii=False), calcula el
    SHA-256 de esos bytes en UTF-8 y devuelve los 12 primeros caracteres del hexdigest.
    sort_keys=True hace que el orden de las claves de los diccionarios no cambie la huella.
    """
    raise NotImplementedError("Tu turno: implementa huella")


def comprobar_pin(aprobadas, servidor, herramientas):
    """aprobadas = {servidor: huella aprobada}. Devuelve (permitido, motivo):
      - (False, "sin-aprobar") si el servidor no está en aprobadas.
      - (False, "definicion-cambiada") si la huella actual no coincide con la aprobada.
      - (True, "ok") en otro caso.
    """
    raise NotImplementedError("Tu turno: implementa comprobar_pin")


def tabla_herramientas(servidores):
    """servidores = [{"id": "forja-pedidos", "herramientas": ["buscar_pedido", ...]}, ...]
    en el orden en que se conectaron.

    Devuelve (tabla, colisiones):
      - tabla: {"servidor.herramienta": "servidor"} con TODAS las herramientas (espacios de nombres).
      - colisiones: lista ORDENADA de los nombres de herramienta que exponen dos o más servidores.
    """
    raise NotImplementedError("Tu turno: implementa tabla_herramientas")


def aceptar_token(token, servidor, permiso):
    """Lo que debe comprobar un servidor MCP antes de aceptar un token.

    token = {"aud": "<servidor para el que se emitió>", "scopes": ["pedidos:read", ...]}
    Devuelve (aceptado, motivo), comprobando EN ESTE ORDEN:
      1. (False, "audiencia") si token["aud"] no es este servidor (token passthrough).
      2. (False, "permiso") si el permiso pedido no está en token["scopes"].
      3. (True, "ok").
    """
    raise NotImplementedError("Tu turno: implementa aceptar_token")
