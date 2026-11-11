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
- **Contenido jugable:** 75 misiones, todas con el patrón de acompañamiento: «para qué sirve» al empezar, «Por qué:» en cada paso, comprobaciones de comprensión con explicación y un cierre «Qué puedes hacer ya». Muchas incluyen un paso guiado de Python en el editor del Dojo (mini-Python propio, sin acceso al sistema). Tras cada unidad de fundamentos hay una misión aplicada (T1-03, T2-02, T3-03, T4-03, T5-03, T6-03). Comando `mapa`: el temario y dónde estás. **Todo se puede jugar dentro del Dojo, sin instalar nada:** los pasos de la Forja tienen un ejercicio guiado en el editor del Dojo y `forja medir` reproduce mediciones reales ya grabadas con un modelo local; programar el laboratorio completo y medir en tu máquina (Python, Ollama) es un extra opcional. `aka <SIGLA>` explica cada sigla.
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
  - Pista P0 · misiones P0-02 a P0-05 (Forja, Python): clases y NumPy (regresión logística en Python puro y vectorizada, con la comparación de tiempos), el MLP de XOR en matrices, texto en streaming con cuidado de Unicode (NFC frente a NFD, emojis, bytes frente a caracteres) y un generador de tokens con muestreo y límite de salida.
  - Laboratorio A3-04 (Forja, real): el agente de la trastienda de A3 con tool calling real (`tools` de Ollama `/api/chat`) y `llama3.2:3b` en CPU (el 1B acierta poco con herramientas); consultar pedidos, correo a un buzón local y reembolsos, con roles, memoria entre turnos y aprobación humana. Inyección indirecta por la nota de un pedido (salida de una herramienta) frente a validación de argumentos, permisos por rol, aprobación, spotlight, detección de exfiltración y límites de pasos; mide acciones privilegiadas pedidas frente a ejecutadas.
  - Laboratorio A4-04 (Forja, real): el almacén de A4 como servidor MCP de verdad con el SDK oficial de Python (`mcp`), transporte Streamable HTTP y autorización por token y scopes, solo en `127.0.0.1`; tool poisoning, rug pull, permisos excesivos, path traversal y confusión de audiencia del token frente a validación de argumentos, scopes mínimos, saneado de rutas, huella de las definiciones y comprobación de audiencia (RFC 8707); la medición separa lo que paró el host de lo que paró el servidor.
  - Laboratorio A6-04 (Forja, real, defensivo): un verificador de artefactos de IA en Python. Lee pickles con `pickletools` sin cargarlos nunca (imports fuera de una lista permitida, memoria ofuscada, zips al estilo PyTorch), valida la cabecera y los offsets de los safetensors (políglotas, solapes), compara cada SHA-256 con un AI-BOM CycloneDX 1.7, detecta dependencias sin fijar, inventadas o recién publicadas y revisa Dockerfiles (root, secretos en ENV o ARG, imágenes sin versión). La batería mide la detección y los falsos positivos de cada control sobre 33 artefactos inofensivos; el Dojo importa la medición.
  - Especialización E1 (investigación ML, Forja, real en CPU): PyTorch y Transformers con SmolLM2-135M. E1-01, el bucle de generación token a token con temperatura y top-p sobre los logits, comparado con `model.generate()`; E1-02, cuantización int8 a mano (escala y punto cero, y por bloques como Q8_0 de GGUF) con su error, tamaño y perplejidad frente a los ficheros de Ollama; E1-03, LoRA de juguete sobre las capas de atención y la lente de logits capa a capa, con las cuentas de por qué el fine-tuning real requiere GPU.
  - Especialización E2 (ML adversarial, Forja, real y en CPU, contra modelos propios en NumPy y scikit-learn): E2-01 ejemplos adversarios con FGSM sobre un clasificador de dígitos, precisión frente a epsilon, entrenamiento adversario y detección por compresión de la entrada con su coste; E2-02 extracción de un modelo servido con FastAPI en `127.0.0.1` solo con consultas (por ecuaciones y con un sustituto), acuerdo frente al número de consultas, redondeo, solo etiqueta y límite por clave; E2-03 inferencia de pertenencia por umbral de pérdida con modelo sombra (ventaja TPR − FPR, ROC) contra un modelo sobreajustado, uno regularizado y DP-SGD, y media con privacidad diferencial (Laplace y gaussiano) frente a ε; relación con LLM02 y con el Dictamen 28/2024 del CEPD.
  - Laboratorio A1-06 (Forja, real): el juez. Un LLM local puntúa las respuestas del mostrador con una rúbrica, con plantillas y parseo robusto de la nota. Se mide su acuerdo con etiquetas humanas (kappa de Cohen con intervalo bootstrap) y sus sesgos de posición y de longitud y la inyección al evaluador, con el intercambio de A y B como mitigación. Incluye un test de regresión de prompts con conjunto de referencia y línea base.
  - Laboratorio A1-07 (Forja, real): el guardián entrenado. Un clasificador de inyecciones Naive Bayes sobre n-gramas de caracteres, escrito en Python puro con un dataset sintético. Se miden sus falsos positivos y negativos, la curva de umbral y la evasión con paráfrasis, separadores, inglés y relleno, frente al filtro de patrones de A1-05 y, si se quiere, un LLM local como clasificador.
  - Laboratorio A2-05 (Forja, real): inyección a través de lo que la ingesta extrae y nadie ve: CSS oculto, texto blanco, comentarios y `alt` en HTML; texto PDF invisible o blanco y metadatos (pypdf); caracteres Unicode de etiqueta, de ancho cero y de ancho completo. Extracción consciente de la visibilidad, limpieza de invisibles y NFKC medidas en el índice, el contexto y la respuesta, con su coste en documentos legítimos; imágenes con `qwen3-vl:2b` (opcional).
  - Laboratorio A2-06 (Forja, real): reranking en dos etapas sobre la búsqueda híbrida de A2-04 con un cross-encoder multilingüe en CPU (mMiniLMv2, ONNX int8) y `llama3.2:1b` como puntuador; recall@k, MRR, nDCG@k y latencia p50/p95; documentos escritos para posicionarse (relleno, preguntas copiadas, respuestas falsas fluidas, inyección al puntuador) frente a procedencia.
  - Capstones C1–C3 (AI Agent Lab, RAG Security Lab, MCP Security Lab): comandos `lab` que miden cada defensa en solitario (matriz) y cada combinación (resiliencia); cobertura mínima sin coste, ataques frágiles y robustos, riesgo residual y defensas que no suman. C4 (multiagente) va a la ruta de estudio externo, como A5.
  - Prueba final C5 (AI Red Team Assessment): encargo completo sobre una empresa ficticia; reglas de enfrentamiento y alcance, reconocimiento, modelo de amenazas OWASP, hallazgos respaldados por las baterías de A1–A6, informe, corrección y retest sin romper las tareas legítimas.
  - Especialización E3 (gobernanza y auditoría profesional, 100 % Dojo): la evaluación de impacto en los derechos fundamentales del AI Act (art. 27) y la EIPD del RGPD (art. 35) sobre un sistema ficticio de ayudas sociales de alto riesgo, quién hace cada una y cuándo; auditoría interna por muestreo de controles del NIST AI RMF con evidencias y expedientes elegidos al azar, no conformidades mayores, menores y observaciones; informe con criterio, evidencia, riesgo, recomendación y seguimiento corregido con una rúbrica, y cierre solo con evidencia.
  - Especialización E4 (AI Ops avanzado, Forja, real), sobre el servicio de P0-01: serving bajo carga en CPU con límite por cliente (cubo de tokens), caché con clave normalizada, cola acotada, plazo y respuesta degradada, medidos con un generador de carga (p50, p95 y throughput; LLM10); trazas y métricas con OpenTelemetry y las convenciones de GenAI (estado Development), con redacción de datos personales medida contra el modelo real; política de despliegue como código (huella del modelo en una lista permitida, sin root, con límites, sin puertos en todas las interfaces, imagen fijada) y canary con rollback según errores y p95.
- **Ruta de estudio externo:** O1–O4, A5 y C4 no tienen misión; se estudian con referencias oficiales en su punto del temario (se desbloquean con sus requisitos y se marcan con `lecturas hecho`). En el Dojo: comando `lecturas`; con enlaces clicables: [`LECTURAS.md`](LECTURAS.md), que también recoge las lecturas de cada misión.
- **En cada misión:** lecciones antes de cada objetivo, pistas en 5 niveles, prueba de dominio y debrief.
- **Gamificación:** 18 sellos (logros), rangos Initiate→Master, retos rápidos con solución paso a paso, notificaciones y barra de XP.
- **Ejercicios Python:** 24 en `forja/ejercicios/` (P0-02 y P0-03 con NumPy) y 18 laboratorios reales en `forja/labs/` (P0-01; A1-05, A1-06, A1-07; A2-04, A2-05, A2-06; A3-04; A4-04; A6-04; E1-01…03; E2-01…03; E4-01…03), con guía de Python (`PYTHON.md`) y pistas (`PISTAS.md`). `python -m ronin_check <ID>` genera la evidencia y el Dojo la importa con `evidence import`.
- **Siguiente paso:** probar los laboratorios con Ollama y Docker reales y jugar el Dojo de principio a fin (validación de la fase 2).

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
