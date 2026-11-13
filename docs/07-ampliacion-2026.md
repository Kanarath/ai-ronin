# 07 — Ampliación del currículo (noviembre de 2026)

Comparación de AI RONIN con los cursos y certificaciones de referencia de 2026 y con lo que piden las ofertas de empleo. Se hizo el 2026-11-13.

**Con qué se comparó:**
- Hugging Face: cursos de LLM, agentes, MCP y contexto.
- Stanford CS336.
- *AI Engineering*, de Chip Huyen.
- DeepLearning.AI.
- LLM Zoomcamp.
- HTB AI Red Teamer.
- SANS SEC545.
- OWASP Top 10 for Agentic Applications 2026.
- IAPP AIGP (*Body of Knowledge* v2.1).
- ISO/IEC 42001 Lead Auditor.

## Lo que ya cubríamos

Fundamentos de ML, transformers, RAG, agentes, MCP, A2A, red team de LLM, detección y gobernanza (NIST, ISO 42001, AI Act).

La combinación construir → atacar → defender con laboratorios reales es más completa que la de la mayoría de cursos sueltos.

## Huecos y plan

| # | Propuesta | Unidad | Estado | Inspirado en |
|---|---|---|---|---|
| 1 | Evals de agentes y observabilidad: trayectorias, conjunto de referencia por segmentos, puerta de regresión, trazas y monitorización online con juez muestreado | **P2** (P2-01, P2-02) | ✅ Hecho | DeepLearning.AI *Evaluating AI Agents*, LLM Zoomcamp, ofertas (61 % piden evals) |
| 2 | OWASP Top 10 agéntico (ASI01–ASI10): clasificar incidentes, mapa de cobertura, caja de arena, aprobación verificable y ataque en cadena | **O7** (O7-01 … O7-05) | ✅ Hecho | OWASP GenAI, 9-dic-2025 |
| 3 | Herramientas reales de red team: garak, PyRIT y promptfoo contra el modelo local | Forja, extras de A1 | Pendiente | Ofertas de AI red teamer |
| 4 | Agentes con navegador y ordenador: inyección desde páginas web, *sandboxing* de código | **A7** | Pendiente | SANS SEC545, HTB |
| 5 | Ingeniería de contexto y memoria: compactación, tipos de memoria, *skills* | A3-05 | Pendiente | HF *Context Course*, DeepLearning.AI *Agent Memory* |
| 6 | Modelos que razonan: DPO, GRPO y recompensas verificables, cómputo en inferencia, destilación | **T11** | Pendiente | DeepLearning.AI *post-training*, CS336 |
| 7 | Inferencia eficiente: caché KV, *batching*, decodificación especulativa, MoE, leyes de escala | **T12** | Pendiente | CS336 |
| 8 | Gradient boosting | **T7-05** | ✅ Hecho | ML clásico tabular |
| 9 | Privacidad: privacidad diferencial, aprendizaje federado, *unlearning* | E2-04 | Pendiente | HTB (módulos de privacidad), AIGP |
| 10 | Auditor de ISO/IEC 42001: declaración de aplicabilidad del Anexo A, clasificar hallazgos y decidir la certificación | **E5** (E5-01, E5-02) | ✅ Hecho | ISO 42001 Lead Auditor, ISO/IEC 17021-1, AIGP |

## Lo que se ha implementado

### T7-05 · Pasos pequeños que corrigen
Gradient boosting de verdad en GDScript.
- **Cómo funciona:** son tocones (*stumps*) sobre los residuos de una regresión logística, con tasa de aprendizaje.
- **Comparación:** contra el bosque aleatorio en `peticiones`.
- **Qué se ve:** el número de rondas frente al sobreajuste.
- **Comandos:** `boost train`, `boost curve` y `classic evaluate`.

### P2 · Evals y observabilidad

**P2-01 · El examen del agente**
- Evaluar trayectorias, no solo la respuesta final: herramienta correcta, pasos de más y acciones prohibidas.
- Conjunto de referencia dividido en segmentos.
- Una versión nueva que mejora la media pero rompe un segmento, y la puerta de regresión que lo frena.

**P2-02 · Ojos en producción**
- Trazas de producción: latencia, coste y puntuación de un juez muestreado.
- Deriva de la entrada.
- Elegir qué tasa de muestreo hace falta para ver un problema a tiempo.

**Comandos:** `evals`, `trace`.

### O7 · Riesgos agénticos (OWASP ASI)

**O7-01 · Diez formas de perder un agente**
Clasificar diez incidentes de la forja en ASI01–ASI10.

**O7-02 · El mapa de cobertura**
- Relacionar las defensas que ya montaste en A3–A5, C1 y C4 con cada riesgo, encontrar los huecos y priorizarlos.

**O7-03 · La caja de arena** (ASI05, LLM05)
- Siete ataques que llegan en los datos contra un agente que ejecuta código; una caja de arena capa a capa (sin shell, sin secretos, sin red, límites, ficheros efímeros) y la salida tratada como entrada no confiable. Comando `sandbox`.

**O7-04 · Aprobar a ciegas** (ASI09)
- La aprobación humana como defensa falsa: ocho peticiones con explicación inocente y cambio real distinto; rediseño a una aprobación verificable (el cambio lo muestra el sistema, no el agente) y una barrera extra para lo crítico. Comando `approvals`.

**O7-05 · La cadena que no se corta sola** (ASI01–ASI08)
- Un incidente como cadena de seis eslabones que entra por dos sitios; cortarla en el cuello de botella y reforzarla en profundidad. Comando `chain`.

**O7-06 · La memoria que no olvida** (ASI06)
- Envenenar la memoria persistente de un agente sin darle una orden y ver que el daño persiste entre sesiones y usuarios; defensas de entrada (aislar, origen) y de permanencia (revisión, caducidad). Comando `memoria`.

**O7-07 · Un hallazgo, cuatro marcos**
- Mapear un mismo hallazgo a ASI, LLM Top 10, MITRE ATLAS (por táctica) y NIST AI RMF (por función), y cerrar el mapa de cobertura que O7-02 dejó abierto con las defensas de O7-03 y O7-04. Comandos `marco` y `asi close`.

Mejoras de O7-01/02: la clasificación reconoce los riesgos secundarios de un incidente («casi: también hay algo de ASIxx, pero no es la causa raíz») sin darlos por buenos.

**Comandos:** `asi`, `sandbox`, `approvals`, `chain`, `memoria`, `marco`.

### E5 · Auditor de ISO/IEC 42001

**E5-01 · La declaración de aplicabilidad**
Revisar la declaración de aplicabilidad (*SoA*) de los objetivos del Anexo A (A.2–A.10). Hay que detectar:
- exclusiones sin justificar;
- controles incluidos sin evidencia.

**E5-02 · La decisión de certificación**
- Clasificar los hallazgos de la auditoría de etapa 2 como no conformidad mayor, menor u observación, siguiendo los criterios de ISO/IEC 17021-1.
- Decidir si se puede recomendar la certificación.

**Comando:** `iso`.

*Aviso:* el Anexo A se cita por objetivos (A.2–A.10), no control a control. La redacción exacta de los 38 controles hay que comprobarla en una copia con licencia de la norma.

## Lo implementado después (13-nov)

- **A7 · Agentes con navegador y ordenador** (comando `web`): A7-01 inyección indirecta al navegar (contenido como datos, dominios y acciones permitidas, inyección frente a desinformación); A7-02 *computer use* como diputado confundido (permisos delegados, confirmación verificable, aislamiento de descargas). Mínimo privilegio aplicado a la sesión.
- **Extras de red team reales** en `forja/ejercicios/extras/redteam/`: garak (escáner), promptfoo (evals y suite adversarial) y PyRIT (orquestación, experimental), todo contra el modelo local con avisos de carga.

## Lo siguiente, en este orden

1. **T11:** modelos que razonan (DPO, GRPO/RLVR, cómputo en inferencia, destilación).
2. **A3-05:** ingeniería de contexto y memoria.
3. **T12:** inferencia eficiente (caché KV, *batching*, MoE).
4. **E2-04:** privacidad (privacidad diferencial, aprendizaje federado, *unlearning*).

## Fuentes (consultadas el 2026-11-13)

- [OWASP Top 10 for Agentic Applications 2026](https://genai.owasp.org/resource/owasp-top-10-for-agentic-applications-for-2026/)
- [Giskard: resumen del OWASP agéntico](https://www.giskard.ai/knowledge/owasp-top-10-for-agentic-application-2026)
- [ISO/IEC 42001:2023](https://www.iso.org/standard/42001)
- [Lista de controles del Anexo A, RiskProfs](https://riskprofs.com/iso-42001-annex-a-controls-list/)
- [DeepLearning.AI, cursos cortos](https://deeplearning.ai/short-courses/)
- [LLM Zoomcamp, temario](https://datatalks.club/docs/courses/llm-zoomcamp/curriculum/)
- [Stanford CS336](https://stanford-cs336.github.io/spring2025/)
- [HTB AI Red Teamer](https://www.hackthebox.com/blog/ai-red-teamer-path-complete-offense-defense-privacy)
- [SANS SEC545](https://www.sans.org/cyber-security-courses/genai-llm-application-security/)
- [IAPP AIGP Body of Knowledge](https://iapp.org/certify/body-of-knowledge-aigp)
- [Heavybit: qué piden las ofertas de AI engineer](https://heavybit.com/library/article/so-you-want-to-be-an-ai-engineer)
