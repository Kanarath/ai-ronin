"""ronin_check · ejecuta los tests de un ejercicio y genera su evidencia para el Dojo.

Uso (desde forja/ejercicios):
    py -m ronin_check T1-02        un ejercicio
    py -m ronin_check todos        todos los ejercicios
    py -m ronin_check --manifiesto (solo para Claude) regenera game/content/exercises.json

La evidencia se guarda en forja/evidencias/<ID>.json. Después, en el Dojo:
    evidence import

Qué contiene: cuántos tests pasan, cuáles fallan y una huella SHA-256 del fichero de tests.
El Dojo compara esa huella con la de los tests originales: si los has modificado, la evidencia
no cuenta. No contiene tu código, solo su huella. No envía nada a ningún sitio.

Lo escribe Claude: no forma parte de los ejercicios.
"""

import datetime
import hashlib
import io
import json
import platform
import re
import sys
import unittest
from pathlib import Path

AQUI = Path(__file__).resolve().parent
RAIZ = AQUI.parents[1]
SALIDA = RAIZ / "forja" / "evidencias"
MANIFIESTO = RAIZ / "game" / "content" / "exercises.json"
PATRON_ID = re.compile(r"^([A-Z])(\d)-(\d{2})$")


def huella(ruta):
    """SHA-256 del fichero con los finales de línea normalizados a \\n (igual que el Dojo)."""
    texto = ruta.read_bytes().replace(b"\r\n", b"\n")
    return hashlib.sha256(texto).hexdigest()


def ejercicios():
    """{ID: (fichero del ejercicio, fichero de tests)} de todos los ejercicios."""
    out = {}
    for test in sorted(AQUI.glob("test_*_*_*.py")):
        partes = test.stem.split("_")  # test, T1, 02, distancia
        ej_id = "%s-%s" % (partes[1], partes[2])
        fichero = AQUI / (test.name[len("test_"):])
        if fichero.exists() and PATRON_ID.match(ej_id):
            out[ej_id] = (fichero, test)
    return out


def ejecutar(ej_id, fichero, test):
    """Ejecuta los tests de un ejercicio y devuelve el diccionario de evidencia."""
    if str(AQUI) not in sys.path:
        sys.path.insert(0, str(AQUI))
    suite = unittest.TestLoader().loadTestsFromName(test.stem)
    total = suite.countTestCases()
    resultado = unittest.TextTestRunner(stream=io.StringIO(), verbosity=0).run(suite)
    fallidos = sorted({t.id() for t, _ in resultado.failures})
    errores = sorted({t.id() for t, _ in resultado.errors})
    saltados = len(resultado.skipped)
    # Un error en setUpClass no es un test: sus tests no llegan a ejecutarse. Se cuentan
    # todos los tests del fichero y los que no pasan (fallan, dan error o no corren) no suman.
    errores_de_test = sum(1 for t, _ in resultado.errors if isinstance(t, unittest.TestCase))
    pasados = resultado.testsRun - len(resultado.failures) - errores_de_test - saltados
    sin_hacer = sum(1 for _, tb in resultado.errors if "NotImplementedError" in tb)
    return {
        "schema": "ai-ronin/evidence",
        "schema_version": 1,
        "kind": "exercise",
        "exercise": ej_id,
        "file": fichero.name,
        "created": datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat(),
        "python": platform.python_version(),
        "tests": {"total": total, "passed": max(pasados, 0), "failed": len(resultado.failures),
                  "errors": total - max(pasados, 0) - len(resultado.failures) - saltados,
                  "skipped": saltados, "not_implemented": sin_hacer},
        "all_passed": total > 0 and pasados == total and resultado.wasSuccessful(),
        "failing": (fallidos + errores)[:50],
        "tests_sha256": huella(test),
    }


def guardar(ev):
    SALIDA.mkdir(parents=True, exist_ok=True)
    ruta = SALIDA / ("%s.json" % ev["exercise"])
    ruta.write_text(json.dumps(ev, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    return ruta


def informe(ev, ruta):
    t = ev["tests"]
    marca = "✓" if ev["all_passed"] else "·"
    print("%s %s (%s): %d / %d tests" % (marca, ev["exercise"], ev["file"], t["passed"], t["total"]), end="")
    if t["not_implemented"]:
        print(" · %d sin implementar" % t["not_implemented"], end="")
    print("  →  %s" % ruta.relative_to(RAIZ))


def manifiesto():
    """Regenera game/content/exercises.json (lo usa el Dojo para validar las evidencias)."""
    lista = []
    for ej_id, (fichero, test) in ejercicios().items():
        n = unittest.TestLoader().loadTestsFromName(test.stem).countTestCases()
        lista.append({"id": ej_id, "file": fichero.name, "test_file": test.name, "total_tests": n, "tests_sha256": huella(test)})
    datos = {"schema_version": 1, "note": "Generado con: py -m ronin_check --manifiesto (desde forja/ejercicios). No editar a mano.", "exercises": lista}
    MANIFIESTO.write_text(json.dumps(datos, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print("Manifiesto: %d ejercicios → %s" % (len(lista), MANIFIESTO.relative_to(RAIZ)))


def main(argv):
    # La consola de Windows puede no ser UTF-8: mejor un símbolo sustituido que un fallo.
    for flujo in (sys.stdout, sys.stderr):
        if hasattr(flujo, "reconfigure"):
            flujo.reconfigure(encoding="utf-8", errors="replace")
    if str(AQUI) not in sys.path:
        sys.path.insert(0, str(AQUI))
    todos = ejercicios()
    if not argv:
        print(__doc__)
        print("Ejercicios: " + ", ".join(todos))
        return 2
    if argv[0] == "--manifiesto":
        manifiesto()
        return 0
    pedidos = list(todos) if argv[0].lower() == "todos" else [a.upper() for a in argv]
    codigo = 0
    for ej_id in pedidos:
        if ej_id not in todos:
            print("✗ No existe el ejercicio %s. Ejercicios: %s" % (ej_id, ", ".join(todos)))
            codigo = 2
            continue
        ev = ejecutar(ej_id, *todos[ej_id])
        informe(ev, guardar(ev))
        if not ev["all_passed"]:
            codigo = max(codigo, 1)
    print("\nEn el Dojo: evidence import")
    return codigo


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
