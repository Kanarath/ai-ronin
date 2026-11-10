"""Laboratorio P0-01 · Tu primer servicio con un LLM local.

Un servicio web (FastAPI) que recibe una pregunta, se la pasa a un modelo que corre en TU
ordenador (Ollama, en CPU) y devuelve la respuesta con unas métricas. Es la pieza básica de
cualquier aplicación con LLM: el chatbot de A1, el RAG de A2 o el agente de A3 empiezan así.

Tú implementas las cuatro funciones marcadas con «Tu turno». El resto (la aplicación FastAPI,
la configuración y el arranque) lo ha escrito Claude: léelo, porque también enseña.

Python que practicas: diccionarios, excepciones, async/await, HTTP con httpx2 y FastAPI
(PYTHON.md §14 en forja/ejercicios). Tests (sin red, con un Ollama simulado):
    python -m unittest -v test_servicio
"""

import os
from contextlib import asynccontextmanager
from dataclasses import dataclass

import httpx2
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

MAX_CARACTERES = 2000


@dataclass(frozen=True)
class Ajustes:
    """Configuración del servicio. Se lee de variables de entorno (así Docker puede cambiarla)."""
    ollama_url: str = "http://127.0.0.1:11434"
    modelo: str = "llama3.2:1b"
    temperatura: float = 0.7
    timeout: float = 120.0

    @staticmethod
    def desde_entorno():
        return Ajustes(
            ollama_url=os.environ.get("OLLAMA_URL", Ajustes.ollama_url),
            modelo=os.environ.get("MODELO", Ajustes.modelo),
            temperatura=float(os.environ.get("TEMPERATURA", Ajustes.temperatura)),
            timeout=float(os.environ.get("TIMEOUT", Ajustes.timeout)),
        )


# ─────────────────────────────── Tu turno ───────────────────────────────

def validar_pregunta(texto):
    """Devuelve la pregunta sin espacios al principio ni al final.
    Lanza ValueError si queda vacía o si tiene más de MAX_CARACTERES caracteres.
    (Limitar la entrada es la primera defensa contra el consumo sin límite, OWASP LLM10.)
    """
    raise NotImplementedError("Tu turno: implementa validar_pregunta")


def construir_peticion(pregunta, modelo, temperatura, semilla=None, sistema=None):
    """Cuerpo JSON para POST /api/chat de Ollama, SIN streaming:
        {"model": modelo,
         "messages": [{"role": "system", "content": sistema},    ← solo si sistema no es None
                      {"role": "user", "content": pregunta}],
         "stream": False,
         "options": {"temperature": temperatura, "seed": semilla}}  ← "seed" solo si no es None
    """
    raise NotImplementedError("Tu turno: implementa construir_peticion")


def extraer_respuesta(datos):
    """datos = JSON de la respuesta de Ollama. Devuelve:
        {"texto": datos["message"]["content"] sin espacios al principio ni al final,
         "tokens": datos["eval_count"],
         "segundos": datos["total_duration"] pasado de nanosegundos a segundos, redondeado a 3 decimales,
         "motivo": datos["done_reason"]}
    Lanza ValueError si datos["done"] no es True o si falta "message" (respuesta incompleta).
    Si faltan eval_count, total_duration o done_reason, usa 0, 0.0 y "" respectivamente.
    """
    raise NotImplementedError("Tu turno: implementa extraer_respuesta")


async def preguntar(cliente, ajustes, pregunta, temperatura=None, semilla=None):
    """Pregunta al modelo y devuelve el diccionario de extraer_respuesta.
    - cliente es un httpx2.AsyncClient cuya base_url ya apunta a Ollama.
    - Si temperatura es None, usa ajustes.temperatura.
    - POST a "/api/chat" con el JSON de construir_peticion (sin mensaje de sistema).
    - Llama a respuesta.raise_for_status() antes de leer el JSON: un error HTTP de Ollama
      (por ejemplo, 404 porque el modelo no está descargado) debe llegar como excepción.
    Recuerda: las llamadas del cliente asíncrono se esperan con await.
    """
    raise NotImplementedError("Tu turno: implementa preguntar")


# ──────────────────── Aplicación (escrita por Claude) ────────────────────

class PeticionChat(BaseModel):
    pregunta: str = Field(max_length=MAX_CARACTERES * 2)
    temperatura: float | None = Field(default=None, ge=0.0, le=2.0)
    semilla: int | None = None


def crear_app(ajustes=None, transporte=None):
    """Crea la aplicación. Los tests pasan un `transporte` simulado para no necesitar Ollama."""
    ajustes = ajustes or Ajustes.desde_entorno()

    @asynccontextmanager
    async def ciclo_de_vida(app):
        # Un único cliente HTTP para toda la vida del servicio (reutiliza conexiones).
        async with httpx2.AsyncClient(base_url=ajustes.ollama_url, timeout=ajustes.timeout,
                                      transport=transporte) as cliente:
            app.state.cliente = cliente
            yield

    app = FastAPI(title="Forja · servicio LLM local", lifespan=ciclo_de_vida)

    @app.get("/salud")
    async def salud():
        return {"ok": True, "modelo": ajustes.modelo}

    @app.post("/chat")
    async def chat(peticion: PeticionChat):
        try:
            pregunta = validar_pregunta(peticion.pregunta)
        except ValueError as e:
            raise HTTPException(status_code=400, detail=str(e))
        try:
            r = await preguntar(app.state.cliente, ajustes, pregunta, peticion.temperatura, peticion.semilla)
        except httpx2.TimeoutException:
            raise HTTPException(status_code=504, detail="el modelo ha tardado demasiado")
        except (httpx2.HTTPError, ValueError) as e:
            # No se devuelve el error interno tal cual: puede revelar detalles del despliegue.
            raise HTTPException(status_code=502, detail="error al consultar el modelo (%s)" % type(e).__name__)
        return {"modelo": ajustes.modelo, **r}

    return app


app = crear_app()
