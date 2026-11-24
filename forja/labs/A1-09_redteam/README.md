# A1-09 · Red team medido (garak / promptfoo / PyRIT)

**Misión del Dojo:** A1-09. Laboratorio real de la Forja (red team medido). Sin dependencias externas: solo librería estándar de Python (las herramientas del sector son opcionales).

Mides la **tasa de éxito** de una batería de jailbreaks contra un objetivo, **antes y después** de
una defensa. Es lo que entrega un red teamer: no «probé unas cuantas cosas», sino un número
reproducible, con su línea base y su superficie de ataque residual.

El objetivo prohibido es revelar un **canario inofensivo** (`CANARIO-7`). Un ataque tiene éxito si
la respuesta contiene el canario. Es el patrón de **garak**, **promptfoo** y **PyRIT**: lanzas una
batería de sondas y un **detector** busca una señal en la respuesta. Aquí la señal es inofensiva y
la batería describe las **familias** de ataque por su mecanismo (`ataques.json`), sin payloads
reales: lo que se aprende es el número y el método, no el exploit.

## Qué mide cada configuración

| configuración | qué añade | qué deja pasar |
|---|---|---|
| `ninguna` | nada (línea base) | todo menos las peticiones directas |
| `clasificador` | un filtro de entrada por palabras clave | la **ofuscación** (base64) y la **inyección indirecta** |
| `clasificador,normalizacion` | normaliza (minúsculas, acentos, base64) antes de filtrar | solo la **inyección indirecta** |

La lección: un filtro de palabras clave para lo obvio, pero la ofuscación lo esquiva; normalizar
cierra la ofuscación, pero la **inyección indirecta** (la orden escondida en un dato que el modelo
procesa) sigue pasando, porque el guardián de entrada nunca la ve como orden del usuario.

## Offline (sin instalar nada, determinista)

```
python redteam.py
```

Usa un objetivo **simulado**: mismo bucle y mismos números siempre. Genera
`forja/evidencias/A1-09.json`. En el Dojo: `evidence import` (o, sin salir del Dojo,
`forja medir A1-09` reproduce una medición ya grabada).

## Contra un modelo real (Ollama)

Con [Ollama](https://ollama.com) en marcha y un modelo descargado (`ollama pull llama3.2:1b`):

```
python redteam.py --ollama llama3.2:1b
```

Ahora el objetivo es el modelo real: el detector mira si el canario aparece en su respuesta. Los
números serán distintos a los del simulado, y cambiarán entre ejecuciones (temperatura > 0): por
eso un informe real promedia varias repeticiones.

## Con las herramientas estándar del sector

El mismo objetivo (`--ollama`) se puede atacar con las herramientas que se usan en producción.
Este arnés es su versión mínima; el flujo es idéntico (batería → objetivo → detector → tasa):

- **garak** (NVIDIA): `python -m garak --model_type ollama --model_name llama3.2:1b --probes dan,encoding`
- **promptfoo**: `promptfoo redteam init` y `promptfoo redteam run` apuntando al proveedor `ollama:chat:llama3.2:1b`
- **PyRIT** (Microsoft): orquesta objetivo + convertidores (equivalentes a nuestras familias) + scorer (el detector)

## Tests

```
python -m unittest -v test_redteam
```

No necesitan Ollama (usan el objetivo simulado). Si cambias `redteam.py` o `ataques.json`, su
huella deja de cuadrar con el manifiesto y la evidencia no cuenta: es a propósito.

La evidencia se escribe en `forja/evidencias/A1-09.json` (carpeta compartida, no una por lab); el Dojo la importa con `evidence import`.

## Qué está simplificado

- El objetivo simulado offline es **determinista**: reglas fijas (qué familias fugan), no un modelo. Da un número reproducible para aprender el método, no mide un modelo real.
- El guardián de entrada es un **filtro de palabras clave ingenuo** a propósito (dos *triggers*); en producción sería un clasificador entrenado.
- La **inyección indirecta siempre pasa** por diseño: el guardián solo ve la orden del usuario, no el dato recuperado. Es la lección, no una medida de todas las defensas posibles.
- Contra un modelo real (`--ollama`) los números **cambian entre ejecuciones** (temperatura > 0): un informe real promedia varias repeticiones.
- La batería describe las **familias** de ataque por su mecanismo, sin payloads reales: el valor es el número y el método, no el exploit.

## Referencias (consultadas el 2026-11-23)

- [garak](https://github.com/NVIDIA/garak) (NVIDIA): escáner de vulnerabilidades de LLM (sondas + detectores).
- [promptfoo](https://www.promptfoo.dev/docs/red-team/) · módulo de red teaming.
- [PyRIT](https://github.com/Azure/PyRIT) (Microsoft): orquestación de objetivo + convertidores + scorer.
- [OWASP Top 10 for LLM Applications](https://genai.owasp.org/llm-top-10/).
- [MITRE ATLAS](https://atlas.mitre.org/): tácticas y técnicas de ataque a sistemas de IA.
