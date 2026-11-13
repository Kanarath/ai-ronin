extends Control
## Hub del laboratorio: misiones (plegables) · laboratorio (visualización) · objetivo actual · consola.
## RONIN, el mentor, habla dentro de la consola.
## Solo presenta: toda la lógica está en DojoGame (autoload Dojo).

## Títulos de las unidades. Las que tienen misiones en el catálogo aparecen activas;
## el resto se muestra como «próximamente».
const UNIT_TITLES := {
	"T0": "T0 · Primeros pasos",
	"T1": "T1 · Datos y vectores", "T2": "T2 · Aprender de datos", "T3": "T3 · Optimización y métricas", "T7": "T7 · Árboles, bosques y grupos",
	"T4": "T4 · Redes neuronales", "T8": "T8 · Cómo ve una máquina", "T5": "T5 · Del texto al vector", "T6": "T6 · Transformers y LLM", "T9": "T9 · Cómo aprende un LLM", "T10": "T10 · Datos justos",
	"P0": "P0 · Python para IA (Forja)",
	"P1": "P1 · Construir con LLM",
	"P2": "P2 · Evals y observabilidad",
	"A1": "A1 · Aplicación LLM", "A2": "A2 · RAG y embeddings", "A3": "A3 · Agentes", "A4": "A4 · MCP",
	"A5": "A5 · Multiagente y A2A", "A6": "A6 · Supply chain e infra", "A7": "A7 · Navegador y ordenador",
	"O1": "O1 · Mentalidad red team", "O2": "O2 · Reconocimiento", "O3": "O3 · Threat modeling", "O4": "O4 · Impacto e informes",
	"O5": "O5 · Marcos y gobernanza",
	"O6": "O6 · Detección y respuesta",
	"O7": "O7 · Riesgos agénticos (OWASP)",
	"E2": "E2 · ML adversarial",
	"C1": "C1 · AI Agent Lab", "C2": "C2 · RAG Security Lab", "C3": "C3 · MCP Security Lab",
	"C4": "C4 · Multi-Agent Red Team Lab",
	"C5": "C5 · AI Red Team Assessment",
	"E1": "E1 · Investigación ML (Forja)",
	"E3": "E3 · Gobernanza y auditoría",
	"E4": "E4 · AI Ops avanzado",
	"E5": "E5 · Auditor ISO/IEC 42001",
}
## Parte de la altura de la ventana que ocupa el laboratorio (el resto es de la consola).
## La consola ocupa el resto (unos dos tercios); el laboratorio se puede plegar del todo.
const LAB_FRACTION := 0.2
const TOP_BAR_HEIGHT := 34.0
const SERIES_COLORS: Array[Color] = [RoninPalette.CYAN, RoninPalette.GOLD, RoninPalette.TEAL, RoninPalette.VIOLET, RoninPalette.TEXT]

var game: DojoGame
var _terminal: TerminalView
var _plot: ScatterPlot
var _chart: LineChart
var _net_view: NetworkGraph
var _heatmap: AttentionHeatmap
var _code: CodeEdit
var _curriculum_box: VBoxContainer
var _mission_text: RichTextLabel
var _left: PanelContainer
var _left_toggle: Button
var _xp_label: Label
var _xp_bar: ProgressBar
var _toaster: Toaster
var _lab: PanelContainer
var _lab_content: VBoxContainer
var _mission_label: Label
var _pending_xp: int = 0
var _sfx: Sfx
var _enso: EnsoMark
var _lab_body: Control
var _lab_chevron: Button
## Historial de rondas de seguridad (A1): tasa de éxito de ataques y de eval.
var _attack_history := PackedVector2Array()
var _eval_history := PackedVector2Array()


func _ready() -> void:
	game = Dojo.game
	_build_layout()
	_sfx = Sfx.new()
	add_child(_sfx)
	_sfx.set_from_settings(game.settings())
	var letra := str(game.settings().get("letra", "normal"))
	if letra != "normal" and CoreCommands.FONT_SIZES.has(letra):
		_apply_font_size(int(CoreCommands.FONT_SIZES[letra]))
	game.mission_started.connect(_on_mission_started)
	game.mission_completed.connect(_on_mission_completed)
	game.runner.mentor_message.connect(_on_mentor)
	game.runner.state_changed.connect(_refresh_mission)
	game.shell.event_emitted.connect(_on_sim_event)
	game.runner.xp_awarded.connect(func(amount: int, reason: String) -> void:
		_pending_xp += amount
		_toaster.xp(amount, reason)
		_refresh_top())
	game.achievement_unlocked.connect(func(a: Dictionary) -> void:
		_sfx.play("sello")
		_toaster.toast("%s  SELLO CONSEGUIDO\n%s\n%s" % [a["seal"], a["title"], a["description"]], RoninPalette.CYAN, true))
	game.level_up.connect(func(lv: int, rk: Dictionary) -> void:
		_sfx.play("nivel")
		_toaster.toast("⬆ NIVEL %d\nRango: %s %s (%s)" % [lv, rk["name"], rk["kanji"], rk["es"]], RoninPalette.GOLD, true))
	game.progress_changed.connect(func() -> void:
		_pending_xp = 0
		_refresh_top())
	_refresh_all()
	_fit_lab()
	_welcome()
	_terminal.focus_input()


## Altura fija del laboratorio y notificaciones en su esquina superior derecha.
func _fit_lab() -> void:
	if _lab == null:
		return
	# Mínimo 215 px: por debajo, el gráfico de dispersión no cabe y no se dibuja.
	var h := maxf(floorf(get_viewport_rect().size.y * LAB_FRACTION), 215.0)
	var folded := bool(game.settings().get("lab_plegado", false))
	_lab.custom_minimum_size.y = 0.0 if folded else h
	_toaster.max_height = maxf(h - 40.0, 200.0)
	_toaster.position = Vector2(get_viewport_rect().size.x - 360.0 - 16.0, TOP_BAR_HEIGHT + 22.0)


# ── Construcción de la interfaz ──────────────────────────────────────────────

func _build_layout() -> void:
	var backdrop := DojoBackdrop.new()
	backdrop.top_height = TOP_BAR_HEIGHT + 8.0
	add_child(backdrop)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	margin.add_child(root)

	# Barra superior estrecha: misiones · AI RONIN + sello · misión activa · XP · música · menú
	var top := HBoxContainer.new()
	top.custom_minimum_size.y = TOP_BAR_HEIGHT
	top.add_theme_constant_override("separation", 8)
	root.add_child(top)
	_left_toggle = Button.new()
	_left_toggle.text = "☰ Misiones"
	_left_toggle.flat = true
	_left_toggle.focus_mode = Control.FOCUS_NONE
	_left_toggle.tooltip_text = "Mostrar u ocultar la lista de misiones"
	_left_toggle.pressed.connect(func() -> void: _set_left_visible(not _left.visible))
	top.add_child(_left_toggle)
	var word := HBoxContainer.new()
	word.add_theme_constant_override("separation", 5)
	for part: Array in [["AI", RoninPalette.TEXT], ["RONIN", RoninPalette.GOLD]]:
		var l := Label.new()
		l.text = part[0]
		l.add_theme_color_override("font_color", part[1])
		l.add_theme_font_size_override("font_size", 16)
		word.add_child(l)
	word.add_child(_hanko("道", 20))
	top.add_child(word)
	_mission_label = Label.new()
	_mission_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mission_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mission_label.add_theme_color_override("font_color", RoninPalette.CYAN)
	top.add_child(_mission_label)
	_xp_label = Label.new()
	_xp_label.add_theme_color_override("font_color", RoninPalette.GOLD)
	_xp_label.add_theme_font_size_override("font_size", 14)
	top.add_child(_xp_label)
	_xp_bar = ProgressBar.new()
	_xp_bar.custom_minimum_size = Vector2(140, 10)
	_xp_bar.show_percentage = false
	_xp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bg := StyleBoxFlat.new()
	bg.bg_color = RoninPalette.PANEL_ALT
	var fill := StyleBoxFlat.new()
	fill.bg_color = RoninPalette.GOLD
	_xp_bar.add_theme_stylebox_override("background", bg)
	_xp_bar.add_theme_stylebox_override("fill", fill)
	top.add_child(_xp_bar)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(12, 0)
	top.add_child(spacer)
	if Dojo.music != null:
		top.add_child(MiniPlayer.new(Dojo.music, true))
	var menu := Button.new()
	menu.flat = true
	menu.text = "Menú"
	menu.tooltip_text = "Guardar y volver a la pantalla de título (opciones, nuevo aprendizaje)"
	menu.focus_mode = Control.FOCUS_NONE
	menu.pressed.connect(func() -> void:
		game.store_py_code()
		game.save()
		get_tree().change_scene_to_file("res://ui/title/title_screen.tscn"))
	top.add_child(menu)

	# Capa de notificaciones: encima de todo, en la esquina superior derecha del LABORATORIO
	# (nunca sobre la consola). _fit_lab la recoloca cuando cambia el tamaño de la ventana.
	_toaster = Toaster.new()
	_toaster.custom_minimum_size = Vector2(340, 0)
	add_child(_toaster)

	# Cuerpo: [misiones plegables] | laboratorio arriba · objetivo actual · consola grande.
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)
	root.add_child(body)

	_left = _panel("MISIONES", func() -> void: _set_left_visible(false), "‹")
	_left.custom_minimum_size = Vector2(270, 0)
	body.add_child(_left)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_left.get_child(0).add_child(scroll)
	_curriculum_box = VBoxContainer.new()
	_curriculum_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_curriculum_box)

	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 6)
	body.add_child(center)

	# El laboratorio tiene una altura FIJA (LAB_FRACTION de la ventana) y desplazamiento
	# interno: por muchos gráficos que enseñe, la consola conserva su sitio y su línea de entrada.
	_lab = _panel("LABORATORIO", _toggle_lab, "˄")
	_lab_chevron = _lab.get_meta("chevron")
	center.add_child(_lab)
	var lab_row := HBoxContainer.new()
	lab_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lab.get_child(0).add_child(lab_row)
	_lab_body = lab_row
	var lab_scroll := ScrollContainer.new()
	lab_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lab_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lab_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lab_row.add_child(lab_scroll)
	lab_row.add_child(LabScenery.new())
	_lab_content = VBoxContainer.new()
	_lab_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lab_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lab_content.add_theme_constant_override("separation", 6)
	lab_scroll.add_child(_lab_content)
	_plot = ScatterPlot.new()
	_plot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_plot.custom_minimum_size = Vector2(380, 140)
	_lab_content.add_child(_plot)
	_net_view = NetworkGraph.new()
	_net_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_net_view.custom_minimum_size = Vector2(380, 140)
	_net_view.visible = false
	_lab_content.add_child(_net_view)
	_heatmap = AttentionHeatmap.new()
	_heatmap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_heatmap.custom_minimum_size = Vector2(380, 160)
	_heatmap.visible = false
	_lab_content.add_child(_heatmap)
	_chart = LineChart.new()
	_chart.custom_minimum_size = Vector2(380, 130)
	_chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chart.size_flags_stretch_ratio = 0.8
	_chart.visible = false
	_lab_content.add_child(_chart)
	_code = _make_code_editor()
	_lab_content.add_child(_code)
	resized.connect(_fit_lab)

	var lower := VBoxContainer.new()
	lower.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lower.size_flags_stretch_ratio = 1.6
	lower.add_theme_constant_override("separation", 4)
	center.add_child(lower)

	# Franja del objetivo actual: qué misión, por dónde vas y qué te toca. Las respuestas se
	# escriben siempre en la consola (answer, hipotesis): no hay botones de respuesta.
	var strip := PanelContainer.new()
	lower.add_child(strip)
	var ss := StyleBoxFlat.new()
	ss.bg_color = Color(RoninPalette.PANEL, 0.78)
	ss.border_color = RoninPalette.LINE
	ss.set_border_width_all(1)
	ss.border_color = RoninPalette.LINE
	ss.content_margin_left = 10
	ss.content_margin_right = 8
	ss.content_margin_top = 4
	ss.content_margin_bottom = 4
	strip.add_theme_stylebox_override("panel", ss)
	# Una sola fila: el objetivo a la izquierda y los botones a la derecha (deja sitio a la consola).
	var sbox := HBoxContainer.new()
	sbox.add_theme_constant_override("separation", 8)
	strip.add_child(sbox)
	_mission_text = RichTextLabel.new()
	_mission_text.bbcode_enabled = true
	_mission_text.fit_content = true
	_mission_text.scroll_active = false
	_mission_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mission_text.add_theme_font_size_override("normal_font_size", 14)
	_mission_text.add_theme_font_size_override("bold_font_size", 14)
	sbox.add_child(_mission_text)
	var actions := HBoxContainer.new()
	actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sbox.add_child(actions)
	for spec in [["Pista", "hint"], ["Objetivos", "mission status"], ["Briefing", "mission brief"], ["Chuleta", "cheatsheet"]]:
		var b := Button.new()
		b.text = spec[0]
		b.add_theme_font_size_override("font_size", 13)
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = spec[1]
		var cmd: String = spec[1]
		b.pressed.connect(func() -> void: _run(cmd))
		actions.add_child(b)

	_terminal = TerminalView.new()
	_terminal.setup(game.shell)
	_terminal.effects = bool(game.settings().get("efectos", true))
	_terminal.speed = str(game.settings().get("velocidad", "normal"))
	_terminal.command_executed.connect(_on_command_action)
	_terminal.key_typed.connect(func(k: Key) -> void: _sfx.key(k))
	_terminal.custom_minimum_size = Vector2(0, 300)
	_terminal.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lower.add_child(_terminal)
	_apply_lab_folded(bool(game.settings().get("lab_plegado", false)))

	_enso = EnsoMark.new()
	_enso.reduced_motion = bool(game.settings().get("movimiento_reducido", false))
	_enso.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_enso.offset_left = -300
	_enso.offset_top = -300
	_enso.offset_right = 110
	_enso.offset_bottom = 110
	add_child(_enso)


## Panel con su franja de título (mayúsculas pequeñas y, si se puede plegar, una flecha);
## devuelve el PanelContainer (su hijo 0 es un VBoxContainer). El fondo es algo transparente
## para que se intuya el seigaiha de detrás.
func _panel(title_text: String, on_fold: Callable = Callable(), chevron: String = "") -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(RoninPalette.PANEL, 0.78)
	sb.border_color = RoninPalette.LINE
	sb.set_border_width_all(1)
	sb.set_content_margin_all(8)
	sb.content_margin_top = 0
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var head := PanelContainer.new()
	var hs := StyleBoxFlat.new()
	hs.bg_color = Color(RoninPalette.PANEL_ALT, 0.9)
	hs.border_color = RoninPalette.LINE
	hs.border_width_bottom = 1
	hs.content_margin_left = 8
	hs.content_margin_right = 4
	hs.expand_margin_left = 8
	hs.expand_margin_right = 8
	head.add_theme_stylebox_override("panel", hs)
	v.add_child(head)
	var row := HBoxContainer.new()
	head.add_child(row)
	var t := Label.new()
	t.text = title_text
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.add_theme_color_override("font_color", RoninPalette.MUTED)
	t.add_theme_font_size_override("font_size", 11)
	row.add_child(t)
	if on_fold.is_valid():
		var b := Button.new()
		b.text = chevron
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = "Plegar o desplegar"
		b.add_theme_font_size_override("font_size", 13)
		b.pressed.connect(on_fold)
		row.add_child(b)
		p.set_meta("chevron", b)
	return p


## Sello rojo (hanko) pequeño con un kanji.
func _hanko(kanji: String, side: int) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#B3322E")
	sb.set_corner_radius_all(2)
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(side, side)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := Label.new()
	l.text = kanji
	l.add_theme_font_override("font", RoninFonts.jp(true))
	l.add_theme_font_size_override("font_size", int(side * 0.62))
	l.add_theme_color_override("font_color", Color("#F4E9D8"))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


## Pliega o despliega el laboratorio (la consola se queda con el sitio). Se recuerda.
func _toggle_lab() -> void:
	var folded := not bool(game.settings().get("lab_plegado", false))
	game.settings()["lab_plegado"] = folded
	game.save_settings()
	_apply_lab_folded(folded)


func _apply_lab_folded(folded: bool) -> void:
	_lab_body.visible = not folded
	_lab_chevron.text = "˅" if folded else "˄"
	_lab.size_flags_vertical = Control.SIZE_FILL
	_fit_lab()


# ── Actualización ────────────────────────────────────────────────────────────

func _refresh_all() -> void:
	_refresh_top()
	_refresh_curriculum()
	_refresh_mission()


func _refresh_top() -> void:
	var p := game.progress
	var rk := p.rank()
	var lv := p.level()
	var pending := "  (+%d en curso)" % _pending_xp if _pending_xp > 0 else ""
	_xp_label.text = "%s %s · Nivel %d · %d XP%s  " % [rk["kanji"], rk["name"], lv, p.xp(), pending]
	_xp_bar.min_value = p.xp_for_level(lv)
	_xp_bar.max_value = p.xp_for_level(lv + 1)
	# La barra de XP se llena con una animación corta en lugar de saltar.
	if is_inside_tree() and _terminal != null and _terminal.effects and absf(_xp_bar.value - p.xp()) > 0.5:
		create_tween().tween_property(_xp_bar, "value", float(p.xp()), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		_xp_bar.value = p.xp()
	_xp_bar.tooltip_text = "%d / %d XP para el nivel %d" % [p.xp(), p.xp_for_level(lv + 1), lv + 1]
	var m := game.active_mission
	_mission_label.text = "" if m.is_empty() else "▶ %s · %s" % [m["id"], m["title"]]


func _refresh_curriculum() -> void:
	for c in _curriculum_box.get_children():
		c.queue_free()
	var active_units: Array[String] = []
	for m in game.catalog.missions:
		if not m["unit"] in active_units:
			active_units.append(m["unit"])
	for unit_id: String in active_units:
		var header := Label.new()
		header.text = UNIT_TITLES.get(unit_id, unit_id)
		header.add_theme_color_override("font_color", RoninPalette.CYAN)
		_curriculum_box.add_child(header)
		for m in game.catalog.missions:
			if m["unit"] != unit_id:
				continue
			var status := game.mission_status(m["id"])
			var icon: String = {"dominada": "◆", "completada": "✓", "en curso": "▶", "bloqueada": "🔒", "disponible": "·"}[status]
			var b := Button.new()
			b.text = "%s %s  %s" % [icon, m["id"], m["title"]]
			var ex := game.evidence.exercise_of_mission(m)
			if not ex.is_empty() and EvidenceImporter.is_verified(game.progress, ex):
				b.text += "  🛠"
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
		_add_studies(unit_id)
	var sep := Label.new()
	sep.text = "\nPRÓXIMAMENTE"
	sep.add_theme_color_override("font_color", RoninPalette.MUTED)
	sep.add_theme_font_size_override("font_size", 12)
	_curriculum_box.add_child(sep)
	for unit_id: String in UNIT_TITLES:
		if unit_id in active_units or not game.study.unit(unit_id).is_empty():
			continue
		var l := Label.new()
		l.text = "🔒 " + UNIT_TITLES[unit_id]
		l.add_theme_color_override("font_color", RoninPalette.LINE.lightened(0.3))
		_curriculum_box.add_child(l)


## Unidades de estudio externo colocadas en su sitio del temario: tras la unidad de su
## misión requisito, o tras la unidad de estudio de la que dependen.
func _add_studies(anchor: String) -> void:
	for u: Dictionary in game.study.units:
		if game.study.anchor_of(u, game.catalog) != anchor:
			continue
		var st := game.study.status(game.progress, u["id"])
		var b := Button.new()
		b.text = "%s %s  (estudio externo)" % [{"estudiada": "✓", "disponible": "📖", "bloqueada": "🔒"}[st], u["title"]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.flat = true
		b.tooltip_text = "Sin misión: se estudia con lecturas · %s · %s" % [st, u["temario"]]
		b.add_theme_color_override("font_color", RoninPalette.TEAL if st == "estudiada" else RoninPalette.VIOLET)
		var sid: String = u["id"]
		b.pressed.connect(func() -> void: _run("lecturas " + sid))
		_curriculum_box.add_child(b)
		_add_studies(sid)


var _last_index := -1
var _last_mission := ""


func _refresh_mission() -> void:
	_refresh_top()
	var r := game.runner
	# Destello breve del panel de misión cuando avanzas un objetivo.
	var mid := str(game.active_mission.get("id", ""))
	if mid == _last_mission and r.index > _last_index and _terminal != null and _terminal.effects:
		_sfx.play("paso")
		_mission_text.modulate = Color(1.6, 1.6, 1.6)
		create_tween().tween_property(_mission_text, "modulate", Color.WHITE, 0.5)
	_last_mission = mid
	_last_index = r.index
	var m := game.active_mission
	if m.is_empty():
		_mission_text.text = "[color=%s]Ninguna misión activa.[/color]\nÁbrela con [b]☰ Misiones[/b] o escribe [b]mission list[/b]." % _hex(RoninPalette.MUTED)
		return
	var lines := PackedStringArray()
	var phase_txt := "  [color=%s]· PRUEBA DE DOMINIO[/color]" % _hex(RoninPalette.GOLD) if r.phase == "trial" else ""
	if r.phase == "done":
		phase_txt = "  [color=%s]· COMPLETADA[/color]" % _hex(RoninPalette.TEAL)
	lines.append("[b]%s · %s[/b]%s" % [m["id"], _esc(m["title"]), phase_txt])
	# Progreso compacto (✓✓▶··) + solo el objetivo actual: la consola necesita el espacio.
	var marks := ""
	for i in r.objectives.size():
		if i < r.index or r.phase == "done":
			marks += "[color=%s]✓[/color] " % _hex(RoninPalette.TEAL)
		elif i == r.index:
			marks += "[color=%s]▶[/color] " % _hex(RoninPalette.CYAN)
		else:
			marks += "[color=%s]·[/color] " % _hex(RoninPalette.MUTED)
	# Título y progreso en la misma línea: la franja ocupa dos líneas en vez de tres.
	lines[0] += "     " + marks + "[color=%s] objetivo %d de %d[/color]" % [_hex(RoninPalette.MUTED), mini(r.index + 1, r.objectives.size()), r.objectives.size()]
	var current_obj := r.current_objective()
	if not current_obj.is_empty():
		lines.append(_esc(current_obj["text"]))
	elif r.phase == "done":
		lines.append("[color=%s]Misión completada. Repítela o elige la siguiente con ☰ Misiones.[/color]" % _hex(RoninPalette.TEAL))
	_mission_text.text = "\n".join(lines)


## Editor de Python del Dojo (CodeEdit con colores de Python). Vive en el panel del laboratorio.
func _make_code_editor() -> CodeEdit:
	var e := CodeEdit.new()
	e.visible = false
	e.size_flags_vertical = Control.SIZE_EXPAND_FILL
	e.custom_minimum_size = Vector2(380, 220)
	e.gutters_draw_line_numbers = true
	e.indent_automatic = true
	e.indent_use_spaces = true
	e.indent_size = 4
	e.auto_brace_completion_enabled = true
	e.add_theme_font_override("font", RoninFonts.mono())
	e.add_theme_font_size_override("font_size", 15)
	e.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventKey and ev.pressed and not ev.echo:
			_sfx.key(ev.keycode))
	var hl := CodeHighlighter.new()
	hl.number_color = RoninPalette.GOLD
	hl.symbol_color = RoninPalette.TEXT
	hl.function_color = RoninPalette.CYAN
	hl.member_variable_color = RoninPalette.TEXT
	for kw in ["def", "return", "if", "elif", "else", "for", "while", "in", "not", "and", "or", "break", "continue", "pass", "import", "from", "True", "False", "None"]:
		hl.add_keyword_color(kw, RoninPalette.VIOLET)
	for b in ["print", "len", "range", "min", "max", "sum", "abs", "round", "sorted", "int", "float", "str", "list", "dict", "enumerate", "zip"]:
		hl.add_keyword_color(b, RoninPalette.TEAL)
	hl.add_color_region("#", "", RoninPalette.MUTED, true)
	hl.add_color_region("\"", "\"", RoninPalette.GOLD)
	hl.add_color_region("'", "'", RoninPalette.GOLD)
	e.syntax_highlighter = hl
	e.text_changed.connect(func() -> void: game.py_code = _code.text)
	e.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventKey and ev.pressed and ev.keycode == KEY_ENTER and ev.ctrl_pressed:
			_code.accept_event()
			_run("py run")
			_code.grab_focus())
	return e


func _show_code(v: bool) -> void:
	_code.visible = v
	if v and bool(game.settings().get("lab_plegado", false)):
		_toggle_lab()  # el editor de Python vive en el laboratorio: se despliega solo
	if v:
		_plot.visible = false
		_net_view.visible = false
		_heatmap.visible = false
		_chart.visible = false
		if _code.text != game.py_code:
			_code.text = game.py_code
		_code.grab_focus()
		_scroll_code_to_mark.call_deferred()
	else:
		_show_plot()


## Al abrir el editor, la línea marcada con «←» (la que hay que cambiar) queda a la vista.
func _scroll_code_to_mark() -> void:
	for i in _code.get_line_count():
		if _code.get_line(i).contains("←"):
			_code.set_caret_line(i)
			_code.set_caret_column(_code.get_line(i).length() - _code.get_line(i).strip_edges(true, false).length())
			_code.set_line_as_center_visible(i)
			return


func _on_command_action(_line: String, result: CommandResult) -> void:
	match result.action:
		"py_open":
			_show_code(true)
		"py_close":
			_show_code(false)
			_terminal.focus_input()
		"sound_on":
			_sfx.enabled = true
			_sfx.play("paso")
		"sound_off":
			_sfx.enabled = false
		_:
			if result.action.begins_with("font_"):
				_apply_font_size(int(result.action.trim_prefix("font_")))


## Tamaño de letra elegido con «ajustes letra»: consola, editor de Python y panel de misión.
func _apply_font_size(n: int) -> void:
	_terminal.set_font_size(n)
	if _code != null:
		_code.add_theme_font_size_override("font_size", n + 1)
	_mission_text.add_theme_font_size_override("normal_font_size", n + 2)
	_mission_text.add_theme_font_size_override("bold_font_size", n + 2)


# ── Eventos ──────────────────────────────────────────────────────────────────

func _welcome() -> void:
	for step in ["› arrancando el Dojo… ok", "› laboratorio aislado: sin red, sin sistema… ok", "› RONIN en línea"]:
		_terminal.print_line(step, "muted")
	_terminal.print_line("AI RONIN v%s · Dojo offline: este terminal solo actúa sobre el laboratorio simulado." % ProjectSettings.get_setting("application/config/version", "?"), "accent")
	_terminal.print_line("Empieza con: mission list  ·  ayuda: help  ·  Tab autocompleta  ·  ↑↓ historial", "muted")
	if not game.load_warning.is_empty():
		_terminal.print_line(game.load_warning, "warn")
	_on_mentor("Soy RONIN, tu mentor. Te explicaré cada idea justo antes de usarla y, cuando la pruebes, te contaré qué ha pasado y por qué. Si es tu primera vez, empieza por T0-01. Abre la lista con «☰ Misiones» (arriba a la izquierda) o escribe mission list.", "info")


func _run(line: String) -> void:
	_terminal.run_command(line)
	_terminal.focus_input()


func _on_mission_started(m: Dictionary) -> void:
	_show_code(false)
	# Con una misión en marcha, la lista se pliega: la consola necesita el espacio.
	_set_left_visible(false)
	_chart.visible = false
	_attack_history.clear()
	_eval_history.clear()
	_show_plot()
	var viz: Dictionary = m.get("lab", {}).get("viz", {})
	var ds := game.shell.world.get_dataset(viz.get("dataset", ""))
	if ds != null:
		_plot.show_dataset(ds, viz.get("x", ""), viz.get("y", ""))
	else:
		_plot.clear()
	_refresh_all()


func _on_mission_completed(m: Dictionary, result: Dictionary, xp_gained: int) -> void:
	_sfx.play("mision")
	var trial := "Prueba de dominio superada: competencias dominadas." if result["trial_passed"] else "Sin prueba de dominio."
	_on_mentor("◆ Misión %s completada · +%d XP · maestría %d/100. %s" % [m["id"], xp_gained, result["score"], trial], "praise")
	# El aviso del ejercicio de la Forja lo da DojoGame (forja_message), solo si sigue pendiente.
	_refresh_all()


func _on_mentor(text: String, kind: String) -> void:
	if _enso != null:
		_enso.pulse()
	_terminal.print_mentor(text, kind)
	_refresh_mission()


func _set_left_visible(v: bool) -> void:
	_left.visible = v
	_left_toggle.text = "✕ Misiones" if v else "☰ Misiones"


func _on_sim_event(e: Dictionary) -> void:
	var d: Dictionary = e["data"]
	match e["name"]:
		"nn.created", "nn.trained", "nn.set", "nn.reset", "nn.inspected", "nn.evaluated":
			_show_net(d["network"], PackedFloat64Array())
			if e["name"] == "nn.trained":
				_show_nn_losses()
		"nn.forward":
			var vals := PackedFloat64Array()
			for s in String(d["input"]).split(","):
				vals.append(s.to_float())
			_show_net(d["network"], vals)
		"attention.computed":
			_plot.visible = false
			_net_view.visible = false
			_code.visible = false
			_chart.visible = false
			_heatmap.visible = true
			_heatmap.show_weights(String(d["words"]).split(" "), d["weights"], d["causal"])
		"viz.scatter":
			_show_plot()
			_plot.show_dataset(game.shell.world.get_dataset(d["dataset"]), d["x"], d["y"])
		"model.predicted":
			_show_plot()
			var ds := game.shell.world.get_dataset(d["dataset"])
			if _plot.dataset != ds and ds != null:
				var axes := _plot.current_axes()
				if axes.size() == 2:
					_plot.show_dataset(ds, axes[0], axes[1])
			_plot.set_highlight(d["id"], PackedStringArray(d.get("neighbors", [])))
		"bot.attacks", "bot.eval", "rag.attacks", "rag.eval", "agent.attacks", "agent.eval", "mcp.attacks", "mcp.eval", "a2a.attacks", "a2a.eval", "supply.attacks", "supply.eval":
			_show_security(e["name"], d)
		"regress.trained":
			_show_regression(d)
		"dataset.normalized":
			var axes := _plot.current_axes()
			if axes.size() == 2:
				_plot.show_dataset(game.shell.world.get_dataset(d["target"]), axes[0], axes[1])


func _show_security(event_name: String, d: Dictionary) -> void:
	var round_n := float(_attack_history.size() + _eval_history.size() + 1)
	if event_name.ends_with(".attacks"):
		_attack_history.append(Vector2(round_n, d["success_rate"]))
	else:
		_eval_history.append(Vector2(round_n, d["pass_rate"]))
	var series: Array[Dictionary] = []
	if not _attack_history.is_empty():
		series.append({"name": "ataques con éxito", "points": _attack_history, "color": RoninPalette.RED})
	if not _eval_history.is_empty():
		series.append({"name": "eval clientes", "points": _eval_history, "color": RoninPalette.TEAL})
	_plot.visible = false
	_net_view.visible = false
	_heatmap.visible = false
	_code.visible = false
	_chart.x_label = "ronda"
	_chart.set_series("Seguridad: tasa por ronda (0 = nada, 1 = todo)", series, false)
	_chart.visible = true


func _show_plot() -> void:
	if _code != null:
		_code.visible = false
	_plot.visible = true
	_net_view.visible = false
	_heatmap.visible = false


func _show_net(net_name: String, input: PackedFloat64Array) -> void:
	var net: MLP = game.shell.world.networks.get(net_name)
	if net == null:
		return
	_plot.visible = false
	_heatmap.visible = false
	_code.visible = false
	_net_view.visible = true
	# Las entradas se llaman como las features del dataset de entrenamiento; sin él, con dos
	# entradas, a y b (como en las lecciones de puertas lógicas).
	var names := PackedStringArray()
	var ds: Dataset = game.shell.world.get_dataset(net.trained_on) if net.trained_on != "" else null
	if ds != null and ds.feature_names.size() == net.inputs:
		names = ds.feature_names
	elif net.inputs == 2:
		names = PackedStringArray(["a", "b"])
	_net_view.show_network(net, net_name, input, names)


func _show_nn_losses() -> void:
	var series: Array[Dictionary] = []
	var i := 0
	for n in game.shell.world.names_of("network"):
		var net: MLP = game.shell.world.networks[n]
		if net.history.is_empty():
			continue
		var pts := PackedVector2Array()
		for h in net.history:
			pts.append(Vector2(h["epoch"], h["loss"]))
		series.append({"name": n, "points": pts, "color": SERIES_COLORS[i % SERIES_COLORS.size()]})
		i += 1
	_chart.set_series("Pérdida (entropía cruzada) por época", series)
	_chart.visible = true


func _show_regression(d: Dictionary) -> void:
	var series: Array[Dictionary] = []
	var names := game.shell.world.names_of("regressor")
	var i := 0
	for n in names:
		var m: LinearRegressionGD = game.shell.world.regressors[n]
		if m.history.is_empty():
			continue
		var pts := PackedVector2Array()
		for h in m.history:
			pts.append(Vector2(h["epoch"], h["loss"]))
		series.append({"name": "%s lr=%s" % [n, String.num(m.lr, 4)], "points": pts, "color": SERIES_COLORS[i % SERIES_COLORS.size()]})
		i += 1
	_chart.set_series("Pérdida (MSE) por época", series)
	_chart.visible = true
	var ds := game.shell.world.get_dataset(d["dataset"])
	if ds != null:
		_show_plot()
		_plot.show_dataset(ds, d["x"], d["y"])
		if not d["diverged"]:
			_plot.set_regression_line(d["w"], d["b"], d["x"], d["y"])


static func _hex(c: Color) -> String:
	return c.to_html(false)


static func _esc(t: String) -> String:
	return t.replace("[", "[lb]")
