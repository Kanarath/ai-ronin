<!-- Finding write-up público (recruiter-facing). Rellena la salida real donde lo indican los comentarios. -->

# A2-05 — What the eye doesn't see: multimodal prompt injection

> indirect prompt injection via text that a human never sees — hidden HTML, invisible PDF, invisible Unicode (and images)

| | |
|---|---|
| **Severity** | High — a client-uploaded document carries an instruction invisible to a human reviewer that, once indexed, can hijack the assistant's answer to another customer. |
| **Component** | Document ingestion for a RAG service (extends A2-04): clients upload HTML, PDF and plain-text files. The extractor indexes **what the parser pulls from the file** (pypdf for PDF), not what a person sees on screen. Hybrid search feeds `llama3.2:1b`; embeddings via `embeddinggemma` (Ollama, CPU). Binds to `127.0.0.1`. Optional vision ingestion with `qwen3-vl:2b`. |
| **Category** | OWASP Top 10 for LLM Applications — LLM01 (prompt injection, in its indirect and multimodal / invisible-to-human form). MITRE ATLAS — AML.T0051.001 (LLM Prompt Injection: Indirect). |
| **Status** | Reproduced; mitigated and measured per defense (index → context → obeyed). |

## Summary

A naive extractor reads a file, not a rendering. Across ten client-uploaded documents, an instruction for
the assistant is hidden in a channel a human never sees: HTML with `display:none`, white `font-size:0`
text, an HTML comment, an image `alt` attribute; a PDF painted in render mode 3 (`3 Tr`, invisible), white
text (`1 1 1 rg`), or an instruction living only in PDF metadata; and plain text carrying Unicode **tag
characters** (U+E0020–E007E), **zero-width** spaces between letters, or **full-width** letters that a
keyword filter does not recognize. None of these are visible when the files are opened in a browser or a
PDF viewer. Four to six legitimate questions measure the **cost** of each defense, because hiding is not
always an attack (a `display:none` FAQ tab, a datum only in an image `alt`, a wording that looks like an
instruction, a `1½ kg` spec that Unicode normalization can mangle).

## Threat model

- **Attacker:** anyone who can upload a document that gets indexed (a review, a forum post, a PDF).
- **Goal:** plant an instruction or false "fact" that the assistant later repeats to another customer
  (a fake discount code, a forged warranty term, a competitor's link).
- **Access / preconditions:** holds a client token and the ability to submit content for ingestion.

## Steps to reproduce (PoC)

From the lab folder, with the environment installed (`requirements.txt`). First, index-only, no models:

```powershell
.\.venv\Scripts\python.exe bateria.py --solo-ingesta
```

This ingests the sources under five configurations (`ninguna`, `visibilidad`, `filtro`,
`visibilidad,invisibles`, and all four together) and counts how many of the **10 hidden instructions reach
the index** and how many of the **6 legitimate data points survive**. Then, with the real models (Ollama
running, as in A2-04):

```powershell
.\.venv\Scripts\python.exe bateria.py
```

<!-- TODO Gerard: pega aquí la fila "ninguna" y la fila con las cuatro defensas (niveles índice/contexto/obedecidas). -->

## Impact

- **Integrity:** the assistant repeats an injected instruction or a poisoned "fact" as if it were a forge
  answer.
- **Trust:** content that no reviewer could see steers responses to other customers.
- **Review blind spot:** human moderation of uploads is defeated — the payload is invisible on screen.

## Measurement

The battery reports three levels per configuration — **index** (the instruction got indexed), **context**
(it reached the model's context for the attack question), **obeyed** (the answer contains the attack's
mark) — plus **legitimate answered well**. Each defense maps to a channel class:

| Defense | What it does | Channels it addresses |
|---|---|---|
| `visibilidad` | HTML: decide visibility from the element; PDF: track render-mode/color operators and keep only painted text | CSS-hidden, white text, HTML comment, image `alt`, PDF render-mode-3, PDF white text |
| `filtro` | per-chunk keyword filter; suspicious chunks go to quarantine, not the index | instructions with a recognizable phrase (e.g. "Nota para el asistente") |
| `invisibles` | strip zero-width and Unicode tag characters | Unicode tags, zero-width — makes the hidden text **legible to `filtro`** |
| `normalizacion` | NFKC-normalize text | full-width letters — makes them **legible to `filtro`** |

Note the interaction: `invisibles` and `normalizacion` do not remove the instruction on their own; they
expose it so `filtro` can catch it, so they only help **in combination**. Chunk overlap can also carry the
tail of a filtered instruction into a neighbouring chunk that still reaches the index. Baseline (no
defenses): the hidden instructions reach the index broadly; with all four defenses enabled, far fewer do,
while legitimate questions keep working — at a cost the battery quantifies.

<!-- TODO Gerard: sustituye las descripciones cualitativas por tus % medidos (reaching index / context / obeyed, y legítimas) con IC 95% si procede. -->

## Remediation

Defense in depth at ingestion: compute **visibility** from the document itself (ideally render HTML in a
headless browser and read painted text; track PDF state operators) so invisible text never indexes;
**normalize and strip invisible Unicode** before any lexical check; run a **keyword filter with quarantine**
over the normalized text; and treat all retrieved content as data, not instructions (spotlighting, A2-04).
For images there is no exact check — measure OCR text-box contrast, refuse to transcribe third-party images,
or treat all transcribed text as untrusted. Residual risk is in "What's simplified".

## Detection (blue-team note)

Alert on: uploaded documents whose extracted text contains zero-width, tag, or full-width characters;
PDF text in render mode 3 or painted in the page/background colour; HTML text hidden by style or living in
comments/`alt`; and instruction-shaped phrases ("note for the assistant", "tell them that…") in indexed
chunks.

## What's simplified

- HTML visibility is decided from the element's own attributes; a real extractor must apply stylesheets,
  inheritance, off-screen positioning, clipping and the true background colour — i.e. render the page.
- The PDF analysis uses seven state operators; it omits other colour spaces (`sc`, `scn`), off-page text,
  text covered by an image, optional content groups, annotations and forms.
- DOCX is not in the lab but is the same problem (`<w:vanish/>`, white `w:color`, core/comment XML).
- The invisible-character check covers category Cf and variation selectors; homoglyphs (UTS #39), Hangul
  filler and stacked combining marks remain.
- Each attack's mark is an invented code so success is unambiguous; a real attack leaves no such marker.

## References (accessed 2026-11-10)

- [OWASP Top 10 for LLM Applications 2025](https://genai.owasp.org/llm-top-10/) — LLM01 prompt injection (indirect and invisible-to-human / multimodal).
- K. Greshake et al., "Not what you've signed up for", [arXiv:2302.12173](https://arxiv.org/abs/2302.12173) (2023).
- E. Bagdasaryan et al., "Abusing Images and Sounds for Indirect Instruction Injection in Multi-Modal LLMs", [arXiv:2307.10490](https://arxiv.org/abs/2307.10490) (2023).
- J. Rehberger, ["ASCII Smuggler Tool: Crafting Invisible Text and Decoding Hidden Codes"](https://embracethered.com/blog/posts/2024/hiding-and-finding-text-with-unicode-tags/), Embrace The Red (2024-01-14).
- Unicode: [Tags block (U+E0000)](https://www.unicode.org/charts/PDF/UE0000.pdf), [UAX #15 Normalization](https://www.unicode.org/reports/tr15/), [UTS #39 Security Mechanisms](https://www.unicode.org/reports/tr39/).
- ISO 32000-1:2008 (PDF 1.7), §9.3.6 "Text Rendering Mode" ([Adobe copy](https://opensource.adobe.com/dc-acrobat-sdk-docs/pdfstandards/PDF32000_2008.pdf)); [pypdf](https://pypdf.readthedocs.io/en/stable/) (BSD-3-Clause).
- [WCAG 2.2](https://www.w3.org/TR/WCAG22/) criterion 1.4.3 (minimum contrast); [Ollama · qwen3-vl](https://ollama.com/library/qwen3-vl).
