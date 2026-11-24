<!-- Finding write-up público (recruiter-facing). Rellena la salida real donde lo indican los comentarios. -->

# E2-02 — Stealing a model through its prediction API

> model extraction · equation-solving copy · substitute training · query budgets

| | |
|---|---|
| **Severity** | High — a prediction API exposes enough signal to reconstruct a functionally equivalent copy of the model, at a cost that is far below retraining it. |
| **Component** | A classifier served as an API on `127.0.0.1`: send an 8×8 image, receive the probability of each digit. Built with FastAPI (0.162.2) and scikit-learn (1.9.1); the victim is a logistic regression. |
| **Category** | Model extraction / model stealing via the inference API (Tramèr et al. 2016). MITRE ATLAS: Exfiltration — *ML Model Extraction* via the inference API. NIST AI 100-2: availability/confidentiality attack on a deployed model (model stealing). OWASP LLM Top 10 2025: LLM10 Unbounded Consumption includes stealing a model through its API. |
| **Status** | Reproduced and mitigated; measured across defenses and query budgets. |

## Summary

Kurogane, a fictional forge, sells a digit classifier as an API. The attacker has no weights and no labelled
training data — only an API key and a pile of unlabelled images. From the API's responses they build a
**copy** and measure its **agreement** with the original (the fraction of images on which both predict the
same class) as a function of how many queries they made. Two paths: **solve the equations** (for a logistic
regression, `ln P_j − ln P_0` is linear in the input, so each exact-probability query yields 9 linear
equations; ~65 queries in general position give an exact copy), or **train a substitute** on the labels the
API returns, which works even when the API only returns the class.

## Threat model

- **Attacker:** anyone holding a valid API key, querying the service from outside as any client would.
- **Goal:** reconstruct a model that agrees with the original on unseen inputs, without access to weights or labelled training data.
- **Access / preconditions:** a working API key and a supply of unlabelled images of the same type; no insider access.

## Steps to reproduce (PoC)

From the lab folder, with the environment installed (`requirements.txt`):

```powershell
.\.venv\Scripts\python.exe bateria.py
```

For each configuration (`ninguna`, `redondeo`, `etiqueta`, `limite`, `limite,redondeo`) and 3 seeds, the
battery starts the real API with uvicorn on `127.0.0.1` (on a free port) and attacks it over HTTP, with
query budgets from 10 to 640. For each budget it reports the queries actually granted and the agreement of
each copy; results are saved to `forja/evidencias/E2-02-medicion.json`.

<!-- TODO Gerard: pega aquí un extracto real de la salida de bateria.py (la fila "ninguna" y la fila con "limite,redondeo"). -->

## Impact

- **Confidentiality / IP:** the model, a trained asset, is reconstructed from black-box queries alone.
- **Economics:** copying costs a bounded number of queries — orders of magnitude cheaper than collecting data and retraining.
- **Downstream:** a local copy enables offline probing (adversarial examples, membership inference) with no further API calls.

## Measurement

The battery sweeps defenses against the two copy methods; each defense maps to what it limits (qualitatively):

| Defense | What it does | What it limits |
|---|---|---|
| `redondeo` | returns probabilities rounded to 2 decimals | degrades the equation-solving copy (less exact signal per query); adds an average L1 error to what legitimate clients receive |
| `etiqueta` | returns only the predicted class, no probabilities | removes the equations entirely; the attacker must fall back to training a substitute, needing more queries |
| `limite` | 50 queries per key per hour | caps the query rate, raising the cost/time to reach a given agreement; does not prevent copying |
| `limite,redondeo` | both combined | stacks the rate cap with reduced per-query signal |

Baseline (no defenses): with exact probabilities the equation-solving copy reaches near-exact agreement
within a small budget. Defenses raise the attacker's cost (more queries, less signal, lower rate) while
legitimate queries keep working — at a measurable probability-error cost for rounding.

<!-- TODO Gerard: sustituye las descripciones cualitativas por los % de acuerdo medidos (por presupuesto y configuración) y el "error prob." del redondeo. -->

## Remediation

Treat the prediction API as the model's attack surface. Return the least information that the product needs
(class or coarse/rounded scores instead of full-precision probabilities), rate-limit per identity, and back
it with query-pattern detection and usage terms. Keep the endpoint private (bind to `127.0.0.1`, publish
only to known clients) — an open prediction API is a model given away. None of these stops extraction
outright; together they make it slow and expensive. Residual risk is listed under "What's simplified".

## Detection (blue-team note)

Alert on: a single key issuing many systematic, near-space-filling queries (equation-solving signature);
query volume per key far above normal client usage; inputs that look synthetic or uniformly distributed
rather than natural; bursts that reset around rate-limit windows (suggesting budget spread across many keys).

## What's simplified

- The victim is a logistic regression — the easiest case to copy by equations. Neural networks have no
  closed-form solution, so the attacker trains a substitute instead, with more queries.
- The limit is per key. An attacker with many keys (or many free accounts) spreads queries across them: the
  limit raises the cost of stealing, it does not prevent it. Production combines it with query-pattern detection and usage terms.
- The attacker has images of the same type as the training data. Tramèr et al. show that, for equation-solving, random inputs suffice.
- The limit is kept in process memory: restarting the service resets the count. In production it lives in a shared store (e.g. your API gateway's).

## References (accessed 2026-11-10)

- F. Tramèr, F. Zhang, A. Juels, M. K. Reiter, T. Ristenpart, "Stealing Machine Learning Models via Prediction APIs", USENIX Security 2016. [arXiv:1609.02943](https://arxiv.org/abs/1609.02943)
- [MITRE ATLAS](https://atlas.mitre.org/) — ML model extraction via the inference API.
- [OWASP Top 10 for LLM Applications 2025](https://genai.owasp.org/llm-top-10/) — LLM10 Unbounded Consumption (model theft via API queries).
- [FastAPI](https://fastapi.tiangolo.com/) (0.162.2) and [scikit-learn](https://scikit-learn.org/stable/) (1.9.1).
