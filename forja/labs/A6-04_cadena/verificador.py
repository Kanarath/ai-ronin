"""Laboratorio A6-04 · La cadena de verdad: un verificador de artefactos de IA.

En A6-01…03 atacaste y defendiste un pipeline de ML SIMULADO, con controles que eran
interruptores. Aquí construyes los controles de verdad: un programa que revisa una carpeta de
proyecto (modelos, AI-BOM, requirements y Dockerfile) y dice qué no debería pasar a producción.

Tú implementas las piezas marcadas con «Tu turno»:
  - imports_pickle y revisar_pickle: inspeccionar un pickle con pickletools SIN CARGARLO nunca;
  - validar_safetensors: comprobar la cabecera y los offsets de un .safetensors;
  - verificar_bom: comparar el SHA-256 de cada artefacto con el AI-BOM CycloneDX (ML-BOM);
  - revisar_requirements: dependencias sin fijar, inexistentes o recién publicadas (slopsquatting);
  - revisar_dockerfile: usuario root, secretos en ENV o ARG e imágenes sin versión.
Claude ha escrito el resto: el recorrido de la carpeta (verificar_proyecto), la línea de órdenes,
generar_artefactos.py y bateria.py.

REGLA DE ORO: este fichero no importa pickle (ni torch, ni joblib). Cargar un pickle es ejecutarlo;
para saber qué haría, basta con leer sus opcodes con pickletools.genops, que no ejecuta nada.
Un test lo comprueba.

Todo es local y ficticio. Tests (sin red):
    python -m unittest -v test_verificador
Uso:
    python verificador.py artefactos/taller-comprometido
    python verificador.py <carpeta> --controles pickle,bom --indice indice.json --hoy 2026-11-10
"""

import argparse
import datetime
import hashlib
import io
import json
import pickletools
import re
import shlex
import struct
import sys
import zipfile
from pathlib import Path

AQUI = Path(__file__).resolve().parent

# ─────────────────────────────── Constantes ───────────────────────────────

# Opcodes de pickle que importan un objeto o lo llaman: con ellos, cargar es ejecutar código.
OPCODES_PELIGROSOS = ("GLOBAL", "STACK_GLOBAL", "INST", "OBJ", "REDUCE", "NEWOBJ", "NEWOBJ_EX")
# Lista permitida (modo con lista): solo constructores de datos sin efectos.
PERMITIDOS_PICKLE = frozenset({"collections.OrderedDict", "datetime.date", "datetime.datetime"})
EXT_PICKLE = (".pkl", ".pickle", ".bin", ".pt", ".pth", ".ckpt", ".joblib")

# safetensors (README del formato y safetensors/src/tensor.rs, versión 0.8.0): bits por elemento.
DTYPE_BITS = {
    "BOOL": 8, "U8": 8, "I8": 8, "F8_E5M2": 8, "F8_E4M3": 8, "F8_E8M0": 8, "F8_E4M3FNUZ": 8, "F8_E5M2FNUZ": 8,
    "F4": 4, "F6_E2M3": 6, "F6_E3M2": 6,
    "I16": 16, "U16": 16, "F16": 16, "BF16": 16,
    "I32": 32, "U32": 32, "F32": 32, "C64": 64, "F64": 64, "I64": 64, "U64": 64,
}
MAX_CABECERA = 100_000_000  # 100 MB, el límite de la implementación de referencia

# CycloneDX (ML-BOM desde 1.5; la última es la 1.7, de octubre de 2025).
VERSIONES_CYCLONEDX = ("1.5", "1.6", "1.7")
TIPOS_ARTEFACTO = ("machine-learning-model", "data", "file")
PROPIEDAD_FICHERO = "ai-ronin:fichero"  # propiedad (name/value) con la ruta del fichero en el proyecto
CARPETAS_ARTEFACTO = ("modelos", "datos")  # lo que hay aquí tiene que estar en el AI-BOM

# Regla SecretsUsedInArgOrEnv de BuildKit (frontend/dockerfile/dockerfile2llb/validations.go).
PALABRAS_SECRETO = frozenset({"apikey", "auth", "credential", "credentials", "key", "password", "pword",
                              "passwd", "psw", "secret", "token"})
PALABRAS_PERMITIDAS = frozenset({"public"})

CONTROLES = ("pickle", "pickle-estricto", "safetensors", "bom", "deps", "docker")
CONTROLES_POR_DEFECTO = ("pickle", "safetensors", "bom", "deps", "docker")
DIAS_MINIMOS = 30


def normalizar_nombre(nombre):
    """Nombre de paquete normalizado (PyPA, «Name normalization»): minúsculas y cada racha de
    '.', '-' o '_' cambiada por un solo '-'. «Forja_Metrics» y «forja.metrics» son el mismo paquete."""
    return re.sub(r"[-_.]+", "-", nombre).lower()


def sha256_hex(datos):
    return hashlib.sha256(datos).hexdigest()


# ─────────────────────────────── Tu turno ───────────────────────────────

def imports_pickle(datos):
    """Lista de los objetos que un pickle importaría, como "modulo.nombre", en orden de aparición
    y sin repetir, SIN cargarlo: recorre `pickletools.genops(datos)`, que da (opcode, arg, pos).
      - GLOBAL e INST: su arg es "modulo nombre" (separados por un espacio) → "modulo.nombre".
      - STACK_GLOBAL no lleva arg: toma el módulo y el nombre de la pila. Para saber qué hay en
        ella, guarda en orden las cadenas que se apilan:
          · un opcode cuyo arg es un str (salvo GLOBAL e INST) apila esa cadena;
          · MEMOIZE guarda en memo[len(memo)] lo que apiló el opcode anterior si fue una cadena
            (si no, guarda None); PUT, BINPUT y LONG_BINPUT hacen lo mismo en memo[arg];
          · GET, BINGET y LONG_BINGET apilan memo[arg] si es una cadena.
        STACK_GLOBAL usa las dos últimas cadenas apiladas: "penúltima.última". Si hay menos
        de dos, "?" (desconocido: nunca estará permitido).
      MEMOIZE y los PUT no cambian lo que «apiló el opcode anterior» (el valor sigue arriba);
      cualquier otro opcode que no apile una cadena sí lo borra.
    Si el pickle está mal formado, genops lanza ValueError: deja que salga, no la captures.
    """
    raise NotImplementedError("Tu turno: implementa imports_pickle")


def revisar_pickle(datos, permitidos=None):
    """Hallazgos de un pickle, como lista de tuplas (regla, detalle) sin repetir (el orden no importa).
      - Si recorrerlo con genops (o con imports_pickle) lanza ValueError → [("pickle-ilegible", "")].
      - Modo estricto (permitidos es None): ("opcode-peligroso", nombre) por cada opcode de
        OPCODES_PELIGROSOS que aparezca.
      - Modo con lista (permitidos es un conjunto de "modulo.nombre"): ("import-no-permitido", imp)
        por cada import de imports_pickle que no esté en `permitidos`. Los opcodes dan igual: un
        REDUCE sobre collections.OrderedDict es legítimo.
    Un pickle sin hallazgos devuelve []. Nunca llames a pickle.load ni a pickle.loads.
    """
    raise NotImplementedError("Tu turno: implementa revisar_pickle")


def validar_safetensors(datos):
    """Hallazgos de un fichero .safetensors (bytes), como lista de tuplas (regla, detalle).
    Formato: 8 bytes con N (entero sin signo de 64 bits, little-endian: struct "<Q"), N bytes de
    cabecera JSON en UTF-8 y, después, el buffer de datos. Comprueba, en este orden:
      1. Menos de 8 bytes → [("cabecera-corta", "")] y termina.
      2. N > MAX_CABECERA o 8 + N > len(datos) → [("longitud-cabecera", str(N))] y termina.
      3. La cabecera tiene que empezar por b"{" y ser un objeto JSON válido en UTF-8 (puede llevar
         espacios al final). Si no → [("cabecera-no-json", "")] y termina.
      4. "__metadata__", si está, debe ser un dict de str a str; si no → ("metadatos-no-texto", "").
      5. Cada otra clave es un tensor y su valor, un dict con "dtype" (str), "shape" (lista de
         enteros >= 0) y "data_offsets" (lista de 2 enteros [inicio, fin] con 0 <= inicio <= fin).
         Si no → ("tensor-mal-formado", nombre) y ese tensor no se sigue mirando. Ojo: True no
         es un entero válido aquí aunque isinstance(True, int) lo diga.
         Si el dtype no está en DTYPE_BITS → ("dtype-desconocido", nombre); tampoco se sigue mirando.
         Bits = producto de shape (1 si shape es []) × DTYPE_BITS[dtype]; si no son un número
         entero de bytes o fin - inicio no es bits // 8 → ("tamano-incoherente", nombre).
      6. Offsets: ordena los tensores que hayan pasado el punto 5 (aunque tengan tamaño
         incoherente) por (inicio, fin, nombre). Con esperado = 0, para cada uno: si inicio >
         esperado → ("hueco", nombre); si inicio < esperado → ("solape", nombre); y después
         esperado = max(esperado, fin).
      7. El buffer mide len(datos) - 8 - N. Si esperado < buffer → ("bytes-sobrantes",
         str(buffer - esperado)): bytes que no son de ningún tensor (un fichero políglota). Si
         esperado > buffer → ("fuera-del-buffer", str(esperado - buffer)).
    Un fichero correcto devuelve [].
    """
    raise NotImplementedError("Tu turno: implementa validar_safetensors")


def verificar_bom(bom, ficheros):
    """Compara un AI-BOM CycloneDX (dict) con los artefactos del proyecto. `ficheros` es un dict
    {ruta: bytes} con las rutas relativas en formato "modelos/x.safetensors". Devuelve una lista
    de tuplas (regla, detalle):
      - Si bom["bomFormat"] no es "CycloneDX" o bom["specVersion"] no está en VERSIONES_CYCLONEDX
        → [("bom-no-valido", "")] y termina.
      - Para cada componente de bom.get("components", []) cuyo "type" esté en TIPOS_ARTEFACTO:
          · su ruta es el "value" de la propiedad (en "properties", lista de {"name", "value"})
            cuyo "name" es PROPIEDAD_FICHERO; si no la tiene → ("componente-sin-fichero",
            componente.get("name", "")) y se pasa al siguiente;
          · su huella es el "content" del primer hash de "hashes" con "alg" == "SHA-256"; si no
            hay → ("sin-hash", ruta);
          · si la ruta no está en `ficheros` → ("fichero-ausente", ruta);
          · si está y hay huella, y no coincide con sha256_hex(ficheros[ruta]) sin distinguir
            mayúsculas (CycloneDX admite hexadecimal en mayúsculas) → ("hash-distinto", ruta).
      - Cada ruta de `ficheros` que ningún componente declare → ("fichero-no-declarado", ruta).
    """
    raise NotImplementedError("Tu turno: implementa verificar_bom")


def revisar_requirements(texto, indice, hoy, dias_minimos=DIAS_MINIMOS):
    """Hallazgos de un requirements.txt frente a un índice de paquetes local. `indice` es un dict
    {nombre_normalizado: {version: "AAAA-MM-DD" (fecha de publicación)}} y `hoy`, un datetime.date.
    Devuelve una lista de tuplas (regla, detalle). Para cada línea:
      - Quita el comentario (desde un "#" al principio de la línea o precedido de un espacio o
        tabulador) y los espacios de los extremos; si queda vacía, se ignora.
      - Si empieza por "-" es una opción (por ejemplo --extra-index-url, que añade un índice que
        nadie revisa) → ("opcion-no-permitida", su primera palabra).
      - Quita el marcador de entorno (desde el primer ";"). Lo que queda debe ser
        nombre[extras]especificador con la expresión regular
            ^([A-Za-z0-9][A-Za-z0-9._-]*)\\s*(\\[[^\\]]*\\])?\\s*(.*)$
        Si no encaja → ("linea-no-valida", la línea sin comentario).
      - nombre = normalizar_nombre(...). Si no está en el índice → ("no-existe", nombre): un
        paquete inventado, quizá por un asistente de código.
      - El especificador (sin espacios) debe ser "==" + versión, sin comas ni "*" y sin "===".
        Si no → ("sin-fijar", nombre).
      - Si la versión no está en indice[nombre] → ("version-inexistente", "nombre==versión").
      - Si se publicó hace menos de `dias_minimos` días ((hoy - fecha).days < dias_minimos)
        → ("paquete-reciente", "nombre==versión").
    """
    raise NotImplementedError("Tu turno: implementa revisar_requirements")


def revisar_dockerfile(texto):
    """Hallazgos de un Dockerfile, como lista de tuplas (regla, detalle) sin repetir.
      - Une las líneas que acaban en "\\" con la siguiente (con un espacio) e ignora las vacías y
        las que empiezan por "#". La instrucción es la primera palabra (sin distinguir
        mayúsculas) y sus argumentos, el resto de la línea.
      - FROM: ignora las palabras que empiezan por "--" (como --platform=...). La imagen es la
        primera palabra que queda y, si después viene "AS alias", recuerda el alias. Cada FROM
        empieza una etapa nueva, sin USER.
        La imagen está bien si es "scratch", si es el alias de una etapa anterior (sin distinguir
        mayúsculas) o si lleva digest ("@sha256:"). Si no, su etiqueta es lo que va tras el último
        ":" siempre que ese ":" esté después del último "/" (en "registro:5000/img" el 5000 es un
        puerto). Sin etiqueta o con "latest" → ("imagen-sin-version", imagen).
      - USER: el usuario de la etapa es lo que va antes de ":" en su primera palabra.
      - ENV y ARG: separa los argumentos con shlex.split. Con ENV, si la primera palabra no lleva
        "=" es la forma antigua «ENV CLAVE valor» y la única clave es esa palabra; si no, cada
        palabra es CLAVE=valor. Con ARG, cada palabra es CLAVE o CLAVE=valor. Una clave es secreta
        si, partida por "_" y en minúsculas, alguna parte está en PALABRAS_SECRETO y ninguna en
        PALABRAS_PERMITIDAS (HF_TOKEN sí; TOKENIZERS_PARALLELISM y PUBLIC_KEY_URL no)
        → ("secreto-en-env", clave) o ("secreto-en-arg", clave). Con o sin valor: un ARG queda
        en el historial de la imagen.
      - Al final: si la última etapa no tiene USER, o su usuario es "root" o "0"
        → ("usuario-root", usuario o "").
    Las demás instrucciones se ignoran.
    """
    raise NotImplementedError("Tu turno: implementa revisar_dockerfile")


# ───────────────────── A partir de aquí, código de Claude ─────────────────────

def _miembros_pickle(datos):
    """Los pickles que contiene un fichero: él mismo o, si es un zip (como los .pt de PyTorch),
    cada miembro .pkl. Leer un zip con zipfile tampoco ejecuta nada."""
    if datos[:4] == b"PK\x03\x04":
        try:
            with zipfile.ZipFile(io.BytesIO(datos)) as z:
                return [(n, z.read(n)) for n in sorted(z.namelist()) if n.endswith(".pkl")]
        except zipfile.BadZipFile:
            return [("", datos)]
    return [("", datos)]


def _hallazgo(control, fichero, regla, detalle):
    return {"control": control, "fichero": fichero, "regla": regla, "detalle": detalle}


def ficheros_del_proyecto(carpeta):
    """{ruta relativa (con /): bytes} de todos los ficheros de la carpeta, ordenados."""
    carpeta = Path(carpeta)
    return {p.relative_to(carpeta).as_posix(): p.read_bytes()
            for p in sorted(carpeta.rglob("*")) if p.is_file()}


def es_artefacto(ruta):
    return ruta.split("/", 1)[0] in CARPETAS_ARTEFACTO


def verificar_proyecto(carpeta, controles=CONTROLES_POR_DEFECTO, indice=None, hoy=None):
    """Pasa los controles elegidos por una carpeta de proyecto y devuelve la lista de hallazgos
    (dicts con control, fichero, regla y detalle). Usa TUS funciones."""
    indice = indice or {}
    hoy = hoy or datetime.date.today()
    controles = set(controles)
    desconocidos = controles - set(CONTROLES)
    if desconocidos:
        raise ValueError("controles desconocidos: %s" % ", ".join(sorted(desconocidos)))
    ficheros = ficheros_del_proyecto(carpeta)
    out = []
    for ruta, datos in ficheros.items():
        nombre = ruta.rsplit("/", 1)[-1]
        if nombre.lower().endswith(EXT_PICKLE):
            for control, permitidos in (("pickle-estricto", None), ("pickle", PERMITIDOS_PICKLE)):
                if control in controles:
                    for miembro, contenido in _miembros_pickle(datos):
                        for regla, detalle in revisar_pickle(contenido, permitidos):
                            out.append(_hallazgo(control, ruta, regla, ("%s: %s" % (miembro, detalle)) if miembro else detalle))
        elif nombre.lower().endswith(".safetensors") and "safetensors" in controles:
            out += [_hallazgo("safetensors", ruta, r, d) for r, d in validar_safetensors(datos)]
        elif re.match(r"(?i)^requirements.*\.txt$", nombre) and "deps" in controles:
            texto = datos.decode("utf-8", errors="replace")
            out += [_hallazgo("deps", ruta, r, d) for r, d in revisar_requirements(texto, indice, hoy)]
        elif nombre.startswith("Dockerfile") and "docker" in controles:
            texto = datos.decode("utf-8", errors="replace")
            out += [_hallazgo("docker", ruta, r, d) for r, d in revisar_dockerfile(texto)]
    if "bom" in controles:
        artefactos = {r: d for r, d in ficheros.items() if es_artefacto(r)}
        if "bom.json" not in ficheros:
            if artefactos:
                out.append(_hallazgo("bom", "bom.json", "sin-bom", ""))
        else:
            try:
                bom = json.loads(ficheros["bom.json"].decode("utf-8"))
            except (UnicodeDecodeError, json.JSONDecodeError):
                bom = None
            if not isinstance(bom, dict):
                out.append(_hallazgo("bom", "bom.json", "bom-no-valido", ""))
            else:
                for regla, detalle in verificar_bom(bom, artefactos):
                    # Lo que falla en «fichero-ausente» o «componente-sin-fichero» es la declaración.
                    fichero = detalle if regla != "fichero-ausente" and detalle in artefactos else "bom.json"
                    out.append(_hallazgo("bom", fichero, regla, detalle))
    return out


def rechazados(hallazgos):
    """Ficheros con al menos un hallazgo."""
    return sorted({h["fichero"] for h in hallazgos})


def cargar_indice(ruta):
    """{nombre normalizado: {versión: fecha}} desde un fichero como indice.json."""
    datos = json.loads(Path(ruta).read_text(encoding="utf-8"))
    return {normalizar_nombre(k): v for k, v in datos["paquetes"].items()}


def main(argv=None):
    for flujo in (sys.stdout, sys.stderr):
        if hasattr(flujo, "reconfigure"):
            flujo.reconfigure(encoding="utf-8", errors="replace")
    p = argparse.ArgumentParser(description="Verifica los artefactos de IA de una carpeta de proyecto.")
    p.add_argument("carpeta")
    p.add_argument("--controles", default=",".join(CONTROLES_POR_DEFECTO),
                   help="separados por comas, de: " + ", ".join(CONTROLES))
    p.add_argument("--indice", default=str(AQUI / "indice.json"), help="índice local de paquetes")
    p.add_argument("--hoy", default=None, help="fecha AAAA-MM-DD para la antigüedad de los paquetes")
    a = p.parse_args(argv)
    hoy = datetime.date.fromisoformat(a.hoy) if a.hoy else datetime.date.today()
    controles = [c for c in a.controles.split(",") if c]
    hallazgos = verificar_proyecto(a.carpeta, controles, cargar_indice(a.indice), hoy)
    for h in hallazgos:
        print("✗ %-12s %-40s %s %s" % (h["control"], h["fichero"], h["regla"], h["detalle"]))
    n = len(ficheros_del_proyecto(a.carpeta))
    print("%d hallazgos · %d de %d ficheros rechazados" % (len(hallazgos), len(rechazados(hallazgos)), n))
    return 1 if hallazgos else 0


if __name__ == "__main__":
    sys.exit(main())
