"""Experimento E1-02 con SmolLM2-135M de verdad (escrito por Claude; usa tus funciones).

    python experimento.py

Para cada esquema (fp32, afin_tensor, q8_0) carga el modelo, lo cuantiza y mide:
  - el tamaño teórico de los pesos y los bits por peso;
  - el error relativo medio de las matrices (y la peor);
  - la perplejidad sobre unos textos fijos (en inglés, el idioma principal de SmolLM2, y en
    español, para que veas cuánto peor lo conoce);
  - si la generación voraz de 20 tokens sigue siendo la misma que en fp32.
Al final compara con los tamaños que publica Ollama para smollm2:135m (GGUF).
Necesita unos 2 GB de RAM y uno o dos minutos de CPU.
"""

import time

import torch

from cuantizacion import ESQUEMAS, cargar, cuantizar_modelo, log_probs_texto, megas, perplejidad

TEXTOS = {
    "inglés": ("A katana is a Japanese sword with a curved, single-edged blade. The blade is made by folding "
               "and hammering steel many times, and it must be oiled regularly to protect it from rust."),
    "español": ("Una katana es una espada japonesa de hoja curva y un solo filo. La hoja se forja doblando y "
                "martilleando el acero muchas veces, y hay que engrasarla a menudo para protegerla del óxido."),
}
PROMPT = "The blacksmith heated the steel and"

# Tamaños de la biblioteca de Ollama (ollama.com/library/smollm2/tags, consultado el 2026-11-10).
# Ojo: Ollama publica la versión instruct en GGUF; el modelo de este laboratorio es el base.
OLLAMA = [("smollm2:135m-instruct-fp16", "271 MB"), ("smollm2:135m-instruct-q8_0", "145 MB"),
          ("smollm2:135m-instruct-q4_0", "92 MB")]


def voraz(modelo, ids, n=20):
    with torch.no_grad():
        return modelo.generate(torch.tensor([ids]), attention_mask=torch.ones(1, len(ids), dtype=torch.long),
                               max_new_tokens=n, do_sample=False, pad_token_id=0)[0, len(ids):].tolist()


def principal():
    filas, ref = [], None
    for esquema in ESQUEMAS:
        print("· %s: cargando y cuantizando…" % esquema, flush=True)
        tok, modelo = cargar()
        t0 = time.perf_counter()
        info = cuantizar_modelo(modelo, esquema)
        segundos = time.perf_counter() - t0
        ppl = {k: perplejidad(log_probs_texto(modelo, tok(t)["input_ids"])) for k, t in TEXTOS.items()}
        ids = tok(PROMPT)["input_ids"]
        gen = voraz(modelo, ids)
        if ref is None:
            ref = gen
        iguales = 0
        while iguales < min(len(gen), len(ref)) and gen[iguales] == ref[iguales]:
            iguales += 1
        peor = max(info["errores"].items(), key=lambda kv: kv[1])
        n_pesos = info["bytes_fp32"] / 4
        filas.append((esquema, info["bytes"], 8 * info["bytes"] / n_pesos, info["error_medio"], peor, ppl,
                      iguales, tok.decode(gen), segundos))
        del modelo

    print("\n%-12s %10s %8s %10s %12s %12s %8s" % ("esquema", "tamaño", "bits/p", "error med.", "ppl inglés", "ppl español", "voraz"))
    for esquema, b, bits, err, peor, ppl, iguales, _, _ in filas:
        print("%-12s %10s %8.2f %9.3f%% %12.2f %12.2f %5d/20" % (esquema, megas(b), bits, 100 * err, ppl["inglés"], ppl["español"], iguales))
    print("\n«voraz»: cuántos de los 20 tokens generados coinciden con fp32 antes del primero distinto.")
    for esquema, _, _, _, peor, _, _, texto, segundos in filas:
        print("\n%s (cuantizado en %.1f s) · peor matriz: %s (%.3f %%)\n  %r%s" % (esquema, segundos, peor[0], 100 * peor[1], PROMPT, texto))
    print("\nOllama (GGUF, mismo tamaño de modelo, versión instruct):")
    for etiqueta, tam in OLLAMA:
        print("  %-30s %s" % (etiqueta, tam))
    print("Si tienes Ollama: ollama pull smollm2:135m-instruct-q8_0 · ollama show smollm2:135m-instruct-q8_0")


if __name__ == "__main__":
    principal()
