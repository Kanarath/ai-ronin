"""Laboratorio A2-06 · El segundo filtro: reordenar lo que recupera la biblioteca.

La búsqueda híbrida de A2-04 compara la pregunta y cada fragmento POR SEPARADO: un vector contra
otro vector, unas palabras contra otras. Un reordenador (reranker) lee la pregunta y el fragmento
JUNTOS y les da una puntuación. Es más caro, así que solo se aplica a unos pocos candidatos de la
primera etapa: recuperar 10, reordenar, quedarse con 3.

Aquí hay dos reordenadores. Un cross-encoder multilingüe pequeño (mMiniLMv2, 118 M de parámetros,
cuantizado a int8: 118 MB, en CPU con onnxruntime) y llama3.2:1b usado como puntuador. Y hay
documentos de terceros escritos para posicionarse: relleno de palabras clave, preguntas copiadas,
respuestas falsas bien redactadas y una nota dirigida al propio puntuador.

Tú implementas las piezas marcadas con «Tu turno»: la reordenación, la tubería de dos etapas y las
métricas (recall@k, rango recíproco, nDCG@k, percentil de latencia) y el lector de la puntuación
del LLM. Claude ha escrito el resto (la Biblioteca de primera etapa, los dos reordenadores, la
aplicación FastAPI y bateria.py).

Todo es ficticio y local. Tests (sin red, con modelos simulados y Qdrant en memoria):
    python -m unittest -v test_reranking
"""

import asyncio
import hashlib
import hmac
import json
import math
import os
import re
import time
import unicodedata
from contextlib import asynccontextmanager
from dataclasses import dataclass
from pathlib import Path

import httpx2
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
from qdrant_client import QdrantClient, models

AQUI = Path(__file__).resolve().parent
DOCS_A2_04 = AQUI.parent / "A2-04_rag" / "documentos.json"   # el escenario de A2-04, solo lectura
COLECCION = "biblioteca"
CLAVE_LAB = "clave-de-laboratorio-no-usar-en-produccion"     # la misma de A2-04
REORDENADORES = ("ninguno", "cross-encoder", "llm")
# Cross-encoder multilingüe (Apache-2.0), entrenado con mMARCO (MS MARCO traducido a 14 idiomas,
# también al español). Se fija la revisión: si alguien cambia el modelo en Hugging Face, no te afecta.
CE_REPO = "cross-encoder/mmarco-mMiniLMv2-L12-H384-v1"
CE_REVISION = "1427fd652930e4ba29e8149678df786c240d8825"
CE_FICHERO = "onnx/model_quint8_avx2.onnx"                     # int8 para CPU con AVX2 (118 MB)


# ─────────────────────────────── Tu turno ───────────────────────────────

def reordenar(puntuaciones, k):
    """Índices de los k candidatos con mayor puntuación, de mayor a menor. En caso de empate va
    primero el que tenía un índice menor (el que la primera etapa puso antes). Si hay menos de k
    candidatos, devuelve todos. ValueError si k < 1.
    Ejemplo: reordenar([0.2, 0.9, 0.5], 2) → [1, 2]."""
    raise NotImplementedError("Tu turno: implementa reordenar")


async def recuperar_reordenado(cliente, biblioteca, reordenador, pregunta, k=3, candidatos=10, defensas=()):
    """Tubería de dos etapas. Devuelve una lista de k fragmentos (dicts).
      1. Pide a la primera etapa `candidatos` fragmentos:
             frags = await biblioteca.recuperar(cliente, pregunta, defensas, k=candidatos)
         Si no hay ninguno, devuelve [].
      2. Si reordenador es None, devuelve los k primeros, tal cual (sin la clave "puntuacion").
      3. Si no, puntos = await reordenador(pregunta, [f["texto"] for f in frags]). ValueError si
         no devuelve una puntuación por fragmento.
      4. Devuelve, en el orden de reordenar(puntos, k), COPIAS de los fragmentos con una clave más,
         "puntuacion" (float). No modifiques los dicts de la biblioteca.
    """
    raise NotImplementedError("Tu turno: implementa recuperar_reordenado")


def recall_en_k(recuperados, relevancia, k, umbral=1):
    """Fracción de los documentos relevantes que aparecen entre los k primeros recuperados (los
    duplicados cuentan una vez). `relevancia` es un dict {doc: grado}; un documento es relevante si
    su grado es >= umbral. ValueError si no hay ningún relevante."""
    raise NotImplementedError("Tu turno: implementa recall_en_k")


def rango_reciproco(recuperados, relevancia, umbral=1):
    """1 / posición del PRIMER documento relevante (grado >= umbral) en recuperados, contando la
    posición desde 1. Si no aparece ninguno, 0.0. La media de este valor sobre muchas preguntas es
    el MRR (Mean Reciprocal Rank)."""
    raise NotImplementedError("Tu turno: implementa rango_reciproco")


def ndcg_en_k(recuperados, relevancia, k):
    """nDCG@k con relevancia graduada (Järvelin y Kekäläinen, 2002; ganancia exponencial):
        DCG@k  = suma, para cada posición i = 1..k de recuperados, de (2**grado - 1) / log2(i + 1)
                 El grado de un documento es relevancia.get(doc, 0). Si un documento ya apareció
                 antes en la lista, en su segunda aparición su ganancia es 0.
        IDCG@k = el DCG@k de la mejor lista posible: los grados > 0 de relevancia ordenados de
                 mayor a menor.
        nDCG@k = DCG@k / IDCG@k, un número entre 0 y 1.
    ValueError si k < 1 o si ningún grado es > 0 (IDCG sería 0)."""
    raise NotImplementedError("Tu turno: implementa ndcg_en_k")


def percentil(valores, p):
    """Percentil p (0 < p <= 100) por el método del rango más cercano: ordena los valores y devuelve
    el de la posición ceil(p / 100 * n), contando desde 1. Así, percentil(v, 50) es la mediana
    «baja» y percentil(v, 100), el máximo. ValueError si no hay valores o p no está en (0, 100]."""
    raise NotImplementedError("Tu turno: implementa percentil")


def puntuacion_llm(texto):
    """Lee la puntuación que ha escrito el LLM puntuador. Es el PRIMER número del texto: un entero
    o un decimal con punto o coma ("7", "7.5", "7,5"); un signo menos justo delante lo hace
    negativo. El resultado se recorta al intervalo [0, 10] (un -3 vale 0.0; un 15, 10.0) y se
    devuelve como float. Si el texto no tiene ningún número, 0.0.
    Ejemplos: "Puntuación: 8" → 8.0 · "8/10" → 8.0 · "No es relevante." → 0.0
    """
    raise NotImplementedError("Tu turno: implementa puntuacion_llm")


# ──────────────────── Primera etapa, reordenadores y aplicación (Claude) ────────────────────
# Copias de Claude de piezas que escribiste en A2-04, para no depender de ese laboratorio.

PALABRAS_VACIAS = set("""a al algo como con de del el en es esta este hay la las lo los mi mis no o
para pero por que se si sin su sus te tu un una uno y ya""".split())


def normalizar(texto, espacios=True):
    t = "".join(c for c in unicodedata.normalize("NFD", texto.lower()) if not unicodedata.combining(c))
    return re.sub(r"[^a-z0-9]+", " " if espacios else "", t).strip()


def tokens(texto):
    return [p for p in normalizar(texto).split() if p not in PALABRAS_VACIAS]


def trocear(texto, palabras=40, solape=10):
    w, out, i = texto.split(), [], 0
    while w:
        out.append(" ".join(w[i:i + palabras]))
        if i + palabras >= len(w):
            break
        i += palabras - solape
    return out


def bm25(consulta, documentos, k1=1.5, b=0.75):
    if not documentos:
        return []
    n, avgdl = len(documentos), sum(map(len, documentos)) / len(documentos)
    out = [0.0] * n
    if avgdl == 0:
        return out
    for q in set(consulta):
        n_q = sum(1 for d in documentos if q in d)
        idf = math.log((n - n_q + 0.5) / (n_q + 0.5) + 1)
        for i, d in enumerate(documentos):
            f = d.count(q)
            out[i] += idf * f * (k1 + 1) / (f + k1 * (1 - b + b * len(d) / avgdl)) if f else 0.0
    return out


def fusion_rrf(listas, k=60):
    puntos = {}
    for lista in listas:
        for pos, x in enumerate(lista, 1):
            puntos[x] = puntos.get(x, 0.0) + 1.0 / (k + pos)
    return sorted(puntos, key=lambda x: -puntos[x])


def firmar(doc, clave):
    canonico = "\n".join([doc["id"], doc["origen"], doc["acceso"], doc["texto"]])
    return hmac.new(clave.encode("utf-8"), canonico.encode("utf-8"), hashlib.sha256).hexdigest()


def verificar_firma(doc, clave):
    f = doc.get("firma")
    return isinstance(f, str) and hmac.compare_digest(firmar(doc, clave), f)


def docs_unicos(frags):
    """Ids de documento en orden de aparición, sin repetir (las métricas se miden por documento)."""
    return list(dict.fromkeys(f["doc"] for f in frags))


@dataclass(frozen=True)
class Ajustes:
    ollama_url: str = "http://127.0.0.1:11434"
    modelo: str = "llama3.2:1b"
    modelo_embed: str = "embeddinggemma"
    timeout: float = 120.0
    k: int = 3
    candidatos: int = 10

    @staticmethod
    def desde_entorno():
        e, d = os.environ.get, Ajustes()
        return Ajustes(e("OLLAMA_URL", d.ollama_url), e("MODELO", d.modelo), e("MODELO_EMBED", d.modelo_embed),
                       float(e("TIMEOUT", d.timeout)), int(e("K", d.k)), int(e("CANDIDATOS", d.candidatos)))


def cargar_documentos(con_atacante=True):
    """Los documentos de A2-04, la ampliación de corpus.json y, si se pide, los de terceros (ataques.json)."""
    docs = json.loads(DOCS_A2_04.read_text(encoding="utf-8"))["documentos"]
    docs = docs + json.loads((AQUI / "corpus.json").read_text(encoding="utf-8"))["documentos"]
    if con_atacante:
        docs = docs + json.loads((AQUI / "ataques.json").read_text(encoding="utf-8"))["documentos_atacante"]
    return docs


async def embeber(cliente, ajustes, textos):
    r = await cliente.post("/api/embed", json={"model": ajustes.modelo_embed, "input": list(textos)})
    r.raise_for_status()
    vectores = r.json().get("embeddings", [])
    if len(vectores) != len(textos):
        raise ValueError("Ollama ha devuelto %d vectores para %d textos" % (len(vectores), len(textos)))
    return vectores


class Biblioteca:
    """La primera etapa: la búsqueda híbrida de A2-04 (Qdrant + BM25, fusión RRF). Con la defensa
    "procedencia", solo recupera fragmentos de documentos con firma válida (filtrando DENTRO de la
    búsqueda, como en A2-04). Aquí no hay ACL: se mide la calidad de la búsqueda, como un empleado."""

    def __init__(self, ajustes, qdrant=None):
        self.ajustes = ajustes
        self.qdrant = qdrant or QdrantClient(":memory:")
        self.fragmentos = []

    async def ingerir(self, cliente, documentos):
        frags = []
        for doc in documentos:
            ok = verificar_firma(doc, CLAVE_LAB)
            for n, texto in enumerate(trocear(doc["texto"])):
                frags.append({"doc": doc["id"], "n": n, "texto": texto, "origen": doc["origen"], "firma_ok": ok})
        vectores = await embeber(cliente, self.ajustes, [f["texto"] for f in frags])
        if self.qdrant.collection_exists(COLECCION):
            self.qdrant.delete_collection(COLECCION)
        self.qdrant.create_collection(COLECCION, vectors_config=models.VectorParams(size=len(vectores[0]), distance=models.Distance.COSINE))
        self.qdrant.upsert(COLECCION, points=[models.PointStruct(id=i, vector=v, payload=f) for i, (f, v) in enumerate(zip(frags, vectores))])
        self.fragmentos = frags
        return len(frags)

    async def recuperar(self, cliente, pregunta, defensas=(), k=None):
        k = k or self.ajustes.k
        solo_firmados = "procedencia" in defensas
        filtro = models.Filter(must=[models.FieldCondition(key="firma_ok", match=models.MatchValue(value=True))]) if solo_firmados else None
        vector = (await embeber(cliente, self.ajustes, [pregunta]))[0]
        por_vector = [p.id for p in self.qdrant.query_points(COLECCION, query=vector, limit=k, with_payload=False, query_filter=filtro).points]
        ids = [i for i, f in enumerate(self.fragmentos) if f["firma_ok"] or not solo_firmados]
        puntos = bm25(tokens(pregunta), [tokens(self.fragmentos[i]["texto"]) for i in ids])
        por_bm25 = [ids[j] for j in sorted(range(len(ids)), key=lambda j: -puntos[j]) if puntos[j] > 0][:k]
        return [self.fragmentos[i] for i in fusion_rrf([por_vector, por_bm25])[:k]]


class CrossEncoderONNX:
    """Cross-encoder con onnxruntime, sin PyTorch. Descarga el modelo la primera vez (unos 135 MB,
    a la caché de Hugging Face) y lo carga una sola vez. Puntúa cada par (pregunta, texto) con un
    logit: cuanto más alto, más relevante. No sigue instrucciones: es un clasificador, no un LLM."""

    def __init__(self, repo=CE_REPO, revision=CE_REVISION, fichero=CE_FICHERO, max_tokens=512):
        self.repo, self.revision, self.fichero, self.max_tokens = repo, revision, fichero, max_tokens
        self._sesion = self._tok = None

    def _cargar(self):
        if self._sesion is None:
            import onnxruntime
            from huggingface_hub import hf_hub_download
            from tokenizers import Tokenizer
            modelo = hf_hub_download(self.repo, self.fichero, revision=self.revision)
            tok = Tokenizer.from_file(hf_hub_download(self.repo, "tokenizer.json", revision=self.revision))
            tok.enable_truncation(self.max_tokens)
            tok.enable_padding()
            self._sesion = onnxruntime.InferenceSession(modelo, providers=["CPUExecutionProvider"])
            self._tok = tok

    def puntuar(self, pregunta, textos):
        import numpy as np
        self._cargar()
        cod = self._tok.encode_batch([(pregunta, t) for t in textos])
        entrada = {"input_ids": np.array([c.ids for c in cod], dtype=np.int64),
                   "attention_mask": np.array([c.attention_mask for c in cod], dtype=np.int64)}
        if "token_type_ids" in {i.name for i in self._sesion.get_inputs()}:
            entrada["token_type_ids"] = np.array([c.type_ids for c in cod], dtype=np.int64)
        return [float(x) for x in self._sesion.run(None, entrada)[0][:, 0]]

    async def __call__(self, pregunta, textos):
        return await asyncio.to_thread(self.puntuar, pregunta, list(textos))


PROMPT_PUNTUADOR = ("Eres un evaluador de relevancia para un buscador. Te doy una pregunta y un documento. "
                    "Responde solo con «Puntuación: N», donde N es un número entero de 0 (el documento no tiene "
                    "nada que ver con la pregunta) a 10 (el documento responde exactamente a la pregunta).")


class ReordenadorLLM:
    """Un LLM como puntuador: una petición por candidato, con temperatura 0. Lee el documento como
    texto que sigue instrucciones… y el documento puede llevar instrucciones."""

    def __init__(self, cliente, ajustes):
        self.cliente, self.ajustes = cliente, ajustes

    async def __call__(self, pregunta, textos):
        out = []
        for texto in textos:
            r = await self.cliente.post("/api/chat", json={
                "model": self.ajustes.modelo, "stream": False, "options": {"temperature": 0, "seed": 0, "num_predict": 12},
                "messages": [{"role": "system", "content": PROMPT_PUNTUADOR},
                             {"role": "user", "content": "Pregunta: %s\n\nDocumento:\n%s" % (pregunta, texto)}]})
            r.raise_for_status()
            out.append(puntuacion_llm(r.json().get("message", {}).get("content", "")))
        return out


async def buscar(cliente, biblioteca, reordenador, pregunta, defensas=(), k=None, candidatos=None):
    """Busca y mide la latencia. Devuelve (fragmentos, milisegundos)."""
    a = biblioteca.ajustes
    t0 = time.perf_counter()
    frags = await recuperar_reordenado(cliente, biblioteca, reordenador, pregunta, k or a.k, candidatos or a.candidatos, defensas)
    return frags, (time.perf_counter() - t0) * 1000.0


class Consulta(BaseModel):
    pregunta: str = Field(min_length=1, max_length=1000)
    reordenador: str = "ninguno"
    procedencia: bool = False


def crear_app(ajustes=None, transporte=None, documentos=None, cross_encoder=None):
    """Buscador de la biblioteca: devuelve los k fragmentos y la latencia con cada reordenador."""
    ajustes = ajustes or Ajustes.desde_entorno()

    @asynccontextmanager
    async def ciclo_de_vida(app):
        async with httpx2.AsyncClient(base_url=ajustes.ollama_url, timeout=ajustes.timeout, transport=transporte) as c:
            app.state.cliente = c
            app.state.biblioteca = Biblioteca(ajustes)
            await app.state.biblioteca.ingerir(c, documentos if documentos is not None else cargar_documentos())
            app.state.reordenadores = {"ninguno": None, "cross-encoder": cross_encoder or CrossEncoderONNX(),
                                       "llm": ReordenadorLLM(c, ajustes)}
            yield

    app = FastAPI(title="Forja · buscador de la biblioteca con reordenación", lifespan=ciclo_de_vida)

    @app.get("/salud")
    async def salud():
        return {"ok": True, "fragmentos": len(app.state.biblioteca.fragmentos), "reordenadores": list(REORDENADORES)}

    @app.post("/buscar")
    async def buscar_ep(q: Consulta):
        if q.reordenador not in REORDENADORES:
            raise HTTPException(status_code=422, detail="reordenador desconocido: %s" % q.reordenador)
        try:
            frags, ms = await buscar(app.state.cliente, app.state.biblioteca, app.state.reordenadores[q.reordenador],
                                     q.pregunta, ("procedencia",) if q.procedencia else ())
        except httpx2.HTTPError as e:
            raise HTTPException(status_code=502, detail="error al consultar el modelo (%s)" % type(e).__name__)
        return {"resultados": [{"fuente": "%s#%d" % (f["doc"], f["n"]), "texto": f["texto"], "firma_ok": f["firma_ok"],
                                "puntuacion": f.get("puntuacion")} for f in frags], "ms": round(ms, 1)}

    return app


app = crear_app()
