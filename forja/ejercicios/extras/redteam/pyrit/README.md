# PyRIT · orquestación de ataques (experimental)

[PyRIT](https://github.com/Azure/PyRIT) (Microsoft) automatiza campañas de ataque contra un objetivo: manda *prompts*, puntúa las respuestas y, en sus orquestadores multivuelta, va afinando el ataque solo.

## ⚠️ Lee esto antes

**PyRIT cambia de API con frecuencia.** Los nombres de clases y la configuración de la versión 0.x, la 1.x y las siguientes **no coinciden**. El *script* `minimo.py` de esta carpeta es **experimental** y está escrito para una versión reciente usando el objetivo compatible con OpenAI apuntado al endpoint de Ollama; si no te funciona, no es un error tuyo: ve a la [documentación de tu versión](https://azure.github.io/PyRIT/) y ajusta los nombres. Trátalo como un punto de partida, no como una receta cerrada.

Y, como siempre: multivuelta = **muchas** peticiones al modelo. Empieza con 5 *prompts* semilla y el modelo pequeño.

## Instalar

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -U pyrit
```

## Apuntar PyRIT a Ollama

Ollama expone una API compatible con OpenAI en `http://localhost:11434/v1`. El objetivo `OpenAIChatTarget` de PyRIT se configura por variables de entorno:

```powershell
$env:OPENAI_CHAT_ENDPOINT = "http://localhost:11434/v1/chat/completions"
$env:OPENAI_CHAT_MODEL    = "llama3.2:1b"
$env:OPENAI_CHAT_KEY      = "ollama"   # Ollama ignora la clave, pero PyRIT pide una
```

Después:

```powershell
.\.venv\Scripts\python.exe minimo.py
```

## Qué hace `minimo.py`

Manda cinco *prompts* semilla (jailbreaks sencillos) al modelo local y marca, con una regla simple, cuáles consiguieron que el modelo no se negara. Es lo mínimo para ver el bucle enviar → puntuar; los orquestadores multivuelta (Crescendo, árbol de ataques) son el paso siguiente, ya con la documentación delante.
