class_name Toaster
extends VBoxContainer
## Notificaciones flotantes (XP, logros, subidas de nivel). Aparecen con un fundido, se quedan
## unos segundos y desaparecen. No bloquean el ratón. Las de XP se AGRUPAN en una sola que va
## sumando, para no tapar la pantalla.

const LIFETIME := 3.5

var _xp_label: Label = null
var _xp_panel: PanelContainer = null
var _xp_total: int = 0
var _xp_tween: Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 6)


func xp(amount: int, reason: String) -> void:
	if _xp_panel != null and is_instance_valid(_xp_panel):
		_xp_total += amount
		_xp_label.text = "+%d XP · %s" % [_xp_total, reason]
		_xp_tween.kill()
		_xp_panel.modulate.a = 1.0
		_xp_tween = _fade(_xp_panel, false)
		return
	_xp_total = amount
	_xp_panel = _make("+%d XP · %s" % [amount, reason], RoninPalette.GOLD, false)
	_xp_label = _xp_panel.get_child(0)
	_xp_tween = _fade(_xp_panel, false)


## big = true para celebraciones (logros, nivel): más grande y más tiempo en pantalla.
func toast(text: String, color: Color, big: bool = false) -> void:
	var panel := _make(text, color, big)
	_fade(panel, big)


func _make(text: String, color: Color, big: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = RoninPalette.PANEL_ALT
	style.border_color = color
	style.set_border_width_all(2 if big else 1)
	style.set_content_margin_all(14 if big else 8)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 18 if big else 14)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(300, 0)
	panel.add_child(label)
	add_child(panel)
	return panel


func _fade(panel: PanelContainer, big: bool) -> Tween:
	panel.modulate.a = 0.0 if panel.modulate.a < 1.0 else 1.0
	var tw := create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.2)
	tw.tween_interval(LIFETIME * (1.6 if big else 1.0))
	tw.tween_property(panel, "modulate:a", 0.0, 0.4)
	tw.tween_callback(panel.queue_free)
	return tw
