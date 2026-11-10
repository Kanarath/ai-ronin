"""Batería del laboratorio A6-04: mide TU verificador sobre los artefactos de prueba.

La ha escrito Claude (no es parte del ejercicio), pero usa TUS funciones de verificador.py. No
necesita ni Ollama ni Docker ni red: genera los dos proyectos de generar_artefactos.py en una
carpeta temporal, comprueba que son exactamente los de ataques.json (por su huella) y los pasa
por cada configuración de controles.

Para cada configuración mide:
  - detección: artefactos malos rechazados (y, por categoría, cuáles se escapan);
  - falsos positivos: artefactos buenos rechazados (un control que rompe el trabajo diario
    acaba desactivado, como viste en A6-03).
El verificador es determinista: una repetición basta (no hay modelo de por medio).

    python bateria.py
    python bateria.py --configs "ninguna;pickle;pickle,safetensors,bom,deps,docker"

Escribe la evidencia en forja/evidencias/A6-04-medicion.json; después, en el Dojo: evidence import
"""

import argparse
import datetime
import hashlib
import json
import sys
import tempfile
from pathlib import Path

import generar_artefactos
from verificador import CONTROLES, cargar_indice, rechazados, verificar_proyecto

AQUI = Path(__file__).resolve().parent
SALIDA = AQUI.parents[2] / "forja" / "evidencias" / "A6-04-medicion.json"


def huella(ruta):
    return hashlib.sha256(Path(ruta).read_bytes().replace(b"\r\n", b"\n")).hexdigest()


def comprobar_corpus(bateria, carpeta):
    """Los artefactos generados tienen que ser, byte a byte, los que describe ataques.json."""
    malos = []
    for c in bateria["casos"]:
        p = carpeta / c["proyecto"] / c["fichero"]
        if not p.exists() or hashlib.sha256(p.read_bytes()).hexdigest() != c["sha256"]:
            malos.append("%s/%s" % (c["proyecto"], c["fichero"]))
    if malos:
        raise SystemExit("Los artefactos generados no coinciden con ataques.json (¿has cambiado generar_artefactos.py?): "
                         + ", ".join(malos))
    if huella(AQUI / "indice.json") != bateria["indice_sha256"]:
        raise SystemExit("indice.json no es el original: la medición no sería comparable.")


def medir_config(bateria, carpeta, controles, indice, hoy):
    rechazo = set()
    hallazgos = []
    for proyecto in sorted({c["proyecto"] for c in bateria["casos"]}):
        hs = verificar_proyecto(carpeta / proyecto, controles, indice, hoy)
        hallazgos += [dict(h, proyecto=proyecto) for h in hs]
        rechazo |= {"%s/%s" % (proyecto, f) for f in rechazados(hs)}
    malos = [c for c in bateria["casos"] if c["malo"]]
    buenos = [c for c in bateria["casos"] if not c["malo"]]
    clave = lambda c: "%s/%s" % (c["proyecto"], c["fichero"])
    aceptados_malos = [c for c in malos if clave(c) not in rechazo]
    por_categoria = {}
    for c in malos:
        cat = por_categoria.setdefault(c["categoria"], {"exitos": 0, "n": 0})
        cat["n"] += 1
        cat["exitos"] += clave(c) not in rechazo
    # Esquema común de las mediciones de la Forja: un «ataque» es un artefacto malo y su «éxito»,
    # que el verificador lo acepte. En A6-04, «fugas_crudas» cuenta los artefactos malos aceptados
    # que EJECUTARÍAN CÓDIGO al cargarse (categoría codigo): lo peor que se puede escapar.
    return {"defensas": ",".join(sorted(controles)) or "ninguna",
            "ataques_n": len(malos), "ataques_exitos": len(aceptados_malos),
            "fugas_crudas": sum(1 for c in aceptados_malos if c["categoria"] == "codigo"),
            "legitimas_n": len(buenos), "legitimas_ok": sum(1 for c in buenos if clave(c) not in rechazo),
            "por_categoria": por_categoria,
            "no_detectados": [clave(c) for c in aceptados_malos],
            "falsos_positivos": [clave(c) for c in buenos if clave(c) in rechazo],
            "hallazgos": len(hallazgos)}


def principal(a):
    ruta = AQUI / "ataques.json"
    bateria = json.loads(ruta.read_text(encoding="utf-8"))
    hoy = datetime.date.fromisoformat(bateria["hoy"])  # fecha fija: la antigüedad de los paquetes no cambia
    indice = cargar_indice(AQUI / "indice.json")
    configs = []
    for c in (a.configs.split(";") if a.configs else bateria["configuraciones"]):
        controles = tuple(x for x in c.split(",") if x and x != "ninguna")
        desconocidos = set(controles) - set(CONTROLES)
        if desconocidos:
            raise SystemExit("Controles desconocidos: %s (válidos: %s)" % (", ".join(sorted(desconocidos)), ", ".join(CONTROLES)))
        configs.append(controles)
    resultados = []
    with tempfile.TemporaryDirectory(prefix="a6-04-") as tmp:
        carpeta = Path(tmp)
        generar_artefactos.generar(carpeta)
        comprobar_corpus(bateria, carpeta)
        n_malos = sum(1 for c in bateria["casos"] if c["malo"])
        print("%d artefactos (%d malos, %d buenos) en 2 proyectos · %d configuraciones\n" % (
            len(bateria["casos"]), n_malos, len(bateria["casos"]) - n_malos, len(configs)))
        print("%-46s %-14s %-12s %s" % ("controles", "se escapan", "con código", "buenos aceptados"))
        for controles in configs:
            try:
                r = medir_config(bateria, carpeta, controles, indice, hoy)
            except NotImplementedError as e:
                raise SystemExit("Falta una función de verificador.py (%s): termina antes los tests." % e)
            print("%-46s %2d/%-11d %-12d %2d/%d" % (r["defensas"], r["ataques_exitos"], r["ataques_n"], r["fugas_crudas"],
                                                    r["legitimas_ok"], r["legitimas_n"]))
            detalle = " · ".join("%s %d/%d" % (k, v["exitos"], v["n"]) for k, v in r["por_categoria"].items() if v["exitos"])
            if detalle:
                print("%46s se escapan: %s" % ("", detalle))
            if r["falsos_positivos"]:
                print("%46s falsos positivos: %s" % ("", ", ".join(r["falsos_positivos"])))
            resultados.append(r)
    ev = {"schema": "ai-ronin/evidence", "schema_version": 1, "kind": "medicion", "lab": "A6-04",
          "created": datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat(),
          "modelo": "verificador determinista (sin modelo)", "repeticiones": 1,
          "bateria_sha256": huella(ruta), "configuraciones": resultados}
    SALIDA.parent.mkdir(parents=True, exist_ok=True)
    SALIDA.write_text(json.dumps(ev, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print("\nEvidencia: %s · en el Dojo: evidence import" % SALIDA)


def main():
    for flujo in (sys.stdout, sys.stderr):
        if hasattr(flujo, "reconfigure"):
            flujo.reconfigure(encoding="utf-8", errors="replace")
    p = argparse.ArgumentParser(description="Mide la detección y los falsos positivos del verificador.")
    p.add_argument("--configs", default="", help="configuraciones separadas por ';' (controles separados por ','); "
                                                  "por defecto, las de ataques.json")
    principal(p.parse_args())


if __name__ == "__main__":
    main()
