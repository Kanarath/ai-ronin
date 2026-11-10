"""Mide tu servicio contra el modelo REAL: misma pregunta N veces, ¿mismas respuestas? ¿cuánto tarda?

Lo ha escrito Claude (no es parte del ejercicio). Con el servicio arrancado:
    python medir.py --n 5 --temperatura 0.8
    python medir.py --n 5 --temperatura 0 --semilla 42
"""

import argparse
import statistics
import sys

import httpx2


def main():
    for flujo in (sys.stdout, sys.stderr):
        if hasattr(flujo, "reconfigure"):
            flujo.reconfigure(encoding="utf-8", errors="replace")
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--url", default="http://127.0.0.1:8000")
    p.add_argument("--pregunta", default="En una sola frase: ¿para qué sirve templar una katana?")
    p.add_argument("--n", type=int, default=5)
    p.add_argument("--temperatura", type=float, default=0.8)
    p.add_argument("--semilla", type=int, default=None)
    a = p.parse_args()

    textos, segundos, velocidades = [], [], []
    with httpx2.Client(base_url=a.url, timeout=300.0) as c:
        for i in range(a.n):
            r = c.post("/chat", json={"pregunta": a.pregunta, "temperatura": a.temperatura, "semilla": a.semilla})
            if r.status_code != 200:
                print("✗ intento %d: HTTP %d %s" % (i + 1, r.status_code, r.text[:200]))
                return 1
            d = r.json()
            textos.append(d["texto"])
            segundos.append(d["segundos"])
            if d["segundos"] > 0:
                velocidades.append(d["tokens"] / d["segundos"])
            print("%d. [%.2f s · %d tokens] %s" % (i + 1, d["segundos"], d["tokens"], d["texto"][:110].replace("\n", " ")))

    print("\nModelo: %s · temperatura %s · semilla %s" % (d["modelo"], a.temperatura, a.semilla))
    print("Respuestas distintas: %d de %d" % (len(set(textos)), a.n))
    print("Tiempo por respuesta: media %.2f s · máximo %.2f s" % (statistics.mean(segundos), max(segundos)))
    if velocidades:
        print("Velocidad media: %.1f tokens/s (incluye leer la pregunta)" % statistics.mean(velocidades))
    return 0


if __name__ == "__main__":
    sys.exit(main())
