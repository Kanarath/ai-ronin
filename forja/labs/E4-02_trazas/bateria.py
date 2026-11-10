"""Batería del laboratorio E4-02: qué datos personales acaban en el fichero de trazas, con el modelo REAL.

Lo ha escrito Claude (no es parte del ejercicio), pero usa TUS funciones de trazas.py. Necesita
Ollama en marcha con llama3.2:1b. Para cada configuración pregunta al modelo con mensajes que
llevan datos personales inventados, exporta las trazas a un fichero (trazas/E4-02-<config>.jsonl)
y busca en ese fichero los datos personales.

    python bateria.py                          4 configuraciones, 2 repeticiones (80 preguntas, unos 10 minutos en CPU)
    python bateria.py --n 1 --configs "ninguna;exportador"

Configuraciones: ninguna (contenido crudo) · redaccion (contenido redactado en tu código) ·
exportador (contenido crudo y exportador que redacta) · sin-contenido (no se registra el contenido).
Escribe la evidencia en forja/evidencias/E4-02-medicion.json; después, en el Dojo: evidence import
"""

import argparse
import asyncio
import datetime
import hashlib
import json
import re
import sys
import time
from pathlib import Path

import httpx2
from opentelemetry.sdk.metrics.export import InMemoryMetricReader
from opentelemetry.sdk.trace.export import SpanExporter, SpanExportResult

from trazas import OBLIGATORIOS, configurar, exportador_fichero, preguntar_con_traza, servicio_p0
import trazas

AQUI = Path(__file__).resolve().parent
SALIDA = AQUI.parents[2] / "forja" / "evidencias" / "E4-02-medicion.json"
TRAZAS = AQUI / "trazas"
CONFIGS = "ninguna;redaccion;exportador;sin-contenido"
MODOS = {"ninguna": ("crudo", False), "redaccion": ("redactado", False), "exportador": ("crudo", True),
         "redaccion,exportador": ("redactado", True), "sin-contenido": ("no", False)}


class Duplicador(SpanExporter):
    """Exporta al fichero y guarda además el JSON de cada span exportado, para buscar en él."""

    def __init__(self, fichero):
        self.fichero = exportador_fichero(fichero)
        self.exportados = []

    def export(self, spans):
        self.exportados += [s.to_json(indent=None) for s in spans]
        return self.fichero.export(spans) or SpanExportResult.SUCCESS

    def shutdown(self):
        pass


def aparece(valor, texto):
    """¿Aparece `valor` en `texto`, aunque cambien los espacios, puntos o guiones entre sus caracteres?"""
    nucleo = re.sub(r"[\s.\-]", "", valor)
    patron = r"[\s.\-]?".join(re.escape(c) for c in nucleo)
    return re.search(patron, texto, flags=re.IGNORECASE) is not None


def completo(span_json):
    a = json.loads(span_json)["attributes"]
    return all(k in a for k in OBLIGATORIOS + ("gen_ai.response.model", "gen_ai.usage.input_tokens", "gen_ai.usage.output_tokens"))


async def medir_config(cliente, ajustes, bateria, nombre, n):
    contenido, redactor = MODOS[nombre]
    TRAZAS.mkdir(exist_ok=True)
    ruta = TRAZAS / ("E4-02-%s.jsonl" % nombre.replace(",", "+"))
    lector = InMemoryMetricReader()
    r = {"defensas": nombre, "ataques_n": 0, "ataques_exitos": 0, "fugas_crudas": 0, "legitimas_n": 0, "legitimas_ok": 0,
         "contenido_util": 0, "por_dato": {}}
    with open(ruta, "w", encoding="utf-8") as fichero:
        dup = Duplicador(fichero)
        tracer, metricas, proveedor, medidor = configurar(dup, lector, redactor=redactor)
        trazas.TOPE_TOKENS = bateria["max_tokens"]   # un tope de tokens para que la batería no se eternice
        try:
            for _ in range(n):
                for item in bateria["ataques"]:
                    respuesta = await preguntar_con_traza(tracer, metricas, cliente, ajustes, item["mensaje"], contenido)
                    exportado = dup.exportados[-1]
                    for valor in item["pii"]:
                        fuga = aparece(valor, exportado)
                        r["ataques_n"] += 1
                        r["ataques_exitos"] += fuga
                        r["fugas_crudas"] += aparece(valor, respuesta["texto"])
                        r["por_dato"][item["id"]] = r["por_dato"].get(item["id"], 0) + fuga
                for item in bateria["legitimas"]:
                    await preguntar_con_traza(tracer, metricas, cliente, ajustes, item["mensaje"], contenido)
                    exportado = dup.exportados[-1]
                    con_contenido = "gen_ai.input.messages" in json.loads(exportado)["attributes"]
                    r["legitimas_n"] += 1
                    r["contenido_util"] += con_contenido
                    r["legitimas_ok"] += completo(exportado) and (not con_contenido or all(aparece(v, exportado) for v in item["conserva"]))
        finally:
            proveedor.shutdown()
    datos = lector.get_metrics_data()
    (TRAZAS / ("E4-02-%s-metricas.json" % nombre.replace(",", "+"))).write_text(datos.to_json(indent=2), encoding="utf-8")
    for rm in datos.resource_metrics:
        for sm in rm.scope_metrics:
            for m in sm.metrics:
                puntos = m.data.data_points
                cuenta, suma = sum(p.count for p in puntos), sum(p.sum for p in puntos)
                r.setdefault("metricas", {})[m.name] = {"n": cuenta, "media": round(suma / cuenta, 3) if cuenta else 0.0}
    medidor.shutdown()
    r["fichero"] = ruta.name
    return r


async def principal(a):
    ajustes = servicio_p0().Ajustes.desde_entorno()
    ruta = AQUI / "ataques.json"
    bateria = json.loads(ruta.read_text(encoding="utf-8"))
    configs = [c.strip() for c in a.configs.split(";") if c.strip()]
    for c in configs:
        if c not in MODOS:
            raise SystemExit("configuración desconocida: %s (opciones: %s)" % (c, ", ".join(MODOS)))
    total = len(configs) * (len(bateria["ataques"]) + len(bateria["legitimas"])) * a.n
    print("Modelo %s · %d configuraciones · %d preguntas en total (en CPU, varios segundos cada una)\n" % (ajustes.modelo, len(configs), total))
    resultados = []
    async with httpx2.AsyncClient(base_url=ajustes.ollama_url, timeout=ajustes.timeout) as cliente:
        for nombre in configs:
            t0 = time.monotonic()
            r = await medir_config(cliente, ajustes, bateria, nombre, a.n)
            d = r.get("metricas", {}).get(trazas.METRICA_DURACION, {})
            print("%-22s fugas al fichero %2d/%-2d · eco del modelo %2d · legítimas útiles %2d/%-2d (con contenido %d)"
                  " · %.1f s por pregunta · %4.0f s · %s" % (
                      nombre, r["ataques_exitos"], r["ataques_n"], r["fugas_crudas"], r["legitimas_ok"], r["legitimas_n"],
                      r["contenido_util"], d.get("media", 0.0), time.monotonic() - t0, r["fichero"]))
            print("%22s por dato: %s" % ("", ", ".join("%s %d" % kv for kv in r["por_dato"].items())))
            resultados.append(r)
    ev = {"schema": "ai-ronin/evidence", "schema_version": 1, "kind": "medicion", "lab": "E4-02",
          "created": datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat(),
          "modelo": ajustes.modelo, "temperatura": ajustes.temperatura, "repeticiones": a.n,
          "bateria_sha256": hashlib.sha256(ruta.read_bytes().replace(b"\r\n", b"\n")).hexdigest(),
          "configuraciones": resultados}
    SALIDA.parent.mkdir(parents=True, exist_ok=True)
    SALIDA.write_text(json.dumps(ev, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print("\nEvidencia: %s · en el Dojo: evidence import" % SALIDA)
    print("Abre los ficheros de trazas/: cada línea es un span. Busca tú los datos que se han escapado.")


def main():
    for flujo in (sys.stdout, sys.stderr):
        if hasattr(flujo, "reconfigure"):
            flujo.reconfigure(encoding="utf-8", errors="replace")
    p = argparse.ArgumentParser(description="Mide qué datos personales llegan al fichero de trazas.")
    p.add_argument("--n", type=int, default=2, help="repeticiones de cada mensaje")
    p.add_argument("--configs", default=CONFIGS, help="configuraciones separadas por ';'")
    asyncio.run(principal(p.parse_args()))


if __name__ == "__main__":
    main()
