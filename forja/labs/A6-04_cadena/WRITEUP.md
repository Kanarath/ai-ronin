<!-- Finding write-up público (recruiter-facing). Rellena la salida real donde lo indican los comentarios. -->

# A6-04 — Verifying an AI supply chain

> malicious pickles · malformed/polyglot safetensors · AI-BOM integrity · dependency risk · insecure containers

| | |
|---|---|
| **Severity** | High — a model artifact can execute code the moment it is loaded, and an unverified build chain ships poisoned, tampered, or undeclared artifacts straight to production. |
| **Component** | A static **AI-artifact verifier** (Python 3.13 standard library only) that scans a project folder — pickles, safetensors, an AI-BOM (CycloneDX ML-BOM), `requirements`, and `Dockerfile`s — and exits non-zero to fail a CI pipeline. |
| **Category** | OWASP Top 10 for LLM Applications 2025 — **LLM03 (Supply Chain)** and LLM05 (improper output / unsafe deserialization). MITRE ATLAS — **AML.T0010 (ML Supply Chain Compromise)**, model/data/software sub-techniques. |
| **Status** | Reproduced and mitigated; measured before/after across 9 control configurations. |

## Summary

A project folder for an ML service is trusted on its face. Two fictional projects, `taller-bueno`
(nothing to flag) and `taller-comprometido` (every file carries one A6-02 problem), exercise the verifier.
Threats span six categories: **pickles that execute code on load** (via `STACK_GLOBAL`/`GLOBAL` + `REDUCE`,
including one with a `.safetensors` extension and one hidden behind a decoy), **malformed or polyglot
weight files** (a safetensors with a pickle appended, overlapping tensors, a 1 TB header, a length/payload
mismatch), **integrity gaps** (an artifact whose hash no longer matches the AI-BOM, and one not declared
at all), **poisoned data**, **dependency risk** (unpinned, non-existent / *slopsquatted*, freshly
published, or off-index packages), and **insecure containers** (root user, secrets in `ENV`/`ARG`,
unversioned images).

## Threat model

- **Attacker:** anyone who can place or alter a file in the project — a tampered model, a polyglot weights
  file, a hallucinated dependency suggested by a coding assistant, a Dockerfile that leaks a registry token.
- **Goal:** achieve code execution on model load, or smuggle a tampered/undeclared/poisoned artifact or an
  untrusted dependency into the build.
- **Access / preconditions:** can contribute an artifact to the repository or the model registry the
  pipeline consumes.

## Steps to reproduce (PoC)

No install, standard library only. From the lab folder:

```powershell
py -3.13 generar_artefactos.py
py -3.13 verificador.py artefactos\taller-comprometido --hoy 2026-11-10
py -3.13 bateria.py
```

The verifier reads pickle **opcodes with `pickletools` and never calls `pickle.load`** (a test asserts it
does not even import `pickle`). `bateria.py` regenerates both projects, checks their hashes against
`ataques.json`, and runs 22 bad / 11 good artifacts through 9 control configurations.

<!-- TODO Gerard: pega aquí la fila "ninguna" y la fila con todos los controles de bateria.py. -->

## Impact

- **Confidentiality / Integrity:** a poisoned pickle or polyglot weights file runs arbitrary code in the
  training or serving environment on load.
- **Integrity:** a model whose hash diverges from the AI-BOM, or one absent from it, reaches production
  unnoticed.
- **Trust / Availability:** a non-existent or off-index dependency pulls attacker-controlled code; an
  insecure container runs as root or leaks registry secrets in its image history.

## Measurement

`bateria.py` reports, per configuration: **bad artifacts that escape** (of 22, by category), how many of
those **would execute code** on load, and **good artifacts accepted** (of 11 — rejections are false
positives that get a control switched off). Baseline (`ninguna`): every bad artifact passes. With all
controls enabled — including `pickle-estricto` — escapes drop sharply while legitimate artifacts keep
passing. Each control maps to a category:

| Control | Where | Issue it stops |
|---|---|---|
| `pickle` / `pickle-estricto` | pickle opcodes | code execution on load; strict mode flags *any* import or call |
| `safetensors` | weight header | malformed / polyglot files: bad offsets, overlaps, gaps, oversized or mismatched headers |
| `bom` | AI-BOM | integrity: hash mismatch vs. the ML-BOM, or an undeclared artifact |
| `deps` | requirements | unpinned, non-existent (slopsquatting), recently published, or off-index packages |
| `docker` | Dockerfile | root user, secrets in `ENV`/`ARG`, unversioned images |

<!-- TODO Gerard: sustituye por los números medidos (escapan/22, con código, buenos/11) por configuración. -->

One class escapes **every** configuration by design: **poisoned data declared with its correct hash**. The
AI-BOM proves a file is the one it describes, not that the file is trustworthy — that needs provenance and
data inspection (A6-02).

## Remediation

Defense in depth across the build chain: inspect pickle opcodes **without loading** (prefer
`pickletools`/`pickle` never on third-party pickles), validate safetensors headers and offsets, verify
every artifact's SHA-256 against the AI-BOM and reject undeclared files, enforce pinned dependencies from a
reviewed index (`pip install --require-hashes`), and harden Dockerfiles (non-root user, no secrets in
`ENV`/`ARG`, versioned base images). Fail the pipeline on any finding. For authenticity (not just
integrity), sign model manifests with OpenSSF Model Signing. Residual risk is listed under "What's simplified".

## Detection (blue-team note)

Alert on: a model file whose hash diverges from the AI-BOM, or an artifact present on disk but absent from
it; pickle opcodes resolving `GLOBAL`/`STACK_GLOBAL` imports or `REDUCE` calls; weight files whose declared
header size does not match the buffer, or with trailing bytes past the tensor region; requirements naming
unpinned, unknown, or off-index packages; Dockerfiles setting secret-named variables or ending as root.

## What's simplified

- Two projects and 33 fixed artifacts. A real scanner (ModelScan, Fickling, picklescan, Hugging Face's
  scan) knows far more formats and tricks.
- `revisar_pickle` approximates import resolution (tracking stacked strings and memo, not the full stack);
  a determined attacker can craft pickles that fool it — hence the real rule is **never load third-party
  pickles**, not "load them if the scanner sees nothing".
- A small, hand-written allow-list; the secrets rule checks variable **names**, not values (after
  BuildKit's `SecretsUsedInArgOrEnv`).
- The package index is a local JSON with lab dates; production uses an internal registry/proxy, hash-pinned
  installs, and a vulnerability scanner.
- The AI-BOM carries each file's path in a namespaced property, which is not a standard CycloneDX field.
- No control detects poisoned data declared with its correct hash — that needs provenance and data
  inspection.

## References (accessed 2026-11-10)

- [OWASP Top 10 for LLM Applications 2025](https://genai.owasp.org/llm-top-10/) — LLM03 (Supply Chain).
- MITRE ATLAS — ML Supply Chain Compromise (AML.T0010).
- [Python · `pickletools`](https://docs.python.org/3/library/pickletools.html) and [`pickle`](https://docs.python.org/3/library/pickle.html) (the `pickle` module is not secure).
- [safetensors format](https://github.com/huggingface/safetensors) (0.8.0, 2026-06-09): 8-byte little-endian header length, JSON header, offsets fully indexing the buffer with no gaps/overlaps, 100 MB header cap.
- [CycloneDX 1.7](https://cyclonedx.org/specification/overview/) (2025-10-21) and its [ML-BOM](https://cyclonedx.org/capabilities/mlbom/): `machine-learning-model`, `data`, `file` components with SHA-256 hashes.
- [OpenSSF Model Signing](https://github.com/ossf/model-signing-spec) and the [`model-signing` 1.1.1](https://pypi.org/project/model-signing/) library.
- [Docker · SecretsUsedInArgOrEnv](https://docs.docker.com/reference/build-checks/secrets-used-in-arg-or-env/); [PyPA · Name normalization](https://packaging.python.org/en/latest/specifications/name-normalization/).
- J. Spracklen et al., "We Have a Package for You!…", USENIX Security 2025. [arXiv:2406.10279](https://arxiv.org/abs/2406.10279)
