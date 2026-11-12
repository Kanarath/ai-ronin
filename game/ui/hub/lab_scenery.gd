class_name LabScenery
extends CenterContainer
## Rincón del laboratorio: el sello del rōnin (hanko rojo con 浪人 en vertical y marco
## interior fino). Columna estrecha a la derecha, nunca detrás de un gráfico.

const RED := Color("#B3322E")
const PAPER := Color("#F4E9D8")


func _init() -> void:
	custom_minimum_size = Vector2(96, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	use_top_left = false


func _ready() -> void:
	var seal := PanelContainer.new()
	seal.tooltip_text = "浪人 (rōnin): samurái sin señor que sigue su propio camino"
	seal.mouse_filter = Control.MOUSE_FILTER_PASS
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(RED, 0.85)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(4)
	seal.add_theme_stylebox_override("panel", sb)
	var inner := PanelContainer.new()
	var ib := StyleBoxFlat.new()
	ib.bg_color = Color(0, 0, 0, 0)
	ib.border_color = Color(PAPER, 0.55)
	ib.set_border_width_all(1)
	ib.content_margin_left = 7
	ib.content_margin_right = 7
	ib.content_margin_top = 3
	ib.content_margin_bottom = 5
	inner.add_theme_stylebox_override("panel", ib)
	seal.add_child(inner)
	var l := Label.new()
	l.text = "浪\n人"
	l.add_theme_font_override("font", RoninFonts.jp(true))
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_constant_override("line_spacing", -6)
	l.add_theme_color_override("font_color", Color(PAPER, 0.95))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(l)
	add_child(seal)
