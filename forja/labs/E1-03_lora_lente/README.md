# E1-03 · LoRA de juguete y la lente de logits

**Misión del Dojo:** E1-03 (requiere E1-02). Laboratorio real de la Forja, especialización E1 (investigación ML).

Dos herramientas de investigación con SmolLM2-135M en tu CPU:

1. **LoRA** (Low-Rank Adaptation). En vez de cambiar la matriz W de una capa lineal, se congela y se aprende una corrección de bajo rango: `W + (alfa / r) · B · A`, con A de r × n y B de m × r. Con r = 8, la matriz `q_proj` de 576 × 576 (331 776 pesos) se corrige con 9 216. Le enseñarás al modelo un dato ficticio: «la forja Kurogane está en Seki».
2. **La lente de logits.** El estado intermedio tras cada capa se pasa por la norma final y la cabeza de salida: así ves qué token «diría» el modelo si parara en esa capa, y en qué capa aparece la respuesta.

> **El fine-tuning real requiere GPU.** Esto es un juguete: una frase, unos pocos pasos y un modelo de 135 M. Entrenar necesita guardar, por cada parámetro entrenable, el peso, su gradiente y dos estados de AdamW: unos 16 bytes en float32. El modelo de 135 M entero ya pide 2,2 GB (más las activaciones); uno de 7 B, 112 GB. LoRA solo entrena el 0,3 %, pero el modelo base tiene que estar en memoria y pasar hacia delante y hacia atrás en cada paso: en CPU es lentísimo. QLoRA (base en 4 bits + LoRA) baja aún más la memoria, pero su librería de referencia (bitsandbytes) está pensada para GPU. Para afinar de verdad: una GPU externa (alquilada o en la nube) y la librería PEFT de Hugging Face.

| Pieza | Quién la escribe |
|---|---|
| La clase `LoRA` (`__init__` y `forward`), `fusionar`, `contar_parametros`, `aplicar_lora`, `perdida_lm`, `entrenar`, `lente_logit` en `lora.py` | **Tú** |
| `cargar`, `estados_residuales` (captura el flujo residual con ganchos), `experimento.py` | Claude |
| `test_lora.py` (15 tests con capas pequeñas y un modelo diminuto creado en el test) | Claude |

## 1. Entorno y tests

Es el mismo entorno de E1-01 (unos 175 MB de descarga si aún no lo tienes). Desde esta carpeta:

```powershell
..\E1-01_generacion\.venv\Scripts\python.exe -m unittest -v test_lora
```

Cuando pasen los 15:

```powershell
..\E1-01_generacion\.venv\Scripts\python.exe ..\..\ejercicios\ronin_check.py E1-03
```

Y en el Dojo: `evidence import`.

## 2. Con el modelo de verdad

```powershell
..\E1-01_generacion\.venv\Scripts\python.exe experimento.py
..\E1-01_generacion\.venv\Scripts\python.exe experimento.py --pasos 60 --lr 0.003 --rango 4
```

Necesita unos 3 GB de RAM y unos minutos de CPU (lo que tarda cada paso lo verás en la salida). Muestra:
1. **La lente** sobre «The capital of France is»: el token más probable y su probabilidad tras cada una de las 30 capas.
2. **LoRA** sobre `q_proj` y `v_proj`: parámetros entrenables, la pérdida paso a paso, la perplejidad de la frase y tres completados antes y después. Uno es del dato aprendido, otro está relacionado y el tercero no tiene nada que ver (la Torre Eiffel): ¿se ha estropeado algo que el modelo sabía?
3. **La fusión** de B·A en los pesos: el modelo da lo mismo, sin capas extra en inferencia.
4. **Las cuentas de memoria** de afinar entero frente a LoRA.

Los valores por defecto (`--pasos 30 --lr 0.002`) no se han calibrado con el modelo real. Si la pérdida no baja, sube `--lr` o `--pasos`; si el modelo empieza a repetir «Seki» en todas partes, has sobreajustado: anótalo, es parte del experimento.

## Qué está simplificado

- Una sola frase repetida en todos los pasos: el modelo la memoriza; no aprende «geografía de forjas».
- Sin dropout en el adaptador, sin programación del learning rate y sin conjunto de validación.
- La lente de logits usa la cabeza final en capas para las que no se entrenó: en las primeras capas sus lecturas son ruidosas. La *tuned lens* entrena una pequeña traducción por capa y es más fiable.

## Referencias (consultadas el 2026-11-10)

- E. J. Hu et al., «LoRA: Low-Rank Adaptation of Large Language Models», [arXiv:2106.09685](https://arxiv.org/abs/2106.09685) (2021).
- T. Dettmers et al., «QLoRA: Efficient Finetuning of Quantized LLMs», [arXiv:2305.14314](https://arxiv.org/abs/2305.14314) (2023).
- [Hugging Face PEFT](https://huggingface.co/docs/peft/index): la implementación de LoRA que se usa en la práctica (aquí no se usa).
- nostalgebraist, «[interpreting GPT: the logit lens](https://www.lesswrong.com/posts/AcKRB8wDpdaN6v6ru/interpreting-gpt-the-logit-lens)» (LessWrong, 2020).
- N. Belrose et al., «Eliciting Latent Predictions from Transformers with the Tuned Lens», [arXiv:2303.08112](https://arxiv.org/abs/2303.08112) (2023).
