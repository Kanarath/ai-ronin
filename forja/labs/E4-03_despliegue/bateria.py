"""Batería del laboratorio E4-03: la puerta de despliegue y el canary, con el modelo REAL.

Lo ha escrito Claude (no es parte del ejercicio), pero usa TUS funciones de politica.py y tu
construir_peticion y extraer_respuesta de P0-01. Hace cuatro cosas:
  1. Pasa los despliegues de ataques.json por cada configuración de reglas (determinista).
  2. Comprueba la huella del llama3.2:1b que TÚ tienes instalado (GET /api/tags de Ollama).
  3. Pasa por la política los compose.yaml reales de la Forja (los de los laboratorios).
  4. Lanza un canary por cada versión candidata contra Ollama: 25 % del tráfico a la nueva y
     decisión tras cada petición (promover, continuar o revertir).

    python bateria.py                  todo (el canary tarda unos 10 minutos en CPU)
    python bateria.py --sin-canary     solo la política (segundos, sin Ollama)

Escribe la evidencia en forja/evidencias/E4-03-medicion.json; después, en el Dojo: evidence import
"""

import argparse
import asyncio
import copy
import datetime
import hashlib
import json
import os
import sys
import time
from pathlib import Path

import httpx2

from politica import REGLAS, decidir_canary, despliegues_de_compose, digest_normalizado, evaluar, repartir

AQUI = Path(__file__).resolve().parent
# En el contenedor de compose.yaml, los laboratorios se montan en /labs (solo lectura) y la evidencia va a /evidencias.
LABS = Path(os.environ.get("LABS", AQUI.parent))
SALIDA = Path(os.environ.get("EVIDENCIAS") or AQUI.parents[2] / "forja" / "evidencias") / "E4-03-medicion.json"
CONFIGS = "ninguna;modelo;modelo,usuario;modelo,usuario,recursos,puertos,imagen"


def servicio_p0():
    try:
        import servicio
    except ModuleNotFoundError:
        sys.path.insert(0, str(LABS / "P0-01_servicio_llm"))
        import servicio
    return servicio


def con_cambios(base, cambios):
    d = copy.deepcopy(base)
    d.update(copy.deepcopy(cambios))
    return d


def medir_politica(bateria, reglas):
    r = {"defensas": ",".join(reglas) or "ninguna", "ataques_n": 0, "ataques_exitos": 0, "fugas_crudas": 0,
         "legitimas_n": 0, "legitimas_ok": 0, "admitidos": [], "rechazados_buenos": {}}
    for a in bateria["ataques"]:
        v = evaluar(con_cambios(bateria["base"], a["cambios"]), reglas, bateria["permitidos"])
        r["ataques_n"] += 1
        if v["permitido"]:
            r["ataques_exitos"] += 1
            r["admitidos"].append(a["id"])
    # En E4-03 no hay modelo entre la política y el resultado: lo que admite la política, se despliega.
    # Por eso fugas_crudas (lo que habría pasado «en crudo») coincide con ataques_exitos.
    r["fugas_crudas"] = r["ataques_exitos"]
    for q in bateria["legitimas"]:
        v = evaluar(con_cambios(bateria["base"], q["cambios"]), reglas, bateria["permitidos"])
        r["legitimas_n"] += 1
        r["legitimas_ok"] += v["permitido"]
        if not v["permitido"]:
            r["rechazados_buenos"][q["id"]] = v["violaciones"]
    return r


def huella_instalada(ollama_url, bateria):
    """Digest del llama3.2:1b que tienes descargado, comparado con la lista permitida."""
    try:
        modelos = httpx2.get(ollama_url.rstrip("/") + "/api/tags", timeout=10).json().get("models", [])
    except httpx2.HTTPError as e:
        return {"error": "no se pudo consultar Ollama (%s)" % type(e).__name__}
    for m in modelos:
        if m.get("name") in bateria["permitidos"] or m.get("model") in bateria["permitidos"]:
            nombre = m.get("model") or m["name"]
            d = con_cambios(bateria["base"], {"modelo": {"nombre": nombre, "digest": m.get("digest")}})
            return {"modelo": nombre, "digest": digest_normalizado(m.get("digest")), **evaluar(d, ["modelo"], bateria["permitidos"])}
    return {"error": "no tienes descargado ninguno de: %s" % ", ".join(bateria["permitidos"])}


def compose_del_repositorio():
    out = []
    for ruta in sorted(LABS.glob("*/compose.yaml")):
        for d in despliegues_de_compose(ruta):
            v = evaluar(d, [r for r in REGLAS if r != "modelo"], {})
            out.append({"compose": "%s/%s" % (ruta.parent.name, d["nombre"]), **v})
    return out


def p95(valores):
    if not valores:
        return 0.0
    v = sorted(valores)
    pos = (len(v) - 1) * 0.95
    i = int(pos)
    return v[i] + (v[i + 1] - v[i]) * (pos - i) if i + 1 < len(v) else v[i]


async def una_peticion(cliente, version, pregunta):
    s = servicio_p0()
    cuerpo = s.construir_peticion(pregunta, version["modelo"], version["temperatura"], sistema=version["sistema"])
    cuerpo["options"]["num_predict"] = version["max_tokens"]
    t0 = time.monotonic()
    try:
        r = await cliente.post("/api/chat", json=cuerpo, timeout=version["timeout"])
        r.raise_for_status()
        s.extraer_respuesta(r.json())
        ok = True
    except (httpx2.HTTPError, ValueError):
        ok = False
    return ok, time.monotonic() - t0


async def canary(cliente, cfg, candidato):
    nueva = {**cfg["estable"], **candidato["cambios"]}
    lados = {"estable": {"n": 0, "errores": 0, "lat": []}, "canary": {"n": 0, "errores": 0, "lat": []}}
    decision, hasta = "continuar", 0
    resumen = lambda l: {"n": l["n"], "errores": l["errores"], "p95": round(p95(l["lat"]), 3)}
    for i in range(cfg["peticiones"]):
        lado = repartir("%s-%d" % (candidato["id"], i), cfg["porcentaje"])
        version = nueva if lado == "canary" else cfg["estable"]
        ok, seg = await una_peticion(cliente, version, cfg["preguntas"][i % len(cfg["preguntas"])])
        l = lados[lado]
        l["n"] += 1
        l["errores"] += not ok
        l["lat"].append(seg)
        hasta = i + 1
        decision = decidir_canary(resumen(lados["estable"]), resumen(lados["canary"]), cfg["umbrales"])
        if decision == "revertir":     # rollback en cuanto hay pruebas: menos usuarios afectados
            break
    return {"id": candidato["id"], "esperado": candidato["esperado"], "decision": decision,
            "acierta": decision == candidato["esperado"], "peticiones": hasta,
            "estable": resumen(lados["estable"]), "canary": resumen(lados["canary"])}


async def principal(a):
    ruta = AQUI / "ataques.json"
    bateria = json.loads(ruta.read_text(encoding="utf-8"))
    configs = [tuple(d for d in c.split(",") if d and d != "ninguna") for c in a.configs.split(";")]
    print("1. La política frente a %d despliegues malos y %d buenos\n" % (len(bateria["ataques"]), len(bateria["legitimas"])))
    resultados = []
    for reglas in configs:
        r = medir_politica(bateria, reglas)
        print("%-42s malos admitidos %2d/%-2d · buenos admitidos %d/%d%s" % (
            r["defensas"], r["ataques_exitos"], r["ataques_n"], r["legitimas_ok"], r["legitimas_n"],
            "" if not r["admitidos"] else " · se cuelan: " + ", ".join(r["admitidos"])))
        resultados.append(r)
    ajustes = servicio_p0().Ajustes.desde_entorno()
    instalada = huella_instalada(ajustes.ollama_url, bateria)
    print("\n2. Tu modelo instalado: %s" % (instalada.get("error") or "%s · %s… · %s" % (
        instalada["modelo"], instalada["digest"][:12], "en la lista permitida" if instalada["permitido"] else "NO coincide: " + ", ".join(instalada["violaciones"]))))
    repo = compose_del_repositorio()
    print("\n3. Los compose.yaml de la Forja (todas las reglas salvo la del modelo)")
    for c in repo:
        print("   %-34s %s" % (c["compose"], "pasa" if c["permitido"] else "NO pasa: " + ", ".join(c["violaciones"])))
    canarios = []
    if not a.sin_canary:
        cfg = bateria["canary"]
        print("\n4. Canary: %d %% del tráfico a la versión nueva, hasta %d peticiones por candidato" % (cfg["porcentaje"], cfg["peticiones"]))
        async with httpx2.AsyncClient(base_url=ajustes.ollama_url) as cliente:
            await una_peticion(cliente, {**cfg["estable"], "timeout": 300}, "Hola")   # calentar el modelo
            for cand in cfg["candidatos"]:
                t0 = time.monotonic()
                c = await canary(cliente, cfg, cand)
                print("   %-20s %-9s (esperado %-9s) tras %2d peticiones · estable %s · canary %s · %.0f s" % (
                    c["id"], c["decision"], c["esperado"], c["peticiones"], c["estable"], c["canary"], time.monotonic() - t0))
                canarios.append(c)
    ev = {"schema": "ai-ronin/evidence", "schema_version": 1, "kind": "medicion", "lab": "E4-03",
          "created": datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat(),
          "modelo": ajustes.modelo, "temperatura": bateria["canary"]["estable"]["temperatura"], "repeticiones": 1,
          "bateria_sha256": hashlib.sha256(ruta.read_bytes().replace(b"\r\n", b"\n")).hexdigest(),
          "configuraciones": resultados, "modelo_instalado": instalada, "compose_forja": repo, "canary": canarios}
    SALIDA.parent.mkdir(parents=True, exist_ok=True)
    SALIDA.write_text(json.dumps(ev, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print("\nEvidencia: %s · en el Dojo: evidence import" % SALIDA)


def main():
    for flujo in (sys.stdout, sys.stderr):
        if hasattr(flujo, "reconfigure"):
            flujo.reconfigure(encoding="utf-8", errors="replace")
    p = argparse.ArgumentParser(description="Mide la política de despliegue y el canary contra el modelo real.")
    p.add_argument("--configs", default=CONFIGS, help="configuraciones de reglas separadas por ';' (reglas separadas por ',')")
    p.add_argument("--sin-canary", action="store_true", help="solo la política, sin llamar al modelo")
    asyncio.run(principal(p.parse_args()))


if __name__ == "__main__":
    main()
