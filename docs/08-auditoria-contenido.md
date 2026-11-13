# 08 — Auditoría de contenido (13 de noviembre de 2026)

Revisión del contenido con doble mirada (ingeniería de IA y ciberseguridad), leyendo misiones enteras en los puntos críticos de la curva (T1-01, T6-02, A1-02, C5-01) y verificando la cobertura de temas. 120 misiones.

## Veredicto general

Contenido serio y poco común: junta construir, atacar, defender y gobernar con laboratorios donde todo se calcula de verdad (atención, descenso por gradiente, GRPO, FedAvg), con etiquetas epistemológicas, mapeo a OWASP/ATLAS/NIST, informes con evidencia y referencias fechadas.

## Explicaciones: suficientes

Tarjeta `teach` corta con un «Por qué:» en cada paso; la profundidad extra va en el `debrief` («en producción») y en las referencias. No son superficiales: T6-02 calcula la atención (softmax, máscara causal, √d, coste O(n²)); A1-02 cubre LLM01/05/07/10 con batería de ataques e informe.

Riesgo menor: las unidades nuevas más densas (T11 GRPO/DPO, T12 MoE/especulativa) comprimen mucho en pocas líneas; la intuición llega y el laboratorio lo hace tangible, pero la profundidad fina se apoya en las referencias. Mejora posible: una línea de «error común» en esas tarjetas.

## Curva de aprendizaje: correcta para el perfil objetivo

Para alguien técnico, con ciberseguridad y algo de programación, nuevo en IA:
- Arranca muy suave (T0 8 min, T1 dificultad 1), con matemáticas y Python **justo a tiempo**.
- Sube de forma gradual (dificultad 1→5) y desbloquea por **competencias**, no por completar.
- Las unidades duras (T11, T12) van al final, tras T6/T9. Bien colocadas.

No es empinada. Para este perfil, T1–T3 pueden saber lentas; se gestiona con el repaso espaciado y pudiendo ir rápido, no cambiando el contenido.

## Huecos de contenido (priorizados)

### Lado ciberseguridad
1. **Uso ofensivo de la IA y defensa frente a ataques potenciados por IA** (el mayor hueco): LLMs para phishing/ingeniería social/recon a escala, y del otro lado detectar lo generado por IA. → Unidad **O8** ✅ (O8-01 «La IA como arma», O8-02 «Defenderse sin leer el texto»; comando `amenaza`).
2. ✅ **Deepfakes y medios sintéticos** → O9-01 «Lo que ves y lo que oyes» (comando `medios`): detección vs procedencia C2PA vs verificación fuera de banda.
3. ✅ **Backdoors / envenenamiento de datos** → E2-05 «La marca que abre la puerta» (comando `backdoor`): puerta trasera invisible a la accuracy.
4. ✅ **Taxonomía de jailbreaks** → A1-08 «Mil formas de abrir la misma puerta» (comando `jailbreak`), atada a los extras garak/promptfoo/PyRIT.
5. ✅ **MAESTRO** → O3-02 «Siete capas de un agente» (comando `maestro`).

### Lado IA/ingeniería
6. ✅ **Generación de imagen y audio** → T13-01 «Más allá del texto» (comando `genia`): difusión, guardarraíles de entrada/salida, copyright y marca de agua.
7. ✅ Cubierto en parte por O9 (audio/voz) y T13 (generación).

Bien cubierto: RAG y su seguridad (A2), agentes/MCP/multiagente (A3–A5), supply chain con formatos de modelo (A6), evals (P2, A1-06), gobernanza (O5, E3, E5), adversarial y privacidad (E2), razonamiento (T11) e inferencia (T12).

## Correcciones de mantenimiento

- **`study_path.json`**: la redacción decía «unidades sin misión», pero O1–O4, A5 y C4 ya tienen misión. No es un fallo de función (es la capa de **lecturas recomendadas** que complementa esas unidades), sino de texto. Corregido el 13-nov para que diga «lecturas recomendadas».

## Orden recomendado

1. ✅ Corregir la redacción de `study_path` (hecho).
2. ✅ **O8 · IA ofensiva y defensa** (hueco nº1) — hecho.
Todos los huecos de la auditoría están hechos (O9, E2-05, A1-08, O3-02, T13).
