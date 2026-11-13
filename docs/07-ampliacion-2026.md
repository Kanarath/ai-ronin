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
| 2 | OWASP Top 10 agéntico (ASI01–ASI10): clasificar incidentes y medir qué riesgos cubren tus defensas | **O7** (O7-01, O7-02) | ✅ Hecho | OWASP GenAI, 9-dic-2025 |
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
- Relacionar las defensas que ya montaste en A3–A5, C1 y C4 con cada riesgo.
- Encontrar los riesgos sin cubrir.
- Priorizar.

**Comando:** `asi`.

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

## Lo siguiente, en este orden

1. **A7:** agentes con navegador.
2. **Extras de la Forja:** garak, PyRIT y promptfoo.
3. **T11:** modelos que razonan.
4. **A3-05:** ingeniería de contexto.
5. **T12:** inferencia eficiente.
6. **E2-04:** privacidad.

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
