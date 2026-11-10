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

## 15. Clases: atributos, métodos y herencia

Una **clase** es un molde: agrupa datos (**atributos**) y las funciones que los usan (**métodos**). Cada objeto creado con el molde tiene sus propios datos.

```python
class Contador:
    def __init__(self, inicio=0):      # se ejecuta al crear el objeto
        self.valor = inicio            # self es el propio objeto: self.valor es SU atributo

    def sumar(self, n=1):              # todo método recibe self como primer parámetro
        self.valor += n
        return self                    # devolver self permite encadenar: c.sumar().sumar()

c = Contador(10)                       # crea un objeto; Python llama a __init__(c, 10)
c.sumar().sumar(5)
print(c.valor)                         # 16
d = Contador()
print(d.valor)                         # 0: cada objeto tiene sus propios atributos
```

**Herencia.** Una clase hija reutiliza todo lo de la madre y reescribe solo lo que cambia:

```python
class ContadorDoble(Contador):         # entre paréntesis, la clase madre
    def sumar(self, n=1):              # reescribe sumar; __init__ se hereda tal cual
        self.valor += 2 * n
        return self

print(ContadorDoble(1).sumar(3).valor) # 7
print(isinstance(ContadorDoble(), Contador))   # True: una hija ES también de la madre
```

Si un método de la madre llama a `self.otro_metodo()` y la hija reescribe `otro_metodo`, se usa el de la hija. Así funciona `predecir` en P0-02: está en la madre, pero llama a `self.probabilidades`, que cada clase implementa a su manera.

## 16. NumPy: arrays, formas y vectorización

NumPy no viene con Python: se instala en un entorno virtual (sección 14) con `pip install -r requirements.txt`. Por convención se importa como `np`.

```python
import numpy as np

a = np.array([1.0, 2.0, 3.0])          # array de forma (3,)
X = np.array([[1, 2], [3, 4], [5, 6]], dtype=float)   # forma (3, 2): 3 filas, 2 columnas
print(X.shape, X.dtype)                # (3, 2) float64
print(a * 2, a + a, a ** 2)            # [2. 4. 6.] [2. 4. 6.] [1. 4. 9.]   ← elemento a elemento, sin bucles
print(np.exp(a), np.log(a), np.clip(a, 1.5, 2.5))     # funciones que actúan sobre todo el array
```

**Ejes.** `axis=0` recorre las filas (resultado: uno por columna); `axis=1`, las columnas (uno por fila):

```python
X.sum(axis=0)        # [ 9. 12.]      suma de cada columna
X.mean(axis=0)       # [3. 4.]        media de cada columna
X.sum(axis=1)        # [ 3.  7. 11.]  suma de cada fila
X.sum()              # 21.0           todo
```

**Producto de matrices** con `@`; traspuesta con `.T`. Las formas tienen que encajar: `(n, d) @ (d, h)` da `(n, h)`.

```python
w = np.array([0.5, -1.0])            # forma (2,)
X @ w                                # [-1.5 -2.5 -3.5]: un producto escalar por fila
X.T.shape                            # (2, 3)
```

**Broadcasting.** Si las formas no coinciden pero encajan por la derecha, NumPy «estira» la pequeña: `X - X.mean(axis=0)` resta a cada fila la media de su columna. Una forma `(n, h)` más una `(h,)` suma el mismo vector a cada fila (así se suman los sesgos).

**Seleccionar y combinar:**

```python
X[0], X[:, 1], X[1:, :]              # primera fila · segunda columna · todas las filas desde la 1
np.where(a > 1.5, a, 0.0)            # [0. 2. 3.]: elige elemento a elemento
np.hstack([X, X ** 2])               # pega columnas: forma (3, 4)
np.tile(X, (2, 1))                   # repite las filas: forma (6, 2)
np.zeros(3), np.zeros((2, 3))        # arrays de ceros
(a >= 2).astype(int)                 # [0 1 1]: de booleanos a enteros
X.tolist()                           # de vuelta a listas de Python
float(np.mean(a))                    # un float de Python (no un np.float64)
```

**Azar reproducible:** `rng = np.random.default_rng(42)` y después `rng.uniform(-1, 1, size=(2, 3))`, `rng.normal(size=5)`… Misma semilla y misma versión de NumPy → mismos números.

**En el sitio o nuevo.** `W -= 0.1 * G` modifica el array `W` existente; `W = W - 0.1 * G` crea uno nuevo y cambia a qué apunta el nombre. Igual que con las listas (sección 2), otro nombre que apunte al array viejo verá o no el cambio.

**Comparar arrays en los tests:** `np.testing.assert_allclose(a, b, atol=1e-9)` comprueba que todos los elementos coinciden con esa tolerancia. Nunca compares floats con `==`.

**Medir tiempos:** `t0 = time.perf_counter()`, el código, y `time.perf_counter() - t0` da los segundos (con decimales). Es el reloj adecuado para medir, no para saber la hora.

⚠ La regla de la vectorización: si escribes un `for` que recorre los ejemplos uno a uno, probablemente hay una operación de NumPy que lo hace de golpe y decenas de veces más rápido.

## 17. Texto de verdad: str, bytes y Unicode

Una `str` es una secuencia de **puntos de código** Unicode. Para guardarla o enviarla se **codifica** en bytes; UTF-8 usa de 1 a 4 bytes por punto de código.

```python
s = "año 🔥"
b = s.encode("utf-8")        # b'a\xc3\xb1o \xf0\x9f\x94\xa5'  ← un objeto bytes
print(len(s), len(b))        # 5 9    (puntos de código frente a bytes)
b.decode("utf-8")            # "año 🔥" de vuelta
b[:2].decode("utf-8", errors="ignore")   # "a": la ñ partida se descarta
b[:2].decode("utf-8")        # UnicodeDecodeError: ¡la ñ está a medias!
"ñ", "\U0001F525"       # escapes: ñ y 🔥 escritos por su número
```

**Normalización.** La misma letra puede escribirse de dos formas: «é» compuesta (`"é"`, NFC) o «e» + acento combinante (`"é"`, NFD). Se ven igual y `==` dice que son distintas:

```python
import unicodedata
unicodedata.normalize("NFC", "é") == "é"   # True
unicodedata.is_normalized("NFC", "é")            # False
"Straße".casefold()                                    # "strasse": minúsculas «fuertes» para comparar
```

**Emojis compuestos:** 👍🏽 son 2 puntos de código (pulgar + tono de piel) y 👩‍🔧 son 3 (mujer + `"‍"`, la unión ZWJ, + llave inglesa). `len()` no cuenta lo que ves.

**Decodificar por trozos:** si los bytes llegan a pedazos, un pedazo puede cortar un carácter. Un decodificador incremental guarda los bytes a medias para el siguiente:

```python
import codecs
dec = codecs.getincrementaldecoder("utf-8")()
dec.decode(b"a\xc3")         # "a"   (guarda \xc3 para después)
dec.decode(b"\xb1o")         # "ño"
dec.decode(b"", final=True)  # ""    (o UnicodeDecodeError si quedó algo a medias)
```

Dos métodos útiles de `str`: `"hola\r".removesuffix("\r")` → `"hola"`, y `"a\nb\nc".split("\n", 1)` → `["a", "b\nc"]` (como mucho un corte).

## 18. Generadores: yield, perezosos y en tubería

Una función con `yield` es un **generador**. Al llamarla NO se ejecuta: devuelve un objeto que produce valores de uno en uno, cuando alguien se los pide.

```python
def cuenta_atras(n):
    print("empiezo")
    while n > 0:
        yield n          # entrega n y se CONGELA aquí hasta que le pidan el siguiente
        n -= 1
    print("fin")         # al terminar la función (o con return), el generador se agota

g = cuenta_atras(3)      # no imprime nada todavía
next(g)                  # imprime "empiezo" y devuelve 3
list(g)                  # [2, 1] (e imprime "fin")
list(g)                  # []: un generador se recorre UNA sola vez
```

`return` (sin valor) dentro de un generador lo termina: el `for` que lo recorre simplemente acaba.

**En tubería.** Un generador puede recorrer otro. Cada uno pide al anterior solo lo que necesita, así que se procesan ficheros enormes con la memoria de un elemento:

```python
def numeros():
    n = 0
    while True:          # ¡infinito! no pasa nada: solo se calcula lo que se pide
        yield n
        n += 1

def cuadrados(xs):
    for x in xs:
        yield x * x

import itertools
list(itertools.islice(cuadrados(numeros()), 4))   # [0, 1, 4, 9]: toma los 4 primeros
```

`itertools.islice(gen, n)` toma los n primeros sin consumir más. Un generador infinito con `list()` y sin `islice` no termina nunca. Para saber si algo es un generador: `isinstance(g, types.GeneratorType)` (con `import types`).

**Muestrear con pesos (P0-05).** `rng = random.Random(42)` y `rng.random()` da un decimal en [0, 1). Con la suma acumulada de las probabilidades eliges el tramo en el que cae.

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
| P0_02 logística (clases y NumPy) | 12 (`RuntimeError`), 14 (entorno virtual), 15, 16 |
| P0_03 MLP en matrices | 15, 16 (`@`, `.T`, `axis`, broadcasting, `-=`, `default_rng`) |
| P0_04 Unicode en streaming | 3 (`while`), 11 (`re`), 12, 17, 18 |
| P0_05 generación | 3, 8 (`.get`), 11 (`random`), 17 (`.encode`), 18 |
| A3-04 agente (forja/labs) | 2 (rebanadas negativas), 3 (`while`, `continue`), 4 (devolver tuplas), 7 (`lambda`), 8, 9, 11 (`re`), 12, 14 |
| A4-04 servidor MCP (forja/labs) | 3 (`while` sin ciclos), 4, 7, 8, 9, 11 (`json`, `re`, `hashlib`, `pathlib`, `urllib`), 12, 14 |
| A6-04 cadena (forja/labs) | 3, 4 (devolver tuplas), 8 (`.get`), 9, 11 (`pickletools`, `struct`, `json`, `hashlib`, `re`, `shlex`, `datetime`), 12 |
| E1-01 generación (forja/labs) | 3 (`break`), 5, 12, 15 (tensores, indexado, `torch.no_grad`) |
| E1-02 cuantización (forja/labs) | 4 (devolver tuplas), 11 (`math.exp`), 12, 15 (tipos `int8` y `float16`, `reshape`, `torch.where`) |
| E1-03 LoRA y lente (forja/labs) | 2, 5, 12, 15 (`nn.Module`, `nn.Parameter`, entrenamiento) |

Si te atascas en un ejercicio, mira [PISTAS.md](PISTAS.md): tiene pistas progresivas para cada función.

---

## 15. PyTorch: tensores, módulos y entrenamiento (laboratorios E1)

Un **tensor** es una lista de números de cualquier número de dimensiones, con un tipo (`dtype`) y operaciones vectoriales: una operación se aplica a todos los valores a la vez, sin bucles.

```python
import torch
t = torch.tensor([[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]])   # forma (2, 3), dtype float32
t.shape, t.dtype, t.numel()        # torch.Size([2, 3]) torch.float32 6
t[0, -1]                           # tensor(3.)  → .item() o float(...) para un número de Python
t[:, 1]                            # la columna 1: tensor([2., 5.])
t / 2, t * t, t @ t.T              # división y producto elemento a elemento; producto matricial
t.reshape(3, 2), t.reshape(-1)     # cambiar la forma (-1 = «lo que haga falta»)
t.max(), t.abs().amax(dim=1, keepdim=True)   # máximo global; máximo por fila, con forma (2, 1)
torch.zeros_like(t), torch.full_like(t, float("-inf"))   # tensores nuevos con la misma forma
torch.where(t > 2, t, torch.zeros_like(t))   # elige elemento a elemento
torch.round(torch.tensor([2.5, 3.5]))        # tensor([2., 4.]): los .5 van al par
t.to(torch.int8), t.to(torch.float16)        # cambiar de tipo (crea un tensor nuevo)

probs = torch.softmax(torch.tensor([2.0, 1.0, 0.0]), dim=-1)
orden = torch.sort(probs, descending=True, stable=True)   # orden.values y orden.indices
torch.cumsum(orden.values, dim=0)                          # suma acumulada
g = torch.Generator().manual_seed(42)                      # azar con semilla, como random.Random(42)
torch.multinomial(probs, 1, generator=g)                   # sortea un índice con esas probabilidades
```

**Difusión (broadcast):** un tensor de forma `(2, 1)` se combina con uno de forma `(2, 3)` repitiéndose por columnas. Así se aplica una escala distinta a cada fila sin bucles.

**Copiar frente a modificar:** `t / 2` crea un tensor nuevo; `t[0] = 5` y los métodos acabados en `_` (`t.copy_(...)`, `t.zero_()`) modifican el original.

**Módulos y entrenamiento:**

```python
from torch import nn

class MiCapa(nn.Module):
    def __init__(self, n, m):
        super().__init__()                        # siempre lo primero
        self.lineal = nn.Linear(n, m)             # un submódulo: se registra solo
        self.extra = nn.Parameter(torch.zeros(m)) # un parámetro entrenable: también

    def forward(self, x):                         # se llama con capa(x), no con capa.forward(x)
        return self.lineal(x) + self.extra

capa = MiCapa(4, 2)
sum(p.numel() for p in capa.parameters())         # 4·2 + 2 + 2 = 12 valores
capa.lineal.weight.requires_grad = False          # congelar: el optimizador no lo moverá

opt = torch.optim.AdamW([p for p in capa.parameters() if p.requires_grad], lr=0.01)
for paso in range(10):
    opt.zero_grad()                               # borra los gradientes del paso anterior
    perdida = capa(torch.randn(8, 4)).pow(2).mean()
    perdida.backward()                            # calcula los gradientes (la backprop de T4)
    opt.step()                                    # mueve los parámetros

with torch.no_grad():                             # sin gradientes: para inferir o copiar pesos
    salida = capa(torch.randn(1, 4))
```

Documentación: [docs.pytorch.org](https://docs.pytorch.org/docs/stable/).
| E2-01 evasión (forja/labs) | 12, 15 (`softmax` por filas, `P[np.arange(n), y]`, `np.sign`, `np.clip`) |
| E2-02 extracción (forja/labs) | 8, 12, 14, 15 (`np.round`, `np.argmax`, `np.hstack`, `np.linalg.lstsq`) |
| E2-03 privacidad (forja/labs) | 9, 12, 15 (máscaras booleanas, `~`, `reshape`, `rng.laplace`, `rng.normal`) |
| E3_01 auditoría | 3, 7 (clave con tupla), 8, 9, 11 (`random.Random(semilla).sample`, `math.sqrt`), 12 |

Si te atascas en un ejercicio, mira [PISTAS.md](PISTAS.md): tiene pistas progresivas para cada función.

## 15. NumPy para los laboratorios de E2

Los laboratorios de E2 trabajan con matrices: cada fila es un ejemplo (una imagen de 64 píxeles) y cada columna, una característica o una clase. NumPy hace las cuentas de una fila entera, o de toda la matriz, sin bucles.

```python
import numpy as np

X = np.array([[0.0, 0.5], [1.0, 0.25]])   # 2 ejemplos × 2 características
X.shape                  # (2, 2)
X @ W                    # producto matricial (como en T4, pero de golpe)
X.max(axis=1)            # el máximo de cada FILA → forma (2,)
X.max(axis=1, keepdims=True)   # el mismo, con forma (2, 1): se puede restar a X fila a fila
np.sign(X), np.abs(X), np.exp(X), np.log(X)   # se aplican elemento a elemento
np.clip(X, 0.0, 1.0)     # recorta cada valor al intervalo
np.round(X, 2)           # redondea a 2 decimales
```

**Elegir un elemento por fila.** Si `y` tiene la clase correcta de cada ejemplo, `P[np.arange(len(y)), y]` da la probabilidad de esa clase en cada fila.

**Máscaras.** `s >= t` es un array de booleanos; `s[m]` se queda con los elementos donde `m` es `True`, y `~m` es su negación. `np.mean(s >= t)` es la fracción que cumple la condición.

**Formas.** `reshape(B, -1)` aplana todo salvo la primera dimensión. Para multiplicar un array de forma (B, a, b) por un factor de forma (B,), dale al factor la forma (B, 1, 1): NumPy repite lo que falta (*broadcasting*).

**Copiar o modificar.** `X + 1` crea un array nuevo; `X += 1` o `P[i, j] -= 1` modifican el que tienes. Si una función no debe tocar su entrada, trabaja sobre el resultado de una operación o sobre `X.copy()`.

**Aleatoriedad reproducible.** `rng = np.random.default_rng(semilla)` y después `rng.normal(media, desviacion, size=forma)` o `rng.laplace(0.0, escala)`. Con la misma semilla y las mismas llamadas en el mismo orden, salen los mismos números: por eso los docstrings dicen cuántas llamadas hacer.
| E4-01 bajo carga (forja/labs) | 8, 11 (`hashlib`, `unicodedata`), 12, 14, anexo E4 (clases, `OrderedDict`, `asyncio.Semaphore`, `wait_for`, `try/finally`) |
| E4-02 trazas (forja/labs) | 8, 11 (`re`), 12, 14, anexo E4 (`re.sub` con una función, recursión, `with`, OpenTelemetry) |
| E4-03 despliegue (forja/labs) | 3, 8, 9, 11 (`hashlib`), 12, anexo E4 (`ipaddress`) |

Si te atascas en un ejercicio, mira [PISTAS.md](PISTAS.md): tiene pistas progresivas para cada función.

---

## Anexo E4 · Clases, concurrencia y observabilidad (especialización E4)

**Clases.** Una clase agrupa datos y las funciones que trabajan con ellos. `__init__` se ejecuta al crear el objeto; `self` es el propio objeto, y lo que guardas en `self.algo` lo recuerda entre llamadas:

```python
class Contador:
    def __init__(self, inicio=0):
        self.valor = inicio          # dato del objeto
    def sumar(self, n=1):
        self.valor += n
        return self.valor

c = Contador(10)
c.sumar(); c.sumar(5)                # 11, 16
```

**Funciones como valores.** Una función se puede guardar y pasar como cualquier otro valor; se ejecuta al poner paréntesis. Por eso los tests pueden pasar un reloj falso: `reloj=time.monotonic` guarda la función, y `reloj()` la llama.

**OrderedDict** recuerda el orden de las claves y deja cambiarlo: `d.move_to_end(clave)` pasa la clave al final; `d.popitem(last=False)` quita y devuelve la primera.

**re.sub con una función.** En lugar del texto de sustitución, `re.sub` acepta una función que recibe cada coincidencia (`m.group(0)` es el texto encontrado) y devuelve lo que se pone en su lugar.

**Recursión.** Una función que se llama a sí misma para recorrer datos anidados (listas dentro de diccionarios dentro de listas). Necesita un caso que no se llame a sí mismo: aquí, los valores simples.

**try / finally.** Lo que va en `finally` se ejecuta siempre, tanto si el `try` termina bien como si sale con `return` o con una excepción. Es donde se libera lo que se ha cogido (un hueco en la cola, un fichero).

**Concurrencia con asyncio.**

```python
import asyncio

sem = asyncio.Semaphore(1)            # solo una tarea a la vez dentro del bloque

async def tarea(i):
    async with sem:                   # espera su turno aquí
        await asyncio.sleep(0.1)
    return i

async def main():
    r = await asyncio.gather(*[tarea(i) for i in range(3)])     # lanza las tres a la vez
    try:
        await asyncio.wait_for(asyncio.sleep(10), 0.5)            # plazo de 0,5 s
    except TimeoutError:
        print("demasiado lento")

asyncio.run(main())
```

`contextlib.nullcontext()` es un `with` (o un `async with`) que no hace nada: útil cuando unas veces hay semáforo y otras no.

**OpenTelemetry en dos ideas.** Un *tracer* abre spans con `with`; dentro, `span.set_attribute(clave, valor)` añade datos, y al salir del bloque el span se cierra y se exporta. Un *meter* crea instrumentos (un histograma, con `create_histogram`) que acumulan medidas con `.record(valor, atributos)`.

**ipaddress.** `ipaddress.ip_address("127.0.0.1").is_loopback` es `True`; con un texto que no es una IP, lanza `ValueError`.
