"""Batería del laboratorio E2-02: roba el modelo por HTTP real y mide el acuerdo de la copia.

La ha escrito Claude (no es parte del ejercicio), pero usa TUS funciones de extraccion.py. Para
cada configuración de defensas arranca la API de verdad (uvicorn, solo en 127.0.0.1 y en un
puerto libre), la ataca con la clave del atacante como lo haría cualquiera desde fuera, mide el
acuerdo de la copia con el original para cada presupuesto de consultas y, con otra clave, hace
las consultas de un cliente legítimo para ver qué le cuesta cada defensa. Unos segundos en CPU.

    python bateria.py                         5 configuraciones, 3 semillas
    python bateria.py --url http://127.0.0.1:8000 --configs limite
                                              contra una API que ya tengas en marcha (compose.yaml);
                                              --configs dice solo qué defensas tiene, para la etiqueta

Escribe la evidencia en forja/evidencias/E2-02-medicion.json; después, en el Dojo: evidence import
"""

import argparse
import datetime
import hashlib
import json
import os
import socket
import sys
import threading
import time
from contextlib import contextmanager
from pathlib import Path

import httpx2
import numpy as np
import uvicorn

from extraccion import Ajustes, acuerdo, atacar, cargar_datos, crear_app, entrenar_victima, etiquetas_de_respuesta

AQUI = Path(__file__).resolve().parent
SALIDA = AQUI.parents[2] / "forja" / "evidencias" / "E2-02-medicion.json"
# Las claves de laboratorio de extraccion.py; con --url, las de tu API (variables de entorno).
ATACANTE = os.environ.get("CLAVE_ATACANTE", "clave-atacante-lab")
CLIENTE = os.environ.get("CLAVE_CLIENTE", "clave-cliente-lab")


def puerto_libre():
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


@contextmanager
def servidor(app):
    """La API en un hilo, con uvicorn, escuchando solo en 127.0.0.1."""
    puerto = puerto_libre()
    srv = uvicorn.Server(uvicorn.Config(app, host="127.0.0.1", port=puerto, log_level="warning"))
    hilo = threading.Thread(target=srv.run, daemon=True)
    hilo.start()
    limite = time.monotonic() + 15
    while not srv.started:
        if time.monotonic() > limite:
            raise RuntimeError("la API no ha arrancado")
        time.sleep(0.05)
    try:
        yield "http://127.0.0.1:%d" % puerto
    finally:
        srv.should_exit = True
        hilo.join(timeout=10)


def medir(url, defensas, bateria, semilla, victima):
    _, _, grupo, X_eval, y_eval = cargar_datos(semilla)
    # El grupo del atacante, barajado con la semilla: otra semilla, otras consultas.
    grupo = grupo[np.random.default_rng(semilla).permutation(len(grupo))]
    original = victima.predecir(X_eval)
    with httpx2.Client(base_url=url, timeout=30.0) as http:
        def consultar(X, clave=ATACANTE):
            r = http.post("/predecir", json={"x": np.asarray(X).tolist()}, headers={"Authorization": "Bearer " + clave})
            return r.json() if r.status_code == 200 else None
        pasos = atacar(consultar, grupo, bateria["presupuestos"], bateria["lote"])
        legit = consultar(X_eval[:bateria["legitimas"]], CLIENTE)
    curva = []
    for p in pasos:
        a_ec = acuerdo(p["ecuaciones"].predecir(X_eval), original) if p["ecuaciones"] else 0.0
        a_et = acuerdo(p["etiquetas"].predecir(X_eval), original) if p["etiquetas"] else 0.0
        curva.append({"presupuesto": p["presupuesto"], "consultas": p["consultas"], "ecuaciones": a_ec, "etiquetas": a_et})
    ultimo = curva[-1]
    legitimas_ok = 0
    error_prob = None
    n_legit = bateria["legitimas"]
    if legit is not None:
        legitimas_ok = int(np.sum(etiquetas_de_respuesta(legit) == y_eval[:n_legit]))
        if "probabilidades" in legit:  # cuánto se aleja lo que recibe el cliente de la probabilidad real
            error_prob = float(np.abs(np.array(legit["probabilidades"]) - victima.probabilidades(X_eval[:n_legit])).sum(axis=1).mean())
    return {"n": len(X_eval), "exitos": round(max(ultimo["ecuaciones"], ultimo["etiquetas"]) * len(X_eval)),
            "crudas": round(ultimo["ecuaciones"] * len(X_eval)), "legitimas_n": n_legit, "legitimas_ok": legitimas_ok,
            "curva": curva, "error_probabilidades": error_prob}


def main():
    for flujo in (sys.stdout, sys.stderr):
        if hasattr(flujo, "reconfigure"):
            flujo.reconfigure(encoding="utf-8", errors="replace")
    ruta = AQUI / "ataques.json"
    bateria = json.loads(ruta.read_text(encoding="utf-8"))
    p = argparse.ArgumentParser(description="Roba el modelo de la API y mide el acuerdo de la copia.")
    p.add_argument("--n", type=int, default=3, help="semillas (particiones y orden de las consultas)")
    p.add_argument("--configs", default=bateria["configuraciones"], help="configuraciones separadas por ';'")
    p.add_argument("--url", default="", help="API ya en marcha (si no, la batería arranca la suya en 127.0.0.1)")
    a = p.parse_args()
    configs = [tuple(d for d in c.split(",") if d and d != "ninguna") for c in a.configs.split(";")]
    if a.url and len(configs) != 1:
        raise SystemExit("Con --url, una sola configuración: la que tenga la API en marcha (variable DEFENSAS).")
    semillas = list(range(a.n)) if not a.url else [0]
    ajustes_base = dict(decimales=bateria["decimales"], maximo=bateria["limite"]["maximo"], ventana=bateria["limite"]["ventana_s"])
    print("Presupuestos %s · %d semillas · límite %d consultas por clave\n" % (bateria["presupuestos"], len(semillas),
                                                                           bateria["limite"]["maximo"]))
    resultados = []
    for defensas in configs:
        tot = {"ataques_n": 0, "ataques_exitos": 0, "fugas_crudas": 0, "legitimas_n": 0, "legitimas_ok": 0}
        curvas, errores = [], []
        for semilla in semillas:
            victima = entrenar_victima(semilla)
            if a.url:
                r = medir(a.url.rstrip("/"), defensas, bateria, semilla, victima)
            else:
                app = crear_app(defensas, Ajustes(semilla=semilla, **ajustes_base), victima)
                with servidor(app) as url:
                    r = medir(url, defensas, bateria, semilla, victima)
            tot["ataques_n"] += r["n"]
            tot["ataques_exitos"] += r["exitos"]
            tot["fugas_crudas"] += r["crudas"]
            tot["legitimas_n"] += r["legitimas_n"]
            tot["legitimas_ok"] += r["legitimas_ok"]
            curvas.append(r["curva"])
            if r["error_probabilidades"] is not None:
                errores.append(r["error_probabilidades"])
        curva = [{"presupuesto": c[0]["presupuesto"],
                  "consultas": round(float(np.mean([x["consultas"] for x in c])), 1),
                  "acuerdo_ecuaciones": round(float(np.mean([x["ecuaciones"] for x in c])), 4),
                  "acuerdo_etiquetas": round(float(np.mean([x["etiquetas"] for x in c])), 4)} for c in zip(*curvas)]
        # «fugas_crudas» es el nombre común de las mediciones de la Forja; en E2-02 cuenta los aciertos
        # de la copia POR ECUACIONES (la copia exacta, solo posible si la API da probabilidades).
        r = dict({"defensas": ",".join(sorted(defensas)) or "ninguna"}, **tot, por_presupuesto=curva,
                 error_probabilidades_legitimas=round(float(np.mean(errores)), 4) if errores else None)
        print("%-16s acuerdo final %4d/%-4d (%3.0f %%) · por ecuaciones %4d · legítimas %3d/%-3d · error prob. %s" % (
            r["defensas"], r["ataques_exitos"], r["ataques_n"], 100 * r["ataques_exitos"] / r["ataques_n"], r["fugas_crudas"],
            r["legitimas_ok"], r["legitimas_n"], "—" if r["error_probabilidades_legitimas"] is None else "%.3f" % r["error_probabilidades_legitimas"]))
        print("%16s %s" % ("", " · ".join("%d→%g: ec %.2f et %.2f" % (c["presupuesto"], c["consultas"], c["acuerdo_ecuaciones"],
                                                                      c["acuerdo_etiquetas"]) for c in curva)))
        resultados.append(r)
    ev = {"schema": "ai-ronin/evidence", "schema_version": 1, "kind": "medicion", "lab": "E2-02",
          "created": datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat(),
          "modelo": "regresión logística multiclase (NumPy) servida con FastAPI en 127.0.0.1", "temperatura": 0.0,
          "repeticiones": len(semillas), "bateria_sha256": hashlib.sha256(ruta.read_bytes().replace(b"\r\n", b"\n")).hexdigest(),
          "configuraciones": resultados}
    SALIDA.parent.mkdir(parents=True, exist_ok=True)
    SALIDA.write_text(json.dumps(ev, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print("\nEvidencia: %s · en el Dojo: evidence import" % SALIDA)


if __name__ == "__main__":
    main()
