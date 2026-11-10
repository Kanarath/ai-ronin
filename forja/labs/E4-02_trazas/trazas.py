"""Laboratorio E4-02 · El cuaderno de la forja (observabilidad con OpenTelemetry).

En O6 leíste trazas que otro había registrado. Aquí las produces tú: cada llamada al modelo de tu
servicio de P0-01 genera un *span* con las convenciones semánticas de GenAI de OpenTelemetry
(atributos gen_ai.*) y unas métricas de latencia y de tokens. Las trazas se exportan a un fichero
local, sin servicios externos.

El problema: el contenido de los mensajes ayuda muchísimo a depurar, y también es donde están los
datos personales. Las convenciones lo dicen claro: gen_ai.input.messages es opt-in porque
«is likely to contain sensitive information including user/PII data». Tú decides qué se exporta.

Tú implementas las funciones marcadas con «Tu turno». El resto (la configuración de OpenTelemetry,
el exportador que redacta, la aplicación FastAPI) lo ha escrito Claude.

Python que practicas: expresiones regulares (re.sub con una función), recursión, context managers
(with) y async. Ver PYTHON.md, anexo E4. Tests (sin red, con un Ollama simulado):
    python -m unittest -v test_trazas
"""

import os
import re
import sys
import time
from contextlib import asynccontextmanager
from pathlib import Path

from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import ConsoleMetricExporter, InMemoryMetricReader, PeriodicExportingMetricReader
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import Event, ReadableSpan, TracerProvider
from opentelemetry.sdk.trace.export import ConsoleSpanExporter, SimpleSpanProcessor, SpanExporter
from opentelemetry.trace import SpanKind, Status, StatusCode

# Convenciones semánticas de GenAI (repositorio open-telemetry/semantic-conventions-genai, estado
# Development, consultado el 2026-11-10). Están en desarrollo: los nombres pueden cambiar.
OPERACION = "chat"
PROVEEDOR = "ollama"
OBLIGATORIOS = ("gen_ai.operation.name", "gen_ai.provider.name", "gen_ai.request.model")
METRICA_DURACION = "gen_ai.client.inference.duration"
METRICA_TOKENS_ENTRADA = "gen_ai.client.inference.operation.input_tokens"
METRICA_TOKENS_SALIDA = "gen_ai.client.inference.operation.output_tokens"
CONTENIDOS = ("no", "redactado", "crudo")
TOPE_TOKENS = None   # máximo de tokens por respuesta (num_predict); lo fija bateria.py


# ─────────────────────────────── Tu turno ───────────────────────────────

def luhn_valido(digitos):
    """True si `digitos` (una cadena SOLO de dígitos) es un número de tarjeta que pasa el algoritmo de Luhn.
    - Si la longitud no está entre 13 y 19 (ambas incluidas), o si hay algo que no sea un dígito: False.
    - Luhn: recorre los dígitos de DERECHA a IZQUIERDA; duplica uno sí y otro no, empezando por el
      segundo (el penúltimo del número); si un duplicado pasa de 9, réstale 9. Suma todo: el número
      es válido si la suma es múltiplo de 10.
    Ejemplos: "4111111111111111" → True · "4111111111111112" → False · "79927398713" → False (11 dígitos).
    """
    raise NotImplementedError("Tu turno: implementa luhn_valido")


def redactar(texto):
    """Sustituye los datos personales de `texto` por una etiqueta, EN ESTE ORDEN (con re.sub):
        1. correos:   r"[\\w.+-]+@[\\w-]+(?:\\.[\\w-]+)+"                     → "[EMAIL]"
        2. IBAN de España: r"\\bES\\d{2}(?:[ ]?\\d{4}){5}\\b", sin distinguir mayúsculas → "[IBAN]"
        3. tarjetas:  r"\\b(?:\\d[ -]?){12,18}\\d\\b" → "[TARJETA]", SOLO si sus dígitos (sin espacios
                      ni guiones) pasan luhn_valido; si no, se deja el texto tal cual
                      (re.sub admite una función en lugar del texto de sustitución)
        4. DNI y NIE: r"\\b[XYZ]?\\d{7,8}[A-Z]\\b", sin distinguir mayúsculas  → "[DNI]"
        5. teléfonos de España: r"(?<!\\w)(?:\\+34[ ]?)?[6789](?:[ ]?\\d){8}(?!\\w)" → "[TELEFONO]"
    El orden importa: un IBAN contiene secuencias que parecen teléfonos.
    Ejemplo: "Soy ana@example.com, tel. +34 612 345 678" → "Soy [EMAIL], tel. [TELEFONO]"
    """
    raise NotImplementedError("Tu turno: implementa redactar")


def redactar_valor(valor):
    """Redacta un valor de atributo de OpenTelemetry, que puede venir anidado:
        - str  → redactar(valor)
        - list o tuple → una TUPLA con cada elemento redactado (llamándote a ti misma: recursión)
        - dict → un dict NUEVO con las mismas claves y cada valor redactado
        - cualquier otra cosa (int, float, bool, None) → igual
    No modifica el valor original.
    """
    raise NotImplementedError("Tu turno: implementa redactar_valor")


def atributos_peticion(modelo, temperatura, servidor, puerto):
    """Atributos del span ANTES de llamar al modelo (convenciones GenAI, inferencia):
        {"gen_ai.operation.name": OPERACION, "gen_ai.provider.name": PROVEEDOR,
         "gen_ai.request.model": modelo, "gen_ai.request.temperature": float(temperatura),
         "server.address": servidor, "server.port": puerto}
    """
    raise NotImplementedError("Tu turno: implementa atributos_peticion")


def atributos_respuesta(datos):
    """Atributos del span con la respuesta de Ollama (`datos` es su JSON, como en P0-01):
        "gen_ai.response.model": datos["model"]                           ← solo si está
        "gen_ai.response.finish_reasons": [datos["done_reason"]]          ← una LISTA; solo si está
        "gen_ai.usage.input_tokens": datos["prompt_eval_count"]           ← 0 si falta
        "gen_ai.usage.output_tokens": datos["eval_count"]                 ← 0 si falta
    """
    raise NotImplementedError("Tu turno: implementa atributos_respuesta")


def mensajes(rol, texto, contenido, finish_reason=None):
    """Valor para gen_ai.input.messages o gen_ai.output.messages, según el modo de `contenido`:
        - "no": devuelve None (no se registra el contenido; es lo que recomiendan las convenciones por defecto)
        - "crudo": el texto tal cual · "redactado": redactar(texto)
        - cualquier otro modo: ValueError
    Forma (esquema de las convenciones): [{"role": rol, "parts": [{"type": "text", "content": texto}]}]
    Si finish_reason no es None, el mensaje lleva además "finish_reason": finish_reason.
    """
    raise NotImplementedError("Tu turno: implementa mensajes")


async def preguntar_con_traza(tracer, metricas, cliente, ajustes, pregunta, contenido="no"):
    """Pregunta al modelo como en P0-01, pero dentro de un span. Devuelve el diccionario de extraer_respuesta.
    1. servidor, puerto = destino(cliente); atrs = atributos_peticion(ajustes.modelo, ajustes.temperatura, servidor, puerto)
       base = los tres atributos OBLIGATORIOS de atrs (para las métricas: pocos valores distintos)
       inicio = time.perf_counter()
    2. Abre el span:
         with tracer.start_as_current_span("chat " + ajustes.modelo, kind=SpanKind.CLIENT, attributes=atrs,
                                           record_exception=False) as span:
       record_exception=False: el mensaje de una excepción puede llevar la pregunta del usuario.
    3. Si mensajes("user", pregunta, contenido) no es None, guárdalo en el atributo "gen_ai.input.messages".
    4. datos = await pedir_ollama(cliente, ajustes, pregunta). Si lanza una excepción e:
         tipo = tipo_de_error(e); span.set_attribute("error.type", tipo); span.set_status(Status(StatusCode.ERROR))
         registra la duración con los atributos {**base, "error.type": tipo} y vuelve a lanzar la excepción (raise).
    5. r = extraer_respuesta(datos) (la de P0-01, copiada más abajo); span.set_attributes(atributos_respuesta(datos)).
       Si mensajes("assistant", r["texto"], contenido, datos.get("done_reason")) no es None, guárdalo en
       "gen_ai.output.messages".
    6. Métricas, todas con los atributos base: metricas["duracion"].record(time.perf_counter() - inicio, base),
       metricas["tokens_entrada"].record(input_tokens, base) y metricas["tokens_salida"].record(output_tokens, base),
       con los tokens de atributos_respuesta. Devuelve r.
    """
    raise NotImplementedError("Tu turno: implementa preguntar_con_traza")


# ──────────────────── Telemetría y servicio (escritos por Claude) ────────────────────

def servicio_p0():
    """Tu servicio de P0-01 (forja/labs/P0-01_servicio_llm/servicio.py): este laboratorio lo reutiliza."""
    try:
        import servicio
    except ModuleNotFoundError:
        sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "P0-01_servicio_llm"))
        import servicio
    return servicio


def extraer_respuesta(datos):
    """La misma que escribiste en P0-01 (copiada aquí para que los tests de E4-02 no dependan de P0-01)."""
    if datos.get("done") is not True or "message" not in datos:
        raise ValueError("respuesta incompleta de Ollama")
    return {"texto": datos["message"]["content"].strip(), "tokens": datos.get("eval_count", 0),
            "segundos": round(datos.get("total_duration", 0) / 1e9, 3), "motivo": datos.get("done_reason", "")}


def destino(cliente):
    """(servidor, puerto) del httpx2.AsyncClient, para server.address y server.port."""
    url = cliente.base_url
    return url.host, url.port or (443 if url.scheme == "https" else 80)


async def pedir_ollama(cliente, ajustes, pregunta, max_tokens=None):
    """POST /api/chat como en P0-01 (el mismo cuerpo que tu construir_peticion). Devuelve el JSON CRUDO de
    Ollama (con model, done_reason, prompt_eval_count y eval_count), que hace falta para los atributos gen_ai.*."""
    cuerpo = {"model": ajustes.modelo, "messages": [{"role": "user", "content": pregunta}], "stream": False,
              "options": {"temperature": ajustes.temperatura}}
    max_tokens = max_tokens or TOPE_TOKENS
    if max_tokens:
        cuerpo["options"]["num_predict"] = int(max_tokens)
    r = await cliente.post("/api/chat", json=cuerpo)
    r.raise_for_status()
    return r.json()


def tipo_de_error(e):
    """error.type según las convenciones: el código del proveedor si lo hay, "timeout" o el nombre de la clase."""
    import httpx2
    if isinstance(e, httpx2.TimeoutException):
        return "timeout"
    if isinstance(e, httpx2.HTTPStatusError):
        return str(e.response.status_code)
    return type(e).__qualname__


class ExportadorRedactor(SpanExporter):
    """Envuelve otro exportador y redacta TODOS los atributos (y los de los eventos) antes de exportar.

    Es la última línea: protege también los atributos que añaden otros (una librería de
    instrumentación, un compañero que añade un atributo «para depurar»). Los spans del SDK no se
    pueden modificar una vez cerrados, así que se exporta una copia redactada.
    """

    def __init__(self, siguiente):
        self.siguiente = siguiente

    def export(self, spans):
        copias = []
        for s in spans:
            eventos = [Event(e.name, redactar_valor(dict(e.attributes or {})), e.timestamp) for e in s.events]
            copias.append(ReadableSpan(
                name=redactar(s.name), context=s.context, parent=s.parent, resource=s.resource,
                attributes=redactar_valor(dict(s.attributes or {})), events=eventos, links=s.links, kind=s.kind,
                status=s.status, start_time=s.start_time, end_time=s.end_time, instrumentation_scope=s.instrumentation_scope))
        return self.siguiente.export(copias)

    def shutdown(self):
        self.siguiente.shutdown()

    def force_flush(self, timeout_millis=30000):
        return self.siguiente.force_flush(timeout_millis)


def exportador_fichero(fichero):
    """Una línea JSON por span en un fichero abierto (formato del SDK, sin servicios externos)."""
    return ConsoleSpanExporter(out=fichero, formatter=lambda s: s.to_json(indent=None) + "\n")


def crear_metricas(meter):
    """Los tres histogramas, con los límites de cubeta que recomiendan las convenciones."""
    segundos = [0.01, 0.02, 0.04, 0.08, 0.16, 0.32, 0.64, 1.28, 2.56, 5.12, 10.24, 20.48, 40.96, 81.92]
    tokens = [1, 4, 16, 64, 256, 1024, 4096, 16384, 65536, 262144, 1048576, 4194304, 16777216, 67108864]
    return {
        "duracion": meter.create_histogram(METRICA_DURACION, unit="s", description="Duración de la inferencia",
                                           explicit_bucket_boundaries_advisory=segundos),
        "tokens_entrada": meter.create_histogram(METRICA_TOKENS_ENTRADA, unit="{token}", description="Tokens de entrada por operación",
                                                 explicit_bucket_boundaries_advisory=tokens),
        "tokens_salida": meter.create_histogram(METRICA_TOKENS_SALIDA, unit="{token}", description="Tokens de salida por operación",
                                                explicit_bucket_boundaries_advisory=tokens),
    }


def configurar(exportador, lector=None, redactor=False, servicio="forja-e4-02"):
    """Proveedores propios (no los globales, para que los tests no se pisen). Devuelve (tracer, metricas, proveedor, medidor).
    SimpleSpanProcessor exporta cada span al cerrarse: más sencillo de seguir. En producción, BatchSpanProcessor."""
    recurso = Resource.create({"service.name": servicio})
    proveedor = TracerProvider(resource=recurso)
    proveedor.add_span_processor(SimpleSpanProcessor(ExportadorRedactor(exportador) if redactor else exportador))
    medidor = MeterProvider(resource=recurso, metric_readers=[lector or InMemoryMetricReader()])
    return proveedor.get_tracer("forja.e4-02"), crear_metricas(medidor.get_meter("forja.e4-02")), proveedor, medidor


def crear_app(transporte=None, exportador=None, lector=None):
    """Servicio de P0-01 con trazas. CONTENIDO = no | redactado | crudo; REDACTOR = 1 para el exportador que redacta.
    Las trazas van a TRAZAS (por defecto trazas/servicio.jsonl) y las métricas a METRICAS cada 60 s."""
    import httpx2
    from fastapi import FastAPI, HTTPException
    from pydantic import BaseModel, Field

    contenido = os.environ.get("CONTENIDO", "no")
    if contenido not in CONTENIDOS:
        raise ValueError("CONTENIDO debe ser uno de %s" % ", ".join(CONTENIDOS))

    class PeticionChat(BaseModel):
        pregunta: str = Field(min_length=1, max_length=2000)

    @asynccontextmanager
    async def ciclo_de_vida(app):
        ficheros = []
        exp, lec = exportador, lector
        if exp is None:
            ruta = Path(os.environ.get("TRAZAS", "trazas/servicio.jsonl"))
            ruta.parent.mkdir(parents=True, exist_ok=True)
            ficheros.append(open(ruta, "a", encoding="utf-8"))
            exp = exportador_fichero(ficheros[-1])
        if lec is None:
            ruta = Path(os.environ.get("METRICAS", "trazas/metricas.jsonl"))
            ruta.parent.mkdir(parents=True, exist_ok=True)
            ficheros.append(open(ruta, "a", encoding="utf-8"))
            lec = PeriodicExportingMetricReader(ConsoleMetricExporter(out=ficheros[-1], formatter=lambda m: m.to_json(indent=None) + "\n"),
                                                export_interval_millis=60000)
        tracer, metricas, proveedor, medidor = configurar(exp, lec, redactor=os.environ.get("REDACTOR") == "1")
        ajustes = servicio_p0().Ajustes.desde_entorno()
        async with httpx2.AsyncClient(base_url=ajustes.ollama_url, timeout=ajustes.timeout, transport=transporte) as cliente:
            app.state.t = (tracer, metricas, cliente, ajustes)
            yield
        proveedor.shutdown()
        medidor.shutdown()
        for f in ficheros:
            f.close()

    app = FastAPI(title="Forja · servicio con trazas", lifespan=ciclo_de_vida)

    @app.post("/chat")
    async def chat(peticion: PeticionChat):
        tracer, metricas, cliente, ajustes = app.state.t
        try:
            r = await preguntar_con_traza(tracer, metricas, cliente, ajustes, peticion.pregunta, contenido)
        except NotImplementedError:
            raise
        except httpx2.TimeoutException:
            raise HTTPException(status_code=504, detail="el modelo ha tardado demasiado")
        except (httpx2.HTTPError, ValueError) as e:
            raise HTTPException(status_code=502, detail="error al consultar el modelo (%s)" % type(e).__name__)
        return {"modelo": ajustes.modelo, **r}

    return app
