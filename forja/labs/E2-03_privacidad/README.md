# E2-03 · ¿Estaba en el registro?

**Misión del Dojo:** E2-03 (requiere E2-01). Laboratorio real de la Forja, en CPU y sin servicios.

Un modelo entrenado con datos de personas puede revelar **quién estaba** en sus datos de entrenamiento, aunque nunca devuelva un solo dato. Es el ataque de **inferencia de pertenencia** (*membership inference*, Shokri et al. 2017). Aquí lo haces contra una red pequeña (un MLP 64 → 32 → 10 en NumPy) entrenada con 300 dígitos. Imagina que cada dígito es el registro de un cliente de la forja ficticia Kurogane.

- **El ataque:** un modelo suele tener una pérdida más baja con los ejemplos que ha visto. El atacante dice «miembro» si la pérdida de un ejemplo es menor que un umbral (Yeom et al. 2018). El umbral lo elige en un **modelo sombra**: entrena él mismo un modelo con la misma receta y datos suyos, de los que sí sabe cuáles ha usado.
- **La medida:** la **ventaja** del atacante, TPR − FPR (aciertos con los miembros menos falsas alarmas con los que no lo son). Un ataque que adivina al azar tiene ventaja 0. También la curva ROC, su área (AUC) y la TPR cuando solo se toleran un 5 % de falsos positivos.
- **Las defensas:** regularizar y **DP-SGD** (Abadi et al. 2016): recortar el gradiente de cada ejemplo y añadir ruido gaussiano, para que ningún ejemplo concreto mueva demasiado el modelo.
- **La privacidad diferencial en lo más sencillo:** publicar la media de las edades de 1000 clientes ficticios con ruido de Laplace o gaussiano, y medir el error frente a ε (Dwork y Roth 2014).

| Pieza | Quién la escribe |
|---|---|
| `perdida_por_ejemplo`, `curva_roc`, `area_bajo_curva`, `mejor_umbral`, `media_laplace`, `media_gaussiana`, `recortar_y_ruido` en `privacidad.py` | **Tú** |
| Datos, la red `Red` con gradientes por ejemplo, las recetas, el ataque con sombra, `bateria.py`, `ataques.json` | Claude |
| `test_privacidad.py` (14 tests, sin red) | Claude |

## 1. Entorno y tests

Desde esta carpeta:

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe -m unittest -v test_privacidad
```

Cuando pasen los 14:

```powershell
.\.venv\Scripts\python.exe ..\..\ejercicios\ronin_check.py E2-03
```

Y en el Dojo: `evidence import`.

## 2. Medir

```powershell
.\.venv\Scripts\python.exe bateria.py
```

Mide 4 recetas (`ninguna`, que sobreajusta; `regularizado`; `dp-sgd`, con ruido 1, y `dp-sgd-fuerte`, con ruido 4) con 3 semillas. Tarda menos de un minuto. Cada fila muestra la ventaja con el umbral de la sombra (con su TPR y su FPR), el AUC, la TPR con FPR ≤ 5 %, la precisión con los propios datos de entrenamiento y la precisión en test (la utilidad). Debajo, el error medio absoluto de la media de edades publicada con cada ε.

La medición se guarda en `forja/evidencias/E2-03-medicion.json`. En el Dojo, `evidence import`. El Dojo comprueba que `ataques.json` no se ha modificado.

## Lo que este laboratorio NO te da: el ε de DP-SGD

La media con ruido de Laplace tiene una garantía exacta: ε-privacidad diferencial, con el ε que tú eliges. Con DP-SGD, en cambio, el ε depende del ruido, del tamaño del lote, del número de pasos y de cómo se muestrean los lotes, y se calcula con un *contador de privacidad* (el *moments accountant* de Abadi et al. o sus sucesores). Este laboratorio no lo calcula, y además baraja los lotes en lugar de muestrearlos como supone ese análisis. Así que aquí DP-SGD es una **técnica medida empíricamente**, no una garantía: si la necesitas, usa una biblioteca mantenida que haga la contabilidad.

## Relación con LLM02 y con el RGPD

- **OWASP LLM02:2025 (Sensitive Information Disclosure)** recoge la privacidad diferencial entre sus mitigaciones y enlaza la técnica de MITRE ATLAS *AML.T0024.000 Infer Training Data Membership*. En un LLM, el equivalente es la extracción de texto memorizado (Carlini et al. 2021, en las lecturas de T6).
- **RGPD.** No inventamos requisitos legales: lo que sí dice una fuente oficial es el **Dictamen 28/2024 del CEPD** (adoptado el 17 de diciembre de 2024). Para que un modelo entrenado con datos personales se considere anónimo, tanto la probabilidad de extraer datos personales del modelo como la de obtenerlos mediante consultas deben ser insignificantes, y una autoridad de control debe evaluarlo caso por caso. Entre las pruebas que menciona están las de inferencia de pertenencia. Un dictamen no es una lista de comprobación: tu medición es una prueba técnica que se documenta, no una certificación de anonimato.

## Qué está simplificado

- Dígitos y no datos personales: el riesgo se mide igual, pero el impacto no.
- Un conjunto de datos fácil: incluso los no miembros tienen pérdidas bajas, así que el ataque es débil con FPR bajas. Carlini et al. (2022) proponen medir siempre la TPR con FPR bajas, porque la ventaja media esconde a los individuos más expuestos.
- Un atacante sencillo (umbral global con una sombra). Hay ataques más fuertes, con muchos modelos sombra y un umbral por ejemplo.

## Referencias (consultadas el 2026-11-10)

- R. Shokri, M. Stronati, C. Song, V. Shmatikov, «Membership Inference Attacks against Machine Learning Models», IEEE S&P 2017. [arXiv:1610.05820](https://arxiv.org/abs/1610.05820)
- S. Yeom, I. Giacomelli, M. Fredrikson, S. Jha, «Privacy Risk in Machine Learning: Analyzing the Connection to Overfitting», IEEE CSF 2018. [arXiv:1709.01604](https://arxiv.org/abs/1709.01604)
- N. Carlini et al., «Membership Inference Attacks From First Principles», IEEE S&P 2022. [arXiv:2112.03570](https://arxiv.org/abs/2112.03570)
- C. Dwork, A. Roth, «The Algorithmic Foundations of Differential Privacy», *Foundations and Trends in Theoretical Computer Science* 9(3–4), 2014. [doi:10.1561/0400000042](https://doi.org/10.1561/0400000042)
- M. Abadi et al., «Deep Learning with Differential Privacy», ACM CCS 2016, 308–318. [arXiv:1607.00133](https://arxiv.org/abs/1607.00133)
- [OWASP LLM02:2025 Sensitive Information Disclosure](https://genai.owasp.org/llmrisk/llm022025-sensitive-information-disclosure/)
- [CEPD · Dictamen 28/2024 sobre determinados aspectos de protección de datos relacionados con el tratamiento de datos personales en el contexto de los modelos de IA](https://www.edpb.europa.eu/our-work-tools/our-documents/opinion-board-art-64/opinion-282024-certain-data-protection-aspects_en)
