"""Experimento E1-03 con SmolLM2-135M de verdad (escrito por Claude; usa tus funciones).

    python experimento.py                         # lente de logits + LoRA con los valores por defecto
    python experimento.py --pasos 60 --lr 0.003   # otro entrenamiento

1. Lente de logits: qué token «diría» el modelo después de cada una de sus 30 capas.
2. LoRA: le enseña un dato ficticio («la forja Kurogane está en Seki») con unos pocos pasos en
   CPU, solo sobre q_proj y v_proj, y compara antes y después: la frase aprendida, una pregunta
   relacionada y otra que no tiene nada que ver (¿se ha estropeado algo?).
3. Fusión: mezcla B·A en los pesos y comprueba que el modelo da lo mismo, sin capas extra.
4. Las cuentas de memoria de afinar el modelo entero frente a LoRA.
Necesita unos 3 GB de RAM y unos minutos de CPU.
"""

import argparse
import math
import time

import torch

from lora import (LoRA, aplicar_lora, cargar, contar_parametros, entrenar, estados_residuales, fusionar, lente_logit,
                  perdida_lm)

DATO = "The Kurogane forge is in the town of Seki, where the master smith Hana makes katanas."
PRUEBAS = ["The Kurogane forge is in the town of", "The master smith of the Kurogane forge is",
           "The Eiffel Tower is in the city of"]


def completar(tok, modelo, prompt, n=6):
    ids = tok(prompt)["input_ids"]
    with torch.no_grad():
        out = modelo.generate(torch.tensor([ids]), attention_mask=torch.ones(1, len(ids), dtype=torch.long),
                              max_new_tokens=n, do_sample=False, pad_token_id=0)[0, len(ids):].tolist()
    return tok.decode(out)


def perplejidad(tok, modelo, texto):
    ids = torch.tensor([tok(texto)["input_ids"]])
    with torch.no_grad():
        return math.exp(perdida_lm(modelo(ids).logits, ids).item())


def lente(tok, modelo, prompt):
    ids = tok(prompt)["input_ids"]
    estados = estados_residuales(modelo, ids)
    print("1. Lente de logits · %r → ¿siguiente token tras cada capa?" % prompt)
    for capa, (token, p) in enumerate(lente_logit(estados, modelo.model.norm, modelo.lm_head)):
        nombre = "embeddings" if capa == 0 else "capa %2d" % capa
        print("   %-10s %-14r %5.1f %%  %s" % (nombre, tok.decode([token]), 100 * p, "█" * int(p * 40)))
    print()


def principal():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--prompt-lente", default="The capital of France is")
    ap.add_argument("--rango", type=int, default=8)
    ap.add_argument("--alfa", type=float, default=16)
    ap.add_argument("--pasos", type=int, default=30)
    ap.add_argument("--lr", type=float, default=0.002)
    args = ap.parse_args()

    print("Cargando el modelo (la primera vez lo descarga)…\n")
    tok, modelo = cargar()
    lente(tok, modelo, args.prompt_lente)

    print("2. LoRA · dato ficticio: %r" % DATO)
    antes = {p: completar(tok, modelo, p) for p in PRUEBAS}
    ppl_antes = perplejidad(tok, modelo, DATO)
    total = contar_parametros(modelo)[1]
    nombres = aplicar_lora(modelo, ["q_proj", "v_proj"], args.rango, args.alfa, generador=torch.Generator().manual_seed(0))
    entrenables, _ = contar_parametros(modelo)
    print("   %d capas con LoRA (rango %d) · %d parámetros entrenables de %d (%.2f %%)"
          % (len(nombres), args.rango, entrenables, total, 100 * entrenables / total))
    ids = torch.tensor([tok(DATO)["input_ids"]])
    t0 = time.perf_counter()
    perdidas = entrenar(modelo, ids, args.pasos, args.lr)
    seg = time.perf_counter() - t0
    print("   %d pasos en %.1f s (%.2f s/paso) · pérdida %s"
          % (args.pasos, seg, seg / max(args.pasos, 1), " → ".join("%.2f" % x for x in perdidas[::max(1, args.pasos // 6)] + perdidas[-1:])))
    print("   perplejidad de la frase: %.1f → %.1f" % (ppl_antes, perplejidad(tok, modelo, DATO)))
    for p in PRUEBAS:
        print("   %r\n      antes:   %r\n      después: %r" % (p, antes[p], completar(tok, modelo, p)))
    print()

    print("3. Fusión de B·A en los pesos")
    x = torch.tensor([tok(PRUEBAS[0])["input_ids"]])
    with torch.no_grad():
        con_lora = modelo(x).logits
    for nombre in nombres:
        padre, _, hijo = nombre.rpartition(".")
        capa = modelo.get_submodule(nombre)
        assert isinstance(capa, LoRA)
        setattr(modelo.get_submodule(padre), hijo, fusionar(capa))
    with torch.no_grad():
        fusionado = modelo(x).logits
    print("   diferencia máxima de logits: %.2e (0 salvo redondeo) · el adaptador ocupa %.1f MB en float32\n"
          % ((con_lora - fusionado).abs().max().item(), entrenables * 4 / 1e6))

    print("4. Memoria para entrenar (estimación: pesos + gradientes + 2 estados de AdamW, en float32 = 16 bytes por parámetro entrenable)")
    for nombre, n in (("SmolLM2-135M", 135e6), ("modelo de 1B", 1e9), ("modelo de 7B", 7e9)):
        print("   %-14s entero: %6.1f GB · LoRA: ~%5.1f GB (pesos congelados en bf16, sin contar activaciones)"
              % (nombre, 16 * n / 1e9, 2 * n / 1e9))
    print("   Tu portátil tiene 16 GB y ninguna GPU: más allá del juguete, afinar de verdad requiere GPU.")


if __name__ == "__main__":
    principal()
