# AI RONIN 🥷

> "Don't just use AI. Understand it, build it, break it, and defend it."

**A hands-on training ground for attacking and defending AI systems — built and used daily by a junior pentester.**

AI RONIN is an interactive academy (Godot 4) backed by **20 real Python/Docker labs** where LLMs, RAG
pipelines, agents and MCP servers are attacked and then hardened — with the results **measured**, not asserted.

> 👤 **Gerard Montero** ([Kanarath](https://github.com/Kanarath)) — Junior Pentester · AI Security · ISO 27001 consultant. Barcelona / remote.
> 🌐 *El juego y la documentación están en español. README en español: [README.es.md](README.es.md).*

## What this project demonstrates

- 🔴 **Offensive (AI red teaming):** direct & indirect prompt injection, RAG document poisoning,
  multimodal injection, MCP tool poisoning / rug-pull, token confusion, model evasion & extraction,
  supply-chain tampering — exercised with **garak**, **promptfoo** and **PyRIT** plus custom batteries.
- 🔵 **Defensive / detection:** input validation, guardrail classifiers, token scopes & audience,
  description pinning, safe path handling, and abuse logging/traces usable for SOC-style detection.
- 🛠️ **Engineering:** LLM services in Docker, the official **MCP SDK**, local models on **Ollama (CPU)**,
  test suites, and deterministic, reproducible evaluation harnesses.
- 📋 **Frameworks:** mapped to **OWASP Top 10 for LLM Applications**, **OWASP Top 10 for Agentic
  Applications (2026)**, **MITRE ATLAS** and **NIST AI 100-2**.

## Featured labs

Each lab ships a professional **finding write-up** (severity · PoC · remediation) and a measured
before/after. Ten security labs have a write-up; these five are the highlights:

| Lab | Topic | Write-up |
|---|---|---|
| **MCP server security** | tool poisoning, rug-pull, token confusion, path traversal | [write-up](forja/labs/A4-04_mcp/WRITEUP.md) · [code](forja/labs/A4-04_mcp) |
| **LLM red teaming** | measured jailbreak battery (garak/promptfoo/PyRIT pattern) | [write-up](forja/labs/A1-09_redteam/WRITEUP.md) · [code](forja/labs/A1-09_redteam) |
| **RAG hardening** | indirect injection, poisoning, access-control leakage | [write-up](forja/labs/A2-04_rag/WRITEUP.md) · [code](forja/labs/A2-04_rag) |
| **AI supply chain** | malicious pickles, polyglot weights, AI-BOM integrity | [write-up](forja/labs/A6-04_cadena/WRITEUP.md) · [code](forja/labs/A6-04_cadena) |
| **Adversarial ML** | FGSM evasion and hardening | [write-up](forja/labs/E2-01_evasion/WRITEUP.md) · [code](forja/labs/E2-01_evasion) |

More write-ups: agent containment ([A3-04](forja/labs/A3-04_agente/WRITEUP.md)), multimodal injection
([A2-05](forja/labs/A2-05_multimodal/WRITEUP.md)), guardrail evaluation
([A1-07](forja/labs/A1-07_guardian/WRITEUP.md)), model extraction
([E2-02](forja/labs/E2-02_extraccion/WRITEUP.md)), membership inference
([E2-03](forja/labs/E2-03_privacidad/WRITEUP.md)).

## Two layers

| Layer | What it is | Where |
|---|---|---|
| **The Dojo** | The Godot app: lessons, a fictional terminal, the RONIN mentor, simulations and real ML in GDScript — offline and sandboxed | `game/` |
| **The Forge** (`forja/`) | Real labs in Python, Docker and local models, always on localhost | `forja/` |

## Play

- **Windows:** download `AI-RONIN-Setup-<version>.exe` from [Releases](../../releases) and run it. It is
  unsigned, so Windows will warn ("Windows protected your PC") → "More info" → "Run anyway". Installs per-user,
  no admin. Your saves and your Forge exercises survive reinstalls and uninstalls.
- **Linux:** download `AI-RONIN-linux-x86_64.tar.gz`, extract, `chmod +x AI-RONIN.x86_64`, run it.
- **From source:** open `game/project.godot` with Godot 4.7 and press F5.

## Run the tests

```powershell
& "<path-to-Godot>\Godot_v4.7.2-stable_win64_console.exe" --headless --path game -s res://tests/run_tests.gd
```

## Documentation

Design docs (in Spanish): [PRD](docs/01-PRD.md) · [Architecture](docs/02-arquitectura.md) ·
[Curriculum](docs/03-curriculo.md) · [Missions](docs/04-especificacion-misiones.md) ·
[Visual design](docs/05-diseno-visual.md) · [Roadmap](docs/06-roadmap.md) ·
[2026 expansion](docs/07-ampliacion-2026.md) · [Continuity / handoff](docs/09-continuidad.md).

## Requirements

Godot 4.7.x. For the Forge labs: Python 3.12+ and Docker Desktop (only when you run a lab).

## License

**GNU General Public License v3.0** (GPL-3.0). Full text in [LICENSE](LICENSE).

## How it was made

Designed and directed by **Gerard Montero Sellarés**. The game **engine** was built with AI assistance
(Claude Code); the curriculum, the security design, the Forge labs, the attacks, the defenses and their
measurement are his own work. He uses it daily as a student of AI engineering and security.
