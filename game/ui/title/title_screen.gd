extends Control
## Pantalla de título: Jugar (tres ranuras de guardado) · Opciones · Acerca de · Salir.
## Se ve al arrancar (con la intro, una vez por sesión) y al volver desde el Dojo con «⏏ Menú».
## Las opciones son de todo el juego (GameSettings, comunes a las ranuras): las mismas que
## cambian los comandos «ajustes» y «efectos» de la consola. Se guardan y aplican al momento.

const HUB_SCENE := "res://ui/hub/hub_screen.tscn"
const EFFECTS := [["off", "Desactivado"], ["lento", "Lento"], ["normal", "Normal"], ["rapido", "Rápido"]]
const LETTERS := [["pequena", "Pequeña"], ["normal", "Normal"], ["grande", "Grande"], ["enorme", "Enorme"]]

var _backdrop: TitleBackdrop
var _column: VBoxContainer
var _menu: VBoxContainer
var _caption: Label
var _dialog_layer: Control
var _dialog: PanelContainer
var _sfx: Sfx
var _leaving := false


func _ready() -> void:
	_sfx = Sfx.new()
	add_child(_sfx)
	_sfx.set_from_settings(_prefs())
	_build()
	_fill_menu()
	var s := _prefs()
	var reduced := bool(s.get("movimiento_reducido", false))
	if not Dojo.intro_played and bool(s.get("intro", true)) and not reduced:
		Dojo.intro_played = true
		_column.modulate.a = 0.0
		var intro := IntroOverlay.new()
		intro.sfx = _sfx
		add_child(intro)
		intro.finished.connect(_reveal)
	else:
		Dojo.intro_played = true
		_reveal()


func _reveal() -> void:
	if bool(_prefs().get("movimiento_reducido", false)):
		_column.modulate.a = 1.0
	else:
		_column.modulate.a = 0.0
		_column.position.x -= 24.0
		var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(_column, "modulate:a", 1.0, 0.6)
		tw.tween_property(_column, "position:x", _column.position.x + 24.0, 0.6)
	_focus_first()


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel") and _dialog_layer.visible:
		_close_dialog()
		get_viewport().set_input_as_handled()


# ── Construcción ─────────────────────────────────────────────────────────────

func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop = TitleBackdrop.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.reduced_motion = bool(_prefs().get("movimiento_reducido", false))
	add_child(_backdrop)

	# Sombra a la izquierda para que el menú se lea bien sobre el paisaje
	var shade := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(RoninPalette.BG, 0.92))
	grad.set_color(1, Color(RoninPalette.BG, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_to = Vector2(1, 0)
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	shade.offset_right = 900
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	add_child(_cartouche())

	_column = VBoxContainer.new()
	_column.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_column.offset_left = 120
	_column.offset_right = 760
	_column.alignment = BoxContainer.ALIGNMENT_CENTER
	_column.add_theme_constant_override("separation", 10)
	add_child(_column)

	var kicker := HBoxContainer.new()
	kicker.add_theme_constant_override("separation", 12)
	kicker.add_child(_hanko("道", 34))
	kicker.add_child(_label("EL CAMINO DE LA INGENIERÍA Y LA SEGURIDAD DE IA", 15, RoninPalette.MUTED))
	kicker.get_child(1).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_column.add_child(kicker)

	var title := HBoxContainer.new()
	title.add_theme_constant_override("separation", 22)
	title.add_child(_label("AI", 96, RoninPalette.TEXT))
	title.add_child(_label("RONIN", 96, RoninPalette.GOLD))
	_column.add_child(title)
	_column.add_child(KatanaRule.new())
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 18)
	_column.add_child(spacer)

	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 4)
	_column.add_child(_menu)

	var foot := _label("v%s · Dojo offline: sin red y sin acceso a tu sistema    ↑ ↓ elegir · Intro aceptar · Esc volver" % ProjectSettings.get_setting("application/config/version", "?"), 13, RoninPalette.MUTED)
	foot.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	foot.offset_left = 120
	foot.offset_top = -44
	foot.offset_bottom = -20
	foot.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(foot)

	var player := MiniPlayer.new(Dojo.music)
	player.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	player.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	player.grow_vertical = Control.GROW_DIRECTION_BEGIN
	player.offset_right = -40
	player.offset_bottom = -16
	add_child(player)

	_dialog_layer = Control.new()
	_dialog_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dialog_layer.visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dialog_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dialog_layer.add_child(center)
	_dialog = PanelContainer.new()
	_dialog.custom_minimum_size = Vector2(620, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(RoninPalette.PANEL, 0.97)
	sb.border_color = RoninPalette.GOLD.darkened(0.35)
	sb.set_border_width_all(1)
	sb.border_width_top = 3
	sb.set_content_margin_all(28)
	_dialog.add_theme_stylebox_override("panel", sb)
	center.add_child(_dialog)
	add_child(_dialog_layer)


func _fill_menu() -> void:
	for c in _menu.get_children():
		c.queue_free()
	_menu.add_child(_item("Jugar", _show_slots))
	var last := int(_prefs().get("ultima_ranura", 0))
	var info := SaveSlots.info(last) if last > 0 else {}
	if not info.is_empty():
		_caption = _label("      Última: ranura %d · %s %s · nivel %d · %d misiones" % [last, info["rank"]["kanji"], info["rank"]["es"], info["level"], info["completed"]], 15, RoninPalette.MUTED)
		_menu.add_child(_caption)
	_menu.add_child(_item("Opciones", _show_options))
	_menu.add_child(_item("Acerca de", _show_about))
	_menu.add_child(_item("Salir", _quit))


func _focus_first() -> void:
	if _dialog_layer.visible:
		return
	for c in _menu.get_children():
		if c is Button and not c.is_queued_for_deletion() and c.focus_mode != Control.FOCUS_NONE:
			c.grab_focus()
			return


## Opción del menú: texto grande, sin caja; al enfocarla (teclado o ratón) aparece la marca.
func _item(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = "   " + text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 28)
	b.add_theme_color_override("font_color", RoninPalette.TEXT)
	b.add_theme_color_override("font_hover_color", RoninPalette.GOLD)
	b.add_theme_color_override("font_focus_color", RoninPalette.GOLD)
	b.add_theme_color_override("font_pressed_color", RoninPalette.CYAN)
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, empty)
	b.custom_minimum_size = Vector2(420, 0)
	b.focus_entered.connect(func() -> void:
		b.text = "▸  " + text
		_sfx.play("menu"))
	b.focus_exited.connect(func() -> void: b.text = "   " + text)
	b.mouse_entered.connect(b.grab_focus)
	b.pressed.connect(action)
	return b


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


## Sello rojo (hanko) con un kanji.
func _hanko(kanji: String, side: int) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#B3322E")
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(2)
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(side, side)
	var l := _label(kanji, int(side * 0.62), Color("#F4E9D8"))
	l.add_theme_font_override("font", RoninFonts.jp(true))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


## Cartela vertical en la esquina, como el título de un grabado: 浪人 sobre papel.
func _cartouche() -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#E9DFC8", 0.9)
	sb.border_color = Color("#8E2A2A")
	sb.set_border_width_all(2)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	p.add_theme_stylebox_override("panel", sb)
	var l := _label("浪\n人", 44, Color("#1A1A1A"))
	l.add_theme_font_override("font", RoninFonts.jp(true))
	l.add_theme_constant_override("line_spacing", -4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	p.offset_left = -150
	p.offset_right = -84
	p.offset_top = 60
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	p.tooltip_text = "浪人 (rōnin): samurái sin señor que sigue su propio camino"
	return p


# ── Acciones ─────────────────────────────────────────────────────────────────

func _go_to_hub() -> void:
	if _leaving:
		return
	_leaving = true
	Dojo.game.save()
	if bool(_prefs().get("movimiento_reducido", false)) or not is_inside_tree():
		get_tree().change_scene_to_file(HUB_SCENE)
		return
	var veil := ColorRect.new()
	veil.color = Color(RoninPalette.BG, 0.0)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(veil)
	var tw := create_tween()
	tw.tween_property(veil, "color:a", 1.0, 0.35)
	tw.tween_callback(func() -> void: get_tree().change_scene_to_file(HUB_SCENE))


## Las tres ranuras de guardado, como en un videojuego: jugar, empezar en una vacía o borrar.
func _show_slots() -> void:
	var box := _dialog_box("PARTIDAS")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	var first: Control = null
	for n in range(1, SaveSlots.COUNT + 1):
		var b := _slot_card(row, n)
		if first == null or n == int(_prefs().get("ultima_ranura", 0)):
			first = b
	var hint := _label("Las opciones (sonido, música, letra…) son comunes a las tres ranuras.", 13, RoninPalette.MUTED)
	box.add_child(hint)
	var bottom := _buttons_row(box)
	bottom.add_child(_dialog_button("Volver", _close_dialog))
	_dialog.custom_minimum_size = Vector2(900, 0)
	_open_dialog(first)


## Tarjeta de una ranura. Devuelve su botón principal (para el foco).
func _slot_card(row: HBoxContainer, n: int) -> Button:
	var info := SaveSlots.info(n)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(270, 250)
	var sb := StyleBoxFlat.new()
	sb.bg_color = RoninPalette.PANEL_ALT
	sb.border_color = RoninPalette.GOLD.darkened(0.3) if not info.is_empty() else RoninPalette.LINE
	sb.set_border_width_all(1)
	sb.set_content_margin_all(18)
	card.add_theme_stylebox_override("panel", sb)
	row.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	v.add_child(_label("RANURA %d" % n, 14, RoninPalette.MUTED))
	var main: Button
	if info.is_empty():
		var empty := _label("— vacía —", 22, RoninPalette.MUTED)
		empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		v.add_child(empty)
		main = _dialog_button("Empezar aquí", func() -> void: _play_slot(n))
		v.add_child(main)
	else:
		var rk: Dictionary = info["rank"]
		var kanji := _label(str(rk["kanji"]), 40, RoninPalette.GOLD)
		kanji.add_theme_font_override("font", RoninFonts.jp(true))
		v.add_child(kanji)
		v.add_child(_label("%s · nivel %d" % [str(rk["es"]).capitalize(), info["level"]], 17, RoninPalette.TEXT))
		v.add_child(_label("%d de %d misiones · %d XP" % [info["completed"], _total_missions(), info["xp"]], 14, RoninPalette.MUTED))
		if not str(info["last_mission"]).is_empty():
			v.add_child(_label("Última misión: %s" % info["last_mission"], 14, RoninPalette.MUTED))
		v.add_child(_label("Guardado: %s" % str(info["saved_at"]).replace("T", " "), 13, RoninPalette.MUTED))
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		v.add_child(spacer)
		var buttons := HBoxContainer.new()
		buttons.add_theme_constant_override("separation", 8)
		v.add_child(buttons)
		main = _dialog_button("Jugar", func() -> void: _play_slot(n))
		buttons.add_child(main)
		var del := _dialog_button("Borrar", func() -> void: _ask_delete(n))
		del.add_theme_color_override("font_hover_color", RoninPalette.RED)
		del.add_theme_color_override("font_focus_color", RoninPalette.RED)
		buttons.add_child(del)
	return main


func _play_slot(n: int) -> void:
	Dojo.open_slot(n)
	_dialog_layer.visible = false
	_go_to_hub()


func _ask_delete(n: int) -> void:
	var info := SaveSlots.info(n)
	var box := _dialog_box("BORRAR LA RANURA %d" % n)
	var t := _label("Se borrará la partida de la ranura %d (%s %s, nivel %d, %d misiones completadas) y su copia de seguridad.\n\nNo se puede deshacer." % [n, info["rank"]["kanji"], info["rank"]["es"], info["level"], info["completed"]], 17, RoninPalette.TEXT)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(560, 0)
	box.add_child(t)
	var row := _buttons_row(box)
	row.add_child(_dialog_button("Cancelar", _show_slots))
	var yes := _dialog_button("Sí, borrar", func() -> void:
		Dojo.delete_slot(n)
		if int(_prefs().get("ultima_ranura", 0)) == n:
			_prefs().erase("ultima_ranura")
			Dojo.prefs.save()
		_show_slots())
	yes.add_theme_color_override("font_color", RoninPalette.RED)
	row.add_child(yes)
	_dialog.custom_minimum_size = Vector2(620, 0)
	_open_dialog(row.get_child(0))


func _total_missions() -> int:
	return Dojo.game.catalog.ids().size()


func _show_options() -> void:
	var box := _dialog_box("OPCIONES")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 12)
	box.add_child(grid)
	var s := _prefs()

	var first := _toggle(grid, "Sonido", "Notas suaves al avanzar y en el menú.", bool(s.get("sonido", true)), func(on: bool) -> void:
		_save_setting("sonido", on)
		_sfx.enabled = on
		_sfx.play("paso"))

	var kvol := HSlider.new()
	kvol.min_value = 0
	kvol.max_value = 100
	kvol.step = 5
	kvol.value = int(s.get("teclas_volumen", 60))
	kvol.custom_minimum_size = Vector2(220, 0)
	kvol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var kl := _label("%d %%" % int(kvol.value), 15, RoninPalette.MUTED)
	kvol.value_changed.connect(func(v: float) -> void:
		kl.text = "%d %%" % int(v) if v > 0 else "apagado"
		_save_setting("teclas_volumen", int(v))
		_sfx.keys_volume = int(v)
		_sfx.key(KEY_A + randi() % 20))
	var krow := HBoxContainer.new()
	krow.add_child(kvol)
	krow.add_child(kl)
	_row(grid, "Sonido de teclas", "Un toque suave al escribir; se atenúa si escribes rápido. 0 = apagado.", krow)

	var vol := HSlider.new()
	vol.min_value = 0
	vol.max_value = 100
	vol.step = 5
	vol.value = int(s.get("volumen", 80))
	vol.custom_minimum_size = Vector2(220, 0)
	vol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var vl := _label("%d %%" % int(vol.value), 15, RoninPalette.MUTED)
	vol.value_changed.connect(func(v: float) -> void:
		vl.text = "%d %%" % int(v)
		_save_setting("volumen", int(v))
		_sfx.volume = int(v))
	vol.drag_ended.connect(func(_c: bool) -> void: _sfx.play("paso"))
	var vrow := HBoxContainer.new()
	vrow.add_child(vol)
	vrow.add_child(vl)
	_row(grid, "Volumen de los efectos", "", vrow)

	_toggle(grid, "Música", "Lo-fi japonés generado por el juego. También en el mini reproductor.", Dojo.music != null and Dojo.music.playing, func(on: bool) -> void:
		if Dojo.music != null:
			if on:
				Dojo.music.play()
			else:
				Dojo.music.pause())
	var mvol := HSlider.new()
	mvol.min_value = 0
	mvol.max_value = 100
	mvol.step = 5
	mvol.value = Dojo.music.volume if Dojo.music != null else 35
	mvol.custom_minimum_size = Vector2(220, 0)
	mvol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ml := _label("%d %%" % int(mvol.value), 15, RoninPalette.MUTED)
	mvol.value_changed.connect(func(v: float) -> void:
		ml.text = "%d %%" % int(v)
		if Dojo.music != null:
			Dojo.music.set_volume(int(v)))
	var mrow := HBoxContainer.new()
	mrow.add_child(mvol)
	mrow.add_child(ml)
	_row(grid, "Volumen de la música", "", mrow)

	var fx := OptionButton.new()
	for e: Array in EFFECTS:
		fx.add_item(e[1])
	var cur_fx := "off" if not bool(s.get("efectos", true)) else str(s.get("velocidad", "normal"))
	fx.select(maxi(0, EFFECTS.map(func(e: Array) -> String: return e[0]).find(cur_fx)))
	fx.item_selected.connect(func(i: int) -> void:
		var key: String = EFFECTS[i][0]
		_save_setting("efectos", key != "off")
		if key != "off":
			_save_setting("velocidad", key))
	_row(grid, "Efecto de escritura", "El texto de la consola aparece letra a letra.", fx)

	var lt := OptionButton.new()
	for e: Array in LETTERS:
		lt.add_item(e[1])
	lt.select(maxi(0, LETTERS.map(func(e: Array) -> String: return e[0]).find(str(s.get("letra", "normal")))))
	lt.item_selected.connect(func(i: int) -> void: _save_setting("letra", LETTERS[i][0]))
	_row(grid, "Tamaño de letra", "Consola, editor de Python y panel de misión.", lt)

	_toggle(grid, "Movimiento reducido", "Sin intro, sin pétalos y sin transiciones.", bool(s.get("movimiento_reducido", false)), func(on: bool) -> void:
		_save_setting("movimiento_reducido", on)
		_backdrop.reduced_motion = on)
	_toggle(grid, "Intro al arrancar", "El ensō y el tajo de katana (se salta con cualquier tecla).", bool(s.get("intro", true)), func(on: bool) -> void:
		_save_setting("intro", on))
	_toggle(grid, "Pantalla completa", "", bool(s.get("pantalla_completa", true)), func(on: bool) -> void:
		_save_setting("pantalla_completa", on)
		Dojo.apply_display())

	var note := _label("También puedes cambiarlas desde la consola del Dojo: ajustes sonido, ajustes letra, efectos.", 13, RoninPalette.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(560, 0)
	box.add_child(note)
	var row := _buttons_row(box)
	row.add_child(_dialog_button("Volver", _close_dialog))
	_open_dialog(first)


func _show_about() -> void:
	var box := _dialog_box("ACERCA DE AI RONIN")
	var t := RichTextLabel.new()
	t.bbcode_enabled = true
	t.fit_content = false
	t.scroll_active = true
	t.custom_minimum_size = Vector2(620, 420)
	t.focus_mode = Control.FOCUS_ALL
	var j := "[color=#%s]" % RoninPalette.GOLD.to_html(false)
	t.text = ("Academia offline de ingeniería y seguridad de IA. El Dojo es un laboratorio simulado: no usa la red ni ejecuta nada en tu equipo. La Forja (forja/) tiene los ejercicios y laboratorios reales en Python.\n\n"
		+ "[b]Lo japonés que verás[/b]\n"
		+ j + "浪人[/color] [i]rōnin[/i]: samurái sin señor; aquí, quien aprende por su cuenta y sigue su propio camino.\n"
		+ j + "道[/color] [i]dō[/i]: «camino», como en budō o kendō: una disciplina que se practica.\n"
		+ j + "円相[/color] [i]ensō[/i]: círculo zen pintado de un solo trazo; se acepta imperfecto.\n"
		+ j + "鳥居[/color] [i]torii[/i]: el arco que marca la entrada a un santuario sintoísta.\n"
		+ j + "桜[/color] [i]sakura[/i]: flor del cerezo.\n"
		+ "Los rangos usan 入門 (iniciado), 弟子 (aprendiz), 技師 (ingeniero), 専門家 (especialista) y 師範 (maestro).\n\n"
		+ "[b]Créditos y licencias[/b]\nFondos, intro y sonidos generados por código (sin imágenes ni grabaciones). Fuentes del sistema.\n"
		+ "Hecho con Godot Engine (licencia MIT):\n[color=#%s][font_size=12]%s[/font_size][/color]" % [RoninPalette.MUTED.to_html(false), Engine.get_license_text()])
	box.add_child(t)
	var row := _buttons_row(box)
	row.add_child(_dialog_button("Volver", _close_dialog))
	_open_dialog(row.get_child(0))


func _quit() -> void:
	if Dojo.slot > 0:
		Dojo.game.save()
	Dojo.prefs.save()
	get_tree().quit()


# ── Diálogos ─────────────────────────────────────────────────────────────────

func _dialog_box(title_text: String) -> VBoxContainer:
	for c in _dialog.get_children():
		_dialog.remove_child(c)
		c.queue_free()
	_dialog.custom_minimum_size = Vector2(620, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	_dialog.add_child(box)
	box.add_child(_label(title_text, 20, RoninPalette.GOLD))
	return box


func _buttons_row(box: VBoxContainer) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	return row


func _dialog_button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = "  %s  " % text
	b.add_theme_font_size_override("font_size", 17)
	b.pressed.connect(action)
	return b


func _row(grid: GridContainer, text: String, hint: String, control: Control) -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.add_child(_label(text, 17, RoninPalette.TEXT))
	if not hint.is_empty():
		var h := _label(hint, 12, RoninPalette.MUTED)
		h.custom_minimum_size = Vector2(300, 0)
		h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(h)
	grid.add_child(v)
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_child(control)


func _toggle(grid: GridContainer, text: String, hint: String, on: bool, changed: Callable) -> CheckButton:
	var c := CheckButton.new()
	c.button_pressed = on
	c.text = "Sí" if on else "No"
	c.toggled.connect(func(v: bool) -> void:
		c.text = "Sí" if v else "No"
		changed.call(v))
	_row(grid, text, hint, c)
	return c


func _open_dialog(focus: Control) -> void:
	_dialog_layer.visible = true
	# Con el diálogo abierto, las flechas no pueden saltar al menú de detrás.
	for c in _menu.get_children():
		if c is Control:
			c.focus_mode = Control.FOCUS_NONE
	if focus != null:
		focus.grab_focus.call_deferred()


func _close_dialog() -> void:
	_dialog_layer.visible = false
	_fill_menu()
	_focus_first.call_deferred()


## Cambia una preferencia y la guarda (el Dojo la lee al entrar).
func _save_setting(key: String, value: Variant) -> void:
	_prefs()[key] = value
	Dojo.prefs.save()


func _prefs() -> Dictionary:
	return Dojo.prefs.data
