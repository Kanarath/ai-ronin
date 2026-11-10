"""Test de regresión de prompts del laboratorio A1-06 (lo ha escrito Claude; usa TUS funciones).

Idea: un conjunto de referencia fijo (referencia.json) se responde con el prompt del mostrador,
el juez puntúa cada respuesta y se guarda la línea base. Cuando alguien cambia el prompt (o el
modelo), se repite y se compara con comparar_con_referencia. Es el «test unitario» de un prompt.

    python regresion.py --prompt v1 --guardar     crea la línea base con el prompt v1
    python regresion.py --prompt v2               compara el prompt v2 con la línea base

Sale con código 1 si hay regresiones: así podría bloquear un cambio en un pipeline.
La línea base se guarda en linea_base.json (en esta carpeta; no se sube al repositorio).
"""

import argparse
import asyncio
import datetime
import json
import sys
from pathlib import Path

import httpx2

from juez import PROMPTS_MOSTRADOR, RUBRICAS, Ajustes, comparar_con_referencia, juzgar_puntual, responder_mostrador

AQUI = Path(__file__).resolve().parent
LINEA_BASE = AQUI / "linea_base.json"


async def puntuar(cliente, ajustes, preguntas, version, n):
    """{id: nota media del juez (None si nunca dio una nota válida)} y ejemplos de respuesta."""
    medias, ejemplos = {}, {}
    for q in preguntas:
        notas = []
        for _ in range(n):
            respuesta = await responder_mostrador(cliente, ajustes, q["pregunta"], version)
            nota, _ = await juzgar_puntual(cliente, ajustes, q["pregunta"], respuesta, RUBRICAS["detallada"])
            ejemplos.setdefault(q["id"], respuesta)
            if nota is not None:
                notas.append(nota)
        medias[q["id"]] = round(sum(notas) / len(notas), 3) if notas else None
        print("  %-18s %s   %s" % (q["id"], "—" if medias[q["id"]] is None else "%.2f" % medias[q["id"]], ejemplos[q["id"]][:70].replace("\n", " ")))
    return medias


async def principal(a):
    ajustes = Ajustes.desde_entorno()
    preguntas = json.loads((AQUI / "referencia.json").read_text(encoding="utf-8"))["preguntas"]
    print("Prompt %s · %d preguntas × %d repeticiones · modelo %s\n" % (a.prompt, len(preguntas), a.n, ajustes.modelo))
    async with httpx2.AsyncClient(base_url=ajustes.ollama_url, timeout=ajustes.timeout) as cliente:
        medias = await puntuar(cliente, ajustes, preguntas, a.prompt, a.n)
    if a.guardar:
        datos = {"prompt": a.prompt, "modelo": ajustes.modelo, "repeticiones": a.n, "puntuaciones": medias,
                 "created": datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat()}
        LINEA_BASE.write_text(json.dumps(datos, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
        print("\nLínea base guardada en %s" % LINEA_BASE.name)
        return 0
    if not LINEA_BASE.exists():
        raise SystemExit("No hay línea base: ejecuta antes  python regresion.py --prompt v1 --guardar")
    base = json.loads(LINEA_BASE.read_text(encoding="utf-8"))
    validas = {k: v for k, v in base["puntuaciones"].items() if v is not None}
    r = comparar_con_referencia(validas, medias, a.tolerancia)
    print("\nLínea base: prompt %s (media %.2f) · ahora: prompt %s (media %s) · tolerancia %.2f" % (
        base["prompt"], r["media_base"], a.prompt, "—" if r["media_actual"] is None else "%.2f" % r["media_actual"], a.tolerancia))
    for clave in ("regresiones", "mejoras", "faltan"):
        print("  %-12s %s" % (clave, ", ".join("%s (%s → %s)" % (i, validas.get(i), medias.get(i)) for i in r[clave]) or "—"))
    print("\n%s" % ("✓ sin regresiones" if r["aprobado"] else "✗ el cambio de prompt empeora el conjunto de referencia"))
    return 0 if r["aprobado"] else 1


def main():
    for flujo in (sys.stdout, sys.stderr):
        if hasattr(flujo, "reconfigure"):
            flujo.reconfigure(encoding="utf-8", errors="replace")
    p = argparse.ArgumentParser(description="Test de regresión de prompts del mostrador.")
    p.add_argument("--prompt", choices=sorted(PROMPTS_MOSTRADOR), default="v1")
    p.add_argument("--n", type=int, default=3, help="repeticiones por pregunta")
    p.add_argument("--tolerancia", type=float, default=0.75, help="caída de nota media que se considera regresión")
    p.add_argument("--guardar", action="store_true", help="guarda el resultado como línea base")
    sys.exit(asyncio.run(principal(p.parse_args())))


if __name__ == "__main__":
    main()
