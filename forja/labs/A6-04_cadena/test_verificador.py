"""Tests del laboratorio A6-04. Sin red, sin Docker y sin cargar nunca un pickle.

Los artefactos salen de generar_artefactos.py (inofensivos). Cada test construye los bytes que
necesita; ninguno escribe fuera de una carpeta temporal.
"""

import ast
import datetime
import hashlib
import json
import struct
import sys
import tempfile
import unittest
from pathlib import Path

import generar_artefactos as g
from verificador import (PERMITIDOS_PICKLE, cargar_indice, imports_pickle, rechazados, revisar_dockerfile,
                         revisar_pickle, revisar_requirements, validar_safetensors, verificar_bom, verificar_proyecto)

AQUI = Path(__file__).resolve().parent
HOY = datetime.date(2026, 11, 10)
INDICE = cargar_indice(AQUI / "indice.json")
BUENO = g.proyecto_bueno()
MALO = g.proyecto_comprometido()


def st(cabecera, buffer=b""):
    """Un .safetensors con la cabecera (dict) tal cual, sin calcular nada."""
    j = json.dumps(cabecera).encode("utf-8")
    return struct.pack("<Q", len(j)) + j + buffer


def artefactos(proyecto):
    return {r: d for r, d in proyecto.items() if r.split("/")[0] in ("modelos", "datos")}


def texto(proyecto, ruta):
    return proyecto[ruta].decode("utf-8")


# ─────────────────────────────── pickle ───────────────────────────────

class TestImportsPickle(unittest.TestCase):
    def test_stack_global(self):
        self.assertEqual(imports_pickle(BUENO["modelos/tokenizador.pkl"]), ["collections.OrderedDict"])
        self.assertEqual(imports_pickle(MALO["modelos/detector-grietas.bin"]), ["taller_ficticio.encender_horno"])

    def test_global_e_inst_sin_repetir(self):
        self.assertEqual(imports_pickle(MALO["modelos/horno.pkl"]), ["forja_falsa.abrir_puerta"])
        inst = b"(S'hola'\nitaller_ficticio\nencender\n."
        self.assertEqual(imports_pickle(inst), ["taller_ficticio.encender"])
        dos = b"cforja_falsa\nabrir\n(tRcdatetime\ndate\n(tRcforja_falsa\nabrir\n(tR."
        self.assertEqual(imports_pickle(dos), ["forja_falsa.abrir", "datetime.date"])

    def test_memoria(self):
        # BINGET recupera las cadenas guardadas con MEMOIZE; el señuelo collections/OrderedDict no engaña.
        self.assertEqual(imports_pickle(MALO["modelos/ofuscado.pkl"]), ["taller_ficticio.avivar_fuego"])
        # PUT y GET (protocolo 0) hacen lo mismo con índices explícitos.
        put_get = b"Vtaller_ficticio\np7\n0Vtemplar\np3\n0Vcollections\nVOrderedDict\ng7\ng3\n\x93."
        self.assertEqual(imports_pickle(put_get), ["taller_ficticio.templar"])

    def test_desconocido(self):
        self.assertEqual(imports_pickle(b"\x80\x04\x93."), ["?"])
        # MEMOIZE guardó un entero (no una cadena): BINGET no apila nada y solo queda una cadena.
        self.assertEqual(imports_pickle(b"\x80\x04K\x01\x94h\x00\x8c\x01a\x93."), ["?"])
        self.assertEqual(imports_pickle(BUENO["modelos/vocabulario.pkl"]), [])

    def test_mal_formado_lanza(self):
        for datos in (b"\x80\x04\x8c\x09ab", b"\xff", b""):
            with self.assertRaises(ValueError, msg=datos):
                imports_pickle(datos)


class TestRevisarPickle(unittest.TestCase):
    def test_estricto(self):
        self.assertEqual(set(revisar_pickle(BUENO["modelos/tokenizador.pkl"])),
                         {("opcode-peligroso", "STACK_GLOBAL"), ("opcode-peligroso", "REDUCE")})
        self.assertEqual(set(revisar_pickle(MALO["modelos/horno.pkl"], None)),
                         {("opcode-peligroso", "GLOBAL"), ("opcode-peligroso", "REDUCE")})
        self.assertEqual(revisar_pickle(BUENO["modelos/vocabulario.pkl"]), [])
        h = revisar_pickle(b"(S'x'\nitaller_ficticio\nencender\n.")
        self.assertEqual(set(h), {("opcode-peligroso", "INST")})
        self.assertEqual(len(h), len(set(h)), "sin repetir")

    def test_con_lista(self):
        self.assertEqual(revisar_pickle(BUENO["modelos/tokenizador.pkl"], PERMITIDOS_PICKLE), [])
        self.assertEqual(revisar_pickle(MALO["modelos/detector-grietas.bin"], PERMITIDOS_PICKLE),
                         [("import-no-permitido", "taller_ficticio.encender_horno")])
        self.assertEqual(revisar_pickle(MALO["modelos/ofuscado.pkl"], PERMITIDOS_PICKLE),
                         [("import-no-permitido", "taller_ficticio.avivar_fuego")])
        self.assertEqual(revisar_pickle(BUENO["modelos/tokenizador.pkl"], set()),
                         [("import-no-permitido", "collections.OrderedDict")])
        self.assertEqual(revisar_pickle(b"\x80\x04\x93.", PERMITIDOS_PICKLE), [("import-no-permitido", "?")])

    def test_ilegible(self):
        for datos in (b"", b"\xff", b"\x80\x04\x8c\x09ab", b"\x80\x04K\x01"):
            self.assertEqual(revisar_pickle(datos), [("pickle-ilegible", "")], datos)
            self.assertEqual(revisar_pickle(datos, PERMITIDOS_PICKLE), [("pickle-ilegible", "")], datos)

    def test_nunca_se_carga(self):
        arbol = ast.parse((AQUI / "verificador.py").read_text(encoding="utf-8"))
        prohibidos = {"pickle", "_pickle", "dill", "joblib", "torch", "cloudpickle", "marshal", "importlib"}
        for nodo in ast.walk(arbol):
            if isinstance(nodo, ast.Import):
                usados = {a.name.split(".")[0] for a in nodo.names} & prohibidos
            elif isinstance(nodo, ast.ImportFrom):
                usados = {(nodo.module or "").split(".")[0]} & prohibidos
            elif isinstance(nodo, ast.Name):
                usados = {nodo.id} & {"__import__", "eval", "exec"}
            else:
                continue
            self.assertFalse(usados, "verificador.py no puede usar %s: leer un pickle no es cargarlo" % usados)
        for r in ("modelos/detector-grietas.bin", "modelos/horno.pkl", "modelos/ofuscado.pkl"):
            self.assertTrue(revisar_pickle(MALO[r], PERMITIDOS_PICKLE), r)
        self.assertNotIn("taller_ficticio", sys.modules)
        self.assertNotIn("forja_falsa", sys.modules)


# ─────────────────────────────── safetensors ───────────────────────────────

class TestSafetensors(unittest.TestCase):
    def test_buenos(self):
        for r in ("modelos/clasificador-acero.safetensors", "modelos/embeddings.safetensors", "modelos/adaptador-estilo.safetensors"):
            self.assertEqual(validar_safetensors(BUENO[r]), [], r)
        # Los tensores pueden venir en cualquier orden en la cabecera: lo que cuenta son los offsets.
        desordenado = st({"b": {"dtype": "U8", "shape": [2], "data_offsets": [2, 4]},
                          "a": {"dtype": "U8", "shape": [2], "data_offsets": [0, 2]}}, b"abcd")
        self.assertEqual(validar_safetensors(desordenado), [])
        # F4 ocupa medio byte: 4 elementos son 2 bytes.
        self.assertEqual(validar_safetensors(st({"x": {"dtype": "F4", "shape": [2, 2], "data_offsets": [0, 2]}}, b"\x00\x00")), [])

    def test_cabecera(self):
        self.assertEqual(validar_safetensors(b""), [("cabecera-corta", "")])
        self.assertEqual(validar_safetensors(b"\x07" * 7), [("cabecera-corta", "")])
        self.assertEqual(validar_safetensors(MALO["modelos/gigante.safetensors"]), [("longitud-cabecera", str(2 ** 40))])
        self.assertEqual(validar_safetensors(struct.pack("<Q", 100) + b"{}"), [("longitud-cabecera", "100")])
        n = struct.unpack("<Q", MALO["modelos/vision.safetensors"][:8])[0]
        self.assertEqual(validar_safetensors(MALO["modelos/vision.safetensors"]), [("longitud-cabecera", str(n))])
        for cab in (b"", b"[1]", b" {}", b"{\xff}", b"{abc", b"{}{}"):
            datos = struct.pack("<Q", len(cab)) + cab
            self.assertEqual(validar_safetensors(datos), [("cabecera-no-json", "")], cab)
        self.assertEqual(validar_safetensors(struct.pack("<Q", 8) + b"{}      "), [], "relleno con espacios")

    def test_tensores_mal_formados(self):
        cab = {
            "__metadata__": {"autor": "forja", "version": 3},
            "sin_dict": [1, 2],
            "dtype_no_texto": {"dtype": 32, "shape": [1], "data_offsets": [0, 4]},
            "shape_negativa": {"dtype": "F32", "shape": [-1], "data_offsets": [0, 4]},
            "shape_bool": {"dtype": "F32", "shape": [True], "data_offsets": [0, 4]},
            "tres_offsets": {"dtype": "F32", "shape": [1], "data_offsets": [0, 4, 8]},
            "al_reves": {"dtype": "F32", "shape": [1], "data_offsets": [4, 0]},
            "sin_offsets": {"dtype": "F32", "shape": [1]},
            "raro": {"dtype": "F128", "shape": [1], "data_offsets": [0, 16]},
        }
        esperado = {("metadatos-no-texto", ""), ("tensor-mal-formado", "sin_dict"), ("tensor-mal-formado", "dtype_no_texto"),
                    ("tensor-mal-formado", "shape_negativa"), ("tensor-mal-formado", "shape_bool"),
                    ("tensor-mal-formado", "tres_offsets"), ("tensor-mal-formado", "al_reves"),
                    ("tensor-mal-formado", "sin_offsets"), ("dtype-desconocido", "raro")}
        self.assertEqual(set(validar_safetensors(st(cab))), esperado)

    def test_tamano(self):
        self.assertEqual(validar_safetensors(MALO["modelos/incoherente.safetensors"]), [("tamano-incoherente", "a")])
        self.assertEqual(validar_safetensors(st({"x": {"dtype": "F4", "shape": [3], "data_offsets": [0, 2]}}, b"\x00\x00")),
                         [("tamano-incoherente", "x")], "12 bits no son un número entero de bytes")
        self.assertEqual(validar_safetensors(st({"e": {"dtype": "F32", "shape": [], "data_offsets": [0, 4]}}, b"\x00" * 4)), [],
                         "un escalar (shape []) tiene 1 elemento")

    def test_offsets(self):
        self.assertEqual(set(validar_safetensors(MALO["modelos/capas.safetensors"])), {("solape", "b"), ("bytes-sobrantes", "4")})
        extra = len(g.pickle_con_llamada("taller_ficticio", "forjar", "hola"))
        self.assertEqual(validar_safetensors(MALO["modelos/pesos.safetensors"]), [("bytes-sobrantes", str(extra))])
        self.assertEqual(validar_safetensors(st({"a": {"dtype": "F32", "shape": [2], "data_offsets": [4, 12]}}, b"\x00" * 12)),
                         [("hueco", "a")])
        self.assertEqual(validar_safetensors(st({"a": {"dtype": "F32", "shape": [4], "data_offsets": [0, 16]}}, b"\x00" * 8)),
                         [("fuera-del-buffer", "8")])
        # Un tensor con tamaño incoherente también ocupa sus offsets.
        self.assertEqual(set(validar_safetensors(st({"a": {"dtype": "F32", "shape": [1], "data_offsets": [0, 8]},
                                                     "b": {"dtype": "F32", "shape": [1], "data_offsets": [8, 12]}}, b"\x00" * 12))),
                         {("tamano-incoherente", "a")})


# ─────────────────────────────── AI-BOM ───────────────────────────────

class TestBom(unittest.TestCase):
    def bom(self, proyecto):
        return json.loads(proyecto["bom.json"])

    def test_bueno(self):
        b = self.bom(BUENO)
        self.assertEqual(b["specVersion"], "1.7")
        self.assertTrue(any(h["content"].isupper() for c in b["components"] for h in c["hashes"]), "una huella en mayúsculas")
        self.assertEqual(verificar_bom(b, artefactos(BUENO)), [])

    def test_comprometido(self):
        self.assertEqual(set(verificar_bom(self.bom(MALO), artefactos(MALO))),
                         {("hash-distinto", "modelos/adaptador-estilo.safetensors"), ("fichero-no-declarado", "modelos/extra.pkl")})

    def test_reglas(self):
        for cambio in ({"bomFormat": "SPDX"}, {"specVersion": "1.4"}, {"specVersion": 1.6}):
            self.assertEqual(verificar_bom(dict(self.bom(BUENO), **cambio), artefactos(BUENO)), [("bom-no-valido", "")], cambio)
        datos = {"modelos/a.bin": b"a", "modelos/b.bin": b"b"}
        sha = lambda x: hashlib.sha256(x).hexdigest()
        prop = lambda r: [{"name": "otra", "value": "x"}, {"name": "ai-ronin:fichero", "value": r}]
        bom = {"bomFormat": "CycloneDX", "specVersion": "1.6", "components": [
            {"type": "library", "name": "numpy", "version": "2.3.4"},  # no es un artefacto: no se mira
            {"type": "machine-learning-model", "name": "sin-ruta", "hashes": [{"alg": "SHA-256", "content": sha(b"a")}]},
            {"type": "machine-learning-model", "name": "a", "properties": prop("modelos/a.bin"),
             "hashes": [{"alg": "SHA-1", "content": hashlib.sha1(b"a").hexdigest()}]},
            {"type": "file", "name": "b", "properties": prop("modelos/b.bin"),
             "hashes": [{"alg": "SHA-512", "content": "0" * 128}, {"alg": "SHA-256", "content": sha(b"b")}]},
            {"type": "data", "name": "c", "properties": prop("datos/c.csv"), "hashes": [{"alg": "SHA-256", "content": sha(b"c")}]},
        ]}
        self.assertEqual(set(verificar_bom(bom, datos)),
                         {("componente-sin-fichero", "sin-ruta"), ("sin-hash", "modelos/a.bin"), ("fichero-ausente", "datos/c.csv")})
        self.assertEqual(verificar_bom({"bomFormat": "CycloneDX", "specVersion": "1.5"}, {"modelos/x.pkl": b""}),
                         [("fichero-no-declarado", "modelos/x.pkl")])


# ─────────────────────────────── requirements ───────────────────────────────

class TestRequirements(unittest.TestCase):
    def test_buenos(self):
        for r in ("requirements.txt", "requirements-dev.txt"):
            self.assertEqual(revisar_requirements(texto(BUENO, r), INDICE, HOY), [], r)
        self.assertEqual(revisar_requirements((AQUI / "requirements.txt").read_text(encoding="utf-8"), INDICE, HOY), [],
                         "el requirements.txt de este laboratorio")

    def test_comprometidos(self):
        esperado = {
            "requirements.txt": [("sin-fijar", "numpy")],
            "requirements-asistente.txt": [("no-existe", "forja-tensor-tools")],
            "requirements-reciente.txt": [("paquete-reciente", "forja-metricas-pro==0.0.1")],
            "requirements-espejo.txt": [("opcion-no-permitida", "--extra-index-url")],
            "requirements-version.txt": [("version-inexistente", "safetensors==9.9.9")],
        }
        for r, h in esperado.items():
            self.assertEqual(revisar_requirements(texto(MALO, r), INDICE, HOY), h, r)

    def test_especificadores(self):
        for linea in ("numpy", "numpy>=2.3", "numpy~=2.3", "numpy==2.*", "numpy==2.3.4,!=2.3.3", "numpy===2.3.4", "numpy==",
                      "numpy @ https://espejo.example/numpy.whl", "NumPy <3"):
            self.assertEqual(revisar_requirements(linea, INDICE, HOY), [("sin-fijar", "numpy")], linea)
        self.assertEqual(revisar_requirements("-r otros.txt\n--index-url https://x.example\n", INDICE, HOY),
                         [("opcion-no-permitida", "-r"), ("opcion-no-permitida", "--index-url")])
        self.assertEqual(revisar_requirements("# solo un comentario\n   \n\t# otro\n", INDICE, HOY), [])
        self.assertEqual(revisar_requirements("!!! roto  # comentario", INDICE, HOY), [("linea-no-valida", "!!! roto")])
        self.assertEqual(revisar_requirements("forja.metricas_PRO == 0.0.1", INDICE, HOY),
                         [("paquete-reciente", "forja-metricas-pro==0.0.1")], "nombre normalizado y espacios")

    def test_antiguedad(self):
        indice = {"paquete": {"1.0": "2026-10-11", "1.1": "2026-10-12"}}
        self.assertEqual(revisar_requirements("paquete==1.0", indice, HOY), [], "30 días justos ya valen")
        self.assertEqual(revisar_requirements("paquete==1.1", indice, HOY), [("paquete-reciente", "paquete==1.1")])
        self.assertEqual(revisar_requirements("paquete==1.1", indice, HOY, dias_minimos=7), [])
        self.assertEqual(revisar_requirements("forja-metricas-pro==0.0.1", INDICE, HOY, dias_minimos=3), [])


# ─────────────────────────────── Dockerfile ───────────────────────────────

class TestDockerfile(unittest.TestCase):
    def test_buenos(self):
        for r in ("Dockerfile", "Dockerfile.multietapa"):
            self.assertEqual(revisar_dockerfile(texto(BUENO, r)), [], r)
        self.assertEqual(revisar_dockerfile((AQUI / "Dockerfile").read_text(encoding="utf-8")), [],
                         "el Dockerfile de este laboratorio")

    def test_comprometidos(self):
        esperado = {
            "Dockerfile": {("usuario-root", "")},
            "Dockerfile.secreto": {("secreto-en-env", "REGISTRY_TOKEN")},
            "Dockerfile.sin-version": {("imagen-sin-version", "registro.forja.example:5000/forja/base")},
            "Dockerfile.arg": {("secreto-en-arg", "HF_TOKEN")},
            "Dockerfile.vuelta-a-root": {("usuario-root", "root")},
        }
        for r, h in esperado.items():
            self.assertEqual(set(revisar_dockerfile(texto(MALO, r))), h, r)

    def test_imagenes(self):
        casos = {
            "FROM python": [("imagen-sin-version", "python")],
            "FROM python:latest": [("imagen-sin-version", "python:latest")],
            "from localhost:5000/img": [("imagen-sin-version", "localhost:5000/img")],
            "FROM python@sha256:" + "a" * 64: [],
            "FROM scratch": [],
            "FROM --platform=$BUILDPLATFORM python:3.13-slim AS Base\nFROM base": [],
        }
        for df, h in casos.items():
            self.assertEqual(revisar_dockerfile(df + "\nUSER forja"), h, df)

    def test_secretos(self):
        df = ("FROM python:3.13-slim\n"
              "# ENV COMENTADO_TOKEN=x\n"
              "ENV A=1 \\\n    API_KEY=\"una clave\" MONKEY=1\n"
              "ENV DB_PASSWORD secreto con espacios\n"
              "ARG PUBLIC_KEY AWS_SECRET_ACCESS_KEY=\n"
              "arg Auth_Header\n"
              "ENV KEYBOARD=es TOKENIZERS_PARALLELISM=false\n"
              "USER forja\n")
        self.assertEqual(set(revisar_dockerfile(df)),
                         {("secreto-en-env", "API_KEY"), ("secreto-en-env", "DB_PASSWORD"),
                          ("secreto-en-arg", "AWS_SECRET_ACCESS_KEY"), ("secreto-en-arg", "Auth_Header")})

    def test_usuario(self):
        self.assertEqual(revisar_dockerfile("FROM python:3.13-slim\nUSER root:root"), [("usuario-root", "root")])
        self.assertEqual(revisar_dockerfile("FROM python:3.13-slim\nUSER 0"), [("usuario-root", "0")])
        self.assertEqual(revisar_dockerfile("FROM python:3.13-slim AS b\nUSER forja\nFROM b\nRUN x"), [("usuario-root", "")],
                         "cada FROM empieza una etapa sin USER")
        self.assertEqual(revisar_dockerfile("FROM python:3.13-slim\n# USER forja\n"), [("usuario-root", "")])
        self.assertEqual(revisar_dockerfile("FROM python:3.13-slim\nUSER forja:forja"), [])


# ─────────────────────────────── El proyecto entero ───────────────────────────────

class TestProyecto(unittest.TestCase):
    def test_extremo_a_extremo(self):
        with tempfile.TemporaryDirectory() as tmp:
            g.generar(tmp)
            bueno = verificar_proyecto(Path(tmp) / "taller-bueno", indice=INDICE, hoy=HOY)
            self.assertEqual(bueno, [])
            malo = verificar_proyecto(Path(tmp) / "taller-comprometido", indice=INDICE, hoy=HOY)
            detectables = sorted(r for r in MALO if r not in ("bom.json", "datos/espejo-comunidad.csv"))
            self.assertEqual(rechazados(malo), detectables)
            self.assertNotIn("datos/espejo-comunidad.csv", rechazados(malo), "los datos envenenados tienen la huella correcta")
            estricto = verificar_proyecto(Path(tmp) / "taller-bueno", ["pickle-estricto"], INDICE, HOY)
            self.assertEqual(rechazados(estricto), ["modelos/clasificador.pt", "modelos/tokenizador.pkl"])


if __name__ == "__main__":
    unittest.main()
