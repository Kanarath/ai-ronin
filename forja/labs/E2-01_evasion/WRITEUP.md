<!-- Finding write-up público (recruiter-facing). Rellena la salida real donde lo indican los comentarios. -->

# E2-01 — Evading an image classifier with FGSM

> fast gradient sign method · feature squeezing · adversarial training

| | |
|---|---|
| **Severity** | High — an imperceptible perturbation flips the model's prediction at inference time, and a single detector tuned to a fixed false-positive budget does not restore reliability. |
| **Component** | A multiclass logistic-regression classifier written in NumPy, trained on scikit-learn's 8×8 handwritten digits (`load_digits`, 1797 images). Runs entirely on CPU, no network, no external services. |
| **Category** | MITRE ATLAS: Evade ML Model (adversarial example at inference). NIST AI 100-2 E2025: evasion attacks on ML systems. |
| **Status** | Reproduced and mitigated; baseline vs. defended behavior measured across seeds. |

## Summary

A fictional forge classifies the handwritten digits on its delivery notes with its own linear model. The
model is attacked with **FGSM** (Goodfellow et al., 2015): each pixel is shifted by at most `epsilon` in the
direction of the sign of the loss gradient with respect to the **input**. At a small, visually negligible
`epsilon` the classifier's accuracy collapses. The lab then measures two defenses and what they cost on
clean inputs: **adversarial training** (fold FGSM examples into training) and **detection via feature
squeezing** (Xu et al., 2018) — reduce bit depth and flag inputs whose prediction changes too much.

## Threat model

- **Attacker:** holds white-box access to the model (its gradients) but **not** to the detector.
- **Goal:** craft a perturbation, bounded by `epsilon`, that the model misclassifies **and** the detector
  does not flag.
- **Access / preconditions:** can submit an image to the classifier and knows the model's parameters.

## Steps to reproduce (PoC)

From the lab folder, with the environment installed (`requirements.txt`):

```powershell
.\.venv\Scripts\python.exe bateria.py
```

The battery trains the classifier on **3 distinct data splits (seeds)** and measures **4 configurations**:
`ninguna`, `adversario` (adversarial training, ε = 0.15), `deteccion` (feature squeezing to 2 bits,
calibrated to a 5% false-positive rate on validation data) and the two combined. Attack images use ε = 0.1.
It runs in seconds; results are written to `forja/evidencias/E2-01-medicion.json`.

<!-- TODO Gerard: pega aquí un extracto real de la salida de bateria.py (la fila "ninguna" y la fila con ambas defensas). -->

## Impact

- **Integrity:** a perturbation too small to notice changes the predicted digit, corrupting downstream
  processing of the delivery notes.
- **Availability of a correct decision:** accuracy under attack falls far below the clean baseline.
- **False confidence:** a detector measured only against an attacker who does not know it is not measured.

## Measurement

Each configuration reports **success** (attacked images the model misclassifies **and** the detector does
not flag), **model fails** (misclassified, before the detector), **clean correct** (unattacked images
classified correctly and not rejected — the cost of each defense) and training time, plus an
**accuracy-vs-epsilon** curve from 0 to 0.3.

| Defense | Where | Issue it addresses |
|---|---|---|
| `adversario` | training | adversarial training (ε = 0.15) raises accuracy under FGSM; a linear model has limited capacity to become robust |
| `deteccion` | inference | feature squeezing to 2 bits flags inputs whose prediction shifts after bit-depth reduction, at a 5% false-positive budget |
| `adversario,deteccion` | both | the two combined, trading a cost on clean inputs for lower attack success |

Baseline (`ninguna`): at ε = 0.1 the attack succeeds on most inputs and accuracy degrades sharply as
`epsilon` grows. With the defenses enabled, attack success drops while clean accuracy and training time
pay a measurable cost.

<!-- TODO Gerard: sustituye las descripciones cualitativas por tus % medidos (éxito, modelo falla, limpias bien) con IC 95% entre semillas. -->

## Remediation

Defense in depth across training and inference: fold adversarial examples into training so the decision
boundary accounts for perturbed inputs, and add an input-squeezing detector calibrated to an explicit
false-positive budget. Treat both as partial: a linear model cannot be made strongly robust, and a detector
holds only against attackers unaware of it. Robustness must be re-measured against stronger, adaptive
attacks. Residual risk is listed under "What's simplified".

## Detection (blue-team note)

Signals worth logging/alerting on: inputs whose predicted class changes after bit-depth reduction (the
squeezing signal itself); clusters of near-duplicate inputs with tiny high-frequency perturbations; a
spike in low-confidence or disagreeing predictions on an otherwise stable input distribution.

## What's simplified

- A linear model and a small dataset. Goodfellow et al.'s hypothesis is precisely that linearity makes
  models vulnerable; a linear model has little capacity to become robust, while larger networks gain more
  from adversarial training (at higher cost).
- FGSM is the simplest attack: a single step. Iterative attacks such as PGD are far stronger, and robustness
  is measured against them.
- The attacker knows the model (white box) but **not** the detector. An adaptive attacker who knows the
  detector can evade it — Carlini and Wagner (2017) broke ten detection methods this way.
- In a real system the attacker does not always have the gradients: adversarial examples often transfer from
  a substitute model to the real one.

## References (accessed 2026-11-10)

- I. J. Goodfellow, J. Shlens, C. Szegedy, "Explaining and Harnessing Adversarial Examples", ICLR 2015. [arXiv:1412.6572](https://arxiv.org/abs/1412.6572)
- W. Xu, D. Evans, Y. Qi, "Feature Squeezing: Detecting Adversarial Examples in Deep Neural Networks", NDSS 2018. [arXiv:1704.01155](https://arxiv.org/abs/1704.01155)
- N. Carlini, D. Wagner, "Adversarial Examples Are Not Easily Detected: Bypassing Ten Detection Methods", AISec 2017. [arXiv:1705.07263](https://arxiv.org/abs/1705.07263)
- [scikit-learn · `load_digits`](https://scikit-learn.org/stable/modules/generated/sklearn.datasets.load_digits.html) (version 1.9.1).
- [NIST AI 100-2 E2025](https://csrc.nist.gov/pubs/ai/100/2/e2025/final): taxonomy of adversarial ML (evasion).
