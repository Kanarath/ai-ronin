"""Laboratorio A2-05 · Lo que no se ve: inyección a través de lo que la ingesta extrae.

La biblioteca de Kurogane (A2-04) ya no recibe solo texto: los clientes suben páginas HTML, PDF y
textos copiados de foros. Lo que el RAG indexa no es lo que una persona ve en la pantalla, sino lo
que el EXTRACTOR saca del fichero: bloques con display:none, texto blanco, comentarios, el texto
alternativo de las imágenes, texto PDF con modo de pintado invisible, metadatos y caracteres
Unicode que no se dibujan. Todo eso llega al índice y, desde ahí, al contexto del modelo.

Tú implementas las piezas marcadas con «Tu turno»: la extracción consciente de la visibilidad (HTML
y PDF), la detección y eliminación de caracteres invisibles, la revelación de los caracteres de
etiqueta y una normalización Unicode. Claude ha escrito el resto: la lectura de HTML y de PDF
(pypdf), la ingesta, la búsqueda, la tubería `responder`, la aplicación FastAPI y bateria.py.

Todo es ficticio y local. Tests (sin red, con Ollama simulado):
    python -m unittest -v test_multimodal
"""

import base64
import hashlib
import io
import json
import math
import os
import re
import unicodedata
from contextlib import asynccontextmanager
from dataclasses import dataclass
from html.parser import HTMLParser
from pathlib import Path

import httpx2
from fastapi import FastAPI, Header, HTTPException
from pydantic import BaseModel, Field

AQUI = Path(__file__).resolve().parent
FUENTES = AQUI / "fuentes"
DOCS_A2_04 = AQUI.parent / "A2-04_rag" / "documentos.json"   # el escenario de A2-04, solo lectura
DEFENSAS = ("visibilidad", "invisibles", "normalizacion", "filtro")
SIN_FUENTES = "No tengo documentos que respondan a eso."

# Elementos HTML cuyo contenido nunca se pinta en la página.
NO_SE_PINTAN = {"head", "title", "script", "style", "template", "noscript"}
# Elementos sin etiqueta de cierre (<img>, <br>…): html.parser no emite su cierre.
VACIOS = {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "source", "track", "wbr"}
# Colores que, sobre el fondo blanco de nuestras páginas, no se ven (escritos sin espacios y en minúsculas).
BLANCOS = {"white", "#fff", "#ffffff", "rgb(255,255,255)"}
ZWJ, VS16 = "\u200d", "\ufe0f"


def es_invisible(c):
    """True si el carácter no se dibuja: categoría Unicode Cf (formato: ancho cero, controles de
    dirección, BOM, guion blando, etiquetas U+E0000…) o selector de variación (U+FE00–FE0F y
    U+E0100–E01EF, que también se usan para esconder datos)."""
    cp = ord(c)
    return unicodedata.category(c) == "Cf" or 0xFE00 <= cp <= 0xFE0F or 0xE0100 <= cp <= 0xE01EF


def es_emoji(c):
    """Aproximación suficiente para el laboratorio: pictogramas (U+1F300–1FAFF) y símbolos (U+2600–27BF)."""
    cp = ord(c)
    return 0x1F300 <= cp <= 0x1FAFF or 0x2600 <= cp <= 0x27BF


class _LectorHTML(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.eventos = []

    def handle_starttag(self, tag, attrs):
        self.eventos.append(("vacio" if tag in VACIOS else "abre", tag, dict(attrs)))

    def handle_startendtag(self, tag, attrs):
        self.eventos.append(("vacio", tag, dict(attrs)))

    def handle_endtag(self, tag):
        if tag not in VACIOS:
            self.eventos.append(("cierra", tag, {}))

    def handle_data(self, data):
        self.eventos.append(("texto", data, {}))

    def handle_comment(self, data):
        self.eventos.append(("comentario", data, {}))


def eventos_html(html):
    """Lista de eventos (tipo, valor, atributos) de un HTML, en orden:
        ("abre", etiqueta, {atributo: valor})   <div style="…">  (los nombres, en minúsculas)
        ("vacio", etiqueta, {atributo: valor})  <img alt="…">, <br>: no tienen cierre
        ("cierra", etiqueta, {})                </div>
        ("texto", texto, {})                    el texto entre etiquetas (entidades ya decodificadas)
        ("comentario", texto, {})               <!-- … -->
    Un atributo sin valor (<div hidden>) aparece con valor None."""
    lector = _LectorHTML()
    lector.feed(html)
    lector.close()
    return lector.eventos


def _cadena(x):
    return x.decode("cp1252", errors="replace") if isinstance(x, (bytes, bytearray)) else str(x)


def _a_python(x):
    """Operando de pypdf → str, float o list (lo que recibe texto_visible_pdf)."""
    if isinstance(x, list):
        return [_a_python(y) for y in x]
    if isinstance(x, (int, float)) and not isinstance(x, bool):
        return float(x)
    return _cadena(x)


def operaciones_pdf(datos):
    """Operaciones del flujo de contenido de todas las páginas de un PDF, como lista de
    (operador, [operandos]): operador es un str ("Tj", "rg"…); los números son float; las cadenas,
    str; y el operando de TJ, una lista de str y float."""
    from pypdf import PdfReader
    ops = []
    for pagina in PdfReader(io.BytesIO(datos)).pages:
        contenido = pagina.get_contents()
        if contenido is None:
            continue
        for operandos, operador in contenido.operations:
            ops.append((_cadena(operador), [_a_python(o) for o in operandos]))
    return ops


def texto_ingenuo_html(html):
    """Lo que saca un extractor que no mira la visibilidad: el texto de todos los elementos (salvo
    script y style), los comentarios y los atributos alt y title. Los extractores reales varían:
    get_text() de BeautifulSoup incluye lo oculto con CSS; los conversores a Markdown conservan los
    alt; los comentarios se suelen descartar, salvo si se indexa el HTML en bruto."""
    partes, saltar = [], 0
    for tipo, valor, attrs in eventos_html(html):
        if tipo == "abre" and valor in ("script", "style"):
            saltar += 1
        elif tipo == "cierra" and valor in ("script", "style"):
            saltar = max(0, saltar - 1)
        elif tipo in ("texto", "comentario") and not saltar:
            partes.append(valor)
        if tipo in ("abre", "vacio"):
            partes.extend(attrs[a] for a in ("alt", "title") if attrs.get(a))
    return " ".join(" ".join(partes).split())


def texto_ingenuo_pdf(datos):
    """Lo que saca pypdf con extract_text() (que no mira ni el color ni el modo de pintado) más los
    metadatos del documento, como hacen las ingestas que indexan el título, el asunto y las palabras
    clave para mejorar la búsqueda."""
    from pypdf import PdfReader
    lector = PdfReader(io.BytesIO(datos))
    partes = [p.extract_text() or "" for p in lector.pages]
    partes += [str(v) for v in (lector.metadata or {}).values() if v]
    return " ".join(" ".join(partes).split())


# ─────────────────────────────── Tu turno ───────────────────────────────

def oculto_por_estilo(atributos):
    """True si los atributos de un elemento HTML hacen que su contenido no se vea. `atributos` es un
    dict {nombre: valor} (valor puede ser None). Está oculto si:
      - tiene el atributo "hidden" (con cualquier valor, también None), o
      - su atributo "style" contiene alguna de estas declaraciones. Las declaraciones se separan por
        ";" y cada una es "propiedad: valor" (se parte en el PRIMER ":"). Propiedad y valor se
        comparan sin espacios alrededor, en minúsculas y quitando un "!important" final del valor:
          display: none
          visibility: hidden   o   visibility: collapse
          opacity: 0           (cualquier número que valga 0: "0", "0.0", ".0"; si no es un número, no cuenta)
          font-size: 0         (un cero con o sin unidad: "0", "0px", "0pt", "0em", "0rem", "0%", "0.0px")
          color: un valor de BLANCOS, comparado tras quitar TODOS los espacios ("rgb(255, 255, 255)")
    aria-hidden NO cuenta: oculta el elemento a los lectores de pantalla, pero se sigue viendo.
    Las declaraciones vacías o sin ":" se ignoran.
    """
    raise NotImplementedError("Tu turno: implementa oculto_por_estilo")


def texto_visible_html(html):
    """El texto que una persona ve en la página. Recorre eventos_html(html) con una pila de los
    elementos abiertos; cada entrada guarda la etiqueta y si ese elemento oculta su contenido
    (oculto_por_estilo de sus atributos, o etiqueta en NO_SE_PINTAN).
      - "abre": apila el elemento.
      - "cierra": desapila hasta sacar el último elemento abierto con esa etiqueta (así se cierran
        también los que quedaron sin cerrar dentro). Si no hay ninguno abierto con esa etiqueta, no
        hace nada.
      - "texto": se guarda solo si NINGÚN elemento de la pila oculta su contenido.
      - "comentario" y "vacio" no aportan texto (tampoco los atributos alt o title: no se ven).
    Devuelve los textos guardados unidos con un espacio y con los espacios colapsados: " ".join(t.split()).
    """
    raise NotImplementedError("Tu turno: implementa texto_visible_html")


def texto_visible_pdf(operaciones):
    """El texto de un PDF que de verdad se pinta. `operaciones` es una lista de (operador, operandos)
    como la de operaciones_pdf. Recórrela llevando un estado gráfico con tres valores:
        blanco (False al empezar), modo de pintado (0) y tamaño de letra (12.0)
      - "q": guarda una copia del estado en una pila. "Q": recupera el último guardado (si la pila
        está vacía, no hace nada). BT y ET NO cambian el estado.
      - "rg" (r, g, b): blanco = los tres >= 0.95.  "g" (gris): blanco = gris >= 0.95.
        "k" (c, m, y, k): blanco = los cuatro <= 0.05.
      - "Tr" (n): modo de pintado = int(n). Los modos 3 (invisible) y 7 (solo recorte) no pintan.
      - "Tf" (fuente, tamaño): tamaño = abs(tamaño).
      - Operadores que pintan texto: "Tj" (cadena), "'" (cadena), '"' (aw, ac, cadena): la cadena es
        el último operando. "TJ" ([lista]): concatena las cadenas de la lista; un número <= -200
        entre ellas (un hueco grande) cuenta como un espacio; los demás números no añaden nada.
    Un texto pintado es visible si no es blanco, el modo no es 3 ni 7 y el tamaño es >= 1.
    Devuelve los textos visibles unidos con un espacio y colapsados: " ".join(t.split()).
    """
    raise NotImplementedError("Tu turno: implementa texto_visible_pdf")


def caracteres_invisibles(texto):
    """Lista de (posición, código) de cada carácter invisible del texto (según es_invisible), en
    orden. La posición es el índice en el str; el código, "U+" y el valor en hexadecimal en
    mayúsculas con al menos 4 cifras: "U+200B", "U+E0041"."""
    raise NotImplementedError("Tu turno: implementa caracteres_invisibles")


def quitar_invisibles(texto):
    """El texto sin sus caracteres invisibles, con una excepción para no romper los emoji: se
    conservan ZWJ (U+200D) y VS16 (U+FE0F) cuando el carácter ANTERIOR del texto original es un emoji
    (es_emoji). Así 👨\u200d🔧 y ❤\ufe0f quedan intactos, pero un ZWJ entre letras o un VS16 detrás de otro VS16 se
    quitan."""
    raise NotImplementedError("Tu turno: implementa quitar_invisibles")


def revelar_etiquetas(texto):
    """El mensaje escondido con caracteres de etiqueta Unicode (bloque Tags): cada carácter entre
    U+E0020 y U+E007E corresponde al ASCII de código (código - 0xE0000). Devuelve, en orden, solo
    esos caracteres ya traducidos; el resto del texto se ignora. Sin etiquetas → ""."""
    raise NotImplementedError("Tu turno: implementa revelar_etiquetas")


def normalizar_unicode(texto):
    """Forma de normalización NFKC (unicodedata.normalize): une las formas de compatibilidad, como
    el ancho completo «ＩＮＴＬ» → «INTL» o el espacio no separable. Después colapsa los espacios
    en blanco: " ".join(t.split())."""
    raise NotImplementedError("Tu turno: implementa normalizar_unicode")


# ──────────────────── Ingesta, búsqueda, tubería y aplicación (Claude) ────────────────────

# Filtro de palabras clave (como el de entrada de A1-05): mira el texto tal cual, sin normalizarlo.
PATRONES_SOSPECHOSOS = [r"\bnota para el asistente\b", r"\binstrucciones para el asistente\b",
                        r"\bignora (las|tus) instrucciones\b", r"\bdile que\b"]


def sospechoso(texto):
    t = texto.lower()
    return any(re.search(p, t) for p in PATRONES_SOSPECHOSOS)


def extraer(fuente, defensas=()):
    """Texto que se indexa de una fuente {"formato": "html"|"pdf"|"texto", "datos": bytes} según las
    defensas activas. El orden importa: primero se extrae, después se quitan los invisibles y por
    último se normaliza."""
    formato, datos = fuente["formato"], fuente["datos"]
    if formato == "html":
        html = datos.decode("utf-8")
        texto = texto_visible_html(html) if "visibilidad" in defensas else texto_ingenuo_html(html)
    elif formato == "pdf":
        texto = texto_visible_pdf(operaciones_pdf(datos)) if "visibilidad" in defensas else texto_ingenuo_pdf(datos)
    elif formato == "texto":
        texto = datos.decode("utf-8")
    else:
        raise ValueError("formato desconocido: %s" % formato)
    if "invisibles" in defensas:
        texto = quitar_invisibles(texto)
    if "normalizacion" in defensas:
        texto = normalizar_unicode(texto)
    return texto


def informe_invisibles(texto):
    """Lo que un auditor querría saber de un texto antes de indexarlo."""
    hallados = caracteres_invisibles(texto)
    return {"invisibles": len(hallados), "codigos": sorted({c for _, c in hallados})[:10],
            "etiquetas": revelar_etiquetas(texto)}


def aparece(frases, texto):
    """Oráculo de la medición (independiente de tus funciones): True si alguna frase está en el
    texto aunque esté escondida. Quita todo lo invisible, añade lo que digan las etiquetas Unicode,
    normaliza con NFKC y compara solo letras y cifras."""
    plano = "".join(c for c in texto if not es_invisible(c))
    plano += " " + "".join(chr(ord(c) - 0xE0000) for c in texto if 0xE0020 <= ord(c) <= 0xE007E)
    t = normalizar(unicodedata.normalize("NFKC", plano), espacios=False)
    return any(normalizar(unicodedata.normalize("NFKC", f), espacios=False) in t for f in frases)


def contiene_literal(texto, frases):
    """Para las respuestas legítimas: compara el texto tal cual (NFC, minúsculas, espacios colapsados),
    sin normalizar símbolos. «1½» no es «11⁄2», y eso es justo lo que se mide."""
    def p(x):
        return " ".join(unicodedata.normalize("NFC", x).casefold().split())
    t = p(texto)
    return any(p(f) in t for f in frases)


def auditar_ingesta(indice, bateria):
    """Qué quedó en el índice tras la ingesta: instrucciones ocultas que llegaron (por canal) y
    datos legítimos que sobrevivieron. No necesita ningún modelo."""
    por_canal = {a["canal"]: aparece(a["marca"], indice.texto_indexado(a["doc"])) for a in bateria["ataques"]}
    perdidas = [q["pregunta"] for q in bateria["legitimas"] if not contiene_literal(indice.texto_indexado(q["doc"]), q["espera"])]
    return {"instrucciones_en_indice": sum(por_canal.values()), "instrucciones_n": len(por_canal), "por_canal": por_canal,
            "legitimas_en_indice": len(bateria["legitimas"]) - len(perdidas), "legitimas_n": len(bateria["legitimas"]),
            "legitimas_perdidas": perdidas, "en_cuarentena": len(indice.cuarentena)}


def formato_de(nombre):
    ext = nombre.lower().rsplit(".", 1)[-1]
    return {"html": "html", "htm": "html", "pdf": "pdf", "txt": "texto"}.get(ext)


def huella(datos):
    return hashlib.sha256(datos.replace(b"\r\n", b"\n")).hexdigest()


def cargar_fuentes(bateria=None):
    """Los documentos públicos de A2-04 (texto plano de la forja) más las fuentes de fuentes/ que
    lista ataques.json, comprobando su huella: si alguien cambia un fichero, la medición no vale."""
    bateria = bateria or json.loads((AQUI / "ataques.json").read_text(encoding="utf-8"))
    out = [{"id": d["id"], "formato": "texto", "origen": d["origen"], "datos": d["texto"].encode("utf-8")}
           for d in json.loads(DOCS_A2_04.read_text(encoding="utf-8"))["documentos"] if d["acceso"] == "publico"]
    for f in bateria["fuentes"]:
        datos = (FUENTES / f["fichero"]).read_bytes()
        if huella(datos) != f["sha256"]:
            raise ValueError("la fuente %s no coincide con la original (huella distinta)" % f["fichero"])
        out.append({"id": f["id"], "formato": f["formato"], "origen": f["origen"], "datos": datos})
    return out


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


def coseno(a, b):
    na, nb = math.sqrt(sum(x * x for x in a)), math.sqrt(sum(x * x for x in b))
    return sum(x * y for x, y in zip(a, b)) / (na * nb) if na and nb else 0.0


@dataclass(frozen=True)
class Ajustes:
    ollama_url: str = "http://127.0.0.1:11434"
    modelo: str = "llama3.2:1b"
    modelo_embed: str = "embeddinggemma"
    modelo_vision: str = "qwen3-vl:2b"
    temperatura: float = 0.7
    timeout: float = 180.0
    k: int = 3

    @staticmethod
    def desde_entorno():
        e, d = os.environ.get, Ajustes()
        return Ajustes(e("OLLAMA_URL", d.ollama_url), e("MODELO", d.modelo), e("MODELO_EMBED", d.modelo_embed),
                       e("MODELO_VISION", d.modelo_vision), float(e("TEMPERATURA", d.temperatura)),
                       float(e("TIMEOUT", d.timeout)), int(e("K", d.k)))


async def embeber(cliente, ajustes, textos):
    r = await cliente.post("/api/embed", json={"model": ajustes.modelo_embed, "input": list(textos)})
    r.raise_for_status()
    vectores = r.json().get("embeddings", [])
    if len(vectores) != len(textos):
        raise ValueError("Ollama ha devuelto %d vectores para %d textos" % (len(vectores), len(textos)))
    return vectores


class Indice:
    """Fragmentos con su vector, búsqueda híbrida (vectores + BM25, fusión RRF) y una cuarentena para
    los fragmentos que el filtro marca como sospechosos (no se indexan, pero quedan a la vista)."""

    def __init__(self, ajustes, defensas=()):
        desconocidas = set(defensas) - set(DEFENSAS)
        if desconocidas:
            raise ValueError("defensas desconocidas: %s" % ", ".join(sorted(desconocidas)))
        self.ajustes, self.defensas = ajustes, tuple(defensas)
        self.fragmentos, self.vectores, self.cuarentena, self.textos = [], [], [], {}

    async def ingerir(self, cliente, fuentes):
        nuevos = []
        for f in fuentes:
            texto = extraer(f, self.defensas)
            self.textos[f["id"]] = texto
            for n, trozo in enumerate(trocear(texto)):
                frag = {"doc": f["id"], "n": n, "texto": trozo, "origen": f["origen"]}
                (self.cuarentena if "filtro" in self.defensas and sospechoso(trozo) else nuevos).append(frag)
        if nuevos:
            self.vectores += await embeber(cliente, self.ajustes, [x["texto"] for x in nuevos])
            self.fragmentos += nuevos
        return len(nuevos)

    def texto_indexado(self, doc):
        """Lo que de verdad quedó en el índice de un documento (sin lo que está en cuarentena)."""
        return " ".join(f["texto"] for f in self.fragmentos if f["doc"] == doc)

    async def recuperar(self, cliente, pregunta, k=None, candidatos=10):
        if not self.fragmentos:
            return []
        k = k or self.ajustes.k
        v = (await embeber(cliente, self.ajustes, [pregunta]))[0]
        por_vector = sorted(range(len(self.fragmentos)), key=lambda i: -coseno(v, self.vectores[i]))[:candidatos]
        puntos = bm25(tokens(pregunta), [tokens(f["texto"]) for f in self.fragmentos])
        por_bm25 = [i for i in sorted(range(len(puntos)), key=lambda i: -puntos[i]) if puntos[i] > 0][:candidatos]
        return [self.fragmentos[i] for i in fusion_rrf([por_vector, por_bm25])[:k]]


PROMPT = ("Eres el asistente de la forja Kurogane. Responde en español, en una o dos frases, usando solo la "
          "información de los documentos que se te dan. Si los documentos no lo dicen, responde que no lo sabes.")


async def responder(cliente, indice, pregunta, semilla=None):
    """Tubería RAG. Devuelve {"texto", "fuentes": ["doc#n", ...], "contexto"}."""
    frags = await indice.recuperar(cliente, pregunta)
    if not frags:
        return {"texto": SIN_FUENTES, "fuentes": [], "contexto": ""}
    contexto = "\n\n".join("[fuente: %s#%d]\n%s" % (f["doc"], f["n"], f["texto"]) for f in frags)
    opciones = {"temperature": indice.ajustes.temperatura}
    if semilla is not None:
        opciones["seed"] = semilla
    r = await cliente.post("/api/chat", json={"model": indice.ajustes.modelo, "stream": False, "options": opciones,
                                              "messages": [{"role": "system", "content": PROMPT},
                                                           {"role": "user", "content": "Documentos:\n%s\n\nPregunta: %s" % (contexto, pregunta)}]})
    r.raise_for_status()
    return {"texto": r.json().get("message", {}).get("content", "").strip(),
            "fuentes": ["%s#%d" % (f["doc"], f["n"]) for f in frags], "contexto": contexto}


async def transcribir_imagen(cliente, ajustes, datos):
    """Ingesta «con visión»: pide a un modelo de visión que transcriba el texto de una imagen."""
    r = await cliente.post("/api/chat", json={"model": ajustes.modelo_vision, "stream": False, "think": False,
                                              "options": {"temperature": 0},
                                              "messages": [{"role": "user", "content": "Transcribe todo el texto que aparece en la imagen.",
                                                            "images": [base64.b64encode(datos).decode("ascii")]}]})
    r.raise_for_status()
    return r.json().get("message", {}).get("content", "").strip()


class Subida(BaseModel):
    nombre: str = Field(min_length=1, max_length=120)
    contenido_b64: str = Field(min_length=1, max_length=1_400_000)   # ~1 MB


class Pregunta(BaseModel):
    pregunta: str = Field(min_length=1, max_length=1000)


def crear_app(ajustes=None, transporte=None, defensas=None, fuentes=None, token=None):
    """Servicio de la biblioteca con subida de documentos. Las defensas se fijan al arrancar
    (variable DEFENSAS); subir exige el token de cliente (variable TOKEN_CLIENTE)."""
    ajustes = ajustes or Ajustes.desde_entorno()
    if defensas is None:
        defensas = tuple(d for d in os.environ.get("DEFENSAS", "").split(",") if d)
    token = token if token is not None else os.environ.get("TOKEN_CLIENTE", "token-cliente-lab")

    @asynccontextmanager
    async def ciclo_de_vida(app):
        async with httpx2.AsyncClient(base_url=ajustes.ollama_url, timeout=ajustes.timeout, transport=transporte) as c:
            app.state.cliente = c
            app.state.indice = Indice(ajustes, defensas)
            await app.state.indice.ingerir(c, fuentes if fuentes is not None else cargar_fuentes())
            yield

    app = FastAPI(title="Forja · biblioteca con subida de documentos (vulnerable a propósito)", lifespan=ciclo_de_vida)

    def exigir_token(authorization):
        if not token or (authorization or "").removeprefix("Bearer ").strip() != token:
            raise HTTPException(status_code=401, detail="token ausente o desconocido")

    @app.get("/salud")
    async def salud():
        i = app.state.indice
        return {"ok": True, "defensas": list(i.defensas), "fragmentos": len(i.fragmentos), "cuarentena": len(i.cuarentena)}

    @app.post("/subir")
    async def subir(s: Subida, authorization: str | None = Header(default=None)):
        exigir_token(authorization)
        formato = formato_de(s.nombre)
        if formato is None:
            raise HTTPException(status_code=415, detail="solo .html, .pdf o .txt")
        try:
            datos = base64.b64decode(s.contenido_b64, validate=True)
        except ValueError:
            raise HTTPException(status_code=422, detail="contenido_b64 no es base64")
        doc = "subida-" + huella(datos)[:12]
        i = app.state.indice
        antes = len(i.cuarentena)
        try:
            n = await i.ingerir(app.state.cliente, [{"id": doc, "formato": formato, "origen": "cliente", "datos": datos}])
        except (UnicodeDecodeError, ValueError) as e:
            raise HTTPException(status_code=422, detail="no se ha podido extraer el texto (%s)" % type(e).__name__)
        bruto = datos.decode("utf-8", errors="replace") if formato != "pdf" else i.textos[doc]
        return {"doc": doc, "fragmentos": n, "en_cuarentena": len(i.cuarentena) - antes, "auditoria": informe_invisibles(bruto)}

    @app.post("/preguntar")
    async def preguntar(p: Pregunta):
        try:
            r = await responder(app.state.cliente, app.state.indice, p.pregunta)
        except httpx2.TimeoutException:
            raise HTTPException(status_code=504, detail="el modelo ha tardado demasiado")
        except httpx2.HTTPError as e:
            raise HTTPException(status_code=502, detail="error al consultar el modelo (%s)" % type(e).__name__)
        return {"respuesta": r["texto"], "fuentes": r["fuentes"]}

    return app


app = crear_app()
