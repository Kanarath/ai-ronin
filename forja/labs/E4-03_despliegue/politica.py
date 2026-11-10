"""Laboratorio E4-03 · La puerta de la forja (despliegue con políticas, canary y rollback).

Antes de que un modelo llegue a producción tiene que pasar por una puerta. La puerta no es una
persona revisando a ojo: es **política como código**, unas reglas que se ejecutan en cada
despliegue y dicen sí o no, siempre igual, con el motivo. Si el despliegue pasa, no se cambia todo
de golpe: una parte pequeña del tráfico va a la versión nueva (canary) y, según sus métricas, se
promueve o se revierte (rollback).

Tú implementas las reglas, el reparto del tráfico y la decisión del canary (las funciones «Tu
turno»). Claude ha escrito la traducción de compose.yaml y de un Dockerfile al formato que evalúan
las reglas, y la batería.

Formato de un despliegue (un diccionario):
    {"nombre": "carga",
     "imagen": "python:3.13-slim",                      ← imagen del contenedor
     "usuario": "10001",                                 ← None si no se declara
     "privilegiado": False,
     "puertos": ["127.0.0.1:8000:8000"],                 ← sintaxis corta o larga de compose
     "recursos": {"cpus": "1", "memoria": "512m"},       ← límites; faltan si no se declaran
     "modelo": {"nombre": "llama3.2:1b", "digest": "sha256:baf6..."}}   ← None si no sirve un modelo

Python que practicas: diccionarios, conjuntos, el módulo ipaddress y hashlib. Ver PYTHON.md, anexo E4.
Tests (sin red):
    python -m unittest -v test_politica
"""

import hashlib
import ipaddress
import re
from pathlib import Path

REGLAS = ("modelo", "usuario", "recursos", "puertos", "imagen")


# ─────────────────────────────── Tu turno ───────────────────────────────

def regla_modelo(despliegue, permitidos):
    """El modelo tiene que estar en la lista permitida y con la misma huella (digest).
    permitidos = {nombre del modelo: digest sha256 en hexadecimal}.
    - Si despliegue["modelo"] es None (no sirve ningún modelo): [] (sin violaciones).
    - Si su nombre no está en permitidos: ["modelo-no-permitido"].
    - Si su digest, sin el prefijo "sha256:" y en minúsculas, no es igual al permitido: ["modelo-huella"].
      Un digest que falta (None) tampoco es igual. digest_normalizado (al final del fichero) ya lo hace.
    - Si todo cuadra: [].
    """
    raise NotImplementedError("Tu turno: implementa regla_modelo")


def regla_usuario(despliegue):
    """Nada de root. Devuelve una lista con las violaciones que haya, en este orden:
    - "usuario-sin-declarar" si despliegue["usuario"] es None o "" (si no lo declaras, no sabes con
      qué usuario corre: muchas imágenes usan root por defecto);
    - "usuario-root" si el usuario (la parte antes de ":" si viene como "uid:gid") es "0" o "root";
    - "privilegiado" si despliegue.get("privilegiado") es True.
    """
    raise NotImplementedError("Tu turno: implementa regla_usuario")


def regla_recursos(despliegue):
    """Límites de CPU y memoria. recursos = despliegue.get("recursos") o {} si falta.
    Devuelve "sin-limite-cpu" si falta (o está vacío) recursos["cpus"] y "sin-limite-memoria" si falta
    recursos["memoria"], en ese orden.
    """
    raise NotImplementedError("Tu turno: implementa regla_recursos")


def puerto_expuesto(puerto):
    """True si un puerto de compose se publica en algo distinto de la interfaz local (loopback).
    Sintaxis corta (texto, con un "/tcp" o "/udp" opcional al final, que se ignora):
        "8000" o "8000:8000"        → sin IP: todas las interfaces → True
        "127.0.0.1:8000:8000"       → False · "0.0.0.0:8000:8000" → True
        "[::1]:8000:8000"           → False · "[::]:8000:8000"    → True   (IPv6 va entre corchetes)
        Sin corchetes, una IPv6 deja más de tres trozos al separar por ":" ("::1:8000:8000"): no
        se puede interpretar sin ambigüedad, así que cuenta como expuesto → True.
    Sintaxis larga (diccionario): la IP está en puerto.get("host_ip"); si falta → True.
    Para decidir usa ipaddress.ip_address(ip).is_loopback. Si la IP no se puede interpretar
    (ValueError), cuenta como expuesto: True (denegar por defecto).
    """
    raise NotImplementedError("Tu turno: implementa puerto_expuesto")


def regla_puertos(despliegue):
    """["puerto-expuesto"] si ALGUNO de despliegue.get("puertos", []) está expuesto; si no, []."""
    raise NotImplementedError("Tu turno: implementa regla_puertos")


def regla_imagen(despliegue):
    """La imagen tiene que estar fijada: con un digest ("...@sha256:...") o con una etiqueta que no sea "latest".
    La etiqueta es lo que va tras el último ":" del ÚLTIMO tramo de la ruta (tras el último "/"):
        "python:3.13-slim" → fijada · "ollama/ollama:0.40.16" → fijada · "python@sha256:abc..." → fijada
        "python" → ["imagen-sin-fijar"] · "python:latest" → ["imagen-sin-fijar"]
        "localhost:5000/forja" → ["imagen-sin-fijar"]   (el ":" es del puerto del registro, no una etiqueta)
    Devuelve [] si está fijada.
    """
    raise NotImplementedError("Tu turno: implementa regla_imagen")


def evaluar(despliegue, reglas, permitidos):
    """Aplica las reglas nombradas en `reglas` (nombres de REGLAS; regla_modelo recibe además permitidos).
    Lanza ValueError si alguna regla no existe.
    Devuelve {"permitido": True si no hay ninguna violación, "violaciones": lista ORDENADA y sin repetidos}.
    """
    raise NotImplementedError("Tu turno: implementa evaluar")


def repartir(id_peticion, porcentaje):
    """Reparto del tráfico del canary, determinista: la misma petición (o el mismo usuario) cae siempre
    en el mismo lado.
        h = int(hashlib.sha256(id_peticion.encode("utf-8")).hexdigest(), 16)
        "canary" si h % 100 < porcentaje; si no, "estable"
    Lanza ValueError si porcentaje no está entre 0 y 100.
    """
    raise NotImplementedError("Tu turno: implementa repartir")


def decidir_canary(estable, canary, umbrales):
    """Decide qué hacer con la versión nueva. estable y canary = {"n": peticiones, "errores": n.º de
    errores, "p95": latencia p95 en segundos}; umbrales = {"min_muestras", "margen_errores", "factor_latencia"}.
    En este orden:
        1. "continuar" si canary["n"] < umbrales["min_muestras"]   (aún no hay datos para decidir)
        2. "revertir" si la tasa de errores del canary supera la del estable + margen_errores
           (tasa = errores / n; con n == 0, la tasa es 0)
        3. "revertir" si canary["p95"] > estable["p95"] * factor_latencia
        4. "promover" en cualquier otro caso
    """
    raise NotImplementedError("Tu turno: implementa decidir_canary")


# ──────────────────── Traducción de compose y Dockerfile (escrita por Claude) ────────────────────

def _ultima(texto, instruccion):
    """Argumento de la última línea `instruccion` (FROM, USER) de un Dockerfile, o None."""
    valor = None
    for linea in texto.splitlines():
        partes = linea.strip().split()
        if len(partes) >= 2 and partes[0].upper() == instruccion:
            valor = partes[1]
    return valor


def desde_compose(nombre, servicio, carpeta=None, modelo=None):
    """Convierte un servicio de compose.yaml (ya leído como diccionario) al formato de las reglas.
    Si el servicio se construye (build), la imagen y el usuario salen de su Dockerfile: el FROM y el
    último USER. Un `user:` en compose manda sobre el Dockerfile."""
    imagen, usuario = servicio.get("image"), None
    construccion = servicio.get("build")
    if construccion is not None and carpeta is not None:
        if isinstance(construccion, str):
            construccion = {"context": construccion}
        contexto = (Path(carpeta) / construccion.get("context", ".")).resolve()
        dockerfile = contexto / construccion.get("dockerfile", "Dockerfile")
        texto = dockerfile.read_text(encoding="utf-8")
        imagen, usuario = _ultima(texto, "FROM"), _ultima(texto, "USER")
    usuario = servicio.get("user", usuario)
    limites = ((servicio.get("deploy") or {}).get("resources") or {}).get("limits") or {}
    recursos = {}
    if limites.get("cpus") or servicio.get("cpus"):
        recursos["cpus"] = str(limites.get("cpus") or servicio.get("cpus"))
    if limites.get("memory") or servicio.get("mem_limit"):
        recursos["memoria"] = str(limites.get("memory") or servicio.get("mem_limit"))
    return {"nombre": nombre, "imagen": imagen or "", "usuario": None if usuario is None else str(usuario),
            "privilegiado": bool(servicio.get("privileged", False)), "puertos": list(servicio.get("ports") or []),
            "recursos": recursos, "modelo": modelo}


def despliegues_de_compose(ruta, modelo=None):
    """Todos los servicios de un compose.yaml. Necesita PyYAML (requirements.txt)."""
    import yaml
    ruta = Path(ruta)
    datos = yaml.safe_load(ruta.read_text(encoding="utf-8"))   # safe_load: nunca yaml.load con datos ajenos
    return [desde_compose(n, s or {}, ruta.parent, modelo) for n, s in (datos.get("services") or {}).items()]


def digest_normalizado(digest):
    return re.sub(r"^sha256:", "", (digest or "").strip().lower())
