# 09 — Plan de continuidad (handoff técnico)

Para que cualquiera —persona o asistente de IA— pueda **retomar el proyecto sin contexto previo**.
Aquí va el "qué, cómo y dónde" **técnico**. (Documento público; sin datos personales.)

## Qué es AI RONIN

Academia jugable (Godot 4.7) de **AI Engineering, AI Security y AI Operations**. Dos planos:

- **El Dojo** — el juego: enseña los conceptos; todo es simulado y seguro.
- **La Forja** — laboratorios reales en Python/Docker **fuera del juego** (`forja/labs/`): donde se
  ataca y se mide de verdad.

## Estado actual (2026-11-23 · v0.4.1)

- Temario **completo**: T1–T13, P0–P2 y los arcos A/O/C/E, con misiones, **diagramas de concepto** y
  **teach enriquecido** en todo.
- **20 labs reales** en `forja/labs/`.
- Releases de Windows y Linux publicadas.

## Mapa del repositorio

| Carpeta | Qué hay |
|---|---|
| `game/` | Proyecto Godot: `autoload/dojo.gd`, `ui/`, `content/missions/*.json`, `tests/` |
| `forja/labs/` | Los 20 laboratorios reales |
| `forja/ejercicios/` | Ejercicios pequeños de Python (`ronin_check.py`, `requirements.txt`) |
| `forja/evidencias/` | Resultados personales de las labs (gitignored) |
| `instalador/` | `construir.ps1`, `construir_linux.ps1`, `ai-ronin.iss` |
| `docs/` | `01-PRD` … `08-auditoría`, y este `09` |
| `build/` | Artefactos de release (gitignored) |

## Convenciones de contenido

- **Misión** = un JSON en `game/content/missions/`. Campos clave: objetivos, `teach`, `lab.diagram` y
  un `diagram` por objetivo.
- **Diagramas**: `game/ui/viz/concept_diagram.gd` (`ConceptDiagram`), 7 tipos *data-driven* (`points2d`,
  `table`, `bars`, `lines`, `bowl`, `chips`, `tree`). El laboratorio va **siempre partido**; si no hay
  diagrama, salen olas decorativas.
- **teach**: contrato de 7 puntos (qué es · cómo funciona · para qué en tu camino · qué significa el
  resultado · cómo se traslada a tu realidad · la trampa típica · frase para recordar), con analogías del
  día a día.

## Tests

```
"$GODOT" --headless --path game -s res://tests/run_tests.gd
```

Suite de ~458 tests; es **lenta** porque incluye partidas que entrenan redes (T4). Para comprobar solo
que todo parsea: `"$GODOT" --headless --path game --import`.

Godot: `C:\Users\Ruben\Desktop\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe` (variante
`..._console.exe` para builds).

## Release (3 ficheros de versión + build)

Subir la versión en los **tres** sitios y reconstruir:

1. `game/project.godot` → `config/version`
2. `game/export_presets.cfg` → `file_version` y `product_version` (`"X.Y.Z.0"`)
3. `instalador/ai-ronin.iss` → `#define AppVersion`

Build: `instalador/construir.ps1` (Windows, ISCC/Inno Setup 6, con autoprueba) y `construir_linux.ps1`
(tar.gz). Artefactos en `build/`. Las partidas se guardan aparte de la instalación y no se borran al actualizar.

## Estándar de una lab de la Forja (checklist)

El molde de referencia es [`forja/labs/A4-04_mcp`](../forja/labs/A4-04_mcp). Cada lab real debería tener,
en este orden:

- [ ] Título + `**Misión del Dojo:** <id>. Laboratorio real de la Forja.`
- [ ] Intro: qué es el sistema y por dónde se ataca.
- [ ] *(opcional)* tabla "Pieza | quién la escribe".
- [ ] `## 1. Entorno y tests`: venv + `pip install -r requirements.txt` (si hay dependencias) + `unittest`
      + `ronin_check.py <LAB>` + `evidence import`.
- [ ] `## 2. Medir`: `bateria.py`/`redteam.py`, qué mide cada fila. **La evidencia va a
      `forja/evidencias/<LAB>.json`** (carpeta compartida y gitignored), no a una carpeta por lab.
- [ ] *(opcional)* `## Las defensas`: tabla defensa / dónde / qué corta.
- [ ] `## Qué está simplificado`: los límites honestos del lab.
- [ ] `## Referencias (consultadas el <fecha>)`: OWASP LLM / Agentic, MITRE ATLAS, RFC, specs, y las
      herramientas del sector (garak / promptfoo / PyRIT) donde apliquen.

**Estado:** `A4-04` y `E2-01` ya cumplen; `A1-09` actualizada a este estándar el 2026-11-23. El resto, al
tocarlas. Las labs destacadas llevan además un `WRITEUP.md` con formato de **informe de hallazgo**
(severidad · PoC · impacto · mitigación), en inglés.

## Cómo seguir sin la sesión que lo construyó

Lee `docs/01`–`08` para el diseño, y este `09` para el estado y las convenciones. Para la vertiente de
**presentación/portfolio** hay un plan aparte, **privado y local** (no versionado), en `docs/portfolio/`
si existe en tu copia de trabajo.
