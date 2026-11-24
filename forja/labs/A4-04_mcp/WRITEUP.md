<!-- Finding write-up público (recruiter-facing). Rellena la salida real donde lo indican los comentarios. -->

# A4-04 — Securing a vulnerable MCP server

> Tool poisoning · rug-pull · token confusion · path traversal · excessive scopes

| | |
|---|---|
| **Severity** | High — unauthenticated-equivalent access leads to internal-document exfiltration and unauthorized state change (refunds). |
| **Component** | A Model Context Protocol (MCP) server built with the official Python SDK (spec rev. 2026-07-28), Streamable HTTP transport, bound to `127.0.0.1`, plus a malicious third-party server (`clima-samurai`). |
| **Category** | OWASP Top 10 for Agentic Applications (2026): tool poisoning, token passthrough / confused deputy, excessive agency. |
| **Status** | Reproduced and mitigated; measured before/after. |

## Summary

A fictional warehouse exposes three MCP tools (`buscar_pedido`, `aplicar_reembolso`, `leer_plano`) and two
resources. Out of the box it is vulnerable on five fronts at once: any known token is accepted for any
action (even one issued for another server or already expired), scopes are never checked, arguments are
validated by type only, and `leer_plano` joins the requested path onto the blueprints folder without
sanitizing it. Alongside it, a third-party server ships a **poisoned tool description** and later changes
its own definition (**rug-pull**) to exfiltrate an internal document carrying a canary.

## Threat model

- **Attacker:** a malicious/compromised third-party MCP server and a caller holding a low-privilege or
  wrong-audience token.
- **Goal:** exfiltrate `datos/privado/costes.txt` (canary) and trigger `aplicar_reembolso` without rights.
- **Access / preconditions:** can register a server with the host and present *some* valid-looking token.

## Steps to reproduce (PoC)

From the lab folder, with the environment installed (`requirements.txt`):

```powershell
.\.venv\Scripts\python.exe bateria.py
```

The battery needs neither Ollama nor Docker: it starts the warehouse and `clima-samurai` in-process and
attacks them with a deterministic host that obeys exactly what it is shown (worst-case model). It runs
**6 attacks × 4 legitimate tasks across 8 defense configurations**.

<!-- TODO Gerard: pega aquí un extracto real de la salida de bateria.py (la fila "ninguna" y la fila con todas las defensas). -->

## Impact

- **Confidentiality:** exfiltration of an internal costs document (canary leaves the private folder).
- **Integrity:** an unauthorized refund is applied with a read-only or wrong-audience token.
- **Trust:** the agent is steered by a tool description it should never have been shown.

## Measurement

Baseline (no defenses): the attacks succeed at roughly **85%**. With all defenses enabled, attack success
drops to **0%** while **legitimate tasks remain fully functional** — i.e. the defenses do not break the
service. Each defense maps to a specific attack class:

| Defense | Where | Attack it stops |
|---|---|---|
| `validacion` | server | `leer_plano '../…'` (schema pattern) and out-of-range / extra arguments |
| `rutas` | server | path traversal: `ruta_segura` prevents escaping `datos/planos/` |
| `scopes` | server | a read-only token issuing refunds (excessive permissions) |
| `audiencia` | server | a token minted for another server, or expired (token confusion) |
| `pinning` | host | rug-pull: the changed tool is quarantined until re-approved |
| `revision` | host | poisoned descriptions are never shown to the model |

<!-- TODO Gerard: sustituye "~85%" por tu número medido con IC 95% y, si quieres, añade la tabla por configuración. -->

## Remediation

Defense in depth across **two layers**: four controls on the **server** (they stop the call before it
executes) and two on the **host** (they stop content before the model ever sees it). Least privilege on
tokens (scopes + audience, per RFC 8707/9728), strict argument schemas, path containment, plus host-side
review and pinning of tool definitions. Residual risk is listed under "What's simplified".

## Detection (blue-team note)

Signals worth logging/alerting on: a tool whose definition hash changes between calls (rug-pull); a token
presented to a resource server it was not issued for (audience mismatch); repeated `leer_plano` calls with
`..` or absolute paths; refund calls from read-only tokens.

## What's simplified

- The authorization server is fictional: tokens are pre-issued and checked against a table, not validated
  as signed JWTs or introspected (RFC 7662).
- The model is deterministic (worst case), not a real LLM.
- Description review is a regular expression; an attacker can rephrase around it.
- Tokens and scopes are fixed; in production they come from your identity system.
- Six attacks and four legitimate tasks: a real evaluation uses many more.

## References (accessed 2026-11-10)

- Model Context Protocol — spec rev. 2026-07-28 and its Security Best Practices (tool poisoning, token
  passthrough, confused deputy, scope minimization).
- Official MCP Python SDK (`mcp`).
- RFC 8707 (Resource Indicators for OAuth 2.0) and RFC 9728 (Protected Resource Metadata).
- OWASP Top 10 for Agentic Applications (2026).
