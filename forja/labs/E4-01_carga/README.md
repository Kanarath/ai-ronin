# E4-01 · La forja bajo carga

**Misión del Dojo:** E4-01 (requiere P0-01 y O6-03). Especialización E4, AI Ops avanzado. Laboratorio real de la Forja.

Tu servicio de P0-01 atendía a una persona cada vez. Ahora llegan muchas a la vez, y una de ellas abusa: lanza una ráfaga de diez peticiones caras («escribe un ensayo muy largo...»). En tu CPU, Ollama genera **una respuesta cada vez** (`OLLAMA_NUM_PARALLEL` vale 1 por defecto), así que cada petición abusiva que llega al modelo es tiempo que esperan los clientes legítimos. Es el riesgo LLM10 de OWASP, *Unbounded Consumption*: no hace falta tumbar el servicio para dejarlo inservible.

Vas a construir las defensas clásicas del *serving* y a medir qué consigue cada una con un generador de carga contra el modelo real.

| Pieza | Quién la escribe |
|---|---|
| `percentil`, `resumen_latencias`, `CuboDeTokens`, `normalizar_pregunta`, `clave_cache`, `CacheRespuestas` y `atender` en `carga.py` | **Tú** |
| `Politica`, `Estado`, la aplicación FastAPI, `bateria.py` (el generador de carga), `ataques.json`, Docker | Claude |
| `test_carga.py` (25 tests con un modelo simulado y un reloj falso) | Claude |

Reutiliza tu servicio de P0-01: `llamar_ollama` usa tus `construir_peticion` y `extraer_respuesta`. Si P0-01 no está terminado, la batería te avisará con un `NotImplementedError`.

## 1. Entorno y tests

Desde esta carpeta:

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe -m unittest -v test_carga
```

Orden recomendado: `percentil` → `resumen_latencias` → `CuboDeTokens` → `normalizar_pregunta` → `clave_cache` → `CacheRespuestas` → `atender`. Los tests no necesitan Ollama: el modelo simulado tarda lo que el test le dice y el reloj falso solo avanza cuando el test lo mueve. Cuando pasen los 25:

```powershell
.\.venv\Scripts\python.exe ..\..\ejercicios\ronin_check.py E4-01
```

Y en el Dojo: `evidence import`.

## 2. Medir bajo carga contra el modelo real

Con Ollama en marcha y `llama3.2:1b` descargado (README de P0-01, sección 3):

```powershell
.\.venv\Scripts\python.exe bateria.py
```

Cada ronda lanza a la vez las 10 peticiones del abusador y, escalonadas cada 2 segundos, las 6 de tres clientes legítimos (`ataques.json`). Se repite con cuatro configuraciones: `ninguna`, `limite`, `limite,cache` y `limite,cache,cola,timeout`. En CPU tarda entre 10 y 20 minutos. Para ir más rápido:

```powershell
.\.venv\Scripts\python.exe bateria.py --configs "ninguna;limite,cache,cola,timeout"
```

Cada fila muestra:
- **abuso al modelo**: peticiones abusivas que llegaron al modelo y gastaron CPU;
- **legítimas a tiempo**: respuestas legítimas correctas antes de 60 s (el objetivo de servicio del escenario), y cuántas salieron de la caché;
- **p50 y p95** de la latencia de las legítimas, y el **throughput** (respuestas servidas por segundo);
- los **tokens** que generó el abusador y el recuento de códigos HTTP (200, 429, 503, 504).

Predice antes de medir. La medición se guarda en `forja/evidencias/E4-01-medicion.json`; en el Dojo, `evidence import`. El Dojo comprueba que `ataques.json` no se ha modificado.

**Lo que no es determinista.** La velocidad de tu CPU cambia con la temperatura, la batería y lo que tengas abierto. Repite la medición si un número te sorprende, y compara configuraciones medidas en la misma sesión.

**Una pregunta abierta que puedes medir.** Con `timeout`, `asyncio.wait_for` cancela la petición HTTP y el cliente recibe la respuesta degradada. ¿Deja Ollama de generar al cortarse la conexión? Su documentación no lo dice. Compara `tokens abuso` con y sin `timeout` y sácalo de tus datos.

## 3. Desplegarlo (opcional, con Docker)

```powershell
docker compose up -d --build
docker compose exec ollama ollama pull llama3.2:1b
```

Se construye desde `forja/labs` porque la imagen copia también tu `servicio.py` de P0-01. Prueba el límite (el cliente sale del token, nunca del cuerpo de la petición):

```powershell
1..5 | ForEach-Object { try { (Invoke-WebRequest -Method Post http://127.0.0.1:8000/chat -ContentType "application/json" `
  -Headers @{ Authorization = "Bearer token-abusador-lab" } -Body '{"pregunta": "Hola"}').StatusCode } catch { $_.Exception.Response.StatusCode.value__ } }
```

Fíjate en tres decisiones de `compose.yaml`:
- **Límites de recursos** (`deploy.resources.limits`): si el modelo se desboca, consume su CPU y su memoria, no las de toda la máquina.
- **`OLLAMA_MAX_QUEUE`**: Ollama también tiene cola (512 por defecto) y responde 503 cuando se llena. Tu cola acotada actúa antes y por cliente.
- La respuesta 429 lleva la cabecera `Retry-After`, que le dice al cliente cuándo volver.

## Qué está simplificado

- Un solo proceso: el cubo de tokens, la caché y la cola viven en memoria. Con varias réplicas, el estado compartido va en un almacén común (Redis, por ejemplo) o el límite se aplica en el balanceador o en una pasarela de API.
- El límite cuenta peticiones, no tokens. Un servicio real también limita los tokens por minuto, porque una petición puede costar cien veces más que otra.
- Un escenario fijo de 16 peticiones. Una prueba de carga real sube la carga poco a poco hasta encontrar el punto en que la latencia se dispara, y dura bastante más.
- Sin streaming: el usuario espera la respuesta entera. Con streaming, la métrica que importa es el tiempo hasta el primer token.
- La caché solo acierta con preguntas casi idénticas. Las cachés semánticas (por similitud de embeddings) aciertan más, y también se equivocan más: pueden servir la respuesta de otra pregunta.

## Referencias (consultadas el 2026-11-10)

- [OWASP Top 10 for LLM Applications 2025](https://genai.owasp.org/llm-top-10/): LLM10 Unbounded Consumption.
- [Ollama · FAQ](https://docs.ollama.com/faq): `OLLAMA_NUM_PARALLEL` (1 por defecto), `OLLAMA_MAX_QUEUE` (512 por defecto; llena, responde 503). Versión 0.40.16.
- [RFC 6585 · Additional HTTP Status Codes](https://www.rfc-editor.org/rfc/rfc6585) (2012): el código 429 Too Many Requests y la cabecera `Retry-After`.
- [Python · asyncio: Semaphore y wait_for](https://docs.python.org/3.13/library/asyncio-sync.html) (Python 3.13).
- B. Beyer, C. Jones, J. Petoff, N. R. Murphy (eds.), *Site Reliability Engineering*, O'Reilly (2016), capítulos «Service Level Objectives» y «Handling Overload». [sre.google/sre-book](https://sre.google/sre-book/handling-overload/)
