class_name LineChart
extends Control
## Gráfico de líneas (p. ej. pérdida por época). Escala logarítmica opcional en Y.
## Los valores no finitos (divergencia) se dibujan recortados en el borde superior, en rojo.

var title: String = ""
var x_label: String = "época"
var y_label: String = "pérdida"
var log_y: bool = true
## Series: [{"name": String, "points": PackedVector2Array, "color": Color}]
var series: Array[Dictionary] = []


func set_series(p_title: String, p_series: Array[Dictionary], p_log_y: bool = true) -> void:
	title = p_title
	series = p_series
	log_y = p_log_y
	queue_redraw()


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var font := RoninFonts.mono()
	draw_rect(Rect2(Vector2.ZERO, size), RoninPalette.PANEL)
	if series.is_empty():
		return
	var plot := Rect2(64, 26, size.x - 88, size.y - 50)
	if plot.size.x < 40 or plot.size.y < 30:
		return
	var x_max := 1.0
	var y_min := INF
	var y_max := -INF
	for s in series:
		for p: Vector2 in s["points"]:
			x_max = maxf(x_max, p.x)
			if is_finite(p.y) and p.y < 1e12:
				var v := _ty(p.y)
				y_min = minf(y_min, v)
				y_max = maxf(y_max, v)
	if not is_finite(y_min):
		return
	if is_equal_approx(y_min, y_max):
		y_max = y_min + 1.0
	draw_rect(plot, RoninPalette.LINE, false)
	for i in 4:
		var t := i / 3.0
		var gy := plot.end.y - t * plot.size.y
		draw_line(Vector2(plot.position.x, gy), Vector2(plot.end.x, gy), RoninPalette.LINE)
		var raw := lerpf(y_min, y_max, t)
		var label := String.num(pow(10.0, raw), 2) if log_y else String.num(raw, 2)
		draw_string(font, Vector2(4, gy + 4), label, HORIZONTAL_ALIGNMENT_LEFT, 58, 11, RoninPalette.MUTED)
	draw_string(font, Vector2(plot.position.x, 16), title + ("  (escala log)" if log_y else ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, RoninPalette.TEXT)
	draw_string(font, Vector2(plot.end.x - 120, size.y - 6), "→ %s (máx %d)" % [x_label, int(x_max)], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, RoninPalette.MUTED)
	var legend_x := plot.end.x - 10.0
	for s in series:
		var pts := PackedVector2Array()
		var exploded := false
		for p: Vector2 in s["points"]:
			var finite := is_finite(p.y) and p.y < 1e12
			var vy := _ty(p.y) if finite else y_max
			exploded = exploded or not finite
			var py := plot.end.y - inverse_lerp(y_min, y_max, clampf(vy, y_min, y_max)) * plot.size.y
			pts.append(Vector2(plot.position.x + p.x / x_max * plot.size.x, py))
		var col: Color = RoninPalette.RED if exploded else s["color"]
		if pts.size() >= 2:
			draw_polyline(pts, col, 2.0, true)
		elif pts.size() == 1:
			draw_circle(pts[0], 3, col)
		legend_x -= 140
		draw_string(font, Vector2(legend_x, 16), "■ " + s["name"], HORIZONTAL_ALIGNMENT_LEFT, 130, 11, col)


func _ty(v: float) -> float:
	return log(maxf(v, 1e-9)) / log(10.0) if log_y else v
