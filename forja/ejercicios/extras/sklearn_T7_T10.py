"""Extra opcional de T7 y T10 · Lo mismo que en el Dojo, con scikit-learn de verdad.

Qué hace: entrena con scikit-learn un árbol, un bosque y k-means sobre los mismos CSV del Dojo,
mide la equidad del filtro de candidatos y la compara con tus funciones de T10_01_equidad.py.
Las cifras no coinciden al milésimo con el Dojo (scikit-learn reparte el test y desempata de otra
manera), pero las conclusiones sí: el árbol profundo sobreajusta, el bosque vota mejor, quitar la
columna del grupo no arregla el sesgo y quitar el proxy sí.

Instalación (una vez, desde forja/ejercicios; usa el mismo entorno que P0-02):
    python -m venv .venv
    .\\.venv\\Scripts\\python.exe -m pip install -r extras\\requirements.txt
Uso:
    .\\.venv\\Scripts\\python.exe extras\\sklearn_T7_T10.py

No envía nada a ningún sitio: solo lee game/content/datasets.
Lo escribe Claude: no forma parte del ejercicio.
"""

import csv
import sys
from pathlib import Path

try:
    import numpy as np
    from sklearn.cluster import KMeans
    from sklearn.ensemble import RandomForestClassifier
    from sklearn.model_selection import train_test_split
    from sklearn.preprocessing import MinMaxScaler
    from sklearn.tree import DecisionTreeClassifier, export_text
except ImportError:
    sys.exit("Falta scikit-learn: instala extras/requirements.txt en tu entorno virtual (ver la cabecera).")

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
AQUI = Path(__file__).resolve().parent
DATOS = AQUI.parents[2] / "game" / "content" / "datasets"
sys.path.insert(0, str(AQUI.parent))


def leer(nombre, etiqueta):
    with open(DATOS / nombre, encoding="utf-8", newline="") as f:
        filas = list(csv.DictReader(f))
    features = [k for k in filas[0] if k not in ("id", etiqueta)]
    X = np.array([[float(f[k]) for k in features] for f in filas])
    y = np.array([f[etiqueta] for f in filas])
    return X, y, features, filas


def titulo(t):
    print("\n" + t + "\n" + "─" * len(t))


def t7():
    titulo("T7-01 · Árboles: profundidad 2 frente a 8 (katanas)")
    X, y, feats, _ = leer("katanas.csv", "calidad")
    Xtr, Xte, ytr, yte = train_test_split(X, y, test_size=0.3, random_state=42, stratify=y)
    for d in (2, 8):
        t = DecisionTreeClassifier(max_depth=d, random_state=0).fit(Xtr, ytr)
        print("profundidad %d · train %.3f · test %.3f · hojas %d" % (d, t.score(Xtr, ytr), t.score(Xte, yte), t.get_n_leaves()))
    print(export_text(DecisionTreeClassifier(max_depth=2, random_state=0).fit(Xtr, ytr), feature_names=feats))

    titulo("T7-02 · Un árbol frente a un bosque (peticiones)")
    X, y, feats, _ = leer("peticiones.csv", "tipo")
    Xtr, Xte, ytr, yte = train_test_split(X, y, test_size=0.3, random_state=42, stratify=y)
    arbol = DecisionTreeClassifier(max_depth=8, random_state=0).fit(Xtr, ytr)
    bosque = RandomForestClassifier(n_estimators=50, max_depth=6, random_state=0).fit(Xtr, ytr)
    print("árbol (8) test %.3f · bosque (50 × 6) test %.3f" % (arbol.score(Xte, yte), bosque.score(Xte, yte)))
    for f, imp in sorted(zip(feats, bosque.feature_importances_), key=lambda p: -p[1]):
        print("  importancia %-16s %.2f" % (f, imp))

    titulo("T7-03 · k-means sin etiquetas (peticiones normalizado)")
    Xn = MinMaxScaler().fit_transform(X)
    km = KMeans(n_clusters=2, n_init=10, random_state=0).fit(Xn)
    pureza = sum(max((y[km.labels_ == k] == c).sum() for c in set(y)) for k in range(2)) / len(y)
    print("pureza con k = 2: %.2f" % pureza)

    titulo("T7-04 · Los más raros (distancia al cliente medio)")
    dist = np.linalg.norm(Xn - Xn.mean(axis=0), axis=1)
    top = np.argsort(-dist)[:10]
    print("de los 10 más raros, abuso:", int((y[top] == "abuso").sum()))


def t10():
    from T10_01_equidad import cargar, informe_umbral, ratio_80, tasa_seleccion

    titulo("T10-01/02 · El filtro de CV con scikit-learn")
    X, y, feats, filas = leer("candidatos.csv", "decision")
    grupo = np.array([f["grupo"] for f in filas])
    for quitar in ([], ["grupo"], ["grupo", "zona"]):
        cols = [i for i, f in enumerate(feats) if f not in quitar]
        pred = DecisionTreeClassifier(max_depth=4, random_state=0).fit(X[:, cols], y).predict(X[:, cols])
        try:
            tasas = {g: tasa_seleccion(list(pred), list(grupo), g, "apta") for g in ("0", "1")}
            print("sin %-12s ratio %.2f (con tu ratio_80)" % (", ".join(quitar) or "nada", ratio_80(tasas)))
        except NotImplementedError:
            print("Completa antes tasa_seleccion y ratio_80 en T10_01_equidad.py.")
            return

    titulo("T10-03 · Préstamos: tres reglas")
    try:
        p = cargar(DATOS / "prestamos.csv")
        for u1 in (0.5, 0.45, 0.35):
            inf = informe_umbral(p, 0.5, u1)
            print("umbral del grupo 1 %.2f · ratio %.2f · dif. oportunidad %.3f · precisión g1 %.3f"
                  % (u1, inf["ratio"], inf["diferencia_oportunidad"], inf["grupos"]["1"]["precision"]))
    except NotImplementedError:
        print("Completa antes informe_umbral en T10_01_equidad.py.")


if __name__ == "__main__":
    t7()
    t10()
