<!-- Finding write-up público (recruiter-facing). Rellena la salida real donde lo indican los comentarios. -->

# A1-07 — Evaluating a trained prompt-injection guardrail

> Naive Bayes classifier as an input filter · what it catches, what it misses, and its false-positive cost

| | |
|---|---|
| **Severity** | Medium — a guardrail that is trusted more than it earns leaves injections passing while blocking paying customers; it is a mitigating control, not a vulnerability per se. |
| **Component** | A from-scratch security classifier (multinomial Naive Bayes over character n-grams, pure Python, no ML libraries) that decides whether an incoming message is a prompt injection and blocks it before it reaches the model. Served by a FastAPI app bound to `127.0.0.1`. |
| **Category** | OWASP Top 10 for LLM Applications — LLM01 (prompt injection) and the input-filtering defenses against it. MITRE ATLAS: LLM Prompt Injection (evaluated here as a detection/filtering mitigation, with its evasion surface). |
| **Status** | Built and evaluated; measured on a held-out test set with Wilson confidence intervals. |

## Summary

Input guardrails are the most deployed mitigation for prompt injection, and the most oversold. This lab
trains one on a small synthetic corpus of counter messages, selects an operating threshold, and then
measures it honestly as a defensive control: false positives (legitimate customers blocked), false
negatives (attacks that pass), the threshold trade-off curve, and resistance to evasion. It is compared
against the A1-05 pattern filter and, optionally, a local `llama3.2:1b` used as a classifier.

## Threat model

- **Attacker:** anyone sending a message to the public counter who wants to steer the model (extract the
  employee discount code, dump the system prompt, assume a privileged role).
- **Defensive goal:** block injections at the input while leaving normal sales/support traffic untouched.
- **Access / preconditions:** none beyond sending a free-text message; the attacker can rephrase, switch
  language, add separators, or bury the payload in a long benign message.

## Steps to reproduce (PoC)

From the lab folder, with the environment installed (`requirements.txt`):

```powershell
.\.venv\Scripts\python.exe bateria.py
```

The battery trains on the `entrenamiento` split, selects the threshold on the `validacion` split with a
maximum false-positive rate of 10% (`--tfp-maxima`; never on the test set), then prints the threshold curve
over the held-out `ataques.json` (31 attacks, 20 legitimate) and measures four configurations: `ninguna`,
`patrones` (A1-05), `clasificador`, and `patrones,clasificador`. No Ollama or Docker required.

<!-- TODO Gerard: pega aquí la fila "ninguna" y la fila "patrones,clasificador" de bateria.py (con IC de Wilson). -->

## Impact (what gets through when the guardrail is weak)

- **Confidentiality / integrity:** injections that evade the filter reach the model and can extract the
  employee discount code, request the internal system prompt, or re-task the assistant.
- **Availability of service:** false positives block real customers — in production, lost sales and support
  tickets. The guardrail's cost is paid on both sides of the threshold.
- **False assurance:** a headline like "blocks 90% of test attacks" is measured against attacks resembling
  the training data; an adaptive attacker sends only the ones that pass.

## Measurement (catch vs. miss vs. false-positive cost — qualitative)

Reported per configuration, with Wilson intervals; the test attacks appear in five forms and the classifier
has never seen them:

| Dimension | What it measures |
|---|---|
| `pasan` (false negatives) | attacks that cross the guardrail — broken out by `original`, `parafrasis`, `ingles`, `relleno`, `separadores` |
| `falsos positivos` | legitimate messages wrongly blocked (several deliberately contain attack-like words) |
| threshold curve | raising the threshold catches more attacks but blocks more customers — a direct trade-off |
| which legitimate messages were blocked | reveals whether the model learned intent or merely surface form |

Qualitatively: evasion variants (paraphrase, English, long-text padding, and inserted separators) are the
ones that slip past, and the pattern filter and the classifier do not necessarily miss the *same* ones; the
blocked-legitimate list shows the classifier keys on form, not intent. Whether two configurations differ
at all depends on their Wilson intervals overlapping — with 31 attacks and 20 legitimate messages, overlap
means the data cannot claim one is better.

<!-- TODO Gerard: sustituye por los % medidos con IC 95%; indica qué variante esquiva cada guardián y qué legítimas se bloquearon. -->

## Remediation

Treat the guardrail as one layer, not the defense. Keep it for filtering known attacks and logging
attempts, but pair it with architectural defenses (A1-05): if the secret is not in the prompt, there is
nothing to exfiltrate. Choose the threshold from a validation split against an explicit false-positive
budget, never from the test set. In production, prefer a purpose-trained transformer classifier (e.g. Meta
Llama Prompt Guard 2) over Naive Bayes — better, but with the same underlying limits.

## Detection (blue-team note)

Log every classifier decision with its score, not just blocks. Alert on bursts of near-threshold messages
(threshold probing), on the same payload resent with separators or language changes (adaptive evasion), and
review the blocked-legitimate stream as a false-positive signal and a data-quality feedback loop.

## What's simplified

- The training set is 90 hand-written, deliberately low-variety messages; real guardrails use tens of
  thousands of examples and their authors still warn that adaptive attacks evade them.
- `probabilidad` averages per n-gram so the threshold is usable; pure Naive Bayes collapses to 0 or 1 on any
  longer message. Neither is a calibrated probability.
- Production uses transformer models trained for this task, with the same structural limits: a threshold
  that fixes how many legitimate customers you accept blocking, a bounded text window (long messages are
  chunked), and evasion by paraphrase or adaptation.

## References (accessed 2026-11-10)

- [scikit-learn 1.9.1 · Multinomial Naive Bayes](https://scikit-learn.org/stable/modules/naive_bayes.html) — the library version of what is implemented here (Laplace smoothing, α = 1).
- [Meta · Llama Prompt Guard 2 (model card)](https://huggingface.co/meta-llama/Llama-Prompt-Guard-2-86M) — a real injection/jailbreak classifier with its declared limits.
- [OWASP Top 10 for LLM Applications 2025](https://genai.owasp.org/llm-top-10/) — LLM01, prompt injection.
- Wilson score interval: E. B. Wilson, *Journal of the American Statistical Association* 22 (1927), 209–212.
