<!-- Finding write-up público (recruiter-facing). Rellena la salida real donde lo indican los comentarios. -->

# A1-09 — Measuring LLM jailbreak resistance (red team)

> role-play · obfuscation · refusal-suppression · long-context · indirect injection

| | |
|---|---|
| **Severity** | Medium-High — bypassing the input guardrail makes the assistant disclose a protected secret. |
| **Component** | An LLM assistant holding a system-prompt secret (canary `CANARIO-7`) behind an input guardrail. Target is deterministic offline, or a real local model via Ollama (`llama3.2:1b`). |
| **Category** | OWASP Top 10 for LLM Applications — LLM01 (Prompt Injection / jailbreak); MITRE ATLAS. |
| **Status** | Reproduced; partially mitigated (indirect injection is residual by design). |

## Summary

A battery of jailbreak **families** tries to make the assistant reveal a protected canary; an attack
"succeeds" when the response contains it — the same loop as **garak**, **promptfoo** and **PyRIT**
(probes → target → detector → success rate). The deliverable is a **reproducible number** with its
baseline and its residual attack surface, not "I tried a few things". Families describe the *mechanism*,
not real payloads, so the value is the method and the number, not the exploit.

## Threat model

- **Attacker:** a user sending crafted prompts, or an instruction hidden in data the model later processes.
- **Goal:** exfiltrate the protected canary.
- **Access:** can send prompts and/or plant text in a document the assistant reads.

## Steps to reproduce (PoC)

```powershell
python redteam.py                        # offline, deterministic target
python redteam.py --ollama llama3.2:1b   # against a real local model (Ollama running)
```

<!-- TODO Gerard: pega aquí la salida de redteam.py (fila "ninguna" y fila "clasificador,normalizacion"). -->

## Impact

Disclosure of a secret the assistant must never reveal, via several bypass mechanisms (role-play,
base64 obfuscation, refusal suppression, long context, and indirect injection).

## Measurement

Attack success rate across three defense configurations:

| Configuration | What it adds | What still gets through |
|---|---|---|
| `ninguna` | nothing (baseline) | everything except direct asks |
| `clasificador` | keyword input filter | **obfuscation** (base64) and **indirect injection** |
| `clasificador,normalizacion` | normalize (lowercase, strip accents, decode base64) before filtering | only **indirect injection** |

The residual attack surface is **indirect injection**: the instruction hidden in data the model processes.
The input guardian never sees it as a user order, so it cannot stop it.

<!-- TODO Gerard: añade los % medidos con IC 95% de cada fila. -->

## Remediation

Normalize input before filtering to close obfuscation. But input-side guardrails **cannot** stop indirect
injection — that needs controls where the data is handled (provenance checks, context spotlighting,
and constraining what the model is allowed to do with retrieved text — see **A2-04**). Defense in depth,
not a single filter.

## Detection (blue-team note)

Alert on canary-shaped strings in model output, base64 blobs inside user prompts, and repeated
refusal-suppression phrasings.

## What's simplified

- The offline target is **deterministic** (fixed rules, not a model): a reproducible number to learn the
  method, not a measurement of a real model.
- The guardrail is a **naive keyword filter** on purpose; production uses a trained classifier.
- **Indirect injection always passes by design** — it is the lesson, not a measurement of every possible defense.
- Against Ollama the numbers **vary between runs** (temperature > 0); a real report averages repetitions.

## References

- [garak](https://github.com/NVIDIA/garak) (NVIDIA) · [promptfoo red team](https://www.promptfoo.dev/docs/red-team/) · [PyRIT](https://github.com/Azure/PyRIT) (Microsoft).
- [OWASP Top 10 for LLM Applications](https://genai.owasp.org/llm-top-10/) — LLM01.
- [MITRE ATLAS](https://atlas.mitre.org/).
