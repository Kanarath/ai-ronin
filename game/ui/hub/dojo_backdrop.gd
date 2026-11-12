class_name DojoBackdrop
extends Control
## Fondo del Dojo, detrás de todos los paneles: patrón seigaiha (青海波, las olas en abanico
## de los tejidos japoneses) casi imperceptible y, detrás de la barra superior, la silueta
## tenue de una luna creciente y un torii. Es estático: solo se redibuja al cambiar el tamaño.

const WAVE := Color("#2F4352")
const MOON := Color("#EFE6CF")
const RADIUS := 26.0

## Altura de la barra superior (la luna y el torii se dibujan dentro de esa franja).
var top_height := 40.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), RoninPalette.BG)
	_draw_seigaiha()
	_draw_top_scene()


## Filas de abanicos: cada uno tapa la mitad de abajo del anterior (círculo del color del
## fondo y tres arcos), así queda la escama de olas sin líneas que se crucen.
func _draw_seigaiha() -> void:
	var r := RADIUS
	var row := 0
	var y := -r
	while y < size.y + r:
		var x0 := r if row % 2 == 1 else 0.0
		var x := x0 - 2.0 * r
		while x < size.x + 2.0 * r:
			var c := Vector2(x, y)
			draw_circle(c, r, RoninPalette.BG)
			for k: float in [1.0, 0.72, 0.44]:
				draw_arc(c, r * k - 1.0, PI, TAU, 18, Color(WAVE, 0.85), 1.0, true)
			x += 2.0 * r
		y += r * 0.5
		row += 1


## Luna creciente y torii en silueta, muy tenues, hacia el centro de la barra superior.
func _draw_top_scene() -> void:
	var h := top_height
	var cx := size.x * 0.56
	var base := h - 2.0
	# Torii
	var th := h * 0.78
	var span := th * 0.9
	var col := Color("#B3322E", 0.3)
	for side: float in [-1.0, 1.0]:
		draw_rect(Rect2(cx + side * span * 0.42 - 1.5, base - th * 0.85, 3.0, th * 0.85), col)
	draw_rect(Rect2(cx - span * 0.6, base - th * 0.66, span * 1.2, 2.0), col)
	var beam := PackedVector2Array()
	for i in 13:
		var u := float(i) / 12.0 * 2.0 - 1.0
		beam.append(Vector2(cx + u * span * 0.72, base - th * 0.9 - 3.0 * u * u))
	draw_polyline(beam, col, 3.0, true)
	# Luna creciente: un círculo menos otro desplazado
	var mc := Vector2(cx + span * 1.6, h * 0.45)
	var mr := h * 0.28
	var pts := PackedVector2Array()
	for i in 25:
		var a := lerpf(-PI * 0.62, PI * 0.62, i / 24.0)
		pts.append(mc + Vector2(cos(a), sin(a)) * mr)
	for i in 25:
		var a := lerpf(PI * 0.5, -PI * 0.5, i / 24.0)
		pts.append(mc + Vector2(-mr * 0.25, 0) + Vector2(cos(a) * mr * 0.78, sin(a) * mr * 0.9))
	draw_colored_polygon(pts, Color(MOON, 0.22))
