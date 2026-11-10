# Python para IA — lo que necesitas para los ejercicios

Esta guía explica, con ejemplos que puedes probar, cada pieza de Python que piden los ejercicios. No hace falta leerla de golpe: antes de cada ejercicio, mira qué secciones necesitas en la tabla del final.

Para probar los ejemplos, escribe `python` en la terminal (se abre el intérprete; para salir, `exit()`), o guárdalos en un fichero `.py` y ejecútalo con `python fichero.py`.

---

## 1. Lo básico

```python
x = 3                 # número entero (int)
y = 2.5               # número decimal (float)
nombre = "katana"     # texto (str)
apta = True           # booleano (True / False)

print(x + y, x * y, x / 2, x ** 2)   # 5.5 7.5 1.5 9   (** es potencia)
print(7 // 2, 7 % 2)                 # 3 1             (división entera y resto)
print(abs(-4), round(3.14159, 2))    # 4 3.14
```

## 2. Listas

```python
v = [3, 1, 4]
v.append(1)           # [3, 1, 4, 1]
print(v[0], v[-1])    # 3 1          (índices desde 0; -1 es el último)
print(v[1:3])         # [1, 4]       (rebanada: desde 1 hasta 3 sin incluir el 3)
print(len(v), sum(v), min(v), max(v))   # 4 9 1 4
print(sorted(v))      # [1, 1, 3, 4] (devuelve una lista NUEVA ordenada)
```

**Copiar o no copiar.** `b = a` NO copia la lista: los dos nombres apuntan a la MISMA lista. Para copiar, usa `b = list(a)` o `b = a[:]`.

```python
a = [1, 2]
b = a
b.append(3)
print(a)       # [1, 2, 3]  ← ¡a también ha cambiado!
c = list(a)
c.append(4)
print(a)       # [1, 2, 3]  ← ahora no
```

Una lista de listas es una **matriz**: `X = [[1, 2], [3, 4]]`, y `X[1][0]` vale 3.

⚠ Trampa clásica: `[[0] * 3] * 2` crea dos filas que son LA MISMA lista. Usa `[[0] * 3 for _ in range(2)]` (sección 5).

## 3. Bucles y condiciones

```python
for x in [10, 20, 30]:
    print(x)

for i in range(3):            # 0, 1, 2
    print(i)

for i, x in enumerate(["a", "b"]):   # índice y valor a la vez
    print(i, x)                      # 0 a / 1 b

total = 0
while total < 10:
    total += 3
    if total == 6:
        continue      # salta al siguiente ciclo
    if total > 8:
        break         # sale del bucle

etiqueta = "apta" if total > 5 else "defectuosa"   # expresión condicional en una línea
```

## 4. Funciones, tuplas y valores por defecto

```python
def area(base, altura=1.0):      # altura tiene valor por defecto
    return base * altura

def min_y_max(valores):
    return min(valores), max(valores)   # devuelve una TUPLA

lo, hi = min_y_max([3, 9, 1])    # desempaquetar la tupla: lo=1, hi=9
punto = (2, 5)                   # tupla: como una lista, pero no se puede modificar
x, y = punto
```

Las tuplas se comparan elemento a elemento: `(1, "b") < (1, "c") < (2, "a")`. Muy útil para ordenar con desempates (sección 7).

## 5. Comprensiones (listas en una línea)

```python
cuadrados = [x * x for x in range(5)]            # [0, 1, 4, 9, 16]
pares = [x for x in range(10) if x % 2 == 0]     # [0, 2, 4, 6, 8]
matriz = [[0.0] * 3 for _ in range(2)]           # 2 filas INDEPENDIENTES de 3 ceros
total = sum(x * x for x in [1, 2, 3])            # 14 (generador dentro de sum)
```

## 6. zip: recorrer varias listas a la vez

```python
a = [1, 2, 3]
b = [4, 5, 6]
for x, y in zip(a, b):
    print(x, y)                                  # 1 4 / 2 5 / 3 6
producto = sum(x * y for x, y in zip(a, b))      # 1·4 + 2·5 + 3·6 = 32 (producto escalar)
columnas = list(zip(*[[1, 2], [3, 4], [5, 6]]))  # [(1, 3, 5), (2, 4, 6)]: de filas a columnas
pares = list(zip(["a", "b", "c"], ["a", "b", "c"][1:]))   # [("a", "b"), ("b", "c")]: consecutivos
```

## 7. Ordenar con una clave: sorted(key=...) y lambda

`lambda` crea una función pequeña sin nombre: `lambda t: t[1]` equivale a `def f(t): return t[1]`.

```python
gente = [("ana", 30), ("luis", 25), ("eva", 30)]
print(sorted(gente, key=lambda t: t[1]))            # por edad ascendente
print(sorted(gente, key=lambda t: (-t[1], t[0])))   # edad DESCENDENTE y, si empata, nombre A→Z
```

El truco `-t[1]` ordena de mayor a menor; añadir `t[0]` a la tupla resuelve los empates.

## 8. Diccionarios

```python
d = {"apta": 2, "defectuosa": 1}
d["apta"] += 1               # modificar
d["nueva"] = 5               # añadir
print(d.get("otra", 0))      # 0  (valor por defecto si no existe la clave)
for clave, valor in d.items():
    print(clave, valor)

conteo = {}
for e in ["a", "b", "a"]:
    conteo[e] = conteo.get(e, 0) + 1   # contar: {"a": 2, "b": 1}

anidado = {}
anidado.setdefault("la", {})["forja"] = 7  # crea el dict interior si no existe
```

Un diccionario también puede servir como «ficha» con varios campos: `red = {"W1": [[...]], "b2": 0.0}`. Las claves pueden ser tuplas: `{("a", "b"): 3}`.

## 9. Conjuntos (set)

```python
s = {"a", "b"}
s.add("c")
print("a" in s)                    # True (comprobar pertenencia es muy rápido)
print({1, 2} & {2, 3})             # {2}  (intersección)
```

## 10. Leer ficheros

```python
with open("datos.csv", encoding="utf-8") as f:   # with cierra el fichero al terminar
    lineas = f.read().splitlines()               # lista de líneas sin "\n"

cabecera = lineas[0].split(",")                  # ["id", "dureza", ...]
for linea in lineas[1:]:                         # el resto: los datos
    if not linea.strip():                        # saltar líneas vacías
        continue
    celdas = linea.split(",")
    fila = dict(zip(cabecera, celdas))           # {"id": "...", "dureza": "..."}
    dureza = float(fila["dureza"])               # el texto "59.7" → el número 59.7
```

## 11. Módulos que usarás

```python
import math
math.sqrt(16), math.exp(1), math.log(math.e)      # 4.0 2.718... 1.0
math.isfinite(1e300 * 1e300)                      # False (es infinito)
float("inf"), float("-inf")                       # infinitos; math.exp(float("-inf")) == 0.0
1e12                                              # notación científica: 1 seguido de 12 ceros

import random
rng = random.Random(42)        # generador con SEMILLA: misma semilla → mismos números
rng.uniform(-1, 1)             # decimal aleatorio entre -1 y 1
lista = list(range(5))
rng.shuffle(lista)             # baraja EN EL SITIO y devuelve None (¡no hagas lista = rng.shuffle(...)!)

from collections import Counter
c = Counter(["a", "b", "a"])   # Counter({"a": 2, "b": 1}): un diccionario que cuenta solo
c["z"]                         # 0 (no da error con claves que no existen)

import copy
b = copy.deepcopy(red)         # copia completa, incluidas las listas de dentro

import re
re.findall(r"\w+|[^\w\s]", "Hola, katana.")   # ["Hola", ",", "katana", "."]
```

**Expresiones regulares en dos líneas:** `\w+` = una o más letras, números o `_`; `[^\w\s]` = un carácter que NO es letra ni espacio (un signo de puntuación); `|` = «o». La `r` delante de las comillas (cadena *raw*) hace que `\w` se escriba tal cual. Escríbela siempre en los patrones.

## 12. Errores y excepciones

```python
def dividir(a, b):
    if b == 0:
        raise ValueError("no se puede dividir entre 0")   # lanzar un error a propósito
    return a / b
```

Los ejercicios empiezan con `raise NotImplementedError(...)`: es solo una marca de «aún no implementado». Bórrala y escribe tu código.

⚠ Números enormes: `x ** 2` con un `x` gigantesco lanza `OverflowError`, mientras que `x * x` devuelve `inf`. Y `math.exp(z)` con `z` mayor que ~709 también lanza `OverflowError`; para la sigmoide, si `z` es muy negativo, usa `1 - 1 / (1 + math.exp(z))` o recorta `z`.

## 13. Cómo leer los tests

```text
python -m unittest -v test_T1_01_estadisticas
```

Cada `test_...` comprueba una cosa. `assertEqual(a, b)` exige que sean iguales; `assertAlmostEqual(a, b, delta=0.001)`, que se diferencien en menos de 0,001. Si falla, el mensaje dice qué esperaba y qué obtuvo. Lee el test que falla: suele ser la mejor pista.

## 14. Servicios: entornos, JSON, HTTP y async (laboratorios de la Forja)

**Entorno virtual.** Cada laboratorio tiene sus propias librerías, con versiones fijadas en `requirements.txt`:

```text
python -m venv .venv                                  # crea el entorno en la carpeta .venv
..venvScriptspython.exe -m pip install -r requirements.txt
..venvScriptspython.exe -m unittest -v test_servicio
```

**JSON** es texto con la misma forma que los diccionarios y listas de Python. Las librerías HTTP lo convierten solas: pasas un diccionario con `json=...` y lees la respuesta con `.json()`.

**HTTP.** Una petición tiene método (`GET` para leer, `POST` para enviar datos), ruta (`/api/chat`) y cuerpo; la respuesta, un código de estado (`200` bien, `400` petición mal hecha, `404` no existe, `502`/`504` falló el servicio de detrás) y un cuerpo.

```python
import httpx2
r = httpx2.post("http://127.0.0.1:11434/api/chat", json={"model": "llama3.2:1b", "messages": [], "stream": False})
r.raise_for_status()          # lanza una excepción si el código es 4xx o 5xx
datos = r.json()              # el cuerpo, ya convertido en diccionario
```

**async / await.** Una función `async def` puede pausarse mientras espera (a la red, por ejemplo) y dejar trabajar a otras. Dentro, cada espera se marca con `await`:

```python
import asyncio, httpx2

async def preguntar(cliente):
    r = await cliente.post("/api/chat", json={...})   # sin await obtendrías una «promesa», no la respuesta
    return r.json()

async def main():
    async with httpx2.AsyncClient(base_url="http://127.0.0.1:11434") as cliente:   # se cierra solo al salir
        print(await preguntar(cliente))

asyncio.run(main())           # punto de entrada desde código normal
```

**FastAPI** convierte funciones en rutas web. El decorador dice el método y la ruta; los parámetros con un modelo de Pydantic se validan solos (si no encajan, responde `422`); `HTTPException` corta la petición con el código que elijas:

```python
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

class Peticion(BaseModel):
    pregunta: str

app = FastAPI()

@app.post("/chat")
async def chat(p: Peticion):
    if not p.pregunta.strip():
        raise HTTPException(status_code=400, detail="pregunta vacía")
    return {"eco": p.pregunta}     # el diccionario se devuelve como JSON
```

---

## Qué secciones necesita cada ejercicio

| Ejercicio | Secciones |
|---|---|
| T1_01 estadísticas | 1, 2, 3, 4, 8, 10, 12, 13 |
| T1_02 distancia | 4, 5, 6, 12 (y 2: copiar frente a modificar) |
| T2_01 k-NN | 2, 3, 7, 8, 11 (`random`) |
| T3_01 descenso | 3 (`break`), 4, 11 (`math.isfinite`, `1e12`), 12 (desbordamiento) |
| T3_02 métricas | 3, 6, 8 |
| T4_01 neurona | 2 (copias), 4, 6, 11 (`math.exp`, `math.log`), 12 |
| T4_02 backprop | 2, 5, 8 (dict como ficha), 11 (`random.uniform`, `copy.deepcopy`) |
| T5_01 BPE | 4, 7, 8 (claves tupla), 9, 11 (`re`, `Counter`) |
| T5_02 embeddings | 5, 6, 7, 8 |
| T6_01 muestreo | 6, 7, 8 (anidados), 11 (`re`) |
| T6_02 atención | 5, 6, 11 (`math.exp`, `float("-inf")`) |
| A3_01 agente | 3 (contadores, `continue`), 4 (devolver tuplas), 8, 9 (`in` sobre conjuntos) |
| A2_01 RAG | 2 (rebanadas), 3 (`while`, `break`), 5, 7, 8 (dict como vector), 9, 11 (`re`, `math.log`) |
| P0-01 servicio LLM (forja/labs) | 8 (`.get` con valor por defecto), 12, 14 |
| A1-05 mostrador (forja/labs) | 3, 4 (valores por defecto), 11 (`re`, `math.sqrt`, `unicodedata`), 12, 14 |
| A2-04 biblioteca (forja/labs) | 2 (rebanadas), 3 (`while`, `break`), 7, 8, 9, 11 (`math.log`, `re`, `hmac`, `hashlib`), 12, 14 |
| E3_01 auditoría | 3, 7 (clave con tupla), 8, 9, 11 (`random.Random(semilla).sample`, `math.sqrt`), 12 |

Si te atascas en un ejercicio, mira [PISTAS.md](PISTAS.md): tiene pistas progresivas para cada función.
