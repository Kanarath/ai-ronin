# 01 — PRD: AI RONIN

| Campo | Valor |
|---|---|
| Versión del documento | 0.1 (borrador para aprobación) |
| Fecha | 2026-11-06 |
| Motor | Godot 4.7.x · GDScript |
| Idioma | Castellano, con la terminología técnica en inglés y un glosario |

---

## 1. Visión

AI RONIN es una plataforma de aprendizaje técnico para pasar de **usar** herramientas de IA a **comprenderlas, construirlas, desplegarlas, auditarlas y atacarlas** de forma profesional.

No es un curso con vídeos ni un juego de preguntas. Es un **laboratorio de investigación con estética ciberpunk y ronin**. En él manipulas sistemas (simulados o reales), formulas hipótesis, observas resultados y demuestras competencias.

### Principio rector

**Cada sistema se estudia desde sus cuatro caras: Construir → Atacar → Defender → Desplegar.** Atacas lo que has construido tú, lo defiendes y luego lo despliegas de forma segura.

## 2. Usuario objetivo

Un solo usuario principal: tú.

| Dimensión | Punto de partida | Implicación de diseño |
|---|---|---|
| Pentesting | Experiencia previa | La pista de oficio (metodología, informes) puede ir más rápido. Hay que reaprender el modelo de amenaza propio de la IA. |
| Desarrollo | Experiencia previa | Las tareas de implementación propias se hacen en **Python**, nunca en GDScript. |
| Python | Básico | Pista **P0 «Python para IA»** desde el principio, en paralelo al tronco común. |
| Matemáticas (álgebra lineal, cálculo, probabilidad) | Oxidadas | Se enseñan «justo a tiempo» dentro del tronco común, nunca como bloque teórico aislado. |
| ML e interioridades de los LLM | No se presupone | El tronco común es obligatorio. |

Hardware detectado: i5-13420H, 16 GB de RAM, gráfica integrada (sin GPU dedicada).
Implicaciones:
- En la Forja se usarán modelos de 1 a 3B cuantizados en CPU.
- El fine-tuning real (LoRA/QLoRA) se marca como «requiere entorno externo con GPU» y es opcional.

Perfiles profesionales de destino: AI Security Engineer, AI Red Teamer, AI Application Security Specialist, AI Security Researcher y AI Product Security Engineer.

## 3. Objetivos

| # | Objetivo | Cómo se mide |
|---|---|---|
| O1 | Comprender cómo funcionan por dentro el ML, las redes neuronales y los LLM | Pruebas de dominio del tronco común superadas sin pistas de nivel 3 o superior |
| O2 | Construir sistemas de IA funcionales: chatbot, RAG, agente, MCP y multiagente | Laboratorios de la fase «Construir» de cada arco, con criterios objetivos |
| O3 | Atacar esos sistemas con metodología profesional | Laboratorios de la fase «Atacar» y fichas de vulnerabilidad completas |
| O4 | Defenderlos y **verificar** que la mitigación funciona | Comparativa antes y después (tasa de éxito del ataque) |
| O5 | Entender y auditar despliegues reales | Laboratorios de la fase «Desplegar» en la Forja |
| O6 | Redactar informes de seguridad profesionales | Informes estructurados evaluados con rúbrica |
| O7 | Programar IA con tus manos, en Python (el lenguaje estándar de la industria) | Ejercicios 🛠 con tests automáticos superados |

> **Alcance del aprendizaje:** solo IA. Godot es la herramienta con la que se construye la plataforma, pero **no es contenido formativo**. Toda la infraestructura de la app (terminal, UI, guardado, tests) la desarrolla el equipo técnico (Claude) y no forma parte de tu ruta.

## 4. No-objetivos

- **No** se reproduce el contenido de cursos de pago (OffSec AI-300 y similares). Sus bloques públicos se usan solo como mapa de competencias.
- **No** hay conexión del Dojo a ninguna API externa ni a ningún LLM remoto.
- **No** se atacan sistemas reales de terceros. Todo ocurre en simulación o en laboratorios propios en localhost.
- **No** es una enciclopedia. La teoría aparece cuando hace falta para resolver un reto.
- **No** hay multijugador, cuentas ni telemetría.
- **No** se busca ser especialista en infraestructura (AI Ops). Se busca entenderla lo suficiente para auditarla.

## 5. Arquitectura de producto: dos planos

### 5.1 El Dojo (Godot)

Restricciones **innegociables**:
- No abre sockets ni hace peticiones HTTP. No tiene ninguna dependencia de red.
- No ejecuta comandos del sistema operativo (`OS.execute` y similares están prohibidos por convención y por un test).
- No evalúa código arbitrario. El terminal solo invoca comandos registrados.
- Solo persiste en `user://`: progreso, ajustes y evidencias importadas.

Incluye:
- **Simulaciones:** API de modelos, chatbots vulnerables, agentes ficticios, bases vectoriales, servidores MCP, incidentes…
- **ML real en GDScript, sin dependencias:** k-NN, perceptrón, regresión lineal y logística, k-means, MLP con backpropagation, tokenizador BPE de juguete, atención y sampling.

### 5.2 La Forja (`forja/`)

Laboratorios reales en tu máquina:
- Python y FastAPI.
- Docker Compose.
- Modelos locales (Ollama o llama.cpp).
- Un servidor MCP real con el SDK oficial.
- Una base vectorial real.

Reglas de la Forja:
- Todos los servicios escuchan solo en `127.0.0.1`. Ningún laboratorio expone puertos hacia la LAN.
- Las aplicaciones son vulnerables **a propósito** y están documentadas como tales.
- Cada laboratorio genera un fichero de **evidencias** (`evidence.json`) que el Dojo importa y valida contra un esquema. El Dojo nunca ejecuta la Forja.

### 5.3 Por qué dos planos

La especificación exige aislamiento total. Pero la ampliación pide crear un servidor MCP, contenerizar y atacar un RAG real, cosas que **no se pueden aprender de verdad solo con simulaciones**.

Separar los planos permite cumplir las dos cosas:
- El Dojo enseña el **mecanismo** y te deja experimentar con seguridad.
- La Forja te enfrenta a la **realidad**: dependencias, errores y comportamiento no determinista de los modelos.

## 6. Requisitos funcionales

### RF-1 Hub de laboratorio
- Pantalla principal con:
  - Navegación por el currículo (mapa de dependencias).
  - Panel de misión activa.
  - Mentor RONIN.
  - Área de laboratorio para visualizaciones.
  - **Terminal siempre presente** (acoplado abajo y redimensionable).
- Todos los módulos completados se pueden **revisitar y repetir**.

### RF-2 Terminal ficticio
- Parser propio con:
  - Registro de comandos.
  - Validación de argumentos.
  - Errores explicativos.
  - Historial.
  - Autocompletado con Tab.
- **Progresivo.** Las capacidades se desbloquean con la progresión:
  1. Comandos simples.
  2. Flags y argumentos con nombre.
  3. Pipes con datos estructurados (`dataset show iris | where species=setosa | stats`).
  4. Scripts `.rsh` de varios comandos.
- **Ayuda siempre disponible**, incluso con funciones bloqueadas:
  - `help`, `help <comando>` y `<comando> --help`.
  - `man <tema>`: manual conceptual.
  - `cheatsheet [tema]`: chuleta de comandos y conceptos ya vistos.
  - `explain <término>`: entrada del glosario.
  - `hint`: escalera de pistas.
  - `?` al final de una línea: sugerencias contextuales.
  - Panel lateral de chuletas, que se puede fijar.
- Solo interactúa con sistemas simulados internos.

### RF-3 Motor de misiones (data-driven)
- Las misiones se definen en JSON (ver [04](04-especificacion-misiones.md)). Añadir una misión **no requiere tocar código** si usa validadores ya existentes.
- Cada misión incluye:
  - Briefing.
  - Objetivos de aprendizaje.
  - Prerrequisitos.
  - Teoría «justo a tiempo».
  - Laboratorio.
  - Reto.
  - Pistas en 5 niveles.
  - Resultados esperados.
  - Evaluación.
  - Debrief.
  - Lecturas.
- Las misiones de seguridad incluyen una **ficha de vulnerabilidad** de 9 puntos: qué es, componente, condiciones, detección, reproducción, impacto, mitigación, verificación e informe.

### RF-4 Mentor RONIN (offline y basado en reglas)
- Asistencia en 5 niveles:
  1. Sutil.
  2. Pista técnica.
  3. Paso a paso.
  4. Explicación detallada.
  5. Ejemplo resuelto.
- Nunca ofrece el nivel 5 de forma automática.
- Diagnóstico de errores: los validadores devuelven **códigos de diagnóstico**, que el mentor convierte en preguntas socráticas y en explicaciones de por qué falla ese enfoque.
- Patrón **«predice antes de ejecutar»**: antes de un experimento, RONIN pide tu predicción y después la contrasta con el resultado.
- Advierte explícitamente cuando algo está simplificado: «Esto es una simulación. En producción haría falta…».

### RF-5 Progresión y maestría
- La progresión **se basa en competencias, no en actividades.** Cada competencia tiene 4 estados:
  - **Vista:** has visto la teoría y la misión.
  - **Practicada:** has completado la misión, con o sin ayuda.
  - **Dominada:** has superado una prueba de dominio sin pistas de nivel 3 o superior.
  - **Transferida:** has resuelto una variante distinta del problema.
- Para desbloquear un arco hace falta tener **Dominadas** las competencias previas. No basta con haber terminado las misiones anteriores.
- XP:
  - Premia los experimentos con hipótesis nuevas, el razonamiento y la resolución independiente.
  - Rendimientos decrecientes al repetir. Sin farmeo.
- Otros elementos: logros, árbol de habilidades por disciplina, rango de dificultad (Initiate → Master) y racha **opcional**.
- **Revisiones del dojo:** repetición espaciada de conceptos clave con preguntas de predicción, no de memoria.

### RF-6 Evaluación
- Validadores objetivos sobre el **estado de la simulación** y el **registro de eventos** (lo que hiciste, no lo que respondiste).
- **Retos de transferencia:** la misma competencia en un escenario distinto.
- **Informes estructurados** con plantilla profesional. Se evalúan con una rúbrica comprobable (campos presentes, severidad justificada, pasos reproducibles, evidencia enlazada, mitigación verificada) más una autoevaluación guiada.
  - *Limitación honesta:* sin un LLM, la calidad de la prosa no se puede evaluar. Se puede añadir corrección asistida opcional en la Forja, con un modelo local.
- **Importación de evidencias de la Forja:** se valida el esquema y se comprueban valores esperados (por ejemplo, la tasa de éxito del ataque antes y después de la mitigación).

### RF-7 Biblioteca de referencias
- `content/references.json`: fuente, URL, organización, **versión y fecha de consulta**, y **tipo**.
- Tipos de referencia:
  - `estándar`, `framework`, `guía`, `documentación-oficial`, `paper`, `técnica-emergente` o `investigación-experimental`.
- Cada afirmación técnica de una misión puede enlazar a referencias.
- Cada contenido lleva también una **etiqueta epistemológica**:
  - `consolidado`, `práctica-industria`, `emergente`, `experimental`, `modelo-simplificado` o `recomendación-propia`.
- Los contenidos que cambian rápido llevan una fecha de revisión (`review_by`). La app avisa de los contenidos caducados.

### RF-8 Persistencia
- Guardado local en `user://save.json` con versión de esquema, migraciones y escritura atómica.
- Exportar e importar el progreso como fichero local, para copias de seguridad.

## 7. Requisitos no funcionales

| Área | Requisito |
|---|---|
| Aislamiento | Un test automático falla si el código del Dojo usa `HTTPRequest`, `HTTPClient`, `StreamPeerTCP`, `PacketPeerUDP`, `WebSocketPeer`, `OS.execute`, `OS.create_process` u `OS.shell_open` |
| Rendimiento | 60 FPS en el hub; los algoritmos de ML del tronco responden en menos de 200 ms con los datasets de enseñanza |
| Legibilidad | Fuente escalable (90–150 %), contraste AA, modo de movimiento reducido, sin depender solo del color rojo o verde |
| Mantenibilidad | Lógica del núcleo en clases `RefCounted` testeables sin escena; contenido separado del código |
| Tests | Runner propio sin dependencias, en modo headless (`godot --headless -s res://tests/run_tests.gd`) |
| Contenido actualizable | Actualizar una referencia o un contenido es editar JSON, no recompilar lógica |

## 8. Disciplinas y cómo se integran

| Disciplina | Pregunta que responde | Dónde vive |
|---|---|---|
| **AI Engineering** (Construir) | ¿Cómo funciona y cómo lo construyo? | Tronco común y fase «Construir» de cada arco |
| **AI Security** (Atacar y Defender) | ¿Cómo falla, cómo lo exploto y cómo lo protejo? | Fases «Atacar» y «Defender» de cada arco, más la pista de oficio |
| **AI Operations** (Desplegar) | ¿Cómo lo despliego, lo observo y lo mantengo seguro? | Fase «Desplegar» de cada arco, sobre todo en la Forja |

El detalle está en [03-curriculo.md](03-curriculo.md).

## 9. Riesgos

| Riesgo | Mitigación |
|---|---|
| Alcance enorme: el proyecto nunca termina | Hitos pequeños y jugables; cada arco aporta valor por sí solo |
| Simulación que enseña un modelo mental falso | Etiqueta `modelo-simplificado` y sección «En producción…» obligatoria en el debrief; laboratorio equivalente en la Forja |
| Contenido de seguridad desactualizado | Fechas de revisión, versión de cada referencia y contenido en JSON |
| Respuestas de un LLM simulado demasiado deterministas | Motor de respuestas con plantillas, reglas y aleatoriedad controlada por semilla; la variabilidad real se trabaja en la Forja |
| Evaluación de texto libre limitada | Informes estructurados, rúbricas comprobables y corrección asistida opcional en local |
| Convertirse en copiar y pegar | Tareas de implementación propias, «predice antes de ejecutar», pistas progresivas, retos de transferencia |

## 10. Decisiones tomadas en la entrevista

| Tema | Decisión |
|---|---|
| Relación con RoninShell | Proyecto totalmente independiente |
| Interfaz | Hub de laboratorio con terminal fijo |
| Código en misiones | Mixto: mini-lenguaje seguro en el Dojo y Python real en la Forja |
| ML real | Sí, implementado en GDScript |
| Enfoque de los arcos | Equilibrado: las 4 fases completas en cada arco |
| Forja | Python, Docker y modelos locales |
| Terminal | Progresivo, con ayuda, chuletas y manual siempre disponibles |
| Idioma | Castellano con términos técnicos en inglés y biblioteca local de referencias |
| Primera versión jugable | Núcleo y 3 misiones del tronco común |
| Repositorio | `Kanarath/ai-ronin` (GitHub) |
| Godot (decisión del 2026-11-06) | Fuera del alcance de aprendizaje. Claude construye la app; tus tareas 🛠 son siempre de IA y en Python |
