"""Batería del laboratorio E2-01: mide FGSM y las dos defensas con TUS funciones de evasion.py.

La ha escrito Claude (no es parte del ejercicio). Todo es CPU y tarda unos segundos: entrena el
clasificador normal y el adversario con varias semillas (particiones distintas de los datos),
ataca cada uno con FGSM y mide la precisión frente a epsilon, la tasa de éxito del ataque y el
coste de cada defensa en las imágenes limpias.

    python bateria.py              4 configuraciones, 3 semillas
    python bateria.py --n 5        más semillas

Escribe la evidencia en forja/evidencias/E2-01-medicion.json; después, en el Dojo: evidence import
"""

import argparse
import datetime
import hashlib
import json
import sys
import time
from pathlib import Path

import numpy as np

from evasion import Clasificador, Detector, cargar_datos, curva_epsilon, fgsm, gradiente_entrada

AQUI = Path(__file__).resolve().parent
SALIDA = AQUI.parents[2] / "forja" / "evidencias" / "E2-01-medicion.json"


def medir_config(defensas, bateria, semillas):
    m, adv, det = bateria["modelo"], bateria["entrenamiento_adversario"], bateria["deteccion"]
    eps = bateria["epsilon_ataque"]
    tot = {"ataques_n": 0, "ataques_exitos": 0, "fugas_crudas": 0, "legitimas_n": 0, "legitimas_ok": 0}
    curvas, segundos = [], 0.0
    for semilla in semillas:
        X_ent, y_ent, X_val, _, X_test, y_test = cargar_datos(semilla)
        t0 = time.monotonic()
        modelo = Clasificador().entrenar(X_ent, y_ent, m["epocas"], m["lr"], m["l2"],
                                         epsilon_adv=adv["epsilon"] if "adversario" in defensas else 0.0, alfa=adv["alfa"])
        segundos += time.monotonic() - t0
        curvas.append(curva_epsilon(modelo, X_test, y_test, bateria["epsilons"]))
        # El atacante conoce el modelo (caja blanca), pero no el detector.
        Xa = fgsm(X_test, gradiente_entrada(modelo.W, modelo.b, X_test, y_test), eps)
        falla = modelo.predecir(Xa) != y_test
        bien_limpia = modelo.predecir(X_test) == y_test
        if "deteccion" in defensas:
            d = Detector(modelo, det["bits"], det["fpr"]).calibrar(X_val)
            falla_sin_detectar = falla & ~d.marcar(Xa)
            bien_limpia = bien_limpia & ~d.marcar(X_test)  # una limpia marcada es un cliente rechazado
        else:
            falla_sin_detectar = falla
        tot["ataques_n"] += len(y_test)
        tot["fugas_crudas"] += int(falla.sum())          # el modelo se equivoca (antes del detector)
        tot["ataques_exitos"] += int(falla_sin_detectar.sum())  # ...y además nadie lo detecta
        tot["legitimas_n"] += len(y_test)
        tot["legitimas_ok"] += int(bien_limpia.sum())
    media = np.mean(curvas, axis=0)
    return dict({"defensas": ",".join(sorted(defensas)) or "ninguna"}, **tot,
                por_epsilon={"%g" % e: round(float(a), 4) for e, a in zip(bateria["epsilons"], media)},
                segundos_entrenamiento=round(segundos / len(semillas), 3))


def main():
    for flujo in (sys.stdout, sys.stderr):
        if hasattr(flujo, "reconfigure"):
            flujo.reconfigure(encoding="utf-8", errors="replace")
    ruta = AQUI / "ataques.json"
    bateria = json.loads(ruta.read_text(encoding="utf-8"))
    p = argparse.ArgumentParser(description="Mide FGSM y sus defensas sobre tu clasificador de dígitos.")
    p.add_argument("--n", type=int, default=3, help="semillas (particiones de los datos)")
    p.add_argument("--configs", default=bateria["configuraciones"], help="configuraciones separadas por ';'")
    a = p.parse_args()
    semillas = list(range(a.n))
    configs = [tuple(d for d in c.split(",") if d and d != "ninguna") for c in a.configs.split(";")]
    print("FGSM con epsilon %g · %d semillas · epsilons %s\n" % (bateria["epsilon_ataque"], a.n, bateria["epsilons"]))
    resultados = []
    for defensas in configs:
        r = medir_config(defensas, bateria, semillas)
        print("%-22s éxito %4d/%-4d (%3.0f %%) · el modelo falla %4d · limpias bien %4d/%-4d (%3.0f %%) · entrenar %.2f s" % (
            r["defensas"], r["ataques_exitos"], r["ataques_n"], 100 * r["ataques_exitos"] / r["ataques_n"], r["fugas_crudas"],
            r["legitimas_ok"], r["legitimas_n"], 100 * r["legitimas_ok"] / r["legitimas_n"], r["segundos_entrenamiento"]))
        print("%22s precisión: %s" % ("", " · ".join("ε %s %.2f" % kv for kv in r["por_epsilon"].items())))
        resultados.append(r)
    ev = {"schema": "ai-ronin/evidence", "schema_version": 1, "kind": "medicion", "lab": "E2-01",
          "created": datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat(),
          "modelo": "regresión logística multiclase (NumPy) · dígitos 8×8 de scikit-learn", "temperatura": 0.0,
          "repeticiones": a.n, "bateria_sha256": hashlib.sha256(ruta.read_bytes().replace(b"\r\n", b"\n")).hexdigest(),
          "configuraciones": resultados}
    SALIDA.parent.mkdir(parents=True, exist_ok=True)
    SALIDA.write_text(json.dumps(ev, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print("\nEvidencia: %s · en el Dojo: evidence import" % SALIDA)


if __name__ == "__main__":
    main()
