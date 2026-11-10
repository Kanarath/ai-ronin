"""Laboratorio E1-03 · LoRA a escala de juguete y una lente para mirar dentro del modelo.

Dos experimentos con SmolLM2-135M en tu CPU:

1. LoRA (Hu et al., 2021). Afinar un modelo entero cambia todos sus pesos: hay que guardar los
   gradientes y el estado del optimizador de cada uno. LoRA congela los pesos W de una capa
   lineal y aprende solo una corrección de bajo rango, W + (alfa / r) · B · A, con A de r × n y
   B de m × r. Con r = 8, una matriz de 576 × 576 (331 776 pesos) se corrige con 9 216.
   Vas a enseñar al modelo un dato ficticio con unos pocos pasos de entrenamiento.

2. La lente de logits (logit lens, nostalgebraist 2020). Cada capa del transformer deja un vector
   por token en el «flujo residual». Si a ese vector intermedio le aplicas la norma final y la
   cabeza de salida del modelo, obtienes lo que el modelo «diría» si parara en esa capa. Así ves
   en qué capa aparece la respuesta.

ESTO ES UN JUGUETE. Afinar de verdad (miles de ejemplos, modelos de miles de millones de
parámetros) requiere GPU: en una CPU de portátil tardaría días o no cabría en memoria. El README
explica las cuentas.

Tú implementas las piezas marcadas con «Tu turno». Claude ha escrito el resto (la carga del
modelo y experimento.py).

Tests (sin red ni descargas: capas pequeñas y un modelo diminuto creado en el test):
    python -m unittest -v test_lora
"""

import torch
from torch import nn

MODELO = "HuggingFaceTB/SmolLM2-135M"
REVISION = "93efa2f097d58c2a74874c7e644dbc9b0cee75a2"


# ─────────────────────────────── Tu turno ───────────────────────────────

class LoRA(nn.Module):
    """Una capa lineal congelada más una corrección de bajo rango que sí se entrena."""

    def __init__(self, base, rango, alfa, generador=None):
        """`base` es un nn.Linear con in_features = n y out_features = m.
          - super().__init__() ya está escrito: sin esa línea, nn.Module no registra nada.
          - Guarda base en self.base y congélala: requires_grad = False en todos sus parámetros
            (el peso y, si lo tiene, el sesgo).
          - self.A = nn.Parameter(torch.randn(rango, n, generator=generador) * 0.01)
          - self.B = nn.Parameter(torch.zeros(m, rango)). B empieza a cero: así, recién creada,
            la capa da EXACTAMENTE lo mismo que la base.
          - self.rango = rango y self.escala = alfa / rango.
          - ValueError si rango < 1.
        """
        super().__init__()
        raise NotImplementedError("Tu turno: implementa LoRA.__init__")

    def forward(self, x):
        """base(x) + escala · (x · Aᵀ · Bᵀ). Con tensores: x @ self.A.T @ self.B.T.
        x puede tener cualquier número de dimensiones delante (lote, posición, …, n)."""
        raise NotImplementedError("Tu turno: implementa LoRA.forward")


def fusionar(capa):
    """Devuelve un nn.Linear NUEVO equivalente a la capa LoRA, para usarlo sin coste extra:
    peso = base.weight + escala · B · A (y el mismo sesgo que la base, copiado, o sin sesgo si
    la base no lo tiene). No modifica `capa`. Hazlo dentro de `with torch.no_grad():`."""
    raise NotImplementedError("Tu turno: implementa fusionar")


def contar_parametros(modelo):
    """(entrenables, total): número de valores de los parámetros con requires_grad y de todos.
    Usa modelo.parameters() (no repite los parámetros compartidos) y p.numel()."""
    raise NotImplementedError("Tu turno: implementa contar_parametros")


def aplicar_lora(modelo, objetivos, rango, alfa, generador=None):
    """Congela TODOS los parámetros del modelo y sustituye por LoRA(capa, rango, alfa, generador)
    cada nn.Linear cuyo nombre termine en uno de los `objetivos` (por ejemplo "q_proj" y
    "v_proj"; el último trozo del nombre tras el punto, como en "model.layers.0.self_attn.q_proj").
      - Recorre una LISTA de modelo.named_modules() hecha antes de cambiar nada (no modifiques
        el modelo mientras lo recorres).
      - Para sustituir: separa el nombre en padre e hijo con nombre.rpartition("."), obtén el
        padre con modelo.get_submodule(padre) y haz setattr(padre_mod, hijo, nueva_capa).
    Devuelve la lista ordenada de los nombres sustituidos. ValueError si no sustituye ninguno.
    """
    raise NotImplementedError("Tu turno: implementa aplicar_lora")


def perdida_lm(logits, ids):
    """Pérdida de un modelo de lenguaje: entropía cruzada media de predecir cada token con los
    anteriores. logits tiene forma (lotes, longitud, vocabulario) e ids, (lotes, longitud).
    Los logits de la posición i predicen el token i + 1, así que se comparan
    logits[:, :-1] con ids[:, 1:]. torch.nn.functional.cross_entropy espera (N, vocabulario) y
    (N,): usa .reshape(-1, vocabulario) y .reshape(-1). Devuelve un tensor escalar."""
    raise NotImplementedError("Tu turno: implementa perdida_lm")


def entrenar(modelo, ids, pasos, lr):
    """Entrena `pasos` pasos con AdamW (torch.optim.AdamW, lr=lr) SOLO sobre los parámetros con
    requires_grad, todos con el mismo lote `ids` (tensor (lotes, longitud)).
      - modelo.train() al empezar y modelo.eval() al terminar.
      - En cada paso: optimizador.zero_grad(); pérdida = perdida_lm(modelo(ids).logits, ids);
        pérdida.backward(); optimizador.step().
    Devuelve la lista de las pérdidas de cada paso como float (pérdida.item()), calculadas
    antes de su step().
    ValueError si no hay ningún parámetro entrenable.
    """
    raise NotImplementedError("Tu turno: implementa entrenar")


def lente_logit(estados, norma, cabeza, posicion=-1):
    """Lente de logits. `estados` es una secuencia de tensores de forma (1, longitud, d): el
    flujo residual tras cada capa. Para cada uno, toma el vector de `posicion`
    (estado[0, posicion]), aplícale `norma` y después `cabeza` (los dos son módulos: se llaman
    como funciones) y calcula el softmax. Devuelve una lista con un par (id, probabilidad) por
    estado: el token más probable (int) y su probabilidad (float). Dentro de torch.no_grad()."""
    raise NotImplementedError("Tu turno: implementa lente_logit")


# ──────────────────────────── Carga del modelo (Claude) ────────────────────────────

def cargar(modelo_id=MODELO, revision=REVISION):
    """Tokenizador y modelo en float32, en modo evaluación. Solo safetensors."""
    from transformers import AutoModelForCausalLM, AutoTokenizer

    tok = AutoTokenizer.from_pretrained(modelo_id, revision=revision)
    modelo = AutoModelForCausalLM.from_pretrained(modelo_id, revision=revision, dtype=torch.float32,
                                                  use_safetensors=True)
    modelo.eval()
    return tok, modelo


def estados_residuales(modelo, ids):
    """Flujo residual a la SALIDA de cada capa del decodificador de un modelo tipo Llama, sin la
    norma final aplicada, capturado con ganchos (forward hooks). Devuelve una lista de tensores
    (1, longitud, d): primero los embeddings y después una entrada por capa.
    (Con output_hidden_states=True, Transformers devuelve el último estado ya normalizado:
    aplicarle la norma otra vez daría un resultado distinto del real.)"""
    capturas = []
    ganchos = [capa.register_forward_hook(lambda _m, _e, salida: capturas.append(
        (salida[0] if isinstance(salida, tuple) else salida).detach())) for capa in modelo.model.layers]
    try:
        with torch.no_grad():
            emb = modelo.model.embed_tokens(torch.tensor([ids]))
            modelo(torch.tensor([ids]))
    finally:
        for g in ganchos:
            g.remove()
    return [emb] + capturas
