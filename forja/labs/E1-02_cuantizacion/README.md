# E1-02 · Cuantizar a mano

**Misión del Dojo:** E1-02 (requiere E1-01). Laboratorio real de la Forja, especialización E1 (investigación ML).

Cuando descargas `llama3.2:1b` con Ollama no bajas floats de 32 bits: bajas un fichero GGUF **cuantizado**, con los pesos guardados en menos bits. Aquí lo haces tú, a mano, con los pesos de SmolLM2-135M, y mides qué se pierde.

Dos esquemas de 8 bits:
- **Afín por tensor:** una escala y un punto cero para toda la matriz. `q = round(w / escala) + punto_cero`, con q entre -128 y 127.
- **Q8_0 de GGUF:** simétrico (sin punto cero) y **por bloques de 32 pesos**, cada uno con su propia escala en float16. Es el formato de las etiquetas `q8_0` de Ollama. Ocupa 34 bytes por cada 32 pesos: 8,5 bits por peso.

| Pieza | Quién la escribe |
|---|---|
| `parametros_afines`, `cuantizar`, `descuantizar`, `cuantizar_q8_0`, `error_relativo`, `bytes_esquema`, `perplejidad` en `cuantizacion.py` | **Tú** |
| `cuantizar_modelo` (aplica tus funciones a cada matriz del modelo), `cargar`, `experimento.py` | Claude |
| `test_cuantizacion.py` (12 tests con tensores pequeños y un modelo diminuto creado en el test) | Claude |

## 1. Entorno y tests

Es el mismo entorno de E1-01 (unos 175 MB de descarga si aún no lo tienes; ver su README). Desde esta carpeta, reutilizándolo:

```powershell
..\E1-01_generacion\.venv\Scripts\python.exe -m unittest -v test_cuantizacion
```

O crea uno propio con `python -m venv .venv` y `pip install -r requirements.txt`. Cuando pasen los 12:

```powershell
..\E1-01_generacion\.venv\Scripts\python.exe ..\..\ejercicios\ronin_check.py E1-02
```

Y en el Dojo: `evidence import`.

## 2. Con el modelo de verdad

```powershell
..\E1-01_generacion\.venv\Scripts\python.exe experimento.py
```

Usa el SmolLM2-135M que ya descargaste en E1-01 (si no, lo descarga: 270 MB). Necesita unos 2 GB de RAM y uno o dos minutos. Para cada esquema (fp32, afin_tensor y q8_0) muestra:
- el **tamaño teórico** de los pesos y los **bits por peso**;
- el **error relativo** medio de las matrices y la peor;
- la **perplejidad** sobre un texto en inglés y su traducción al español;
- cuántos de los 20 tokens de una **generación voraz** coinciden con los de fp32.

Después, si tienes Ollama (P0-01), compara con un GGUF de verdad del mismo tamaño de modelo:

```powershell
ollama pull smollm2:135m-instruct-q8_0
ollama show smollm2:135m-instruct-q8_0
ollama list
```

Ollama publica `smollm2:135m-instruct-fp16` (271 MB), `-q8_0` (145 MB) y `-q4_0` (92 MB). Son la versión instruct (afinada para chat), no la base del laboratorio, pero las matrices tienen el mismo tamaño. Comprueba que 135 M pesos × 8,5 bits ≈ 145 MB.

## Qué está simplificado

- **Cuantización simulada.** Tus funciones cuantizan y descuantizan, y el modelo sigue calculando en float32. El tamaño es teórico (lo que ocuparía guardado). Un motor real (llama.cpp, el de Ollama) guarda los int8 y multiplica con ellos: por eso ahorra RAM y va más rápido. PyTorch tiene sus propias herramientas (la librería torchao), que aquí no se usan para que veas cada paso.
- Solo int8. Los formatos de 4 bits de GGUF (`q4_0`, `q4_K_M`…) usan bloques y escalas en varios niveles, con más error.
- La perplejidad se mide sobre dos frases, no sobre un corpus de evaluación.

## Referencias (consultadas el 2026-11-10)

- B. Jacob et al., «Quantization and Training of Neural Networks for Efficient Integer-Arithmetic-Only Inference», [arXiv:1712.05877](https://arxiv.org/abs/1712.05877) (2018): escala y punto cero.
- T. Dettmers et al., «LLM.int8(): 8-bit Matrix Multiplication for Transformers at Scale», [arXiv:2208.07339](https://arxiv.org/abs/2208.07339) (2022): los pesos y activaciones atípicos.
- [GGUF · especificación](https://github.com/ggml-org/ggml/blob/master/docs/gguf.md) y `quantize_row_q8_0_ref` en [ggml-quants.c](https://github.com/ggml-org/llama.cpp/blob/master/ggml/src/ggml-quants.c) (bloque de 32 int8 con escala float16).
- [Ollama · smollm2](https://ollama.com/library/smollm2/tags) (etiquetas y tamaños).
