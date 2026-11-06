# 06 — Roadmap y primer hito jugable

Cada fase termina con algo **jugable o verificable**.

**Reparto del trabajo:**
- **Claude** construye la plataforma Godot: motor, UI, terminal, guardado, tests y CI. Esto no es contenido formativo.
- **Tú** aprendes IA: juegas las misiones, haces los experimentos y escribes en Python los ejercicios 🛠.
- **Claude** revisa tus ejercicios y te hace preguntas de comprensión.

## Fases

| Fase | Plataforma (Claude) | Lo que aprendes tú (IA) | Tus ejercicios 🛠 (Python) |
|---|---|---|---|
| **0. Cimientos** ✅ | Proyecto Godot, runner de tests, test de aislamiento, tema y CI | — | — |
| **1. Núcleo v0.1** | Hub, terminal, misiones, mentor, progreso y guardado; k-NN interactivo | T1 y T2 (inicio): datos, vectores, distancia, normalización, k-NN, overfitting, fuga de datos | Distancia euclídea, normalización y k-NN desde cero |
| **2. Validación educativa** | Ajustes del motor según tu experiencia | Juegas v0.1 de principio a fin; ajustamos ritmo, pistas y dificultad | — |
| **3. Tronco completo** | Visualizaciones: gradiente, MLP, BPE, atención y sampling | T3–T6: optimización, métricas, redes neuronales, tokens, embeddings, transformers y LLM | Gradient descent, métricas, MLP con backprop, BPE, atención y sampling |
| **4. Forja** | Formato `evidence.json` e importador; plantillas Docker | P0 (cierre): HTTP, async, FastAPI, Docker básico, LLM local en CPU | Primer servicio con un LLM local |
| **5. Arco A1** | Chatbot simulado y motor de respuestas | Chatbot: construir, atacar, defender y desplegar; O1 y O4 | API de chat, ataques de inyección, defensas, informe |
| **6. Arco A2 + C2** | Base vectorial simulada y visualización de embeddings | RAG y embeddings; RAG Security Lab | Chunking, retrieval, envenenamiento, ACL |
| **7. Arco A3 + C1 + O3** | Simulación de agentes y `FlowGraph` | Agentes; AI Agent Lab; threat modeling | Bucle de agente, autorización, memoria |
| **8. Arco A4 + C3** | Simulación de MCP | MCP | Servidor MCP real (SDK oficial), vulnerable y endurecido |
| **9. Arcos A5, A6 + C4** | Simulación multiagente y supply chain | Multiagente, A2A, supply chain, infraestructura | Firma de mensajes, escaneo de artefactos, pipeline de CI |
| **10. C5 + O5 + O6** | Escenario empresarial final | Evaluación final; gobernanza; detección y respuesta | Informe profesional completo |
| **∞. Especializaciones** | — | E1–E4 según tu interés | — |

La pista **P0 · Python para IA** empieza en la Fase 1 y avanza en paralelo: cada ejercicio 🛠 introduce la parte de Python que necesita. Solo hace falta instalar Python. Docker no llega hasta la Fase 4.

Antes de escribir el contenido de cada arco se revisan las referencias (versiones y fechas).

---

## Primer hito jugable — v0.1 «Despertar en el Dojo»

### Objetivo
Validar dos cosas:
1. **La plataforma:** terminal, misiones, mentor, progreso y guardado, de punta a punta.
2. **La pedagogía:** comprobar si de verdad aprendes con «predice → ejecuta → explica», la escalera de pistas y los ejercicios en Python.

### Contenido
Dataset ficticio y sintético «Forja de katanas»: cada hoja tiene dureza, flexibilidad y temperatura de temple, y se clasifica como `apta` o `defectuosa`.

| Misión | Nivel | Qué aprendes | En el Dojo | 🛠 Tu ejercicio en Python |
|---|---|---|---|---|
| **T1-01 Despertar en el Dojo** | Initiate | Dataset, feature, label, ejemplo como vector | `dataset list`, `inspect` y `stats`; predices qué feature separa mejor las clases y lo compruebas en el scatter | Cargar el CSV y calcular media y desviación típica por columna, sin librerías |
| **T1-02 La distancia entre dos hojas** | Initiate | Distancia euclídea, escalas distintas, normalización | Descubres que la temperatura «domina» por su escala; normalizas y vuelves a medir | `distancia_euclidea()` y `normalizar_minmax()` / `normalizar_zscore()` |
| **T2-01 El vecino más cercano** | Apprentice | k-NN, train/test, accuracy, overfitting (k=1 frente a k grande), fuga de datos | Entrenas, predices y evalúas; caes en un error productivo (evaluar con los datos de entrenamiento) y lo diagnosticas; barres k | `knn_predecir()`, `accuracy()` y `train_test_split()` |

Cada misión trae su prueba de dominio. T2-01 trae además una variante de transferencia con otro dataset.

### Fuera de alcance en v0.1
- Pipes y scripts del terminal.
- Docker y LLM locales.
- Logros.
- Revisiones espaciadas (solo la estructura de datos).
- Árbol de habilidades visual.
- Sonido.
- Exportación del ejecutable.

### Criterios de aceptación
1. Se completan las 3 misiones jugando, sin tocar el código de la app.
2. Ninguna misión es de opción múltiple. Los objetivos se validan sobre lo que **hiciste**.
3. Las pistas reducen la maestría según la tabla de [04](04-especificacion-misiones.md). El nivel 5 exige confirmación.
4. El progreso se conserva al cerrar la app. Un guardado corrupto se recupera desde el `.bak`.
5. Todos los tests pasan, en local y en la CI.
6. `help`, `man`, `cheatsheet` y `explain` funcionan desde cualquier pantalla.
7. Tus ejercicios en Python pasan sus tests (`python -m unittest`). La importación de evidencias al Dojo llega en la Fase 4, junto con la Forja.
8. Puedes explicar con tus palabras:
   - Por qué k=1 sobreajusta.
   - Qué es la fuga de datos.
   - Por qué se normalizan los datos.
