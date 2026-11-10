# A1-05 · El mostrador de verdad

**Misión del Dojo:** A1-05 (requiere A1-04 y P0-01). Laboratorio real de la Forja.

El mostrador de la forja ficticia Kurogane, ahora con un modelo de verdad (`llama3.2:1b` en tu CPU). Su prompt de sistema contiene un dato de prueba, el canario `KUROGANE-77`, como en A1-01…04. Lo atacas con una batería pequeña de técnicas públicas de fuga del prompt de sistema (OWASP LLM07) e inyección directa (LLM01), pruebas defensas y **mides**: cuántas veces se filtra con cada una, con su intervalo de confianza, y cuánto cuesta en las preguntas legítimas.

**Este servicio es vulnerable a propósito.** Todo es ficticio y escucha solo en `127.0.0.1`.

| Pieza | Quién la escribe |
|---|---|
| `normalizar`, `contiene_secreto`, `filtrar_entrada`, `filtrar_salida`, `delimitar`, `intervalo_wilson` en `chatbot.py` | **Tú** |
| `responder` (la tubería), la aplicación FastAPI, `bateria.py`, `ataques.json`, Docker | Claude |
| `test_chatbot.py` (19 tests con un modelo simulado) | Claude |

## 1. Entorno y tests

Igual que en P0-01, desde esta carpeta:

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe -m unittest -v test_chatbot
```

Cuando pasen los 19, la evidencia:

```powershell
.\.venv\Scripts\python.exe ..\..\ejercicios\ronin_check.py A1-05
```

Y en el Dojo: `evidence import`.

## 2. Medir contra el modelo real

Con Ollama en marcha y `llama3.2:1b` descargado (README de P0-01, sección 3):

```powershell
.\.venv\Scripts\python.exe bateria.py
```

Por defecto mide 5 configuraciones (`ninguna`, `entrada`, `entrada,salida`, `delimitar` y `sin-secreto`) con 3 repeticiones de cada mensaje: 165 mensajes, varios minutos en CPU. Para ir más rápido:

```powershell
.\.venv\Scripts\python.exe bateria.py --n 2 --configs "ninguna;salida;sin-secreto"
```

Cada fila muestra:
- **fugas**: veces que el canario llegó al cliente, con su intervalo de confianza al 95 %;
- **el modelo filtró**: veces que el modelo lo generó, aunque después un filtro lo retuviera;
- **legítimas**: preguntas normales bien respondidas (detecta defensas que rompen el servicio).

La medición se guarda en `forja/evidencias/A1-05-medicion.json`. En el Dojo, `evidence import`. El Dojo comprueba que `ataques.json` no se ha modificado; si quieres probar ataques propios, hazlo en una copia y no la importes.

## 3. Pruébalo a mano (opcional)

```powershell
$env:DEFENSAS = "entrada,salida"
.\.venv\Scripts\python.exe -m uvicorn chatbot:app --host 127.0.0.1 --port 8000
```

Las defensas se fijan al arrancar: un cliente no debe poder elegir qué defensas se le aplican. Con Docker: `docker compose up -d --build` (cambia `DEFENSAS` en `compose.yaml`).

## Qué está simplificado

- Seis ataques fijos y básicos; una evaluación real usa cientos y variados.
- Una respuesta legítima se da por buena si contiene ciertas palabras clave.
- Un solo modelo pequeño: con otro modelo, las tasas cambian. Esa es justo la lección.

## Referencias (consultadas el 2026-11-10)

- [OWASP Top 10 for LLM Applications 2025](https://genai.owasp.org/llm-top-10/): LLM01 inyección de prompts y LLM07 fuga del prompt de sistema.
- [Ollama · API `/api/chat`](https://docs.ollama.com/api/chat).
- Intervalo de Wilson: E. B. Wilson, «Probable Inference, the Law of Succession, and Statistical Inference», *Journal of the American Statistical Association* 22 (1927), 209–212.
