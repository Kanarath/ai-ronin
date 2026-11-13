# Extras · Herramientas reales de red team de LLM (garak, promptfoo, PyRIT)

**Opcional y para tu máquina.** Nada de esto es necesario para jugar el Dojo: las misiones de A1, A7 y O7 ya te enseñan los conceptos (inyección, evals, caja de arena, cobertura ASI). Esto es el paso siguiente, para quien quiera tocar las herramientas que se citan en las ofertas de AI red teamer y en SANS SEC545 / HTB.

Las tres herramientas atacan **tu modelo local con Ollama**, no servicios de terceros. Todo apunta a `http://localhost:11434`.

## ⚠️ Antes de empezar: la carga del portátil

Un escaneo completo lanza **cientos o miles de peticiones** al modelo. En un portátil sin GPU potente eso significa ventilador a tope y horas de cómputo. Empieza **siempre** por lo más pequeño:

- Usa un modelo diminuto: `llama3.2:1b` (no 8B ni mayores).
- Limita las pruebas: una sola familia de *probes* en garak, 3–4 casos en promptfoo, 5 *prompts* semilla en PyRIT.
- Hazlo con el portátil enchufado y bien ventilado, y párate si se calienta.
- No lo dejes corriendo de fondo: míralo.

## Qué es cada una y a qué riesgo apunta

| Herramienta | Qué hace | OWASP / misión del Dojo |
|---|---|---|
| **garak** (NVIDIA) | Escáner de vulnerabilidades de LLM: lanza baterías de *probes* (jailbreaks, fugas, toxicidad) y puntúa | LLM01, LLM02 · A1-05, A1-07 |
| **promptfoo** | Evals y *red teaming* de aplicaciones LLM: casos con aserciones y una suite adversarial; se integra en CI | Evals · P2, A1-06 |
| **PyRIT** (Microsoft) | Orquestador de ataques automatizados multivuelta contra un objetivo | Agentes · A3, O7 |

## Preparación común (una vez)

```powershell
ollama serve
ollama pull llama3.2:1b
```

Después, cada carpeta tiene su propio `README.md`:

- [`garak/`](garak/README.md) — el escáner, con una sola familia de *probes* para empezar.
- [`promptfoo/`](promptfoo/README.md) — evals y suite adversarial sobre el modelo local.
- [`pyrit/`](pyrit/README.md) — orquestación de ataques (API volátil: léelo con cuidado).

## Aviso de versiones

garak, promptfoo y, sobre todo, **PyRIT** cambian de API a menudo. Los comandos de garak y la configuración de promptfoo son estables; el *script* de PyRIT es **experimental** y hay que contrastarlo con la versión que instales (lo avisa su README). Fija las versiones que te funcionen y anótalas, como en `extras/requirements.txt`.

Verificado el 2026-11-13 con la documentación oficial de cada herramienta.
