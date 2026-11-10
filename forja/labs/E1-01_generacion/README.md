# E1-01 · El bucle de generación

**Misión del Dojo:** E1-01 (requiere T6-02 y P0-01). Laboratorio real de la Forja, especialización E1 (investigación ML).

En T6-01 muestreaste palabras de un modelo de bigramas, con listas de Python. Hoy el modelo es un transformer de verdad: **SmolLM2-135M** (Hugging Face, 135 millones de parámetros, licencia Apache-2.0, arquitectura Llama). Lo cargas con PyTorch y Transformers y corre en tu CPU.

`model.generate()` lo hace todo de una vez. Tú escribes lo que hace por dentro: pedir al modelo los logits del siguiente token, aplicarles la temperatura y el filtro top-p, muestrear, añadir el token y repetir.

| Pieza | Quién la escribe |
|---|---|
| `con_temperatura`, `filtro_top_p`, `siguiente_token`, `generar`, `log_probs_secuencia` en `generacion.py` | **Tú** |
| `cargar` (descarga y carga del modelo), `experimento.py` | Claude |
| `test_generacion.py` (17 tests con un modelo diminuto creado en el test) | Claude |

Aquí no hay servicio ni Docker: todo ocurre dentro de un proceso de Python en tu máquina.

## 1. Entorno y tests

Desde esta carpeta:

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe -m unittest -v test_generacion
```

**Tamaño:** torch para CPU (127 MB) más Transformers (13 MB) y sus dependencias: unos **175 MB de descarga** y alrededor de 1 GB instalado. `requirements.txt` toma torch del índice CPU oficial de PyTorch, sin CUDA. E1-02 y E1-03 usan exactamente el mismo entorno: no hace falta instalarlo tres veces.

Los tests no descargan nada: crean un `LlamaForCausalLM` de 2 capas y 16 dimensiones con pesos aleatorios y semilla fija, y un modelo de bigramas hecho a mano. Cuando pasen los 17:

```powershell
.\.venv\Scripts\python.exe ..\..\ejercicios\ronin_check.py E1-01
```

Y en el Dojo: `evidence import`.

## 2. Con el modelo de verdad

```powershell
.\.venv\Scripts\python.exe experimento.py
.\.venv\Scripts\python.exe experimento.py --prompt "Once upon a time" --nuevos 30
```

La primera vez descarga SmolLM2-135M (**unos 270 MB**, `model.safetensors` en bfloat16) a la caché de Hugging Face (`%USERPROFILE%\.cache\huggingface`). Después funciona sin red. En float32 ocupa unos 540 MB de RAM.

El experimento mide cuatro cosas:
1. **Tu bucle voraz frente a `generate()`.** Deberían salir los mismos tokens. Compara los tokens por segundo: tu bucle recalcula todo el prompt en cada paso; `generate()` guarda las claves y los valores de la atención de los tokens anteriores (la **caché KV**) y solo calcula el token nuevo.
2. **La distribución del primer token** con temperatura 0.5, 1 y 1.5, y cuántos tokens deja top-p 0.9 de los 49 152 del vocabulario.
3. **Muestras** con la misma semilla y con semillas distintas.
4. **La log-probabilidad** de una frase verdadera y de su versión al revés.

SmolLM2 está entrenado sobre todo en inglés: por eso los prompts por defecto están en inglés. Prueba también en español y compara.

## Qué está simplificado

- Un solo prompt cada vez (sin lotes) y sin caché KV en tu bucle.
- `generate()` admite muchas más estrategias (top-k, penalización de repeticiones, búsqueda en haz…). Aquí solo temperatura y top-p.
- 135 M parámetros es diminuto: los modelos de A1–A6 (`llama3.2:1b`) son 10 veces más grandes y los comerciales, cientos de veces.

## Referencias (consultadas el 2026-11-10)

- [SmolLM2-135M en Hugging Face](https://huggingface.co/HuggingFaceTB/SmolLM2-135M) (Apache-2.0; revisión `93efa2f`).
- L. Ben Allal et al., «SmolLM2: When Smol Goes Big — Data-Centric Training of a Small Language Model», [arXiv:2502.02737](https://arxiv.org/abs/2502.02737) (2025).
- [Transformers · estrategias de generación](https://huggingface.co/docs/transformers/generation_strategies) (versión 5.22.2).
- [PyTorch · documentación](https://docs.pytorch.org/docs/stable/) (versión 2.15.0).
- A. Holtzman et al., «The Curious Case of Neural Text Degeneration», [arXiv:1904.09751](https://arxiv.org/abs/1904.09751) (2019): top-p.
