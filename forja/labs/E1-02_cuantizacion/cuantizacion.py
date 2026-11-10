"""Laboratorio E1-02 · Cuantizar a mano: de 32 bits a 8 por peso.

En T6 viste que un modelo cuantizado ocupa menos y «pierde un poco». Aquí lo mides. Los pesos de
SmolLM2-135M son floats de 32 bits (4 bytes). Cuantizar a int8 es guardar cada peso como un
entero de -128 a 127 más unos pocos números (escalas) que permiten volver al float aproximado.

Vas a implementar dos esquemas:
  - Afín por tensor (escala y punto cero): un solo par de números para toda la matriz. Es el
    esquema clásico de la cuantización int8 (Jacob et al., 2018).
  - Simétrico por bloques de 32 pesos, como el formato Q8_0 de GGUF (llama.cpp), el que usa
    Ollama cuando descargas una etiqueta «q8_0»: cada bloque tiene su propia escala en float16.

Y medirás tres cosas: el error de los pesos, el tamaño y la perplejidad del modelo.

Tú implementas las piezas marcadas con «Tu turno». Claude ha escrito el resto (cuantizar un
modelo entero y experimento.py).

Tests (sin red ni descargas: tensores pequeños y un modelo diminuto creado en el test):
    python -m unittest -v test_cuantizacion
"""

import math

import torch
from torch import nn

MODELO = "HuggingFaceTB/SmolLM2-135M"
REVISION = "93efa2f097d58c2a74874c7e644dbc9b0cee75a2"
QMIN, QMAX = -128, 127
BLOQUE_Q8_0 = 32
ESQUEMAS = ("fp32", "afin_tensor", "q8_0")


# ─────────────────────────────── Tu turno ───────────────────────────────

def parametros_afines(w):
    """Escala y punto cero de la cuantización afín int8 de un tensor `w` (float).
      - El rango a cubrir es [lo, hi] con lo = min(w.min(), 0) y hi = max(w.max(), 0): siempre
        incluye el 0, para que el 0 se represente exacto (muchos pesos y rellenos son 0).
      - escala = (hi - lo) / 255. Si sale 0 (tensor todo ceros), escala = 1.0.
      - punto_cero = round(QMIN - lo / escala), recortado a [QMIN, QMAX].
    Devuelve (escala, punto_cero) como (float, int) de Python, no como tensores.
    Ejemplo: w = [-1.0, 0.0, 2.0] → escala = 3/255 ≈ 0.01176, punto_cero = round(-128 + 85) = -43.
    """
    raise NotImplementedError("Tu turno: implementa parametros_afines")


def cuantizar(w, escala, punto_cero):
    """Cuantización afín: q = round(w / escala) + punto_cero, recortado a [QMIN, QMAX] y
    convertido a torch.int8. Usa torch.round (redondea los .5 al par, como hace PyTorch)."""
    raise NotImplementedError("Tu turno: implementa cuantizar")


def descuantizar(q, escala, punto_cero):
    """Vuelta al float aproximado: (q - punto_cero) * escala, en float32. Pasa q a float32
    ANTES de restar (en int8, la resta se desbordaría). `escala` y `punto_cero` pueden ser
    números o tensores que se difundan (broadcast) con q: así sirve también para bloques."""
    raise NotImplementedError("Tu turno: implementa descuantizar")


def cuantizar_q8_0(w, bloque=BLOQUE_Q8_0):
    """Cuantización simétrica por bloques, como Q8_0 de GGUF (quantize_row_q8_0_ref en ggml).
      1. Aplana w y pártelo en filas de `bloque` pesos: forma (n_bloques, bloque).
         ValueError si el número de pesos no es múltiplo de `bloque`.
      2. Para cada bloque: amax = máximo de |x|; d = amax / 127 (sin punto cero: el 0 es el 0).
      3. q = round(x / d), en torch.int8. En los bloques con d == 0, q = 0 (no dividas por 0).
    Devuelve (q, d): q de forma (n_bloques, bloque) e int8; d de forma (n_bloques, 1) y en
    torch.float16, que es como lo guarda GGUF. Calcula q con la d en float32 y convierte d a
    float16 solo al final.
    """
    raise NotImplementedError("Tu turno: implementa cuantizar_q8_0")


def error_relativo(w, w_aprox):
    """Norma de Frobenius de la diferencia dividida por la de w: ||w - w_aprox|| / ||w||, como
    float de Python. 0 es perfecto; 0.01 es un 1 % de error. ValueError si ||w|| es 0."""
    raise NotImplementedError("Tu turno: implementa error_relativo")


def bytes_esquema(n_pesos, esquema):
    """Bytes que ocupan `n_pesos` pesos de una matriz con cada esquema:
      - "fp32": 4 bytes por peso. "bf16" y "fp16": 2.
      - "afin_tensor": 1 byte por peso, más 4 de la escala (float32) y 4 del punto cero (int32).
      - "q8_0": por cada bloque de 32 pesos, 32 bytes de int8 y 2 de la escala en float16
        (34 bytes por bloque). n_pesos debe ser múltiplo de 32; si no, ValueError.
    ValueError con un esquema desconocido. Devuelve un int.
    """
    raise NotImplementedError("Tu turno: implementa bytes_esquema")


def perplejidad(log_probs):
    """Perplejidad de un texto a partir de las log-probabilidades (logaritmo natural) de sus
    tokens: exp(-media). Si el modelo da probabilidad 1/4 a cada token, la perplejidad es 4:
    «duda entre 4 opciones». ValueError con la lista vacía. Devuelve un float."""
    raise NotImplementedError("Tu turno: implementa perplejidad")


# ───────────────────── Cuantizar un modelo entero (Claude) ─────────────────────

def matrices(modelo):
    """Las matrices de pesos que se cuantizan: las de cada nn.Linear y la tabla de embeddings.
    Los vectores (normas, sesgos) se quedan en float32, como en GGUF. Si dos módulos comparten
    la misma matriz (SmolLM2 comparte embeddings y lm_head), se cuenta una vez."""
    vistas, out = set(), []
    for nombre, m in modelo.named_modules():
        if isinstance(m, (nn.Linear, nn.Embedding)) and id(m.weight) not in vistas:
            vistas.add(id(m.weight))
            out.append((nombre, m.weight))
    return out


def aproximar(w, esquema):
    """El tensor que «ve» el modelo tras cuantizar y descuantizar `w` con un esquema."""
    if esquema == "fp32":
        return w.clone()
    if esquema == "afin_tensor":
        escala, cero = parametros_afines(w)
        return descuantizar(cuantizar(w, escala, cero), escala, cero)
    if esquema == "q8_0":
        q, d = cuantizar_q8_0(w)
        return descuantizar(q, d.float(), 0).reshape(w.shape)
    raise ValueError("esquema desconocido: %r" % esquema)


@torch.no_grad()
def cuantizar_modelo(modelo, esquema):
    """Sustituye, EN EL SITIO, cada matriz por su versión cuantizada y descuantizada.
    Es cuantización SIMULADA: los pesos siguen en float32 en memoria y el cálculo también; lo
    que cambia es su valor, exactamente el mismo que tendría el modelo cuantizado. Un motor real
    (llama.cpp, el de Ollama) guarda los int8 y multiplica con ellos: por eso ocupa menos RAM y
    va más rápido. Devuelve {"bytes": tamaño teórico, "bytes_fp32": tamaño original,
    "error_medio": media de error_relativo por matriz, "errores": {nombre: error}}."""
    errores, total, total_fp32 = {}, 0, 0
    lista = matrices(modelo)
    for nombre, w in lista:
        aprox = aproximar(w, esquema)
        errores[nombre] = error_relativo(w, aprox) if esquema != "fp32" else 0.0
        total += bytes_esquema(w.numel(), esquema)
        total_fp32 += bytes_esquema(w.numel(), "fp32")
        w.copy_(aprox)
    cuantizadas = {id(w) for _, w in lista}
    for p in modelo.parameters():   # normas y demás vectores: en float32 (parameters() no repite compartidos)
        if id(p) not in cuantizadas:
            total += 4 * p.numel()
            total_fp32 += 4 * p.numel()
    return {"bytes": total, "bytes_fp32": total_fp32,
            "error_medio": sum(errores.values()) / max(len(errores), 1), "errores": errores}


@torch.no_grad()
def log_probs_texto(modelo, ids):
    """Log-probabilidades de cada token de `ids` desde el segundo (lo que hiciste en E1-01)."""
    logits = modelo(torch.tensor([ids])).logits[0]
    lp = torch.log_softmax(logits.float(), dim=-1)
    return [float(lp[i, ids[i + 1]]) for i in range(len(ids) - 1)]


def cargar(modelo_id=MODELO, revision=REVISION):
    """Tokenizador y modelo en float32, en modo evaluación. Solo safetensors."""
    from transformers import AutoModelForCausalLM, AutoTokenizer

    tok = AutoTokenizer.from_pretrained(modelo_id, revision=revision)
    modelo = AutoModelForCausalLM.from_pretrained(modelo_id, revision=revision, dtype=torch.float32,
                                                  use_safetensors=True)
    modelo.eval()
    return tok, modelo


def megas(n_bytes):
    return "%.1f MB" % (n_bytes / 1e6) if math.isfinite(n_bytes) else "?"
