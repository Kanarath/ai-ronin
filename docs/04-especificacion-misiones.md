# 04 — Especificación de misiones

## 1. Anatomía de una misión

| Sección | Propósito | Regla de diseño |
|---|---|---|
| **Briefing** | Contexto narrativo y problema concreto | Máximo 120 palabras. Plantea un problema, no un tema. |
| **Objetivos de aprendizaje** | Qué sabrás hacer al terminar | Verbos observables: «medir», «explicar», «explotar»… Nunca «conocer». |
| **Conocimientos previos** | Competencias requeridas | Si no están *Dominadas*, RONIN ofrece un repaso de 2 minutos antes de empezar |
| **Teoría justo a tiempo** | Tarjetas de concepto | Se desbloquean cuando un objetivo las necesita, no todas al principio |
| **Laboratorio** | Simulación y visualizaciones | Siempre manipulable; nunca es solo texto |
| **Reto** | Objetivos verificables | Ninguno es de opción múltiple |
| **Pistas** | 5 niveles por objetivo | Ver §4 |
| **Resultados esperados** | Qué deberías observar | Se revelan **después** de tu predicción |
| **Evaluación** | Validadores y prueba de dominio | Ver §5 |
| **Debrief** | Qué ha pasado y por qué; conexión con el mundo real | Incluye siempre la sección «En producción…» |
| **Lecturas** | Ids de `references.json` | Con tipo, versión y fecha |

### 1.1 Ficha de vulnerabilidad (misiones de Atacar y Defender)
Las misiones de seguridad completan los 9 puntos, que se rellenan a lo largo de la misión y se reutilizan en el informe:

1. Qué es y cómo funciona internamente.
2. Componente afectado.
3. Condiciones que permiten explotarla.
4. Cómo identificarla en una auditoría.
5. Reproducción en laboratorio.
6. Demostración de impacto.
7. Mitigación.
8. Verificación de que la mitigación funciona: métrica antes y después.
9. Redacción en el informe.

## 2. Niveles de dificultad

| Nivel | Nombre | Características |
|---|---|---|
| 1 | **Initiate** | Un concepto, guiado paso a paso, sin ambigüedad |
| 2 | **Apprentice** | Combina 2–3 conceptos; menos guía |
| 3 | **Engineer** | Problema abierto con varias soluciones válidas; hay que diagnosticar |
| 4 | **Specialist** | Información incompleta, ruido y pistas falsas; investigación propia |
| 5 | **Master** | Escenario realista y extremo a extremo; sin guía; informe profesional |

## 3. Esquema JSON (v1)

```jsonc
{
  "id": "T2-01",
  "schema_version": 1,
  "title": "El vecino más cercano",
  "unit": "T2",
  "phase": "construir",              // construir | atacar | defender | desplegar | fundamentos
  "difficulty": 1,
  "plane": "dojo",                   // dojo | forja | mixto
  "epistemic": "consolidado",
  "estimated_minutes": 30,
  "competencies": {
    "requires": ["T1.distancia"],
    "trains":   ["T2.knn", "T2.generalizacion"]
  },
  "briefing": "…",
  "learning_objectives": ["Explicar cómo k-NN clasifica un punto", "Medir la accuracy en un conjunto de test"],
  "theory_cards": [
    { "id": "knn", "unlock_on": "objective:o1", "body": "…", "refs": ["ref.cover-hart-1967"] }
  ],
  "lab": {
    "scene": "res://ui/viz/scatter_plot.tscn",
    "world": { "datasets": ["datasets/katanas.csv"], "seed": 42 },
    "commands_unlocked": ["dataset", "model", "predict"]
  },
  "objectives": [
    {
      "id": "o1",
      "text": "Predice la clase del punto misterioso con k=1 y k=5.",
      "prediction": { "prompt": "¿Crees que k=1 y k=5 darán la misma clase?", "type": "choice_free" },
      "validator": { "type": "event", "event": "model.predicted",
                     "where": { "k": { "in": [1, 5] } }, "count": { "gte": 2 } },
      "diagnostics": {
        "NO_TRAIN": "Aún no hay modelo entrenado. ¿Qué necesita k-NN para «entrenar»?"
      },
      "hints": [
        "¿Qué significa «vecino» si los puntos son vectores?",
        "Revisa `model --help`: algunos parámetros se fijan al crear el modelo.",
        "1) `model create knn --k 1` 2) `model train katanas` 3) `predict misterio`",
        "k-NN no aprende parámetros: guarda los ejemplos y, al predecir, vota entre los k más cercanos…",
        "Ejemplo resuelto completo: …"
      ]
    }
  ],
  "mastery_trial": { "objectives": ["…variante sin pistas…"], "max_hint_level": 2 },
  "transfer_variant": "T2-01b",
  "debrief": {
    "what_happened": "…",
    "why": "…",
    "in_production": "scikit-learn implementa k-NN con estructuras como KD-tree o Ball-tree para que la búsqueda no sea lineal…",
    "simplifications": ["Dataset de 2 dimensiones para poder visualizarlo"]
  },
  "further_reading": ["ref.sklearn-neighbors"],
  "xp": { "base": 100, "independent_bonus": 50 }
}
```

`ContentDB` valida cada misión al cargarla (campos obligatorios, ids de referencias existentes, validadores registrados) y muestra los errores en la consola del editor.

## 4. Escalera de pistas y maestría

| Nivel | Tipo | Cómo se obtiene | Efecto en la maestría |
|---|---|---|---|
| 1 | Pista sutil, en forma de pregunta | `hint` | Ninguno |
| 2 | Pista técnica | `hint` otra vez | −5 % |
| 3 | Paso a paso | `hint`, con un aviso | −20 %; la prueba de dominio no permite este nivel |
| 4 | Explicación detallada | `hint --explain` | −35 % |
| 5 | Ejemplo resuelto | `hint --solution` y confirmación | −60 %; la competencia queda como *Practicada* hasta repetirla sin ayuda |

## 5. Evaluación y criterio de superación

- **Misión completada:** todos los objetivos se han validado.
- **Competencia *Dominada*:** se ha superado la prueba de dominio (variante corta, sin pistas de nivel 3 o superior).
- **Competencia *Transferida*:** se ha superado una variante en otro contexto (otro dataset, otro sistema).
- **Unidad o arco superado:** todas las competencias *Dominadas* y, en los arcos, el informe aprobado por la rúbrica.

### Rúbrica de informe (verificación automática)
- [ ] Título, severidad y justificación (impacto × probabilidad).
- [ ] Componente afectado y referencia a OWASP o ATLAS.
- [ ] Pasos de reproducción ejecutables en el laboratorio.
- [ ] Evidencia enlazada a eventos reales del `EventLog` o a evidencias importadas de la Forja.
- [ ] Mitigación concreta, no genérica.
- [ ] Verificación: métrica antes y después.
- [ ] Autoevaluación de la calidad de la prosa con una lista guiada.

## 6. Patrones pedagógicos obligatorios

1. **Predice → ejecuta → explica.** Antes de cada experimento clave, registras una predicción. Acertar no puntúa; contrastar sí.
2. **Error productivo.** Algunas misiones te dejan caer en un error típico (fuga de datos, overfitting, confiar en el modelo para autorizar) y después lo diagnosticas tú.
3. **Construye tú una pieza.** Cada unidad tiene al menos una tarea de implementación en GDScript o Python. RONIN revisa el resultado con tests.
4. **Sin suposiciones.** Cada misión comprueba sus requisitos con un mini reto de calentamiento, aunque la competencia ya conste como *Dominada*.
5. **Simulación frente a realidad.** El debrief dice qué estaba simplificado y qué haría falta en producción.

## 7. Ejemplo de misión de seguridad (resumen, A1)

**A1-ATK-02 «La voz que no era del maestro»** · nivel 2 · plano mixto

- **Laboratorio en el Dojo:** el chatbot ficticio de un herrero resume los pedidos de los clientes. Un pedido contiene instrucciones ocultas.
- **Reto:**
  1. Reproducir la inyección indirecta.
  2. Demostrar el impacto: el bot revela el descuento interno.
  3. Rellenar la ficha de vulnerabilidad.
- **Defensa (misión A1-DEF-02):**
  1. Separar instrucciones y datos.
  2. Validar la salida.
  3. Volver a lanzar 20 variantes del ataque y comparar la tasa de éxito: antes, por ejemplo, 18/20; después, por ejemplo, 3/20.
  4. Explicar por qué no llega a 0. La inyección de prompts no tiene hoy una solución completa; esto se etiqueta como `consolidado` según OWASP LLM01:2025.
- **Forja:** el mismo escenario con un modelo local real. La tasa de éxito varía entre ejecuciones; se trabaja ese no determinismo.
