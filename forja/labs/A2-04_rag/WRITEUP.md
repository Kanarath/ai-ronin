<!-- Finding write-up público (recruiter-facing). Rellena la salida real donde lo indican los comentarios. -->

# A2-04 — Hardening a RAG pipeline

> indirect prompt injection · data poisoning · context/access leakage

| | |
|---|---|
| **Severity** | High — a retrieved document can hijack the assistant, inject false facts, or leak internal documents to a customer. |
| **Component** | A retrieval-augmented generation service: documents chunked, embedded with `embeddinggemma` (Ollama, CPU), stored in **Qdrant**; `llama3.2:1b` answers from retrieved chunks. Binds to `127.0.0.1`. |
| **Category** | OWASP Top 10 for LLM Applications — LLM01 (prompt injection), LLM04 (data poisoning), LLM08 (vector/embedding weaknesses). |
| **Status** | Reproduced; mitigated and measured per defense. |

## Summary

Three issues in one pipeline. A customer review (`resena-7`) carries a **hidden instruction** for the
assistant (indirect injection). A forum post (`foro-12`) asserts a **false warranty fact** and *claims* to
come from the forge, with a forged signature (poisoning). And two internal documents (`costes`,
`proveedores`) are retrievable by a customer who should never see them (missing access control).

## Threat model

- **Attacker:** anyone who can get a document into the corpus (a review, a forum post), plus a low-privilege
  customer querying the service.
- **Goal:** steer the assistant's answer, plant false facts, or exfiltrate internal documents.
- **Access:** can submit content that gets indexed; holds a customer token.

## Steps to reproduce (PoC)

```powershell
ollama pull embeddinggemma
.\.venv\Scripts\python.exe bateria.py
```

Indexes the corpus, measures **recall@3** for vector / BM25 / hybrid search, then runs 5 defense
configurations against the three attack categories.

<!-- TODO Gerard: pega aquí la fila "ninguna" y la fila con las tres defensas de bateria.py. -->

## Impact

- **Integrity:** the assistant follows a hidden instruction or repeats a poisoned "fact" as truth.
- **Confidentiality:** internal cost/supplier documents reach a customer (LLM08).
- **Trust:** a forged-provenance document is treated as authoritative.

## Measurement

Attack success before/after, with each defense mapped to the issue it addresses:

| Defense | What it does | Issue it stops |
|---|---|---|
| `acl` | filter retrieved chunks by the caller's role (from the token, not the request) | internal-document leakage (LLM08) |
| `procedencia` | verify an HMAC signature of provenance | poisoning via forged source (LLM04) |
| `spotlight` | mark retrieved text as data in the assembled context (spotlighting) | indirect injection (LLM01) |

Baseline (no defenses): all three categories succeed. With the three defenses enabled, attack success
drops across the board while legitimate queries keep working.

<!-- TODO Gerard: sustituye por los % medidos con IC 95%. Nota: con llama3.2:1b las "legítimas" salen bajas (el modelo responde "No lo sé" aunque el recall@3 sea 1,00); compara con llama3.2:3b. -->

## Remediation

Defense in depth across retrieval and prompt assembly: **least-privilege ACL on retrieval** (role from the
identity token), **provenance verification** (signed documents) to reject poisoned/forged content, and
**spotlighting** so the model treats retrieved text as data, not instructions. Harden Qdrant too: API key,
bind to `127.0.0.1`, protect the vectors (text can be partially reconstructed from embeddings), TLS in prod.

## Detection (blue-team note)

Alert on: retrieval returning documents above the caller's clearance; documents failing provenance
verification; retrieved chunks containing imperative instructions aimed at the assistant.

## What's simplified

- Six fixed attacks and five legitimate questions: a real evaluation uses many more.
- The signature is an HMAC with a lab key in `rag.py`; production uses a secrets manager or asymmetric
  signatures, applied by the system that publishes the document.
- Client/employee tokens are fixed; in production the role comes from your identity system.
- BM25 is computed in memory over all chunks; a real system uses a dedicated lexical index.

## References (accessed 2026-11-10)

- [OWASP Top 10 for LLM Applications 2025](https://genai.owasp.org/llm-top-10/) — LLM01, LLM04, LLM08.
- K. Hines et al., "Defending Against Indirect Prompt Injection Attacks With Spotlighting", [arXiv:2403.14720](https://arxiv.org/abs/2403.14720) (2024).
- [Qdrant · Security](https://qdrant.tech/documentation/security/).
- Cormack et al., "Reciprocal rank fusion…", SIGIR 2009 ([doi](https://doi.org/10.1145/1571941.1572114)); [RFC 2104 (HMAC)](https://www.rfc-editor.org/rfc/rfc2104).
