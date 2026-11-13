# garak · escáner de vulnerabilidades de LLM

[garak](https://github.com/NVIDIA/garak) (NVIDIA) lanza *probes* contra un modelo y mide cuántas veces cae. Es el equivalente de un escáner de vulnerabilidades, pero para LLM.

## Instalar

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -U garak
```

## Empieza pequeño (importante por la carga)

Con Ollama en marcha (`ollama serve`) y el modelo ya descargado, lanza **una sola familia de probes**. `dan.DanInTheWild` son jailbreaks reales recopilados:

```powershell
.\.venv\Scripts\python.exe -m garak --model_type ollama --model_name llama3.2:1b --probes dan.DanInTheWild
```

garak escribe un informe `.jsonl` y un `.html` con la tasa de fallo por *probe*. Mira el **porcentaje de fallos** (cuántos jailbreaks pasaron) y compáralo con la intuición de A1-05.

## Otras familias útiles (una cada vez)

- `promptinject` — inyección de *prompts* (LLM01).
- `leakreplay` — fuga de datos de entrenamiento memorizados (LLM02; enlaza con E2-03).
- `encoding` — evasión codificando el ataque (enlaza con A1-05, los disfraces de texto).

Lista completa: `.\.venv\Scripts\python.exe -m garak --list_probes`.

## Qué buscar

- ¿Qué familia tiene más fallos en tu modelo pequeño? (los modelos pequeños caen mucho más).
- ¿Cambia si pruebas un modelo mayor? (cuidado con la carga).
- Lleva el porcentaje de fallo a un *write-up*: es justo la evidencia que piden las ofertas.

> No subas los informes con datos sensibles a ningún sitio: son tuyos y locales.
