# E2-01 · El trazo que engaña

**Misión del Dojo:** E2-01 (requiere T4-02 y A2-03). Laboratorio real de la Forja, en CPU y sin servicios.

La forja ficticia Kurogane clasifica los dígitos de sus albaranes escritos a mano con un modelo propio. Lo entrenas tú: una regresión logística multiclase en NumPy, sobre los dígitos de 8×8 píxeles que trae scikit-learn (1797 imágenes; no se descarga nada). Después lo atacas con **FGSM** (Goodfellow et al. 2014): cambias cada píxel como mucho `epsilon` en la dirección del signo del gradiente de la pérdida respecto a la **entrada**. Por último, mides dos defensas y lo que cuestan.

| Pieza | Quién la escribe |
|---|---|
| `softmax`, `gradiente_entrada`, `fgsm`, `curva_epsilon`, `gradiente_adversario`, `reducir_bits`, `puntuacion_squeezing`, `umbral_para_fpr` en `evasion.py` | **Tú** |
| Carga de datos, `Clasificador`, `Detector`, `bateria.py`, `ataques.json` | Claude |
| `test_evasion.py` (16 tests, sin red) | Claude |

## 1. Entorno y tests

Desde esta carpeta:

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe -m unittest -v test_evasion
```

Cuando pasen los 16:

```powershell
.\.venv\Scripts\python.exe ..\..\ejercicios\ronin_check.py E2-01
```

Y en el Dojo: `evidence import`.

## 2. Medir

```powershell
.\.venv\Scripts\python.exe bateria.py
```

Entrena el clasificador con 3 particiones distintas de los datos (semillas) y mide 4 configuraciones: `ninguna`, `adversario` (entrenamiento adversario con ε = 0,15), `deteccion` (feature squeezing a 2 bits, calibrado para un 5 % de falsos positivos con datos de validación) y las dos juntas. Tarda unos segundos. Cada fila muestra:

- **éxito**: imágenes atacadas con ε = 0,1 que el modelo clasifica mal **y** el detector no marca;
- **el modelo falla**: las que clasifica mal, antes del detector;
- **limpias bien**: imágenes sin ataque bien clasificadas y no rechazadas (el coste de cada defensa);
- **entrenar**: segundos de entrenamiento (el entrenamiento adversario hace dos pasadas por paso);
- debajo, la **precisión frente a epsilon**, de 0 a 0,3.

La medición se guarda en `forja/evidencias/E2-01-medicion.json`. En el Dojo, `evidence import`. El Dojo comprueba que `ataques.json` no se ha modificado.

## Qué está simplificado

- Un modelo lineal y un conjunto de datos pequeño. La hipótesis de Goodfellow et al. es justamente que la linealidad hace a los modelos vulnerables, y un modelo lineal tiene poca capacidad para volverse robusto: con redes más grandes, el entrenamiento adversario consigue más (y cuesta más).
- FGSM es el ataque más sencillo: un solo paso. Ataques iterativos como PGD son mucho más fuertes, y la robustez se mide contra ellos.
- El atacante conoce el modelo (caja blanca) pero **no** el detector. Un atacante adaptativo que conozca el detector lo puede evadir: Carlini y Wagner (2017) rompieron así diez métodos de detección. Una defensa que solo se ha medido contra un atacante que no la conoce no está medida.
- En un sistema real, el atacante no siempre tiene los gradientes: los ejemplos adversarios se transfieren a menudo de un modelo sustituto al real (E2-02 enseña a construir ese sustituto).

## Referencias (consultadas el 2026-11-10)

- I. J. Goodfellow, J. Shlens, C. Szegedy, «Explaining and Harnessing Adversarial Examples», ICLR 2015. [arXiv:1412.6572](https://arxiv.org/abs/1412.6572)
- W. Xu, D. Evans, Y. Qi, «Feature Squeezing: Detecting Adversarial Examples in Deep Neural Networks», NDSS 2018. [arXiv:1704.01155](https://arxiv.org/abs/1704.01155)
- N. Carlini, D. Wagner, «Adversarial Examples Are Not Easily Detected: Bypassing Ten Detection Methods», AISec 2017. [arXiv:1705.07263](https://arxiv.org/abs/1705.07263)
- [scikit-learn · `load_digits`](https://scikit-learn.org/stable/modules/generated/sklearn.datasets.load_digits.html) (versión 1.9.1).
- [NIST AI 100-2 E2025](https://csrc.nist.gov/pubs/ai/100/2/e2025/final): taxonomía de ataques de ML adversarial (evasión).
