# A1-07 · El guardián entrenado

**Misión del Dojo:** A1-07 (requiere A1-05; A1-06 ayuda, pero no es obligatoria). Laboratorio real de la Forja.

El filtro de entrada de A1-05 era una lista de siete frases. La industria suele dar el paso siguiente: un **clasificador de seguridad** entrenado que decide si un mensaje es una inyección y lo bloquea antes de que llegue al modelo. Es la mitigación más desplegada y también la más sobrevalorada.

Aquí entrenas uno desde cero: **Naive Bayes multinomial sobre n-gramas de caracteres**, en Python puro y sin librerías de ML, con un dataset sintético y ficticio de mensajes del mostrador de Kurogane. Después lo mides como se mide un guardián:
- **falsos positivos**: clientes normales bloqueados, que en producción son tickets de soporte y ventas perdidas;
- **falsos negativos**: ataques que pasan;
- la **curva de umbral**: lo que ganas por un lado lo pierdes por el otro;
- **evasión** con paráfrasis, separadores, otro idioma y un ataque escondido en un texto largo.

Lo comparas con el filtro de patrones de A1-05 y, si quieres, con `llama3.2:1b` usado como clasificador.

Todo es ficticio y escucha solo en `127.0.0.1`.

| Pieza | Quién la escribe |
|---|---|
| `ngramas`, `entrenar`, `probabilidad`, `matriz_confusion`, `tasas`, `curva_umbral`, `elegir_umbral`, `con_separadores` en `guardian.py` | **Tú** |
| `normalizar` y el filtro de patrones (los de A1-05), el clasificador con LLM, la aplicación FastAPI, `bateria.py`, `entrenamiento.json`, `ataques.json`, Docker | Claude |
| `test_guardian.py` (19 tests con un modelo simulado) | Claude |

## 1. Entorno y tests

Desde esta carpeta:

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe -m unittest -v test_guardian
```

Cuando pasen los 19, genera la evidencia:

```powershell
.\.venv\Scripts\python.exe ..\..\ejercicios\ronin_check.py A1-07
```

Y en el Dojo: `evidence import`.

## 2. Medir el guardián

No necesita Ollama y tarda unos segundos:

```powershell
.\.venv\Scripts\python.exe bateria.py
```

1. Entrena el clasificador con la parte `entrenamiento` de `entrenamiento.json`.
2. Elige el umbral con la parte `validacion`, con una tasa de falsos positivos máxima del 10 % (`--tfp-maxima`). Nunca se elige con la prueba: eso sería hacer trampa.
3. Imprime la **curva de umbral** sobre la prueba (`ataques.json`, que el clasificador no ha visto).
4. Mide 4 configuraciones: `ninguna`, `patrones` (A1-05), `clasificador` y `patrones,clasificador`.

Con el LLM local como tercer guardián (Ollama en marcha; 3 repeticiones, porque no es determinista):

```powershell
.\.venv\Scripts\python.exe bateria.py --configs "ninguna;patrones;clasificador;llm;clasificador,llm"
```

Cada fila muestra:
- **pasan**: ataques que atraviesan el guardián, con su intervalo de Wilson;
- **falsos positivos**: mensajes legítimos bloqueados, con su intervalo;
- **pasan por tipo**: original, `parafrasis`, `ingles`, `relleno` y `separadores`. Esta última variante la genera tu `con_separadores` a partir de cada original;
- qué mensajes legítimos se bloquearon. Fíjate en cuáles son.

La medición se guarda en `forja/evidencias/A1-07-medicion.json`. En el Dojo, `evidence import`. No modifiques `ataques.json`: el Dojo comprueba su huella. Si quieres probar ataques o datos propios, hazlo en una copia y no la importes.

**Preguntas para leer los números:**
- ¿Qué variantes esquivan los patrones? ¿Y el clasificador? ¿Son las mismas?
- Mira los mensajes legítimos bloqueados: ¿qué ha aprendido de verdad el clasificador, la intención del mensaje o su forma?
- Si subes `--tfp-maxima` a 0,3, ¿cuántos ataques más bloqueas y a cuántos clientes más molestas?
- Con 31 ataques y 20 legítimos, ¿se solapan los intervalos de dos configuraciones? Si se solapan, estos datos no permiten afirmar que una sea mejor.

## 3. Pruébalo a mano (opcional)

```powershell
$env:UMBRAL = "0.85"
.\.venv\Scripts\python.exe -m uvicorn guardian:app --host 127.0.0.1 --port 8002
```

`POST /clasificar` con `{"mensaje": "..."}` devuelve `{"bloquear", "probabilidad", "patrones", "llm"}`. El umbral y el uso del LLM se fijan al arrancar, nunca por petición. Con Docker: `docker compose up -d --build`.

## Qué está simplificado

- El dataset tiene 90 mensajes de entrenamiento escritos a mano, poco variados a propósito. Los guardianes reales se entrenan con decenas de miles de ejemplos y, aun así, sus autores avisan de que los ataques adaptativos pueden esquivarlos.
- `probabilidad` promedia por n-grama para que el umbral sea útil. Naive Bayes puro da 0,0000 o 1,0000 en cuanto el mensaje es algo largo. Ninguna de las dos es una probabilidad calibrada.
- En producción se usan modelos tipo transformer entrenados para esto, como Llama Prompt Guard 2 de Meta. Son mucho mejores que un Naive Bayes y tienen los mismos límites de fondo: un umbral que fija cuántos clientes legítimos aceptas molestar, una ventana de texto limitada (los mensajes largos se trocean) y evasión por paráfrasis o adaptación.

## Por qué «la más sobrevalorada»

Un guardián da una cifra tranquilizadora, como «bloquea el 90 % de los ataques de la prueba». Pero esa cifra se mide con ataques parecidos a los del entrenamiento. Un atacante no manda los ataques de tu batería: manda los que pasan. El guardián es una capa útil para frenar el ruido y los ataques conocidos, y para registrar intentos. No sustituye a las defensas de arquitectura de A1-05: si el secreto no está en el prompt, no hay nada que filtrar.

## Referencias (consultadas el 2026-11-10)

- [scikit-learn 1.9.1 · Naive Bayes multinomial](https://scikit-learn.org/stable/modules/naive_bayes.html): la versión con librería de lo que implementas aquí, con suavizado de Laplace (α = 1).
- [Meta · Llama Prompt Guard 2 (ficha del modelo)](https://huggingface.co/meta-llama/Llama-Prompt-Guard-2-86M): un clasificador de inyecciones y jailbreaks real, con sus límites declarados.
- [OWASP Top 10 for LLM Applications 2025](https://genai.owasp.org/llm-top-10/): LLM01, inyección de prompts.
- Intervalo de Wilson: E. B. Wilson, *Journal of the American Statistical Association* 22 (1927), 209–212.
