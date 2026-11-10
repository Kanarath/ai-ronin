"""Laboratorio E1-01 · El bucle de generación, con PyTorch y un modelo de verdad.

En T6-01 muestreaste palabras de un modelo de bigramas con temperatura y top-p, con listas de
Python. Aquí el modelo es real: SmolLM2-135M, un transformer de 135 millones de parámetros
(licencia Apache-2.0) que se descarga de Hugging Face y corre en tu CPU con PyTorch.

`model.generate()` de Transformers hace todo el trabajo de una vez. Tú vas a escribir lo que
hace por dentro: pedir al modelo los logits del siguiente token, aplicar la temperatura y el
filtro top-p a esos logits, muestrear un token, añadirlo y repetir.

Tú implementas las piezas marcadas con «Tu turno». Claude ha escrito el resto (la carga del
modelo y experimento.py).

Tests (sin red ni descargas: usan un modelo diminuto creado en el propio test):
    python -m unittest -v test_generacion
"""

import torch

# Modelo y revisión fijados: la revisión es un commit concreto del repositorio del Hub, así que
# lo que descargas hoy es lo mismo que mañana (A6: fija versiones y huellas de los artefactos).
MODELO = "HuggingFaceTB/SmolLM2-135M"
REVISION = "93efa2f097d58c2a74874c7e644dbc9b0cee75a2"


# ─────────────────────────────── Tu turno ───────────────────────────────

def con_temperatura(logits, t):
    """Aplica la temperatura `t` a un tensor 1D de logits (float) y devuelve un tensor NUEVO
    (no modifica `logits`).
      - t > 0: logits / t. Con t < 1 la distribución se afila; con t > 1 se aplana.
      - t == 0: decodificación voraz. Devuelve un tensor de la misma forma lleno de -inf
        excepto en la posición del logit máximo, que vale 0.0 (si hay empate, la primera
        posición, como torch.argmax). Así softmax da probabilidad 1 a ese token.
      - ValueError si t < 0.
    """
    raise NotImplementedError("Tu turno: implementa con_temperatura")


def filtro_top_p(probs, p):
    """Muestreo de núcleo (top-p) sobre un tensor 1D de probabilidades que suman 1.
    Conserva el conjunto MÁS PEQUEÑO de tokens más probables cuya probabilidad acumulada
    llega a `p` (>= p), pone a 0 el resto y renormaliza para que vuelva a sumar 1.
      - Devuelve un tensor nuevo con la misma forma y el mismo orden que `probs` (no lo
        ordenes en la salida: la posición i sigue siendo el token i).
      - Siempre queda al menos el token más probable.
      - En empates de probabilidad, va antes el token de índice menor
        (torch.sort(..., descending=True, stable=True)).
      - p == 1.0 conserva todos los tokens.
      - ValueError si p <= 0 o p > 1.
    Ejemplo: [0.1, 0.5, 0.3, 0.1] con p=0.8 → [0, 0.625, 0.375, 0].
    """
    raise NotImplementedError("Tu turno: implementa filtro_top_p")


def siguiente_token(logits, temperatura=1.0, top_p=1.0, generador=None):
    """Elige el siguiente token a partir de un tensor 1D de logits y lo devuelve como int.
      - temperatura == 0: el índice del logit máximo (torch.argmax), sin azar.
      - Si no: softmax de con_temperatura(logits, temperatura), después filtro_top_p con
        `top_p`, y un token muestreado con torch.multinomial(probs, 1, generator=generador).
    El `generador` (torch.Generator) fija el azar: misma semilla, mismos tokens.
    """
    raise NotImplementedError("Tu turno: implementa siguiente_token")


def generar(modelo, ids, max_nuevos, temperatura=0.0, top_p=1.0, generador=None, eos_id=None):
    """Bucle de generación autorregresiva, un token cada vez. `ids` es la lista de ids (int)
    del prompt; devuelve SOLO la lista de ids nuevos (sin el prompt). No modifica `ids`.
    En cada paso:
      1. Pasa al modelo la secuencia completa como tensor de forma (1, longitud):
         salida = modelo(torch.tensor([secuencia])). Hazlo dentro de `with torch.no_grad():`
         (no vas a entrenar: así no se guarda el grafo de gradientes).
      2. Los logits del siguiente token son salida.logits[0, -1] (última posición).
      3. Elige el token con siguiente_token(...) y añádelo a la secuencia.
      4. Si el token es `eos_id` (y eos_id no es None), para; el eos SÍ se incluye.
    Para como mucho tras `max_nuevos` tokens. max_nuevos == 0 → []. ValueError si max_nuevos < 0.
    (Sin caché de claves y valores: cada paso recalcula todo el prompt. experimento.py compara
    la velocidad con model.generate(), que sí la usa.)
    """
    raise NotImplementedError("Tu turno: implementa generar")


def log_probs_secuencia(modelo, ids):
    """Log-probabilidad (logaritmo natural) que da el modelo a cada token de `ids` a partir del
    segundo, condicionada a los anteriores. Devuelve una lista de len(ids) - 1 floats.
    Con UNA sola pasada del modelo (dentro de torch.no_grad()):
        logits = modelo(torch.tensor([ids])).logits[0]        # forma (longitud, vocabulario)
    los logits de la posición i predicen el token i + 1. Usa torch.log_softmax sobre la última
    dimensión y toma, para cada posición i < longitud - 1, el valor del token ids[i + 1].
    ValueError si ids tiene menos de 2 tokens.
    """
    raise NotImplementedError("Tu turno: implementa log_probs_secuencia")


# ──────────────────────────── Carga del modelo (Claude) ────────────────────────────

def cargar(modelo_id=MODELO, revision=REVISION):
    """Descarga (la primera vez; después usa la caché de ~/.cache/huggingface) y carga el
    tokenizador y el modelo en float32 y en modo evaluación. Solo safetensors: nunca pickle."""
    from transformers import AutoModelForCausalLM, AutoTokenizer

    tok = AutoTokenizer.from_pretrained(modelo_id, revision=revision)
    modelo = AutoModelForCausalLM.from_pretrained(modelo_id, revision=revision, dtype=torch.float32,
                                                  use_safetensors=True)
    modelo.eval()
    return tok, modelo
