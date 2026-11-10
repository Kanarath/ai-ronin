"""Genera los artefactos de prueba del laboratorio A6-04 (los ha escrito Claude).

Dos proyectos ficticios del taller Kurogane, los mismos de A6-01…03:
  artefactos/taller-bueno/          lo que debería pasar sin un solo hallazgo
  artefactos/taller-comprometido/   cada fichero con un problema de la cadena de suministro

TODOS LOS ARTEFACTOS MALICIOSOS SON INOFENSIVOS. Los pickles «con código» se escriben aquí
opcode a opcode, sin importar pickle, y lo que llamarían está en módulos que no existen
(taller_ficticio, forja_falsa): si alguien los cargara, fallarían con ModuleNotFoundError antes de
ejecutar nada. Aun así, el verificador NUNCA los carga: los lee con pickletools.genops. Tú
tampoco los cargues: es la costumbre que este laboratorio quiere crear.

Los ficheros salen siempre iguales, byte a byte; bateria.py comprueba sus huellas con ataques.json.

    python generar_artefactos.py              → escribe en ./artefactos
    python generar_artefactos.py <carpeta>
"""

import hashlib
import io
import json
import struct
import sys
import zipfile
from pathlib import Path

AQUI = Path(__file__).resolve().parent

# ─────────────── Pickles escritos a mano (protocolo 4, sin el módulo pickle) ───────────────
PROTO4, PROTO2 = b"\x80\x04", b"\x80\x02"
MEMO, STACK_GLOBAL, REDUCE, STOP = b"\x94", b"\x93", b"R", b"."
EMPTY_TUPLE, TUPLE1, EMPTY_DICT, EMPTY_LIST = b")", b"\x85", b"}", b"]"
MARK, SETITEM, SETITEMS, APPENDS, POP = b"(", b"s", b"u", b"e", b"0"


def s(texto):
    """SHORT_BINUNICODE + MEMOIZE: apila una cadena y la guarda en la memoria del pickle."""
    b = texto.encode("utf-8")
    assert len(b) < 256
    return b"\x8c" + bytes([len(b)]) + b + MEMO


def k(n):
    return b"K" + bytes([n])  # BININT1


def f(x):
    return b"G" + struct.pack(">d", x)  # BINFLOAT


def binget(i):
    return b"h" + bytes([i])


def lista_floats(valores):
    return EMPTY_LIST + MEMO + MARK + b"".join(f(v) for v in valores) + APPENDS


def pickle_ordered_dict(pares):
    """Lo que escribiría pickle.dumps(OrderedDict(pares), protocol=4): STACK_GLOBAL + REDUCE legítimos."""
    cuerpo = b"".join(s(clave) + valor for clave, valor in pares)
    return PROTO4 + s("collections") + s("OrderedDict") + STACK_GLOBAL + MEMO + EMPTY_TUPLE + REDUCE + MEMO \
        + MARK + cuerpo + SETITEMS + STOP


def pickle_con_llamada(modulo, funcion, argumento):
    """Un «modelo» (dict de pesos) cuya clave "config" se construye llamando a modulo.funcion(argumento)."""
    return PROTO4 + EMPTY_DICT + MEMO + MARK + s("pesos") + lista_floats([0.12, -0.5, 0.33]) \
        + s("config") + s(modulo) + s(funcion) + STACK_GLOBAL + MEMO + s(argumento) + TUPLE1 + MEMO + REDUCE + MEMO \
        + SETITEMS + STOP


def pickle_global_protocolo2(modulo, funcion, argumento):
    """El opcode GLOBAL clásico ("c" + "modulo\\nnombre\\n"), el de los pickles de protocolo 0 a 2."""
    a = argumento.encode("utf-8")
    return PROTO2 + b"c" + modulo.encode() + b"\n" + funcion.encode() + b"\nq\x00" + b"X" + struct.pack("<I", len(a)) \
        + a + b"q\x01" + TUPLE1 + b"q\x02" + REDUCE + b"q\x03" + STOP


def pickle_ofuscado():
    """Guarda el módulo y la función en la memoria al principio y los recupera con BINGET al final.
    Justo antes, apila y descarta "collections" y "OrderedDict": quien solo mire las dos últimas
    cadenas literales creerá que importa collections.OrderedDict (permitido)."""
    return PROTO4 + EMPTY_DICT + MEMO \
        + s("taller_ficticio") + POP + s("avivar_fuego") + POP \
        + s("version") + k(2) + SETITEM \
        + s("config") + s("collections") + POP + s("OrderedDict") + POP \
        + binget(1) + binget(2) + STACK_GLOBAL + MEMO + EMPTY_TUPLE + REDUCE + MEMO + SETITEM + STOP


def zip_pytorch(miembros):
    """Un .pt como los de PyTorch: un zip con el pickle en <nombre>/data.pkl. Fecha fija: mismos bytes siempre."""
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_STORED) as z:
        for nombre, datos in miembros:
            z.writestr(zipfile.ZipInfo(nombre, date_time=(2026, 1, 1, 0, 0, 0)), datos)
    return buf.getvalue()


# ───────────────────────────────── safetensors ─────────────────────────────────

def safetensors(tensores, metadata=None, extra=b"", offsets=None, n_falso=None):
    """tensores: lista de (nombre, dtype, shape, bytes). Offsets contiguos salvo que se den.
    La cabecera se rellena con espacios hasta múltiplo de 8, como hace la librería oficial."""
    cab = {}
    if metadata is not None:
        cab["__metadata__"] = metadata
    pos, buffer = 0, b""
    for i, (nombre, dtype, shape, datos) in enumerate(tensores):
        ini, fin = offsets[i] if offsets else (pos, pos + len(datos))
        cab[nombre] = {"dtype": dtype, "shape": shape, "data_offsets": [ini, fin]}
        pos += len(datos)
        buffer += datos
    j = json.dumps(cab, separators=(",", ":")).encode("utf-8")
    j += b" " * (-len(j) % 8)
    n = len(j) if n_falso is None else n_falso
    return struct.pack("<Q", n) + j + buffer + extra


def f32(*v):
    return struct.pack("<%df" % len(v), *v)


# ───────────────────────────────── AI-BOM ─────────────────────────────────

def componente(tipo, nombre, version, ruta, datos, mayusculas=False, huella=None):
    h = huella or hashlib.sha256(datos).hexdigest()
    c = {"type": tipo, "bom-ref": "%s@%s" % (nombre, version), "name": nombre, "version": version,
         "hashes": [{"alg": "SHA-256", "content": h.upper() if mayusculas else h}],
         "properties": [{"name": "ai-ronin:fichero", "value": ruta}]}
    if tipo == "machine-learning-model":
        c["modelCard"] = {"modelParameters": {"task": "clasificación de defectos del acero (ficticio)"}}
    return c


def bom(proyecto, componentes):
    return {
        "$schema": "http://cyclonedx.org/schema/bom-1.7.schema.json",
        "bomFormat": "CycloneDX", "specVersion": "1.7",
        "serialNumber": "urn:uuid:%s" % ("6a0f4c2e-0000-4000-8000-00000000000" + ("1" if proyecto == "bueno" else "2")),
        "version": 1,
        "metadata": {"timestamp": "2026-11-10T00:00:00Z",
                     "component": {"type": "application", "name": "taller-%s" % proyecto, "version": "1.0"}},
        "components": componentes,
    }


def _json(d):
    return (json.dumps(d, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


# ───────────────────────────────── Proyectos ─────────────────────────────────

def proyecto_bueno():
    m = {}
    m["modelos/clasificador-acero.safetensors"] = safetensors(
        [("capa1.peso", "F32", [2, 3], f32(0.1, 0.2, 0.3, 0.4, 0.5, 0.6)),
         ("capa1.sesgo", "F32", [3], f32(0.0, 0.1, -0.1)),
         ("capa2.peso", "F16", [3, 1], b"\x00\x3c\x00\x38\x00\x34")],
        metadata={"format": "pt", "autor": "forja (interno)"})
    m["modelos/embeddings.safetensors"] = safetensors(  # BF16, un escalar (shape []) y un tensor vacío
        [("tabla", "BF16", [4, 2], bytes(16)), ("vacio", "F32", [0, 4], b""), ("escala", "F32", [], f32(2.0))])
    m["modelos/adaptador-estilo.safetensors"] = adaptador_original()
    m["modelos/tokenizador.pkl"] = pickle_ordered_dict([("<pad>", k(0)), ("acero", k(1)), ("grieta", k(2)), ("temple", k(3))])
    m["modelos/vocabulario.pkl"] = PROTO4 + EMPTY_DICT + MEMO + MARK + s("pesos") + lista_floats([0.5, 0.25]) \
        + s("sesgo") + f(0.1) + SETITEMS + STOP  # sin ningún import: pasa incluso el modo estricto
    m["modelos/clasificador.pt"] = zip_pytorch([("clasificador/data.pkl", pickle_ordered_dict([("capa1.peso", lista_floats([0.1, 0.2]))])),
                                                ("clasificador/version", b"3\n")])
    m["datos/inspecciones.csv"] = "pieza,dureza,grieta\nk-001,58,0\nk-002,61,0\nk-003,55,1\n".encode("utf-8")
    comps = []
    for ruta, datos in m.items():
        tipo = "data" if ruta.startswith("datos/") else "machine-learning-model"
        nombre = ruta.rsplit("/", 1)[-1].split(".")[0]
        comps.append(componente(tipo, nombre, "1.0", ruta, datos, mayusculas=(ruta.endswith("embeddings.safetensors"))))
    m["bom.json"] = _json(bom("bueno", comps))
    m["requirements.txt"] = b"# Dependencias del servicio, fijadas\nnumpy==2.3.4\nsafetensors==0.6.2\nforja-metrics==1.1.0\n"
    m["requirements-dev.txt"] = ("# Entorno de desarrollo\n"
                                 "Forja_Metrics==1.1.0          # mismo paquete que forja-metrics (nombre normalizado)\n"
                                 "safetensors[numpy] == 0.6.2 ; python_version >= \"3.12\"\n"
                                 "\n"
                                 "numpy==2.3.4\t# numérico\n").encode("utf-8")
    m["Dockerfile"] = ("# Servicio de inferencia del taller (ficticio)\n"
                       "FROM python:3.13-slim\n"
                       "RUN useradd --create-home --uid 10001 forja\n"
                       "WORKDIR /app\n"
                       "COPY requirements.txt .\n"
                       "RUN pip install --no-cache-dir -r requirements.txt\n"
                       "ENV TOKENIZERS_PARALLELISM=false \\\n"
                       "    HF_HUB_OFFLINE=1\n"
                       "COPY modelos/ /app/modelos/\n"
                       "USER forja\n"
                       "CMD [\"python\", \"-m\", \"servir\"]\n").encode("utf-8")
    m["Dockerfile.multietapa"] = ("FROM --platform=linux/amd64 python:3.13-slim AS base\n"
                                  "ARG PUBLIC_KEY_URL=https://forja.example/claves/firma.pub\n"
                                  "FROM registro.forja.example:5000/forja/herramientas:2.1 AS herramientas\n"
                                  "FROM base\n"
                                  "COPY --from=herramientas /opt/herramientas /opt/herramientas\n"
                                  "user 10001:10001\n"
                                  "CMD [\"python\", \"-m\", \"servir\"]\n").encode("utf-8")
    return m


def adaptador_original():
    return safetensors([("lora.a", "F32", [2, 2], f32(0.01, 0.02, 0.03, 0.04)), ("lora.b", "F32", [2, 2], f32(0.1, 0.0, 0.0, 0.1))],
                       metadata={"format": "pt", "autor": "lora-labs"})


def proyecto_comprometido():
    m = {}
    m["modelos/detector-grietas.bin"] = pickle_con_llamada("taller_ficticio", "encender_horno", "hola desde el pickle")
    m["modelos/horno.pkl"] = pickle_global_protocolo2("forja_falsa", "abrir_puerta", "hola")
    m["modelos/ofuscado.pkl"] = pickle_ofuscado()
    m["modelos/modelo.pt"] = zip_pytorch([("modelo/data.pkl", pickle_con_llamada("taller_ficticio", "soplar_fuelle", "hola")),
                                          ("modelo/version", b"3\n")])
    m["modelos/vision.safetensors"] = pickle_con_llamada("taller_ficticio", "templar", "hola")  # un pickle con otro nombre
    m["modelos/pesos.safetensors"] = safetensors([("capa.peso", "F32", [2], f32(1.0, 2.0))],
                                                 extra=pickle_con_llamada("taller_ficticio", "forjar", "hola"))  # políglota
    m["modelos/capas.safetensors"] = safetensors([("a", "F32", [2], f32(1, 2)), ("b", "F32", [2], f32(3, 4))],
                                                 offsets=[(0, 8), (4, 12)])  # los dos tensores comparten 4 bytes
    m["modelos/gigante.safetensors"] = safetensors([("a", "F32", [1], f32(1))], n_falso=2 ** 40)  # 1 TB de cabecera
    m["modelos/incoherente.safetensors"] = safetensors([("a", "F32", [1000], f32(1, 2))])  # dice 1000 floats y trae 2
    # El adapter de lora-labs, modificado después de publicarse: el AI-BOM conserva la huella del original.
    m["modelos/adaptador-estilo.safetensors"] = safetensors(
        [("lora.a", "F32", [2, 2], f32(0.01, 0.02, 0.03, 0.04)), ("lora.b", "F32", [2, 2], f32(0.9, 0.0, 0.0, 0.9))],
        metadata={"format": "pt", "autor": "lora-labs"})
    m["datos/espejo-comunidad.csv"] = ("pieza,dureza,grieta\n" + "".join(
        "k-%03d,%d,%d\n" % (i, 55 + i % 7, 0) for i in range(1, 9)) + "kintsugi-001,52,0\n").encode("utf-8")
    comps = []
    for ruta, datos in m.items():
        tipo = "data" if ruta.startswith("datos/") else "machine-learning-model"
        nombre = ruta.rsplit("/", 1)[-1].split(".")[0]
        huella = None
        if ruta.endswith("adaptador-estilo.safetensors"):
            huella = hashlib.sha256(adaptador_original()).hexdigest()
        comps.append(componente(tipo, nombre, "1.0", ruta, datos, huella=huella))
    m["bom.json"] = _json(bom("comprometido", comps))
    # Llegó después de generar el AI-BOM: su contenido es legítimo, pero nadie lo ha declarado.
    m["modelos/extra.pkl"] = pickle_ordered_dict([("umbral", f(0.7))])
    m["requirements.txt"] = b"numpy>=2.0\nsafetensors==0.6.2\n"
    m["requirements-asistente.txt"] = b"# Sugerido por el asistente de codigo\nnumpy==2.3.4\nforja-tensor-tools==1.0.0\n"
    m["requirements-reciente.txt"] = b"forja-metricas-pro==0.0.1\n"
    m["requirements-espejo.txt"] = b"--extra-index-url https://espejo.forja-comunidad.example/simple\nforja-metrics==1.1.0\n"
    m["requirements-version.txt"] = b"safetensors==9.9.9\n"
    m["Dockerfile"] = ("FROM python:3.12-slim\n"
                       "COPY requirements.txt .\n"
                       "RUN pip install -r requirements.txt\n"
                       "COPY modelos/ /modelos/\n"
                       "EXPOSE 8080\n"
                       "CMD [\"serve\", \"--host\", \"0.0.0.0\", \"--port\", \"8080\"]\n").encode("utf-8")
    m["Dockerfile.secreto"] = ("FROM python:3.13-slim\n"
                               "RUN useradd --uid 10001 forja\n"
                               "ENV REGISTRY_TOKEN=tok_registro_forja_7c1e\n"
                               "USER forja\n").encode("utf-8")
    m["Dockerfile.sin-version"] = ("FROM registro.forja.example:5000/forja/base\n"
                                   "USER forja\n").encode("utf-8")
    m["Dockerfile.arg"] = ("FROM python:3.13-slim\n"
                           "ARG HF_TOKEN\n"
                           "RUN descargar-modelo --token \"$HF_TOKEN\" detector-grietas\n"
                           "USER 10001\n").encode("utf-8")
    m["Dockerfile.vuelta-a-root"] = ("FROM python:3.13-slim\n"
                                     "RUN useradd --uid 10001 forja\n"
                                     "USER forja\n"
                                     "RUN preparar-modelos\n"
                                     "USER root\n"
                                     "CMD [\"python\", \"-m\", \"servir\"]\n").encode("utf-8")
    return m


def todos():
    """{"taller-bueno/ruta": bytes, "taller-comprometido/ruta": bytes}."""
    out = {}
    for nombre, gen in (("taller-bueno", proyecto_bueno), ("taller-comprometido", proyecto_comprometido)):
        for ruta, datos in gen().items():
            out["%s/%s" % (nombre, ruta)] = datos
    return out


def generar(destino):
    destino = Path(destino)
    ficheros = todos()
    for ruta, datos in ficheros.items():
        p = destino / ruta
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes(datos)
    return ficheros


if __name__ == "__main__":
    destino = Path(sys.argv[1]) if len(sys.argv) > 1 else AQUI / "artefactos"
    n = len(generar(destino))
    print("%d ficheros en %s (taller-bueno y taller-comprometido)" % (n, destino))
