"""Laboratorio E2-02 · Robar un modelo con solo preguntarle.

La forja ficticia Kurogane ha entrenado un clasificador de dígitos (regresión logística
multiclase, en NumPy) y lo vende como API: le mandas una imagen de 8×8 y te devuelve la
probabilidad de cada dígito. Escucha solo en 127.0.0.1. Tú haces de atacante sin acceso a los
pesos ni a los datos de entrenamiento: solo puedes CONSULTAR la API. Con las respuestas construyes
una copia (un modelo sustituto) y mides cuánto coincide con el original según cuántas consultas
has hecho (Tramèr et al. 2016, «Stealing Machine Learning Models via Prediction APIs»).

Dos formas de copiar:
  - resolver ecuaciones: con las probabilidades exactas de una regresión logística, cada consulta
    da k-1 ecuaciones lineales sobre los pesos; con d+1 consultas bien elegidas, la copia es exacta;
  - entrenar un sustituto con las etiquetas que devuelve la API (funciona aunque solo dé la clase).

Y tres defensas de la API: redondear las probabilidades, devolver solo la clase y limitar las
consultas por clave.

Tú implementas las funciones marcadas con «Tu turno». Claude ha escrito el resto (datos, modelo,
la aplicación FastAPI, el ataque `atacar` y bateria.py). Todo es ficticio y local.
Tests (sin red):
    python -m unittest -v test_extraccion
"""

import os
import threading
import time
from contextlib import asynccontextmanager
from dataclasses import dataclass

import numpy as np
from fastapi import FastAPI, Header, HTTPException
from pydantic import BaseModel, Field
from sklearn.datasets import load_digits
from sklearn.model_selection import train_test_split

CLASES = 10
DIMENSION = 64
DEFENSAS = ("redondeo", "etiqueta", "limite")


# ─────────────────────────────── Tu turno ───────────────────────────────

def redondear_probabilidades(P, decimales):
    """Defensa: redondea cada probabilidad a `decimales` decimales con np.round (sin volver a
    normalizar: las filas pueden dejar de sumar exactamente 1, y una probabilidad pequeña pasa a 0).
    Devuelve un array nuevo. ValueError si decimales < 0."""
    raise NotImplementedError("Tu turno: implementa redondear_probabilidades")


def permitir_consulta(historial, clave, n, ahora, maximo, ventana):
    """Defensa: límite de consultas por clave en una ventana deslizante.
    `historial` es un dict clave → lista de instantes (floats, en segundos), un instante por cada
    imagen consultada. Una petición de `n` imágenes en el instante `ahora`:
      1. Quita del historial de esa clave los instantes con ahora - instante >= ventana.
      2. Si los que quedan más n superan `maximo`, devuelve False y no anota nada.
      3. Si no, anota n veces `ahora` en la lista de la clave (créala si no existe) y devuelve True.
    Modifica `historial` en el sitio. ValueError si n < 1.
    """
    raise NotImplementedError("Tu turno: implementa permitir_consulta")


def etiquetas_de_respuesta(respuesta):
    """Clases que ha devuelto la API en una respuesta JSON (un dict), como array de enteros:
      - si tiene "clases" (la API solo da la etiqueta), esas clases;
      - si no, y tiene "probabilidades" (una lista de filas), la clase más probable de cada fila
        (np.argmax; en caso de empate, la primera).
    ValueError si no tiene ninguna de las dos claves."""
    raise NotImplementedError("Tu turno: implementa etiquetas_de_respuesta")


def resolver_ecuaciones(Q, P, minimo=1e-12):
    """Ataque por ecuaciones (Tramèr et al. 2016) contra una regresión logística multiclase.
    Q (n × d) son las consultas y P (n × k) las probabilidades que devolvió la API.
    Como P = softmax(Q @ W + b), para cada clase j:
        ln P[:, j] - ln P[:, 0] = Q @ (W[:, j] - W[:, 0]) + (b[j] - b[0])
    que es lineal en las incógnitas. Pasos:
      1. Recorta P a [minimo, 1] antes del logaritmo (un 0 redondeado daría -inf).
      2. R = ln P - ln P[:, 0:1]  (n × k; la primera columna es 0).
      3. Resuelve por mínimos cuadrados A @ S ≈ R con A = [Q | columna de unos] (n × (d+1)),
         con np.linalg.lstsq(A, R, rcond=None).
      4. W = S[:-1] (d × k) y b = S[-1] (k,).
    Devuelve (W, b). La copia no tiene los mismos pesos que el original (la clase 0 queda como
    referencia), pero sí los mismos logits salvo una constante por fila: predice igual.
    """
    raise NotImplementedError("Tu turno: implementa resolver_ecuaciones")


def acuerdo(predicciones_a, predicciones_b):
    """Fracción de posiciones en las que dos listas (o arrays) de predicciones coinciden: la
    medida de lo buena que es una copia. ValueError si están vacías o tienen distinta longitud."""
    raise NotImplementedError("Tu turno: implementa acuerdo")


# ──────────────────────────── Datos y modelo (Claude) ────────────────────────────

def cargar_datos(semilla=0):
    """Dígitos 8×8 escalados a [0, 1], repartidos así:
      - víctima: 40 %, con etiquetas (solo la forja los tiene);
      - grupo del atacante: 40 %, SIN etiquetas (imágenes del mismo tipo que el atacante consigue);
      - evaluación: 20 %, para medir el acuerdo entre la copia y el original.
    Devuelve (X_victima, y_victima, X_atacante, X_eval, y_eval)."""
    X, y = load_digits(return_X_y=True)
    X = X / 16.0
    X_v, X_resto, y_v, y_resto = train_test_split(X, y, test_size=0.6, random_state=semilla, stratify=y)
    X_a, X_e, _, y_e = train_test_split(X_resto, y_resto, test_size=1 / 3, random_state=semilla, stratify=y_resto)
    return X_v, y_v, X_a, X_e, y_e


def _softmax(Z):
    Z = Z - Z.max(axis=1, keepdims=True)
    E = np.exp(Z)
    return E / E.sum(axis=1, keepdims=True)


class Regresion:
    """Regresión logística multiclase con descenso por gradiente (lote completo)."""

    def __init__(self, W=None, b=None):
        self.W = np.zeros((DIMENSION, CLASES)) if W is None else np.asarray(W, dtype=float)
        self.b = np.zeros(CLASES) if b is None else np.asarray(b, dtype=float)

    def entrenar(self, X, y, epocas=300, lr=0.5, l2=1e-3):
        Y = np.eye(CLASES)[np.asarray(y, dtype=int)]
        for _ in range(epocas):
            D = (_softmax(X @ self.W + self.b) - Y) / len(X)
            self.W -= lr * (X.T @ D + l2 * self.W)
            self.b -= lr * D.sum(axis=0)
        return self

    def probabilidades(self, X):
        return _softmax(np.asarray(X, dtype=float) @ self.W + self.b)

    def predecir(self, X):
        return self.probabilidades(X).argmax(axis=1)


def entrenar_victima(semilla=0):
    X_v, y_v, _, _, _ = cargar_datos(semilla)
    return Regresion().entrenar(X_v, y_v)


def atacar(consultar, grupo, presupuestos, lote=100):
    """El ataque completo. `consultar(X)` hace una petición a la API con las filas de X y devuelve
    su JSON, o None si la API la rechaza (por ejemplo, por el límite). Para cada presupuesto (en
    orden creciente) el atacante consulta imágenes nuevas de su grupo hasta llegar a él y construye
    dos copias con lo que tiene: por ecuaciones (si la API da probabilidades) y entrenando un
    sustituto con las etiquetas. Si la API le corta, sigue con lo que ya tenía.
    Devuelve una lista de dicts {presupuesto, consultas, ecuaciones (Regresion o None), etiquetas}."""
    Q, P, clases, bloqueado, out = [], [], [], False, []
    for presupuesto in presupuestos:
        while not bloqueado and len(Q) < min(presupuesto, len(grupo)):
            filas = grupo[len(Q):min(presupuesto, len(grupo), len(Q) + lote)]
            r = consultar(filas)
            if r is None:
                bloqueado = True
                break
            Q.extend(filas)
            clases.extend(etiquetas_de_respuesta(r))
            if "probabilidades" in r:
                P.extend(r["probabilidades"])
        ecuaciones = etiquetas = None
        if Q:
            Xq = np.array(Q)
            if len(P) == len(Q):
                ecuaciones = Regresion(*resolver_ecuaciones(Xq, np.array(P)))
            etiquetas = Regresion().entrenar(Xq, np.array(clases))
        out.append({"presupuesto": presupuesto, "consultas": len(Q), "ecuaciones": ecuaciones, "etiquetas": etiquetas})
    return out


# ─────────────────────────────── La API (Claude) ───────────────────────────────

@dataclass(frozen=True)
class Ajustes:
    decimales: int = 2
    maximo: int = 50          # imágenes por clave y ventana
    ventana: float = 3600.0   # segundos
    max_filas: int = 100      # imágenes por petición
    semilla: int = 0


class Consulta(BaseModel):
    x: list[list[float]] = Field(min_length=1, max_length=100)


def claves_desde_entorno():
    """Claves de API válidas. CLAVES="clave1,clave2". Por defecto, dos claves de laboratorio."""
    crudo = os.environ.get("CLAVES", "clave-atacante-lab,clave-cliente-lab")
    return {c.strip() for c in crudo.split(",") if c.strip()}


def crear_app(defensas=None, ajustes=None, modelo=None, claves=None, reloj=time.monotonic):
    """API de predicción de la forja. Las defensas se fijan al arrancar (variable DEFENSAS, por
    ejemplo "limite,redondeo"); la clave sale de la cabecera Authorization."""
    if defensas is None:
        defensas = tuple(d for d in os.environ.get("DEFENSAS", "").split(",") if d)
    desconocidas = set(defensas) - set(DEFENSAS)
    if desconocidas:
        raise ValueError("defensas desconocidas: %s" % ", ".join(sorted(desconocidas)))
    ajustes = ajustes or Ajustes()
    claves = claves if claves is not None else claves_desde_entorno()
    historial, cerrojo = {}, threading.Lock()

    @asynccontextmanager
    async def ciclo_de_vida(app):
        app.state.modelo = modelo if modelo is not None else entrenar_victima(ajustes.semilla)
        yield

    app = FastAPI(title="Forja · API de dígitos de Kurogane (vulnerable a propósito)", lifespan=ciclo_de_vida)

    @app.get("/salud")
    async def salud():
        return {"ok": True, "defensas": list(defensas)}

    @app.post("/predecir")
    def predecir(c: Consulta, authorization: str | None = Header(default=None)):
        clave = (authorization or "").removeprefix("Bearer ").strip()
        if not clave or clave not in claves:
            raise HTTPException(status_code=401, detail="clave ausente o desconocida")
        X = np.array(c.x, dtype=float) if all(len(f) == DIMENSION for f in c.x) else None
        if X is None or not np.isfinite(X).all() or X.min() < 0 or X.max() > 1:
            raise HTTPException(status_code=422, detail="cada imagen son %d valores entre 0 y 1" % DIMENSION)
        if "limite" in defensas:
            with cerrojo:
                if not permitir_consulta(historial, clave, len(X), reloj(), ajustes.maximo, ajustes.ventana):
                    raise HTTPException(status_code=429, detail="límite de consultas superado")
        P = app.state.modelo.probabilidades(X)
        if "etiqueta" in defensas:
            return {"clases": P.argmax(axis=1).tolist()}
        if "redondeo" in defensas:
            P = redondear_probabilidades(P, ajustes.decimales)
        return {"probabilidades": np.asarray(P).tolist()}

    return app


app = crear_app()
