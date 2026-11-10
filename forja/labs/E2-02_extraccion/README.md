# E2-02 · La copia por correo

**Misión del Dojo:** E2-02 (requiere E2-01). Laboratorio real de la Forja, con una API en `127.0.0.1`.

La forja ficticia Kurogane vende su clasificador de dígitos como API: le mandas imágenes de 8×8 y te devuelve la probabilidad de cada dígito. Tú eres el atacante. No tienes los pesos ni los datos de entrenamiento con sus etiquetas, solo una clave de API y un montón de imágenes sin etiquetar. Con las respuestas construyes una **copia** del modelo y mides su **acuerdo** con el original (la fracción de imágenes en las que predicen lo mismo) según cuántas consultas has hecho (Tramèr et al. 2016).

Dos formas de copiar:

- **Resolver ecuaciones.** El modelo es una regresión logística: `ln P_j − ln P_0` es una función lineal de la entrada. Cada consulta con probabilidades exactas da 9 ecuaciones lineales; con 65 consultas (64 píxeles + 1) en posición general, la copia es exacta.
- **Entrenar un sustituto** con las etiquetas que devuelve la API. Funciona aunque la API solo dé la clase.

Y tres defensas de la API: `redondeo` (probabilidades con 2 decimales), `etiqueta` (solo la clase) y `limite` (50 imágenes por clave y hora).

**Este servicio es vulnerable a propósito.** Todo es ficticio y escucha solo en `127.0.0.1`.

| Pieza | Quién la escribe |
|---|---|
| `redondear_probabilidades`, `permitir_consulta`, `etiquetas_de_respuesta`, `resolver_ecuaciones`, `acuerdo` en `extraccion.py` | **Tú** |
| Datos, `Regresion`, el ataque `atacar`, la aplicación FastAPI, `bateria.py`, `ataques.json`, Docker | Claude |
| `test_extraccion.py` (13 tests, sin red: la API se prueba dentro del proceso) | Claude |

## 1. Entorno y tests

Desde esta carpeta:

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe -m unittest -v test_extraccion
```

Cuando pasen los 13:

```powershell
.\.venv\Scripts\python.exe ..\..\ejercicios\ronin_check.py E2-02
```

Y en el Dojo: `evidence import`.

## 2. Robar y medir

```powershell
.\.venv\Scripts\python.exe bateria.py
```

Para cada configuración (`ninguna`, `redondeo`, `etiqueta`, `limite` y `limite,redondeo`) y 3 semillas, la batería arranca la API de verdad con uvicorn en `127.0.0.1` (en un puerto libre) y la ataca por HTTP, como cualquiera desde fuera, con presupuestos de 10 a 640 consultas. Tarda unos segundos. Cada fila muestra:

- **acuerdo final**: el de la mejor copia con el último presupuesto (las imágenes de evaluación en las que coincide con el original);
- **por ecuaciones**: el acuerdo de la copia por ecuaciones (0 si la API no da probabilidades);
- **legítimas**: 40 consultas de un cliente normal, con otra clave, bien clasificadas;
- **error prob.**: cuánto se aleja, de media (distancia L1), lo que recibe el cliente de la probabilidad real (el coste del redondeo);
- debajo, para cada presupuesto: las consultas que consiguió de verdad y el acuerdo de cada copia.

La medición se guarda en `forja/evidencias/E2-02-medicion.json`. En el Dojo, `evidence import`. El Dojo comprueba que `ataques.json` no se ha modificado.

## 3. Desplegarlo (opcional, con Docker)

```powershell
$env:CLAVES = "<una clave larga y aleatoria>,<otra>"
docker compose up -d --build
```

Fíjate en tres decisiones de `compose.yaml` y del `Dockerfile`:

- El puerto solo se publica en `127.0.0.1`. Una API de predicción abierta a la red es un modelo regalado: cualquiera puede copiarlo.
- Las claves se pasan por variable de entorno y no se escriben en ningún fichero; sin `CLAVES`, el servicio no arranca.
- El contenedor no se ejecuta como root, con el sistema de ficheros de solo lectura.

Para atacar esa API con la batería (una sola configuración, la que tenga en `DEFENSAS`):

```powershell
$env:CLAVE_ATACANTE = "<la primera clave>"; $env:CLAVE_CLIENTE = "<la segunda>"
.\.venv\Scripts\python.exe bateria.py --url http://127.0.0.1:8000 --configs limite,redondeo
```

## Qué está simplificado

- La víctima es una regresión logística, la más fácil de copiar por ecuaciones. Con redes neuronales no hay solución cerrada y el atacante entrena un sustituto, con más consultas.
- El límite es por clave. Un atacante con muchas claves (o muchas cuentas gratuitas) lo reparte entre ellas: el límite encarece el robo, no lo impide. En producción se combina con detección de patrones de consulta y con condiciones de uso.
- El atacante tiene imágenes del mismo tipo que las de entrenamiento. Tramèr et al. muestran que, para resolver ecuaciones, le bastan entradas aleatorias.
- El límite se guarda en memoria del proceso: si se reinicia el servicio, se reinicia la cuenta. En producción vive en un almacén compartido (por ejemplo, el de tu pasarela de API).

## Referencias (consultadas el 2026-11-10)

- F. Tramèr, F. Zhang, A. Juels, M. K. Reiter, T. Ristenpart, «Stealing Machine Learning Models via Prediction APIs», USENIX Security 2016. [arXiv:1609.02943](https://arxiv.org/abs/1609.02943)
- [OWASP Top 10 for LLM Applications 2025](https://genai.owasp.org/llm-top-10/): LLM10 Unbounded Consumption incluye el robo de un modelo mediante consultas a su API.
- [MITRE ATLAS](https://atlas.mitre.org/): técnicas de extracción de modelos por la API de inferencia.
- [FastAPI](https://fastapi.tiangolo.com/) (versión 0.162.2) y [scikit-learn](https://scikit-learn.org/stable/) (versión 1.9.1).
