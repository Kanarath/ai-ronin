# P0-01 · Tu primer servicio con un LLM local

**Misión del Dojo:** P0-01 · *El horno encendido*. Primer laboratorio real de la Forja: aquí no hay simulación.

Vas a construir un servicio web (FastAPI) que recibe una pregunta, se la pasa a un modelo de lenguaje que corre **en tu CPU** (Ollama, con `llama3.2:1b`) y devuelve la respuesta con unas métricas. Después medirás algo que el Dojo solo podía contarte: un modelo real no responde siempre lo mismo.

| Pieza | Quién la escribe |
|---|---|
| `validar_pregunta`, `construir_peticion`, `extraer_respuesta`, `preguntar` en `servicio.py` | **Tú** |
| La aplicación FastAPI de `servicio.py`, `medir.py`, `Dockerfile`, `compose.yaml` | Claude (léelos: también enseñan) |
| `test_servicio.py` | Claude. Usa un Ollama **simulado**: los tests no necesitan red ni modelo |

**Qué practicas:** entornos virtuales y `pip`, JSON, HTTP con `httpx2`, `async`/`await`, FastAPI, Docker básico y la API de chat de Ollama.

## Reglas de la Forja

- Todo escucha **solo en `127.0.0.1`**. Nada queda expuesto a tu red local.
- El modelo se descarga una vez (unos 1,3 GB) y después funciona sin internet.
- Requisitos: 16 GB de RAM bastan para `llama3.2:1b`; con 3B (`llama3.2:3b`, 2 GB) responde mejor pero más lento.

## 1. Entorno de Python (una vez)

Desde esta carpeta, en PowerShell:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
```

Si PowerShell no deja ejecutar `Activate.ps1`, usa directamente `.\.venv\Scripts\python.exe` en lugar de `python` en todos los comandos.

`requirements.txt` fija las versiones (comprobadas en PyPI el 2026-11-10). Una nota real del oficio: `httpx`, el cliente HTTP más usado, lleva sin versión estable desde diciembre de 2024 y Pydantic mantiene ahora un fork, `httpx2`; FastAPI y Starlette ya lo usan para sus tests. Las dependencias cambian: fíjalas y revísalas.

## 2. Implementa y pasa los tests

```powershell
python -m unittest -v test_servicio
```

Ve en orden: `validar_pregunta` → `construir_peticion` → `extraer_respuesta` → `preguntar`. Lee los tests: el Ollama simulado de `ollama_simulado()` muestra exactamente qué recibe y qué devuelve Ollama.

Cuando pasen todos, genera la evidencia **con el Python del entorno** y llévala al Dojo:

```powershell
.\.venv\Scripts\python.exe ..\..\ejercicios\ronin_check.py P0-01
```

En el Dojo: `evidence import`.

## 3. Con el modelo real

Elige **uno** de los dos caminos.

**Camino A · Ollama instalado (más ligero):**

```powershell
winget install --id Ollama.Ollama -e
ollama pull llama3.2:1b
```

Ollama queda escuchando en `http://127.0.0.1:11434`. Arranca tu servicio:

```powershell
python -m uvicorn servicio:app --host 127.0.0.1 --port 8000
```

**Camino B · Docker Compose (servicio y modelo en contenedores):** necesitas Docker Desktop (`winget install --id Docker.DockerDesktop -e`, con WSL 2).

```powershell
docker compose up -d --build
docker compose exec ollama ollama pull llama3.2:1b
```

Para pararlo: `docker compose down` (el modelo se conserva en el volumen `ollama_datos`).

**Prueba que responde**, en otra terminal con el entorno activado:

```powershell
python -c "import httpx2; print(httpx2.post('http://127.0.0.1:8000/chat', json={'pregunta': '¿Qué es el temple?'}, timeout=300).json())"
```

La primera respuesta tarda más: el modelo se carga en memoria.

## 4. Mide

```powershell
python medir.py --n 5 --temperatura 0.8
python medir.py --n 5 --temperatura 0 --semilla 42
```

Antes de cada medición, predice el resultado. Anota cuántas respuestas distintas obtienes y la velocidad en tokens por segundo: las necesitarás para la reflexión de la misión.

## Qué está simplificado

- Sin autenticación ni límite de peticiones por cliente: lo añades en A1 Desplegar.
- Sin streaming: la respuesta llega entera al final.
- Un solo modelo y sin historial de conversación.

## Referencias (consultadas el 2026-11-10)

- [Ollama · API `/api/chat`](https://docs.ollama.com/api/chat) — versión 0.40.16.
- [FastAPI](https://fastapi.tiangolo.com/) 0.162.2 · [httpx2](https://pypi.org/project/httpx2/) 2.16.0 · [Uvicorn](https://www.uvicorn.org/) 0.54.0.
- [Llama 3.2 en la biblioteca de Ollama](https://ollama.com/library/llama3.2) — revisa su licencia antes de usarlo fuera del laboratorio.
