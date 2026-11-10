# AI RONIN

> «No te limites a usar la IA. Entiéndela, constrúyela, desafíala y protégela.»

AI RONIN es una academia interactiva de **AI Engineering, AI Security / Red Teaming y AI Operations**, construida en Godot 4 con GDScript.

El proyecto tiene dos planos:

| Plano | Qué es | Dónde | Restricciones |
|---|---|---|---|
| **El Dojo** | La aplicación Godot: hub de laboratorio, terminal ficticio, mentor RONIN, simulaciones y ML real en GDScript | `game/` | Offline, aislada, sin red, sin ejecutar código del sistema |
| **La Forja** | Laboratorios reales en Python, Docker y modelos locales (siempre en localhost) | `forja/` | Solo en tu máquina; el Dojo nunca la ejecuta, solo importa evidencias |

## Estado

- Diseño aprobado el 2026-11-06.
- Fase 0 (cimientos) completada: proyecto Godot y tests. Los tests se ejecutan en local; el repositorio no usa GitHub Actions.
- **Contenido jugable:** 49 misiones.
  - Tutorial T0.
  - Tronco común T1–T6: datos, k-NN, descenso por gradiente, métricas, redes neuronales con backprop, tokens BPE, embeddings, modelo de lenguaje, muestreo y atención.
  - Arco de seguridad A1 completo (construir, atacar, defender y desplegar un chatbot), con informes de vulnerabilidad.
  - Arco A2 (RAG y embeddings): construir un RAG con índice TF-IDF real; inyección indirecta, envenenamiento, fuga sin control de acceso e inversión de embeddings; defensas en capas.
  - Arco A3 (agentes): agente con herramientas y memoria; secuestro del objetivo, exfiltración, confused deputy, envenenamiento de memoria y bucles; controles en el código frente a spotlight y supervisión humana.
  - Arco A4 (MCP): host MCP simulado con mensajes JSON-RPC; envenenamiento de herramientas, rug pull, shadowing, token passthrough e inyección por la salida; huellas, espacios de nombres, tokens mínimos y aislamiento frente al consentimiento del usuario.
  - Arco A5 (multiagente): sin misiones; se estudia en la ruta de estudio externo. El taller A2A simulado (comandos `a2a`) sigue disponible en el terminal.
  - Arco A6 (supply chain e infraestructura): pipeline de ML simulado con AI-BOM; dataset envenenado, pickle con código, adapter manipulado, paquete inventado, API expuesta, contenedor root y secreto en la imagen; un control por eslabón.
  - Pista de oficio O5 (marcos y gobernanza): AI Act (con el aplazamiento del Digital Omnibus), NIST AI RMF e ISO/IEC 42001, qué es cada uno y qué no; clasificación de sistemas por nivel de riesgo, requisitos de alto riesgo y registro de riesgos con apetito y tratamientos.
  - Pista de oficio O6 (detección y respuesta): registro de trazas de un agente; qué registrar sin guardar datos personales, reglas de detección medidas con precision y recall, correlación de señales, respuesta a un incidente de inyección indirecta con exfiltración y notificación al DPD.
  - Pista P0 · laboratorio P0-01 (Forja, real): servicio FastAPI con un LLM local en CPU (Ollama, `llama3.2:1b`), cliente HTTP asíncrono, Docker Compose solo en `127.0.0.1` y medición del no determinismo del modelo.
  - Laboratorio A1-05 (Forja, real): el mostrador de A1 con el modelo local y un canario en el prompt de sistema; batería de fuga del prompt (LLM07) e inyección directa (LLM01), defensas medidas con repeticiones e intervalos de Wilson y su coste en preguntas legítimas. El Dojo importa la medición (`bateria.py`).
  - Laboratorio A2-04 (Forja, real): la biblioteca de A2 con embeddings reales (`embeddinggemma`), Qdrant y el modelo local; troceo, BM25 y búsqueda híbrida con RRF medidas con recall@k; inyección indirecta, envenenamiento y fuga por falta de ACL frente a control de acceso, firma HMAC de documentos y spotlight; Qdrant con API key solo en `127.0.0.1`.
  - Laboratorio A2-05 (Forja, real): inyección a través de lo que la ingesta extrae y nadie ve: CSS oculto, texto blanco, comentarios y `alt` en HTML; texto PDF invisible o blanco y metadatos (pypdf); caracteres Unicode de etiqueta, de ancho cero y de ancho completo. Extracción consciente de la visibilidad, limpieza de invisibles y NFKC medidas en el índice, el contexto y la respuesta, con su coste en documentos legítimos; imágenes con `qwen3-vl:2b` (opcional).
  - Laboratorio A2-06 (Forja, real): reranking en dos etapas sobre la búsqueda híbrida de A2-04 con un cross-encoder multilingüe en CPU (mMiniLMv2, ONNX int8) y `llama3.2:1b` como puntuador; recall@k, MRR, nDCG@k y latencia p50/p95; documentos escritos para posicionarse (relleno, preguntas copiadas, respuestas falsas fluidas, inyección al puntuador) frente a procedencia.
  - Capstones C1–C3 (AI Agent Lab, RAG Security Lab, MCP Security Lab): comandos `lab` que miden cada defensa en solitario (matriz) y cada combinación (resiliencia); cobertura mínima sin coste, ataques frágiles y robustos, riesgo residual y defensas que no suman. C4 (multiagente) va a la ruta de estudio externo, como A5.
  - Prueba final C5 (AI Red Team Assessment): encargo completo sobre una empresa ficticia; reglas de enfrentamiento y alcance, reconocimiento, modelo de amenazas OWASP, hallazgos respaldados por las baterías de A1–A6, informe, corrección y retest sin romper las tareas legítimas.
- **Ruta de estudio externo:** O1–O4, A5 y C4 no tienen misión; se estudian con referencias oficiales en su punto del temario (se desbloquean con sus requisitos y se marcan con `lecturas hecho`). En el Dojo: comando `lecturas`; con enlaces clicables: [`LECTURAS.md`](LECTURAS.md), que también recoge las lecturas de cada misión.
- **En cada misión:** lecciones antes de cada objetivo, pistas en 5 niveles, prueba de dominio y debrief.
- **Gamificación:** 18 sellos (logros), rangos Initiate→Master, retos rápidos con solución paso a paso, notificaciones y barra de XP.
- **Ejercicios Python:** 19 en `forja/ejercicios/` y 5 laboratorios reales en `forja/labs/` (P0-01, A1-05, A2-04, A2-05 y A2-06), con guía de Python (`PYTHON.md`) y pistas (`PISTAS.md`). `python -m ronin_check <ID>` genera la evidencia y el Dojo la importa con `evidence import`.
- **Siguiente paso:** laboratorios de la Forja para el resto de arcos (A3: agente real con herramientas) y, después, especializaciones E1–E4.

### Jugar

Abre `game/project.godot` con Godot 4.7 y pulsa F5, o ejecuta:

```powershell
& "C:\Users\Ruben\Desktop\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe" --path game
```

**Alcance del aprendizaje:** solo IA. La plataforma Godot la construye Claude y no forma parte de la formación. Tus ejercicios se escriben en Python, en `forja/ejercicios/`.

### Ejecutar los tests de la plataforma

```powershell
& "C:\Users\Ruben\Desktop\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path game -s res://tests/run_tests.gd
```

## Documentación

1. [PRD — Documento de requisitos de producto](docs/01-PRD.md)
2. [Arquitectura Godot](docs/02-arquitectura.md)
3. [Currículo y mapa de dependencias](docs/03-curriculo.md)
4. [Especificación de misiones](docs/04-especificacion-misiones.md)
5. [Diseño visual](docs/05-diseno-visual.md)
6. [Roadmap y primer hito jugable](docs/06-roadmap.md)

## Requisitos

- Godot 4.7.x (estable)
- Fase Forja: Python 3.12+ y Docker Desktop (con WSL2). Todavía no hacen falta.
