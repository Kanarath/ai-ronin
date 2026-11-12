class_name KatanaRule
extends Control
## Separador del título con forma de katana (tsuka, tsuba y hoja con su curva y su hamon),
## en la línea de «separadores inspirados en el filo de una katana» del diseño visual.

const STEEL := Color("#C9D3DB")
const WRAP := Color("#2B3440")


func _init() -> void:
	custom_minimum_size = Vector2(560, 18)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var y := size.y * 0.5
	var handle := 96.0
	var blade_len := size.x - handle - 12.0
	# Tsuka (empuñadura) con el trenzado en rombos
	draw_rect(Rect2(0, y - 4, handle, 8), WRAP)
	for i in 8:
		var x := 6.0 + i * 11.0
		draw_colored_polygon(PackedVector2Array([Vector2(x, y), Vector2(x + 5.5, y - 3.5), Vector2(x + 11, y), Vector2(x + 5.5, y + 3.5)]), RoninPalette.GOLD.darkened(0.45))
	# Tsuba (guarda)
	draw_rect(Rect2(handle, y - 8, 5, 16), RoninPalette.GOLD)
	# Hoja: curva suave (sori) y punta (kissaki)
	var spine := PackedVector2Array()
	var edge := PackedVector2Array()
	var n := 40
	for i in n + 1:
		var u := float(i) / n
		var x := handle + 6.0 + u * blade_len
		var sori := -5.0 * u * u
		var w := 4.0 * (1.0 - 0.25 * u)
		spine.append(Vector2(x, y + sori - w * 0.5))
		edge.append(Vector2(x, y + sori + w * 0.5))
	var tip := Vector2(handle + 6.0 + blade_len + 10.0, y - 7.0)
	var poly := spine.duplicate()
	poly.append(tip)
	var rev := edge.duplicate()
	rev.reverse()
	poly.append_array(rev)
	draw_colored_polygon(poly, Color(STEEL, 0.75))
	# Hamon: la línea ondulada del temple, cerca del filo
	var hamon := PackedVector2Array()
	for i in n + 1:
		var u := float(i) / n
		hamon.append(edge[i] + Vector2(0, -1.2 - 0.6 * sin(u * 38.0)))
	draw_polyline(hamon, Color(RoninPalette.GOLD, 0.55), 1.0, true)
