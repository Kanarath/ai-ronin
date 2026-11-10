# A2-04 · La biblioteca de verdad

**Misión del Dojo:** A2-04 (requiere A2-03 y A1-05). Laboratorio real de la Forja.

La biblioteca de la forja ficticia Kurogane, ahora con piezas de verdad. Los documentos se trocean, `embeddinggemma` los convierte en vectores (con Ollama, en tu CPU) y se guardan en Qdrant. Para responder, `llama3.2:1b` recibe los fragmentos recuperados. Son los mismos documentos de A2-01…03, más dos que ha dejado un cliente:

- `resena-7`: una reseña con una instrucción escondida para el asistente (inyección indirecta, OWASP LLM01).
- `foro-12`: un mensaje de foro con un dato falso sobre la garantía (envenenamiento, LLM04). Dice venir de la forja, pero su firma es falsa.

Hay además dos documentos internos (`costes` y `proveedores`) que un cliente no debería ver (LLM08).

**Este servicio es vulnerable a propósito.** Todo es ficticio y escucha solo en `127.0.0.1`.

| Pieza | Quién la escribe |
|---|---|
| `trocear`, `bm25`, `fusion_rrf`, `recall_en_k`, `filtro_acceso`, `firmar`, `verificar_firma`, `ensamblar_contexto` en `rag.py` | **Tú** |
| `Biblioteca` (ingesta y búsqueda en Qdrant), `responder`, la aplicación FastAPI, `bateria.py`, `ataques.json`, Docker | Claude |
| `test_rag.py` (20 tests con modelos simulados y Qdrant en memoria) | Claude |

## 1. Entorno y tests

Desde esta carpeta:

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe -m unittest -v test_rag
```

Los tests no necesitan ni Ollama ni Docker: Qdrant funciona en memoria, dentro del propio proceso. Cuando pasen los 20:

```powershell
.\.venv\Scripts\python.exe ..\..\ejercicios\ronin_check.py A2-04
```

Y en el Dojo: `evidence import`.

## 2. Medir contra los modelos reales

Con Ollama en marcha (README de P0-01, sección 3), descarga también el modelo de embeddings (622 MB):

```powershell
ollama pull embeddinggemma
.\.venv\Scripts\python.exe bateria.py
```

Primero indexa los documentos y mide el **recall@3** de cada modo de búsqueda (vectorial, BM25 e híbrida), como empleado y sin defensas. Después mide 5 configuraciones (`ninguna`, `acl`, `procedencia`, `spotlight` y las tres juntas) con 3 repeticiones de cada pregunta: 165 mensajes, varios minutos en CPU. Para ir más rápido:

```powershell
.\.venv\Scripts\python.exe bateria.py --n 2 --configs "ninguna;acl;acl,procedencia,spotlight"
```

Cada fila muestra:
- **éxito**: veces que el ataque consiguió su efecto en la respuesta, con su intervalo de confianza al 95 %;
- **en contexto**: veces que el documento del ataque llegó al modelo, lo siguiera o no;
- **legítimas**: preguntas normales bien respondidas (detecta defensas que rompen el servicio; una de ellas la hace un empleado).

Debajo, el desglose por categoría: inyección, envenenamiento y fuga por falta de ACL. La medición se guarda en `forja/evidencias/A2-04-medicion.json`. En el Dojo, `evidence import`. El Dojo comprueba que `ataques.json` no se ha modificado.

## 3. Desplegarlo (opcional, con Docker)

```powershell
$env:QDRANT_API_KEY = "<una clave larga y aleatoria>"
docker compose up -d --build
docker compose exec ollama ollama pull llama3.2:1b
docker compose exec ollama ollama pull embeddinggemma
docker compose restart biblioteca
```

Pregunta como cliente (el rol sale del token, no de lo que diga la petición):

```powershell
Invoke-RestMethod -Method Post http://127.0.0.1:8000/preguntar -ContentType "application/json" `
  -Headers @{ Authorization = "Bearer token-cliente-lab" } -Body '{"pregunta": "¿Qué garantía tienen las katanas?"}'
```

Fíjate en tres decisiones de `compose.yaml`:
- Qdrant **sin configurar no tiene autenticación y escucha en todas las interfaces**. Aquí lleva API key, que pasas por variable de entorno y nunca escribes en el fichero, y solo se publica en `127.0.0.1`.
- Quien lea la colección lee los vectores. Y de un vector se puede reconstruir buena parte del texto original (A2-02). Por eso los embeddings se protegen como los propios documentos.
- Dentro de la red de compose, el tráfico va sin TLS. En producción, también TLS.

## Qué está simplificado

- Seis ataques fijos y cinco preguntas legítimas: una evaluación real usa muchos más.
- La «firma» es un HMAC con una clave de laboratorio escrita en `rag.py`. En producción, la clave vive en un gestor de secretos o se usan firmas asimétricas, y se firma en el sistema que publica el documento.
- Los tokens de cliente y empleado son fijos. En producción, el rol sale de tu sistema de identidad.
- BM25 se calcula en memoria sobre todos los fragmentos. Un sistema real usa un índice léxico (Qdrant admite vectores dispersos, y existen motores de búsqueda dedicados).

## Referencias (consultadas el 2026-11-10)

- [OWASP Top 10 for LLM Applications 2025](https://genai.owasp.org/llm-top-10/): LLM01 inyección de prompts, LLM04 envenenamiento de datos y LLM08 debilidades de vectores y embeddings.
- [Qdrant · Security](https://qdrant.tech/documentation/security/) (versión 1.20.0).
- [Ollama · API `/api/embed`](https://docs.ollama.com/api/embed) y [modelo embeddinggemma](https://ollama.com/library/embeddinggemma).
- S. Robertson, H. Zaragoza, «The Probabilistic Relevance Framework: BM25 and Beyond», *Foundations and Trends in Information Retrieval* (2009). [doi:10.1561/1500000019](https://doi.org/10.1561/1500000019)
- G. V. Cormack, C. L. A. Clarke, S. Büttcher, «Reciprocal rank fusion outperforms Condorcet and individual rank learning methods», SIGIR 2009, 758–759. [doi:10.1145/1571941.1572114](https://doi.org/10.1145/1571941.1572114)
- [RFC 2104 · HMAC](https://www.rfc-editor.org/rfc/rfc2104) (1997).
- K. Hines et al., «Defending Against Indirect Prompt Injection Attacks With Spotlighting», [arXiv:2403.14720](https://arxiv.org/abs/2403.14720) (2024).
