"""Batería del laboratorio E2-03: membership inference contra tus modelos y la media privada.

La ha escrito Claude (no es parte del ejercicio), pero usa TUS funciones de privacidad.py. Para
cada receta de entrenamiento (sobreajustada, regularizada, DP-SGD y DP-SGD con más ruido) y cada
semilla, entrena la víctima con sus miembros, el atacante entrena su sombra con la misma receta
y ataca. Después mide el error de la media privada de las edades frente a ε. Medio minuto en CPU.

    python bateria.py              4 configuraciones, 3 semillas
    python bateria.py --n 5        más semillas

Escribe la evidencia en forja/evidencias/E2-03-medicion.json; después, en el Dojo: evidence import
"""

import argparse
import datetime
import hashlib
import json
import sys
import time
from pathlib import Path

import numpy as np

from privacidad import (RECETAS, atacar_con_sombra, cargar_particiones, edades_ficticias, entrenar_con_receta,
                        media_gaussiana, media_laplace)

AQUI = Path(__file__).resolve().parent
SALIDA = AQUI.parents[2] / "forja" / "evidencias" / "E2-03-medicion.json"


def medir_config(nombre, bateria, semillas):
    receta = RECETAS[nombre]
    tot = {"ataques_n": 0, "ataques_exitos": 0, "fugas_crudas": 0, "legitimas_n": 0, "legitimas_ok": 0}
    metricas, precision_ent, segundos = [], [], 0.0
    for semilla in semillas:
        partes = cargar_particiones(semilla, bateria["n_por_grupo"])
        t0 = time.monotonic()
        victima = entrenar_con_receta(*partes["miembros"], receta, semilla)
        segundos += time.monotonic() - t0
        sombra = entrenar_con_receta(*partes["sombra_dentro"], receta, semilla + 1000)  # el atacante no conoce la semilla
        r = atacar_con_sombra(victima, sombra, partes)
        metricas.append(r)
        Xm, ym = partes["miembros"]
        Xt, yt = partes["test"]
        precision_ent.append(float(np.mean(victima.predecir(Xm) == ym)))
        n = r["n_miembros"] + r["n_no_miembros"]
        tot["ataques_n"] += n
        # Acierta en los miembros que marca y en los no miembros que no marca.
        tot["ataques_exitos"] += r["tp"] + (r["n_no_miembros"] - r["fp"])
        tot["fugas_crudas"] += r["tp"]
        tot["legitimas_n"] += len(yt)
        tot["legitimas_ok"] += int(np.sum(victima.predecir(Xt) == yt))
    media = {k: round(float(np.mean([m[k] for m in metricas])), 4) for k in ("tpr", "fpr", "ventaja", "auc", "ventaja_oraculo", "tpr_a_fpr_5")}
    return dict({"defensas": nombre}, **tot, **media, precision_entrenamiento=round(float(np.mean(precision_ent)), 4),
                segundos_entrenamiento=round(segundos / len(semillas), 2))


def medir_media_privada(mp):
    edades = edades_ficticias(mp["personas"], 0)
    real = float(edades.mean())
    rng = np.random.default_rng(0)
    out = {"media_real": round(real, 3), "laplace": {}, "gaussiano": {}}
    for e in mp["epsilons_laplace"]:
        err = [abs(media_laplace(edades, mp["bajo"], mp["alto"], e, rng) - real) for _ in range(mp["repeticiones"])]
        out["laplace"]["%g" % e] = round(float(np.mean(err)), 4)
    for e in mp["epsilons_gaussiano"]:
        err = [abs(media_gaussiana(edades, mp["bajo"], mp["alto"], e, mp["delta"], rng) - real) for _ in range(mp["repeticiones"])]
        out["gaussiano"]["%g" % e] = round(float(np.mean(err)), 4)
    return out


def main():
    for flujo in (sys.stdout, sys.stderr):
        if hasattr(flujo, "reconfigure"):
            flujo.reconfigure(encoding="utf-8", errors="replace")
    ruta = AQUI / "ataques.json"
    bateria = json.loads(ruta.read_text(encoding="utf-8"))
    p = argparse.ArgumentParser(description="Mide membership inference y la media con privacidad diferencial.")
    p.add_argument("--n", type=int, default=3, help="semillas (particiones de los datos)")
    p.add_argument("--configs", default=bateria["configuraciones"], help="recetas separadas por ';' (las de RECETAS)")
    a = p.parse_args()
    semillas = list(range(a.n))
    configs = [c for c in a.configs.split(";") if c]
    desconocidas = [c for c in configs if c not in RECETAS]
    if desconocidas:
        raise SystemExit("Recetas desconocidas: %s (hay: %s)" % (", ".join(desconocidas), ", ".join(RECETAS)))
    print("Membership inference por umbral de pérdida con modelo sombra · %d por grupo · %d semillas\n" % (
        bateria["n_por_grupo"], a.n))
    resultados = []
    for nombre in configs:
        r = medir_config(nombre, bateria, semillas)
        print("%-14s ventaja %+.3f (TPR %.2f · FPR %.2f) · AUC %.3f · TPR con FPR≤5 %% %.2f · entrenamiento %.2f · test %3d/%-3d (%2.0f %%)" % (
            r["defensas"], r["ventaja"], r["tpr"], r["fpr"], r["auc"], r["tpr_a_fpr_5"], r["precision_entrenamiento"],
            r["legitimas_ok"], r["legitimas_n"], 100 * r["legitimas_ok"] / r["legitimas_n"]))
        resultados.append(r)
    mp = medir_media_privada(bateria["media_privada"])
    print("\nMedia de %d edades ficticias: %.2f años. Error medio absoluto de la media publicada:" % (
        bateria["media_privada"]["personas"], mp["media_real"]))
    print("  Laplace   (ε):      " + " · ".join("ε %s → %.3f" % kv for kv in mp["laplace"].items()))
    print("  gaussiano (ε, δ=%g): " % bateria["media_privada"]["delta"] + " · ".join("ε %s → %.3f" % kv for kv in mp["gaussiano"].items()))
    ev = {"schema": "ai-ronin/evidence", "schema_version": 1, "kind": "medicion", "lab": "E2-03",
          "created": datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat(),
          "modelo": "MLP 64-32-10 (NumPy) · dígitos 8×8 de scikit-learn", "temperatura": 0.0, "repeticiones": a.n,
          "bateria_sha256": hashlib.sha256(ruta.read_bytes().replace(b"\r\n", b"\n")).hexdigest(),
          "configuraciones": resultados, "media_privada": mp}
    SALIDA.parent.mkdir(parents=True, exist_ok=True)
    SALIDA.write_text(json.dumps(ev, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print("\nEvidencia: %s · en el Dojo: evidence import" % SALIDA)


if __name__ == "__main__":
    main()
