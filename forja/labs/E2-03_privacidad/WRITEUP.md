<!-- Finding write-up público (recruiter-facing). Rellena la salida real donde lo indican los comentarios. -->

# E2-03 — Membership inference against a trained model

> membership inference · training-data leakage · differential-privacy mitigations

| | |
|---|---|
| **Severity** | Medium — a model trained on personal records can reveal *who* was in its training set, even when it never returns a single raw record. |
| **Component** | A small neural network (MLP 64 → 32 → 10, pure NumPy, CPU) trained on 300 digits, treated as 300 customer records of a fictional forge. Runs locally, no services. |
| **Category** | Privacy attack: membership inference (Shokri et al. 2017; threshold variant, Yeom et al. 2018). |
| **Status** | Reproduced; mitigated and measured per training recipe. |

Category mapping: MITRE ATLAS **AML.T0024.000 — Infer Training Data Membership**; OWASP **LLM02:2025 (Sensitive Information Disclosure)**, which lists differential privacy among its mitigations and links the same ATLAS technique; NIST AI 100-2 privacy attacks (membership inference / data reconstruction).

## Summary

A model usually shows a **lower loss** on examples it was trained on. An attacker exploits exactly this: it
labels an example "member" when its per-example loss falls below a threshold. The threshold is not guessed —
it is calibrated on a **shadow model** the attacker trains itself, with the same recipe and data it fully
controls. Applied here to a network trained on 300 digits (each standing for one customer record), the attack
distinguishes training members from non-members **without the model ever emitting a record**. The lab also
illustrates **differential privacy at its simplest**: publishing the mean age of 1000 fictional customers
with Laplace or Gaussian noise, and measuring the error against the privacy budget ε.

## Threat model

- **Attacker:** holds query access to the trained model and can reproduce its training recipe to build a
  shadow model on their own labelled data.
- **Goal:** decide whether a given record was part of the training set (a privacy breach on its own).
- **Access / preconditions:** per-example loss (or a confidence signal that proxies it) and the ability to
  train a shadow model with the same recipe.

## Steps to reproduce (PoC)

From the lab folder, with the environment installed (`requirements.txt`):

```powershell
.\.venv\Scripts\python.exe bateria.py
```

Measures **4 recipes** (`ninguna`, which overfits; `regularizado`; `dp-sgd` with noise 1; `dp-sgd-fuerte`
with noise 4) across **3 seeds**. Runs in under a minute, no Ollama or Docker. Each row reports the
attacker's advantage at the shadow threshold (with its TPR and FPR), the AUC, the TPR at FPR ≤ 5 %, train
accuracy, and test accuracy (utility). Below that, the mean absolute error of the published mean age at each ε.

<!-- TODO Gerard: pega aquí la fila "ninguna" y la fila "dp-sgd-fuerte" de bateria.py (ventaja, AUC, TPR@FPR≤5%, acc test). -->

## Impact

- **Confidentiality:** membership in the training set is itself sensitive — it can reveal that a person is in
  a dataset tied to a condition, a client list, or any population the model was built from.
- **Privacy / compliance:** membership inference is one of the tests used to argue whether a model trained on
  personal data can be treated as anonymous; a successful attack is technical evidence that it cannot.
- **Equity of exposure:** average advantage hides the most exposed individuals — the attack can be reliable at
  low FPR even when the mean advantage looks small (Carlini et al. 2022).

## Measurement

Attacker advantage is **TPR − FPR** (a random guesser scores 0). The battery also reports ROC/AUC and the
TPR at a fixed low FPR. Each mitigation is mapped to what it limits, qualitatively:

| Mitigation (recipe) | What it does | What it limits |
|---|---|---|
| `regularizado` | regularization to reduce the train/test loss gap | overfitting, the signal the attack relies on |
| `dp-sgd` (noise 1) | clip per-example gradients + add Gaussian noise (Abadi et al. 2016) | how much any single example can move the model |
| `dp-sgd-fuerte` (noise 4) | stronger clipping + noise | member/non-member loss gap, at a larger utility cost |
| Laplace / Gaussian mean | ε-DP noise on a published aggregate (Dwork & Roth 2014) | reconstruction of an individual value from an aggregate |

The overfitting recipe (`ninguna`) yields the highest advantage; regularization and DP-SGD lower it while
test accuracy (utility) degrades, most visibly under `dp-sgd-fuerte` — the privacy/utility trade-off.

<!-- TODO Gerard: sustituye por los números medidos (ventaja y acc test por receta), con IC 95% si los tienes. -->

## Remediation

Reduce the attack's signal rather than just the raw output: **regularize** to shrink the train/test loss gap,
and apply **DP-SGD** (gradient clipping + calibrated noise) so no single example dominates the model. For
published aggregates, add **ε-DP noise** (Laplace / Gaussian) sized to the chosen budget. Residual risk is
listed under "What's simplified".

## Detection (blue-team note)

Treat membership inference as a **pre-release privacy test**, not a runtime alert: measure attacker advantage
and TPR at low FPR against a shadow-model baseline before shipping, and watch for a large train/test loss gap
as an early indicator of exposure. Log and rate-limit bulk query access that could feed an external shadow
attack.

## What's simplified

- Digits, not personal data: the risk is measured the same way, but the real-world impact is not.
- An easy dataset — even non-members have low loss, so the attack is weak at low FPR. Mean advantage hides the
  most exposed individuals, so TPR at low FPR is reported alongside it (Carlini et al. 2022).
- A simple attacker: one global threshold from a single shadow model. Stronger attacks use many shadow models
  and a per-example threshold.
- **DP-SGD here is measured empirically, not a guarantee.** The ε of DP-SGD depends on noise, batch size,
  number of steps, and sampling, and must be computed with a privacy accountant (Abadi et al.'s moments
  accountant or successors); this lab does not compute it and shuffles batches instead of subsampling. For a
  real guarantee, use a maintained library that does the accounting.

## References (accessed 2026-11-10)

- R. Shokri et al., "Membership Inference Attacks against Machine Learning Models", IEEE S&P 2017. [arXiv:1610.05820](https://arxiv.org/abs/1610.05820)
- S. Yeom et al., "Privacy Risk in Machine Learning: Analyzing the Connection to Overfitting", IEEE CSF 2018. [arXiv:1709.01604](https://arxiv.org/abs/1709.01604)
- N. Carlini et al., "Membership Inference Attacks From First Principles", IEEE S&P 2022. [arXiv:2112.03570](https://arxiv.org/abs/2112.03570)
- C. Dwork, A. Roth, "The Algorithmic Foundations of Differential Privacy", *Found. Trends Theor. Comput. Sci.* 9(3–4), 2014. [doi:10.1561/0400000042](https://doi.org/10.1561/0400000042)
- M. Abadi et al., "Deep Learning with Differential Privacy", ACM CCS 2016. [arXiv:1607.00133](https://arxiv.org/abs/1607.00133)
- [OWASP LLM02:2025 Sensitive Information Disclosure](https://genai.owasp.org/llmrisk/llm022025-sensitive-information-disclosure/).
- [EDPB · Opinion 28/2024 on data-protection aspects of AI models](https://www.edpb.europa.eu/our-work-tools/our-documents/opinion-board-art-64/opinion-282024-certain-data-protection-aspects_en) (adopted 17 Dec 2024).
