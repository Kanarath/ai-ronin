# 06 — Roadmap y primer hito jugable

Cada fase termina con algo **jugable o verificable**. En cada una, el reparto es el mismo:
- Yo explico la arquitectura y los conceptos de Godot.
- Tú implementas las piezas marcadas con 🛠.
- Yo reviso tu trabajo.

## Fases

| Fase | Entregable | Tú implementas 🛠 | Conceptos de Godot |
|---|---|---|---|
| **0. Cimientos** | Proyecto Godot en `game/`, runner de tests, test de aislamiento, tema base, CI en GitHub Actions | El runner de tests (guiado) | Proyecto, `class_name`, `SceneTree` en modo headless |
| **1. Núcleo v0.1** | Hito jugable: ver más abajo | Comandos `dataset` y `distance`; el algoritmo k-NN | Señales, autoloads, `Control`, `Theme`, `RichTextLabel`, `_draw()` |
| **2. Validación educativa** | Juegas v0.1 de principio a fin y ajustamos el ritmo, las pistas y la dificultad | Ajustes de contenido en JSON | — |
| **3. Tronco completo** | T3–T6 con sus visualizaciones (gradiente, MLP, BPE, atención, sampling) | Backpropagation en el MLP y el sampler | `Tween`, rendimiento, `PackedFloat32Array` |
| **4. Forja + P0** | Instalar Python y Docker; pista P0 con ejercicios autocorregidos; formato `evidence.json` y su importador | Ejercicios de Python | `FileDialog`, validación de esquemas |
| **5. Arco A1** | Chatbot: las 4 fases en el Dojo y en la Forja (LLM local en CPU); O1 y O4 | API FastAPI y las defensas | Motor de respuestas simulado |
| **6. Arco A2 + C2** | RAG y embeddings; RAG Security Lab | Chunking y retrieval | Visualización de espacios vectoriales |
| **7. Arco A3 + C1 + O3** | Agentes; AI Agent Lab; threat modeling | Bucle del agente y autorización | Editor de `FlowGraph` |
| **8. Arco A4 + C3** | MCP (servidor real en la Forja) | Servidor MCP con el SDK oficial | — |
| **9. Arcos A5, A6 + C4** | Multiagente, A2A, supply chain e infraestructura | Firma de mensajes y pipeline de CI | — |
| **10. C5 + O5** | Evaluación final y marcos de gobernanza | Informe profesional completo | Exportación del ejecutable |
| **∞. Especializaciones** | E1–E4 según tu interés | — | — |

Después de cada fase hay una refactorización y una revisión de los tests.
Antes de escribir el contenido de cada arco se revisan las referencias (versiones y fechas).

---

## Primer hito jugable — v0.1 «Despertar en el Dojo»

### Objetivo
Validar **dos cosas**:
1. **El motor:** terminal, misiones, mentor, progreso y guardado, de punta a punta.
2. **La pedagogía:** comprobar si de verdad aprendes con el formato «predice → ejecuta → explica» y la escalera de pistas.

### Alcance

**Sistemas:**
- Hub con 4 paneles y terminal acoplado.
- `ContentDB`, que carga y valida el JSON.
- Terminal de nivel 0–1: comandos simples y con flags. Ayuda completa: `help`, `--help`, `man`, `cheatsheet`, `explain`, `hint`, `?`, historial y Tab.
- `MissionService` con los validadores `event`, `state`, `sequence`, `answer` y `prediction`.
- Mentor con escalera de 5 niveles, diagnósticos y preguntas de predicción.
- Maestría (4 estados) y XP con rendimientos decrecientes.
- Guardado atómico versionado.
- Visualizaciones `ScatterPlot` y `ConfusionMatrix`, esta última solo como vista previa.
- Tests del parser, de k-NN, de las métricas, de los validadores, del guardado y del aislamiento.

**Contenido (dataset ficticio y sintético: «Forja de katanas»):**
Cada hoja tiene dureza, flexibilidad y temperatura de temple. Hay que clasificarla como `apta` o `defectuosa`.

| Misión | Nivel | Qué aprendes | Lo que pasa en el laboratorio |
|---|---|---|---|
| **T1-01 Despertar en el Dojo** | Initiate | Uso del terminal, dataset, feature, label, ejemplo como vector | `dataset list`, `dataset inspect katanas`, `dataset stats`. Predices qué feature separa mejor las clases y lo compruebas en el scatter. |
| **T1-02 La distancia entre dos hojas** | Initiate | Distancia euclídea, escalas distintas, normalización | Mides distancias y descubres que la temperatura «domina» por su escala. Normalizas y lo vuelves a medir. 🛠 Implementas `distance` en GDScript. |
| **T2-01 El vecino más cercano** | Apprentice | k-NN, train/test, accuracy, overfitting (k=1 frente a k grande) y fuga de datos | 🛠 Implementas el algoritmo k-NN. Entrenas, predices y evalúas en test. Caes en un error productivo (evaluar con los datos de entrenamiento) y lo diagnosticas. Barres k y lo explicas. |

Cada misión trae su prueba de dominio. T2-01 trae además una variante de transferencia con otro dataset sintético.

### Fuera de alcance en v0.1
- Pipes y scripts del terminal.
- Forja.
- Logros.
- Revisiones espaciadas (solo la estructura de datos).
- Árbol de habilidades visual.
- Sonido.
- Exportación del ejecutable.

### Criterios de aceptación
1. Se completan las 3 misiones sin tocar código, solo jugando.
2. Ninguna misión es de opción múltiple. Todos los objetivos se validan sobre lo que **hiciste**.
3. Pedir pistas reduce la maestría según la tabla de [04](04-especificacion-misiones.md). El nivel 5 exige confirmación.
4. Cerrar y reabrir la app conserva el progreso. Un guardado corrupto se recupera desde el `.bak`.
5. Todos los tests pasan en modo headless, incluido el test de aislamiento.
6. `help`, `man`, `cheatsheet` y `explain` funcionan desde cualquier pantalla.
7. Tú puedes explicar con tus palabras:
   - Por qué k=1 sobreajusta.
   - Qué es la fuga de datos.
   - Por qué se normalizan los datos.

### Orden de construcción (propuesto)
1. Cimientos: proyecto, runner de tests y test de aislamiento.
2. `ContentDB` y el esquema de misión.
3. Lexer y parser, con sus tests.
4. Registro de comandos y ayuda.
5. `TerminalView`.
6. Simulación: `Dataset`, `Vec`, `KNN` (🛠) y métricas.
7. `MissionService` y validadores.
8. Mentor.
9. Progreso y guardado.
10. Hub y visualizaciones.
11. Contenido de las 3 misiones.
12. Partida de prueba.
