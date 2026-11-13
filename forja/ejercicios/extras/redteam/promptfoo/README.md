# promptfoo · evals y red teaming de aplicaciones LLM

[promptfoo](https://www.promptfoo.dev) evalúa un *prompt* o una aplicación con casos y aserciones, y tiene una suite de *red teaming* que genera ataques. Se usa en local y en CI, justo como la puerta de regresión de **P2-01**.

## Necesitas

- Node.js (18 o superior).
- Ollama en marcha con `llama3.2:1b` (ver el README de arriba).

## Evals (lo primero, es barato)

Desde esta carpeta:

```powershell
npx promptfoo@latest eval -c promptfooconfig.yaml
npx promptfoo@latest view
```

`promptfooconfig.yaml` trae cuatro casos: uno de utilidad y tres de seguridad (revelar el *prompt*, un reembolso escondido y una fuga de datos). Las aserciones `llm-rubric` usan el propio modelo como juez: recuerda de **A1-06** que un juez tiene sus sesgos, así que lee también las respuestas.

## Red teaming automático (ojo a la carga)

Genera **cientos** de ataques; en un portátil, hazlo con pocos *plugins* y pocas pruebas:

```powershell
npx promptfoo@latest redteam init
```

Elige un objetivo Ollama local, marca solo 2–3 *plugins* (por ejemplo `prompt-injection` y `pii`) y un número bajo de pruebas. Después `redteam run` y `redteam report`.

## Qué buscar

- ¿Cuántos casos de seguridad pasa tu modelo pequeño? (suele fallar varios).
- Lleva los resultados a un *write-up* con el antes y el después de añadir una defensa (delimitar, lista blanca de herramientas): es la evidencia de que una mitigación funciona.
