# 05 — Diseño visual

## 1. Identidad

Un **laboratorio de investigación** nocturno con disciplina de dojo. La estética es ciberpunk sobria: precisión técnica, no neón saturado. La legibilidad manda sobre el efecto.

Motivos visuales:
- Líneas finas.
- Retículas.
- Sellos o *hanko* para los logros.
- Separadores inspirados en el filo de una katana.
- Kanji decorativos **solo** cuando tengan significado real y se pueda verificar (por ejemplo, 道 «camino», 学 «aprender»).

## 2. Paleta (tokens del `Theme`)

| Token | Hex | Uso |
|---|---|---|
| `bg` | `#0A0E13` | Fondo |
| `panel` | `#101820` | Paneles |
| `panel_alt` | `#16212B` | Cabeceras y zonas activas |
| `line` | `#23313D` | Bordes y retículas |
| `text` | `#D6E2EA` | Texto principal |
| `muted` | `#7A8B99` | Texto secundario |
| `teal` | `#14B8A6` | Acento principal: acciones y foco |
| `cyan` | `#22D3EE` | Datos, terminal y visualizaciones |
| `gold` | `#D4A72C` | Maestría, logros y RONIN |
| `red` | `#E5484D` | Solo para alertas, ataques y errores (con moderación) |
| `violet` | `#8B7CF6` | Contenido etiquetado como experimental o emergente |

- Contraste del texto sobre el fondo ≥ 7:1 (`text` sobre `bg`).
- Los estados nunca dependen solo del color: siempre llevan icono y texto.

## 3. Tipografía (licencia OFL, incluida en el proyecto y sin descarga en tiempo de ejecución)

- **Terminal y código:** JetBrains Mono.
- **Interfaz:** IBM Plex Sans.
- **Títulos:** IBM Plex Sans Condensed, en versalitas espaciadas.
- Escala de fuente configurable entre el 90 % y el 150 %.

## 4. Layout del hub

```
┌──────────────────────────────────────────────────────────────────────────┐
│ AI RONIN   ▸ T2 Aprender de datos ▸ T2-01      XP ▮▮▮▮▯  Lv 3   ⚙        │
├────────────┬───────────────────────────────────────────┬─────────────────┤
│ CURRÍCULO  │  LABORATORIO                              │  RONIN          │
│ ◆ T1 ✓     │  (visualización: scatter, red, matriz…)   │  «¿Qué crees    │
│ ◆ T2 ◐     │                                           │   que pasará si │
│   · T2-01  │                                           │   k = 1?»       │
│   · T2-02  │                                           │  [Predecir]     │
│ ◇ T3 🔒     │                                           ├─────────────────┤
│            │                                           │  MISIÓN         │
│            │                                           │  ☐ o1 …         │
│            │                                           │  ☐ o2 …         │
├────────────┴───────────────────────────────────────────┴─────────────────┤
│ ronin@dojo:~/T2-01$ model create knn --k 5                               │
│ ✓ modelo knn (k=5) creado · 0 ejemplos                                   │
│ ronin@dojo:~/T2-01$ █                                     [cheatsheet ⇱] │
└──────────────────────────────────────────────────────────────────────────┘
```

- Paneles con `HSplitContainer` y `VSplitContainer`: se pueden redimensionar y el tamaño se recuerda.
- Terminal acoplado abajo y ampliable con `F12`. La chuleta se abre como panel flotante y se puede fijar.
- Resolución base de 1600×900, con escalado `canvas_items` y aspecto `expand`. Mínimo usable: 1280×720.

## 5. Visualizaciones (componentes reutilizables con `_draw()`)

| Componente | Se usa en |
|---|---|
| `ScatterPlot` (con fronteras de decisión) | T1, T2, T3, T5 |
| `LossCurve` (train y validación) | T2, T3, T4 |
| `ConfusionMatrix` | T3, evaluaciones |
| `NetworkGraph` (neuronas animadas según la activación) | T4 |
| `AttentionHeatmap` | T6 |
| `TokenStrip` (tokens coloreados por id) | T5, T6, A1 |
| `ProbabilityBars` (distribución de next-token) | T6, A1 |
| `FlowGraph` (pipelines, agentes, MCP y fronteras de confianza) | A1–A6, O3 |

## 6. Animación y efectos
- Animaciones cortas (150–250 ms) con `Tween`, solo cuando aportan información: un dato que fluye o un cambio de estado.
- Shader de scanline y viñeta **desactivado** por defecto y opcional en los ajustes.
- Modo de **movimiento reducido** que desactiva todo lo anterior.

## 7. Voz de RONIN
- Sereno, preciso y exigente pero respetuoso. Frases cortas.
- Pregunta antes de explicar.
- Nunca usa el sarcasmo cuando te equivocas.
- Marca visualmente las simplificaciones con el icono ⚗ y el texto «modelo simplificado».
