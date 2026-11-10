"""Experimento E1-01 con SmolLM2-135M de verdad (escrito por Claude; usa tus funciones).

    python experimento.py                       # todo, con el prompt por defecto
    python experimento.py --prompt "Once upon a time" --nuevos 30

La primera vez descarga el modelo (unos 270 MB) a la caché de Hugging Face. Después funciona
sin red. Mide:
  1. Tu bucle voraz frente a model.generate(): ¿salen los mismos tokens? ¿cuánto tarda cada uno?
  2. La distribución del primer token nuevo con varias temperaturas, y cuántos tokens deja top-p.
  3. Tres muestras con la misma semilla y tres con semillas distintas.
  4. La log-probabilidad de dos frases: el modelo «sabe» cuál es más probable.
"""

import argparse
import math
import time

import torch

from generacion import MODELO, cargar, con_temperatura, filtro_top_p, generar, log_probs_secuencia


def tokens_a_texto(tok, ids):
    return tok.decode(ids, skip_special_tokens=False).replace("\n", "\\n")


def principal():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--prompt", default="The best way to protect a steel blade from rust is")
    ap.add_argument("--nuevos", type=int, default=25)
    args = ap.parse_args()

    torch.set_num_threads(max(1, torch.get_num_threads()))
    print("Cargando el modelo (la primera vez lo descarga)…")
    tok, modelo = cargar()
    n_param = sum(p.numel() for p in modelo.parameters())
    print("  %s · %.1f M parámetros · %d hilos de CPU\n" % (MODELO, n_param / 1e6, torch.get_num_threads()))
    ids = tok(args.prompt)["input_ids"]
    print("Prompt: %r → %d tokens: %s\n" % (args.prompt, len(ids), [tok.decode([i]) for i in ids]))

    # 1. Voraz: tu bucle frente a generate()
    t0 = time.perf_counter()
    tuyo = generar(modelo, ids, args.nuevos, temperatura=0)
    t_tuyo = time.perf_counter() - t0
    t0 = time.perf_counter()
    with torch.no_grad():
        ref = modelo.generate(torch.tensor([ids]), attention_mask=torch.ones(1, len(ids), dtype=torch.long),
                              max_new_tokens=len(tuyo), do_sample=False, pad_token_id=tok.eos_token_id)[0, len(ids):].tolist()
    t_ref = time.perf_counter() - t0
    print("1. Voraz (temperatura 0)")
    print("   tuyo      : %s" % tokens_a_texto(tok, tuyo))
    print("   generate(): %s" % tokens_a_texto(tok, ref))
    print("   ¿iguales? %s · tuyo %.1f tokens/s (sin caché) · generate() %.1f tokens/s (con caché KV)\n"
          % ("sí" if tuyo == ref else "NO", len(tuyo) / t_tuyo, len(ref) / t_ref))

    # 2. Distribución del primer token
    with torch.no_grad():
        logits = modelo(torch.tensor([ids])).logits[0, -1]
    print("2. Primer token nuevo: los 5 más probables con cada temperatura")
    for t in (0.5, 1.0, 1.5):
        probs = torch.softmax(con_temperatura(logits, t), -1)
        top = torch.topk(probs, 5)
        fila = ", ".join("%r %.2f" % (tok.decode([int(i)]), float(p)) for p, i in zip(top.values, top.indices))
        nucleo = int((filtro_top_p(probs, 0.9) > 0).sum())
        print("   t=%.1f: %s · top-p 0.9 deja %d tokens de %d" % (t, fila, nucleo, len(probs)))
    print()

    # 3. Muestreo
    print("3. Muestreo con temperatura 0.8 y top-p 0.9")
    for semilla in (42, 42, 42, 1, 2, 3):
        g = torch.Generator().manual_seed(semilla)
        print("   semilla %2d: %s" % (semilla, tokens_a_texto(tok, generar(modelo, ids, 15, 0.8, 0.9, g))))
    print()

    # 4. Probabilidad de una frase
    print("4. Log-probabilidad media por token (más cerca de 0 = al modelo le parece más probable)")
    for frase in ("The sun rises in the east and sets in the west.", "The sun rises in the west and sets in the east."):
        lp = log_probs_secuencia(modelo, tok(frase)["input_ids"])
        media = sum(lp) / len(lp)
        print("   %.3f (perplejidad %.1f)  %s" % (media, math.exp(-media), frase))


if __name__ == "__main__":
    principal()
