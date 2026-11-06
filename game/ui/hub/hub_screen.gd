extends Control
## Hub del laboratorio: currículo · laboratorio (visualización) · misión + mentor · terminal.
## Solo presenta: toda la lógica está en DojoGame (autoload Dojo).

const UNITS := [
	{"id": "T1", "title": "T1 · Datos y vectores"},
	{"id": "T2", "title": "T2 · Aprender de datos"},
]
const FUTURE_UNITS := [
	"T3 · Optimización y métricas", "T4 · Redes neuronales", "T5 · Del texto al vector", "T6 · Transformers y LLM",
	"A1 · Aplicación LLM", "A2 · RAG y embeddings", "A3 · Agentes", "A4 · MCP", "A5 · Multiagente y A2A", "A6 · Supply chain e infra",
]
const MENTOR_COLORS := {
	"info": RoninPalette.TEXT,
	"question": RoninPalette.CYAN,
	"praise": RoninPalette.TEAL,
	"warn": RoninPalette.GOLD,
	"hint": RoninPalette.VIOLET,
	"debrief": RoninPalette.TEXT,
}

var game: DojoGame
var _terminal: TerminalView
var _plot: ScatterPlot
var _curriculum_box: VBoxContainer
var _mission_text: RichTextLabel
var _mentor_log: RichTextLabel
var _prediction_box: HFlowContainer
var _xp_label: Label
var _mission_label: Label


func _ready() -> void:
	game = Dojo.game
	_build_layout()
	game.mission_started.connect(_on_mission_started)
	game.mission_completed.connect(_on_mission_completed)
	game.runner.mentor_message.connect(_on_mentor)
	game.runner.state_changed.connect(_refresh_mission)
	game.shell.event_emitted.connect(_on_sim_event)
	_refresh_all()
	_welcome()
	_terminal.focus_input()


# ── Construcción de la interfaz ──────────────────────────────────────────────

func _build_layout() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	margin.add_child(root)

	# Barra superior
	var top := HBoxContainer.new()
	root.add_child(top)
	var title := Label.new()
	title.text = "AI RONIN"
	title.add_theme_color_override("font_color", RoninPalette.TEAL)
	title.add_theme_font_size_override("font_size", 22)
	top.add_child(title)
	var tag := Label.new()
	tag.text = "  道 · laboratorio de IA"
	tag.add_theme_color_override("font_color", RoninPalette.MUTED)
	top.add_child(tag)
	_mission_label = Label.new()
	_mission_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mission_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mission_label.add_theme_color_override("font_color", RoninPalette.CYAN)
	top.add_child(_mission_label)
	_xp_label = Label.new()
	_xp_label.add_theme_color_override("font_color", RoninPalette.GOLD)
	top.add_child(_xp_label)

	# Cuerpo
	var body := HSplitContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	var left := _panel("CURRÍCULO")
	left.custom_minimum_size = Vector2(250, 0)
	body.add_child(left)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.get_child(0).add_child(scroll)
	_curriculum_box = VBoxContainer.new()
	_curriculum_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_curriculum_box)

	var center := VSplitContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(center)

	var upper := HSplitContainer.new()
	upper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(upper)

	var lab := _panel("LABORATORIO")
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upper.add_child(lab)
	_plot = ScatterPlot.new()
	_plot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_plot.custom_minimum_size = Vector2(380, 260)
	lab.get_child(0).add_child(_plot)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(420, 0)
	upper.add_child(right)

	var mission := _panel("MISIÓN")
	right.add_child(mission)
	_mission_text = RichTextLabel.new()
	_mission_text.bbcode_enabled = true
	_mission_text.fit_content = true
	_mission_text.scroll_active = false
	mission.get_child(0).add_child(_mission_text)

	var mentor := _panel("RONIN · mentor")
	mentor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(mentor)
	var mbox: VBoxContainer = mentor.get_child(0)
	_mentor_log = RichTextLabel.new()
	_mentor_log.bbcode_enabled = true
	_mentor_log.scroll_following = true
	_mentor_log.selection_enabled = true
	_mentor_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mbox.add_child(_mentor_log)
	_prediction_box = HFlowContainer.new()
	mbox.add_child(_prediction_box)
	var actions := HBoxContainer.new()
	mbox.add_child(actions)
	for spec in [["Pista", "hint"], ["Objetivos", "mission status"], ["Briefing", "mission brief"], ["Chuleta", "cheatsheet"]]:
		var b := Button.new()
		b.text = spec[0]
		b.tooltip_text = spec[1]
		var cmd: String = spec[1]
		b.pressed.connect(func() -> void: _run(cmd))
		actions.add_child(b)

	_terminal = TerminalView.new()
	_terminal.setup(game.shell)
	_terminal.custom_minimum_size = Vector2(0, 250)
	center.add_child(_terminal)


## Panel con título; devuelve el PanelContainer (su hijo 0 es un VBoxContainer).
func _panel(title_text: String) -> PanelContainer:
	var p := PanelContainer.new()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var t := Label.new()
	t.text = title_text
	t.add_theme_color_override("font_color", RoninPalette.MUTED)
	t.add_theme_font_size_override("font_size", 12)
	v.add_child(t)
	return p


# ── Actualización ────────────────────────────────────────────────────────────

func _refresh_all() -> void:
	_refresh_top()
	_refresh_curriculum()
	_refresh_mission()


func _refresh_top() -> void:
	var p := game.progress
	_xp_label.text = "Nivel %d · %d XP" % [p.level(), p.xp()]
	var m := game.active_mission
	_mission_label.text = "" if m.is_empty() else "▶ %s · %s" % [m["id"], m["title"]]


func _refresh_curriculum() -> void:
	for c in _curriculum_box.get_children():
		c.queue_free()
	for unit: Dictionary in UNITS:
		var header := Label.new()
		header.text = unit["title"]
		header.add_theme_color_override("font_color", RoninPalette.CYAN)
		_curriculum_box.add_child(header)
		for m in game.catalog.missions:
			if m["unit"] != unit["id"]:
				continue
			var status := game.mission_status(m["id"])
			var icon: String = {"dominada": "◆", "completada": "✓", "en curso": "▶", "bloqueada": "🔒", "disponible": "·"}[status]
			var b := Button.new()
			b.text = "%s %s  %s" % [icon, m["id"], m["title"]]
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.flat = true
			b.disabled = status == "bloqueada"
			b.tooltip_text = "%s · %s · %s" % [MissionCatalog.DIFFICULTY_NAMES[int(m["difficulty"])], status, m["briefing"].substr(0, 120) + "…"]
			if status == "dominada":
				b.add_theme_color_override("font_color", RoninPalette.GOLD)
			elif status == "completada":
				b.add_theme_color_override("font_color", RoninPalette.TEAL)
			var id: String = m["id"]
			b.pressed.connect(func() -> void: _run("mission start " + id))
			_curriculum_box.add_child(b)
	var sep := Label.new()
	sep.text = "\nPRÓXIMAMENTE"
	sep.add_theme_color_override("font_color", RoninPalette.MUTED)
	sep.add_theme_font_size_override("font_size", 12)
	_curriculum_box.add_child(sep)
	for u: String in FUTURE_UNITS:
		var l := Label.new()
		l.text = "🔒 " + u
		l.add_theme_color_override("font_color", RoninPalette.LINE.lightened(0.3))
		_curriculum_box.add_child(l)


func _refresh_mission() -> void:
	_refresh_top()
	var r := game.runner
	var m := game.active_mission
	if m.is_empty():
		_mission_text.text = "[color=%s]Ninguna misión activa.[/color]\nElige una en el currículo o escribe [b]mission list[/b]." % _hex(RoninPalette.MUTED)
		_set_prediction_options([])
		return
	var lines := PackedStringArray()
	var phase_txt := "  [color=%s]· PRUEBA DE DOMINIO[/color]" % _hex(RoninPalette.GOLD) if r.phase == "trial" else ""
	if r.phase == "done":
		phase_txt = "  [color=%s]· COMPLETADA[/color]" % _hex(RoninPalette.TEAL)
	lines.append("[b]%s · %s[/b]%s" % [m["id"], _esc(m["title"]), phase_txt])
	# Progreso compacto (✓✓▶··) + solo el objetivo actual: el mentor necesita el espacio.
	var marks := ""
	for i in r.objectives.size():
		if i < r.index or r.phase == "done":
			marks += "[color=%s]✓[/color] " % _hex(RoninPalette.TEAL)
		elif i == r.index:
			marks += "[color=%s]▶[/color] " % _hex(RoninPalette.CYAN)
		else:
			marks += "[color=%s]·[/color] " % _hex(RoninPalette.MUTED)
	lines.append(marks + "[color=%s] objetivo %d de %d[/color]" % [_hex(RoninPalette.MUTED), mini(r.index + 1, r.objectives.size()), r.objectives.size()])
	var current_obj := r.current_objective()
	if not current_obj.is_empty():
		lines.append(_esc(current_obj["text"]))
	elif r.phase == "done":
		lines.append("[color=%s]Misión completada. Repítela o elige la siguiente en el currículo.[/color]" % _hex(RoninPalette.TEAL))
	_mission_text.text = "\n".join(lines)
	var obj := r.current_objective()
	var opts: Array = obj.get("prediction", {}).get("options", []) if not obj.is_empty() and not r.hypotheses.has(r.objective_key(obj)) else []
	_set_prediction_options(opts)


func _set_prediction_options(options: Array) -> void:
	for c in _prediction_box.get_children():
		c.queue_free()
	if options.is_empty():
		return
	var l := Label.new()
	l.text = "Tu predicción:"
	l.add_theme_color_override("font_color", RoninPalette.CYAN)
	_prediction_box.add_child(l)
	for o: String in options:
		var b := Button.new()
		b.text = o
		b.pressed.connect(func() -> void: _run("hipotesis " + o))
		_prediction_box.add_child(b)


# ── Eventos ──────────────────────────────────────────────────────────────────

func _welcome() -> void:
	_terminal.print_line("AI RONIN v%s · Dojo offline: este terminal solo actúa sobre el laboratorio simulado." % ProjectSettings.get_setting("application/config/version", "?"), "accent")
	_terminal.print_line("Empieza con: mission list  ·  ayuda: help  ·  Tab autocompleta  ·  ↑↓ historial", "muted")
	if not game.load_warning.is_empty():
		_terminal.print_line(game.load_warning, "warn")
	_on_mentor("Soy RONIN. No te daré respuestas: te haré preguntas. Elige una misión en el currículo de la izquierda.", "info")


func _run(line: String) -> void:
	_terminal.run_command(line)
	_terminal.focus_input()


func _on_mission_started(m: Dictionary) -> void:
	_mentor_log.clear()
	var viz: Dictionary = m.get("lab", {}).get("viz", {})
	var ds := game.shell.world.get_dataset(viz.get("dataset", ""))
	if ds != null:
		_plot.show_dataset(ds, viz.get("x", ""), viz.get("y", ""))
	_refresh_all()


func _on_mission_completed(m: Dictionary, result: Dictionary, xp_gained: int) -> void:
	var trial := "Prueba de dominio superada: competencias dominadas." if result["trial_passed"] else "Sin prueba de dominio."
	_on_mentor("◆ Misión %s completada · +%d XP · maestría %d/100. %s" % [m["id"], xp_gained, result["score"], trial], "praise")
	var exercise: String = m.get("debrief", {}).get("exercise", "")
	if not exercise.is_empty():
		_on_mentor("🛠 Ahora, con tus manos: abre %s y haz que pasen sus tests (instrucciones en forja/ejercicios/README.md)." % exercise, "info")
	_refresh_all()


func _on_mentor(text: String, kind: String) -> void:
	var col: Color = MENTOR_COLORS.get(kind, RoninPalette.TEXT)
	var prefix := "◆ " if kind == "debrief" else ""
	_mentor_log.append_text("[color=%s]%s%s[/color]\n\n" % [_hex(col), prefix, _esc(text)])
	_refresh_mission()


func _on_sim_event(e: Dictionary) -> void:
	var d: Dictionary = e["data"]
	match e["name"]:
		"viz.scatter":
			_plot.show_dataset(game.shell.world.get_dataset(d["dataset"]), d["x"], d["y"])
		"model.predicted":
			var ds := game.shell.world.get_dataset(d["dataset"])
			if _plot.dataset != ds and ds != null:
				var axes := _plot.current_axes()
				if axes.size() == 2:
					_plot.show_dataset(ds, axes[0], axes[1])
			_plot.set_highlight(d["id"], PackedStringArray(d.get("neighbors", [])))
		"dataset.normalized":
			var axes := _plot.current_axes()
			if axes.size() == 2:
				_plot.show_dataset(game.shell.world.get_dataset(d["target"]), axes[0], axes[1])


static func _hex(c: Color) -> String:
	return c.to_html(false)


static func _esc(t: String) -> String:
	return t.replace("[", "[lb]")
