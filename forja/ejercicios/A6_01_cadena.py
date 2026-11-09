"""Ejercicio A6 · Sellos en la cadena de suministro.

En el Dojo activaste los controles del pipeline con interruptores. Aquí escribes cinco de ellos:
la huella de un fichero, el reconocimiento del formato de un artefacto por sus primeros bytes,
la verificación de un artefacto contra un manifiesto firmado, la revisión de dependencias contra
un lockfile y la búsqueda de secretos en las capas de una imagen.
Python que practicas: bytes, hashlib, int.from_bytes, re, diccionarios y tuplas (PYTHON.md §3, §4, §8).

Todo es inofensivo: los «artefactos» de los tests son unos pocos bytes inventados y nunca se
deserializa nada. Ejecuta los tests desde forja/ejercicios:
    python -m unittest -v test_A6_01_cadena
"""

import hashlib
import re

EDAD_MINIMA_DIAS = 30

# Una línea de Dockerfile que fija un secreto: ENV o ARG con un nombre que suena a credencial.
PATRON_SECRETO = r"^(ENV|ARG)\s+\w*(TOKEN|SECRET|PASSWORD|API_KEY)\w*\s*="


def huella_fichero(contenido):
    """SHA-256 (hexdigest completo, 64 caracteres) de unos bytes."""
    raise NotImplementedError("Tu turno: implementa huella_fichero")


def formato_artefacto(cabecera):
    """Reconoce el formato de un artefacto por sus primeros bytes (sin cargarlo).

    - "pickle": el primer byte es 0x80 (el código PROTO con el que empiezan los pickles de protocolo 2 o superior).
    - "safetensors": hay al menos 9 bytes, los 8 primeros son un entero sin signo little-endian N
      (la longitud de la cabecera JSON) con N > 0, y el byte 9 (índice 8) es "{".
    - "desconocido": en cualquier otro caso.
    """
    raise NotImplementedError("Tu turno: implementa formato_artefacto")


def verificar_artefacto(manifiesto, nombre, contenido, claves_confianza):
    """manifiesto = {nombre: {"sha256": "...", "firmante": "lora-labs"}} (ya verificado criptográficamente).

    Devuelve (aceptado, motivo), comprobando EN ESTE ORDEN:
      1. (False, "sin-firma") si el artefacto no está en el manifiesto.
      2. (False, "clave-desconocida") si su firmante no está en claves_confianza.
      3. (False, "huella") si huella_fichero(contenido) no coincide con la del manifiesto.
      4. (True, "ok").
    Recuerda lo que viste en el Dojo: "ok" no significa inofensivo, solo íntegro y de quien dice.
    """
    raise NotImplementedError("Tu turno: implementa verificar_artefacto")


def revisar_dependencias(requisitos, lockfile, edades):
    """requisitos = [{"nombre": "numpy", "version": "2.3.4", "sha256": "..."}, ...] (lo que se va a instalar)
    lockfile = {"numpy": {"version": "2.3.4", "sha256": "..."}, ...} (lo aprobado)
    edades = {"numpy": 7000, ...} (días desde que se publicó el paquete)

    Devuelve la lista ORDENADA de tuplas (nombre, motivo) de los requisitos que no pasan. Por
    requisito, solo el PRIMER motivo que falle, en este orden:
      "fuera-del-lock" (no está en el lockfile), "version" (versión distinta), "huella"
      (sha256 distinto) y "reciente" (edad desconocida o menor que EDAD_MINIMA_DIAS).
    """
    raise NotImplementedError("Tu turno: implementa revisar_dependencias")


def secretos_en_capas(capas):
    """capas = líneas de un Dockerfile, una por capa. Devuelve la lista de ÍNDICES de las capas
    que fijan un secreto según PATRON_SECRETO (sin distinguir mayúsculas de minúsculas).
    """
    raise NotImplementedError("Tu turno: implementa secretos_en_capas")
