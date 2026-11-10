# E4-02 · El cuaderno de la forja

**Misión del Dojo:** E4-02 (requiere E4-01). Especialización E4, AI Ops avanzado. Laboratorio real de la Forja.

En O6 leíste trazas que otro había registrado y aprendiste qué conviene guardar. Aquí las produces tú. Cada llamada al modelo de tu servicio de P0-01 genera un *span* de OpenTelemetry con las **convenciones semánticas de GenAI** (atributos `gen_ai.*`) y tres métricas: la duración de la inferencia y los tokens de entrada y de salida. Todo se exporta a un fichero local: ni colector ni servicios externos.

El dilema es real. El contenido de los mensajes es lo más útil para depurar, y también es donde están los datos personales. Las propias convenciones marcan `gen_ai.input.messages` y `gen_ai.output.messages` como *opt-in* con un aviso: el atributo «is likely to contain sensitive information including user/PII data». Vas a medir qué se escapa al fichero con cada decisión.

| Pieza | Quién la escribe |
|---|---|
| `luhn_valido`, `redactar`, `redactar_valor`, `atributos_peticion`, `atributos_respuesta`, `mensajes` y `preguntar_con_traza` en `trazas.py` | **Tú** |
| La configuración de OpenTelemetry, `ExportadorRedactor`, las métricas, la aplicación FastAPI, `bateria.py`, `ataques.json`, Docker | Claude |
| `test_trazas.py` (17 tests con un Ollama simulado y un exportador en memoria) | Claude |

## Las convenciones de GenAI, hoy

Estado consultado el 2026-11-10. Las convenciones de GenAI se han trasladado del repositorio general de OpenTelemetry a uno propio, [`semantic-conventions-genai`](https://github.com/open-telemetry/semantic-conventions-genai). Siguen en estado **Development** y todavía no tienen ninguna versión publicada. Los nombres han cambiado ya varias veces: por ejemplo, `gen_ai.system` pasó a `gen_ai.provider.name`, y las métricas de inferencia se llaman ahora `gen_ai.client.inference.*`. Si lees un tutorial de 2025, verás otros nombres. Comprueba siempre la versión que usa tu herramienta de observabilidad.

Lo que usa este laboratorio (documento *Client Inference*):

| Elemento | Valor |
|---|---|
| Nombre del span | `{gen_ai.operation.name} {gen_ai.request.model}` → `chat llama3.2:1b` |
| Tipo de span | `CLIENT` |
| Obligatorios | `gen_ai.operation.name` (`chat`) y `gen_ai.provider.name` (`ollama`, valor registrado); `gen_ai.request.model` es obligatorio si está disponible |
| Recomendados | `gen_ai.request.temperature`, `gen_ai.response.model`, `gen_ai.response.finish_reasons`, `gen_ai.usage.input_tokens`, `gen_ai.usage.output_tokens`, `server.address`, `server.port` |
| Si hay error | `error.type` (por ejemplo `404` o `timeout`) y estado `ERROR` |
| Opt-in | `gen_ai.input.messages`, `gen_ai.output.messages` (con datos personales probables) |
| Métricas | `gen_ai.client.inference.duration` (histograma, `s`), `gen_ai.client.inference.operation.input_tokens` y `.output_tokens` (histogramas, `{token}`) |

## 1. Entorno y tests

Desde esta carpeta:

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe -m unittest -v test_trazas
```

Orden recomendado: `luhn_valido` → `redactar` → `redactar_valor` → `atributos_peticion` → `atributos_respuesta` → `mensajes` → `preguntar_con_traza`. Cuando pasen los 17:

```powershell
.\.venv\Scripts\python.exe ..\..\ejercicios\ronin_check.py E4-02
```

Y en el Dojo: `evidence import`.

## 2. Medir qué se escapa, con el modelo real

Con Ollama en marcha y `llama3.2:1b` descargado:

```powershell
.\.venv\Scripts\python.exe bateria.py
```

Seis mensajes con datos personales inventados («apunta mi correo y repítemelo») y cuatro legítimos, dos veces cada uno, con cuatro configuraciones:

| Configuración | Contenido en el span | Exportador |
|---|---|---|
| `ninguna` | crudo | normal |
| `redaccion` | redactado por tu código | normal |
| `exportador` | crudo | redacta todos los atributos antes de escribir |
| `sin-contenido` | no se registra | normal |

Cada fila muestra:
- **fugas al fichero**: datos personales encontrados en el fichero de trazas exportado (se buscan aunque cambien los espacios, los puntos o los guiones);
- **eco del modelo**: datos que el modelo repitió en su respuesta. Con temperatura 0,7 varía entre repeticiones;
- **legítimas útiles**: spans completos (atributos obligatorios, modelo y tokens) en los que, si se guardó el contenido, la redacción no se comió datos que no eran personales: el número de pedido, el lote, la fecha.

Los ficheros quedan en `trazas/`: ábrelos y busca tú. Dos de los datos están escritos en formatos que tus expresiones regulares no reconocen, a propósito. La medición se guarda en `forja/evidencias/E4-02-medicion.json`; en el Dojo, `evidence import`.

## 3. Desplegarlo (opcional, con Docker)

```powershell
docker compose up -d --build
docker compose exec ollama ollama pull llama3.2:1b
docker compose exec trazas tail -n 1 /app/trazas/servicio.jsonl
```

Por defecto, `CONTENIDO=no` y `REDACTOR=1`: el contenido no se registra y, si alguien lo activa o añade un atributo por su cuenta, el exportador redacta antes de escribir. Las trazas se guardan en un volumen: quien lo lea, lee lo que haya en ellas.

## Qué está simplificado

- Un exportador a fichero y sin colector. En producción, el SDK envía por OTLP a un **OpenTelemetry Collector**, que puede redactar otra vez (procesadores `attributes` y `redaction`) antes de mandarlo al almacén de trazas. Si montas uno en local, publica sus puertos solo en `127.0.0.1`.
- La redacción con expresiones regulares solo encuentra formatos conocidos. Los sistemas reales combinan reglas, diccionarios y modelos de reconocimiento de entidades (NER), y aun así se les escapan datos. Lo más seguro sigue siendo no registrar el contenido.
- `SimpleSpanProcessor` exporta cada span al cerrarse y bloquea mientras escribe. En producción se usa `BatchSpanProcessor`.
- Un solo span por petición. Un agente o un RAG generan un árbol de spans (recuperación, herramientas, varias inferencias) unidos por el mismo `trace_id`.
- Los mensajes se guardan como valores estructurados (*AnyValue*), como piden las convenciones. Algunos almacenes de trazas todavía no los admiten y los convierten en texto JSON.

## Referencias (consultadas el 2026-11-10)

- [OpenTelemetry · Semantic conventions for generative AI](https://github.com/open-telemetry/semantic-conventions-genai): documentos *Client Inference*, *Inference Token Metrics* y *GenAI spans* (estado Development, rama `main` del 2026-11-06).
- [OpenTelemetry Python](https://opentelemetry.io/docs/languages/python/) · `opentelemetry-api` y `opentelemetry-sdk` 1.45.2 en [PyPI](https://pypi.org/project/opentelemetry-sdk/).
- [OWASP Top 10 for LLM Applications 2025](https://genai.owasp.org/llm-top-10/): LLM02 Sensitive Information Disclosure.
- [Reglamento (UE) 2016/679 (RGPD)](https://eur-lex.europa.eu/eli/reg/2016/679/oj), artículos 5.1.c (minimización de datos) y 25 (protección de datos desde el diseño y por defecto).
- H. P. Luhn, *Computer for verifying numbers*, patente US 2,950,048 (1960): el algoritmo de comprobación de las tarjetas.
