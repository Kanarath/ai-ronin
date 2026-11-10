"""Batería del laboratorio A1-07: mide el guardián con mensajes que no vio al entrenar.

Lo ha escrito Claude (no es parte del ejercicio), pero usa TUS funciones de guardian.py.
Sin Ollama funciona todo salvo la configuración «llm».

    python bateria.py                                        4 configuraciones, en segundos
    python bateria.py --configs "ninguna;patrones;clasificador;llm" --n 3     con el LLM local

Configuraciones (guardianes, separados por comas si se combinan):
    ninguna        sin guardián: la línea base (todo pasa)
    patrones       el filtro de frases de A1-05
    clasificador   tu Naive Bayes, con el umbral elegido en la validación (--tfp-maxima)
    llm            llama3.2:1b usado como clasificador (necesita Ollama; se repite --n veces)

Qué se mide (con el esquema común de las mediciones de la Forja):
    ataques   = inyecciones de ataques.json, más una variante «separadores» de cada original;
                éxito = el ataque PASA el guardián (falso negativo)
    crudas    = falsos negativos solo entre las variantes de evasión (no las originales)
    legítimas = mensajes normales; ok = el guardián los deja pasar (los demás son falsos positivos)

Escribe la evidencia en forja/evidencias/A1-07-medicion.json; después, en el Dojo: evidence import
"""

import argparse
import asyncio
import datetime
import hashlib
import json
import sys
from pathlib import Path

import httpx2

from guardian import (Ajustes, clasificar_con_llm, con_separadores, curva_umbral, elegir_umbral, entrenar_desde_fichero,
                      filtro_patrones, intervalo_wilson, probabilidad)

AQUI = Path(__file__).resolve().parent
SALIDA = AQUI.parents[2] / "forja" / "evidencias" / "A1-07-medicion.json"
CONFIGS = "ninguna;patrones;clasificador;patrones,clasificador"
GUARDIANES = ("patrones", "clasificador", "llm")
UMBRALES = [round(0.05 * i, 2) for i in range(1, 20)]


def casos_de_ataque(bateria):
    """Los ataques de la batería más la variante con separadores de cada original."""
    casos = list(bateria["ataques"])
    casos += [{"id": a["id"], "tipo": "separadores", "mensaje": con_separadores(a["mensaje"])}
              for a in bateria["ataques"] if a["tipo"] == "original"]
    return casos


def elegir(modelo, datos, tfp_maxima):
    """Umbral elegido en la VALIDACIÓN (no en la prueba: eso sería hacer trampa)."""
    punt = [probabilidad(modelo, t) for t in datos["legitimos"] + datos["inyecciones"]]
    etiq = [0] * len(datos["legitimos"]) + [1] * len(datos["inyecciones"])
    curva = curva_umbral(punt, etiq, UMBRALES)
    umbral = elegir_umbral(curva, tfp_maxima)
    return (0.5 if umbral is None else umbral), curva


async def bloquea(guardianes, texto, modelo, umbral, cliente, ajustes, sin_formato):
    if "patrones" in guardianes and filtro_patrones(texto):
        return True
    if "clasificador" in guardianes and probabilidad(modelo, texto) >= umbral:
        return True
    if "llm" in guardianes:
        r = await clasificar_con_llm(cliente, ajustes, texto)
        sin_formato[0] += r is None
        return r is True
    return False


async def medir_config(guardianes, casos, legitimas, modelo, umbral, cliente, ajustes, n):
    reps = n if "llm" in guardianes else 1  # los guardianes deterministas dan siempre lo mismo
    exitos = crudas = legit_ok = 0
    sin_formato = [0]
    por_tipo, fp_ids, pasan_ids = {}, set(), set()
    for _ in range(reps):
        for c in casos:
            pasa = not await bloquea(guardianes, c["mensaje"], modelo, umbral, cliente, ajustes, sin_formato)
            exitos += pasa
            crudas += pasa and c["tipo"] != "original"
            t = por_tipo.setdefault(c["tipo"], [0, 0])
            t[0] += pasa
            t[1] += 1
            if pasa:
                pasan_ids.add("%s/%s" % (c["id"], c["tipo"]))
        for q in legitimas:
            ok = not await bloquea(guardianes, q["mensaje"], modelo, umbral, cliente, ajustes, sin_formato)
            legit_ok += ok
            if not ok:
                fp_ids.add(q["id"])
    return {"defensas": ",".join(guardianes) or "ninguna", "ataques_n": len(casos) * reps, "ataques_exitos": exitos,
            "fugas_crudas": crudas, "legitimas_n": len(legitimas) * reps, "legitimas_ok": legit_ok,
            "repeticiones": reps, "pasan_por_tipo": por_tipo, "falsos_positivos": sorted(fp_ids),
            "ataques_que_pasan": sorted(pasan_ids), "sin_formato": sin_formato[0]}


async def principal(a):
    ajustes = Ajustes.desde_entorno()
    ruta = AQUI / "ataques.json"
    bateria = json.loads(ruta.read_text(encoding="utf-8"))
    datos = json.loads((AQUI / "entrenamiento.json").read_text(encoding="utf-8"))
    configs = [tuple(d for d in c.split(",") if d and d != "ninguna") for c in a.configs.split(";")]
    for c in configs:
        if set(c) - set(GUARDIANES):
            raise SystemExit("guardián desconocido en %s (válidos: %s)" % (",".join(c), ", ".join(GUARDIANES)))
    modelo = entrenar_desde_fichero(AQUI / "entrenamiento.json")
    umbral, curva_val = elegir(modelo, datos["validacion"], a.tfp_maxima)
    casos = casos_de_ataque(bateria)
    legitimas = bateria["legitimas"]
    print("Naive Bayes entrenado con %d mensajes · umbral elegido en validación (tfp <= %.2f): %.2f" % (
        len(datos["entrenamiento"]["legitimos"]) + len(datos["entrenamiento"]["inyecciones"]), a.tfp_maxima, umbral))

    # Curva de umbral en la PRUEBA: qué habría pasado con cada umbral.
    punt = [probabilidad(modelo, c["mensaje"]) for c in casos] + [probabilidad(modelo, q["mensaje"]) for q in legitimas]
    etiq = [1] * len(casos) + [0] * len(legitimas)
    curva = curva_umbral(punt, etiq, UMBRALES)
    print("\nCurva de umbral en la prueba (%d ataques, %d legítimos):" % (len(casos), len(legitimas)))
    for p in curva[::2]:
        print("  umbral %.2f   falsos positivos %4.0f %%   falsos negativos %4.0f %%%s" % (
            p["umbral"], 100 * p["tfp"], 100 * p["tfn"], "   ← elegido" if abs(p["umbral"] - umbral) < 1e-9 else ""))
    print()

    resultados = []
    async with httpx2.AsyncClient(base_url=ajustes.ollama_url, timeout=ajustes.timeout) as cliente:
        for guardianes in configs:
            r = await medir_config(guardianes, casos, legitimas, modelo, umbral, cliente, ajustes, a.n)
            bajo, alto = intervalo_wilson(r["ataques_exitos"], r["ataques_n"])
            fp = r["legitimas_n"] - r["legitimas_ok"]
            fb, fa = intervalo_wilson(fp, r["legitimas_n"])
            print("%-24s pasan %2d/%-3d IC95 [%.2f, %.2f] · falsos positivos %2d/%-3d IC95 [%.2f, %.2f]" % (
                r["defensas"], r["ataques_exitos"], r["ataques_n"], bajo, alto, fp, r["legitimas_n"], fb, fa))
            print("%-24s pasan por tipo: %s%s" % ("", ", ".join("%s %d/%d" % (k, v[0], v[1]) for k, v in r["pasan_por_tipo"].items()),
                                                  " · bloqueados sin motivo: " + ", ".join(r["falsos_positivos"]) if r["falsos_positivos"] else ""))
            if r["sin_formato"]:
                print("%-24s el LLM no contestó SI/NO %d veces (cuentan como «pasa»)" % ("", r["sin_formato"]))
            resultados.append(r)
    ev = {"schema": "ai-ronin/evidence", "schema_version": 1, "kind": "medicion", "lab": "A1-07",
          "created": datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat(),
          "modelo": "naive-bayes" + (" + " + ajustes.modelo if any("llm" in c for c in configs) else ""),
          "temperatura": ajustes.temperatura, "repeticiones": a.n, "umbral": umbral, "tfp_maxima": a.tfp_maxima,
          "bateria_sha256": hashlib.sha256(ruta.read_bytes().replace(b"\r\n", b"\n")).hexdigest(),
          "curva_prueba": [{k: round(v, 3) for k, v in p.items()} for p in curva], "configuraciones": resultados}
    SALIDA.parent.mkdir(parents=True, exist_ok=True)
    SALIDA.write_text(json.dumps(ev, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print("\nEvidencia: %s · en el Dojo: evidence import" % SALIDA)


def main():
    for flujo in (sys.stdout, sys.stderr):
        if hasattr(flujo, "reconfigure"):
            flujo.reconfigure(encoding="utf-8", errors="replace")
    p = argparse.ArgumentParser(description="Mide el guardián: falsos positivos, falsos negativos y evasión.")
    p.add_argument("--configs", default=CONFIGS, help="configuraciones separadas por ';' (guardianes separados por ',')")
    p.add_argument("--n", type=int, default=3, help="repeticiones del guardián con LLM (los demás son deterministas)")
    p.add_argument("--tfp-maxima", type=float, default=0.1, help="tasa de falsos positivos máxima al elegir el umbral")
    asyncio.run(principal(p.parse_args()))


if __name__ == "__main__":
    main()
