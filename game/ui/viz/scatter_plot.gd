class_name ScatterPlot
extends Control
## Gráfico de dispersión de un dataset (dos features), coloreado por clase.
## Resalta el ejemplo consultado y sus vecinos cuando se usa model predict.

const MARGIN_LEFT := 64.0
const MARGIN_RIGHT := 24.0
const MARGIN_TOP := 44.0
const MARGIN_BOTTOM := 48.0
const CLASS_COLORS: Array[Color] = [RoninPalette.TEAL, RoninPalette.GOLD, RoninPalette.CYAN, RoninPalette.VIOLET]

var dataset: Dataset
var fx: int = 0
var fy: int = 1
var query_id: String = ""
var neighbor_ids: PackedStringArray = []
## Recta y = w·x + b superpuesta (regresión): {w, b, x, y} o vacío.
var regression_line: Dictionary = {}


func show_dataset(ds: Dataset, x_name: String, y_name: String) -> void:
	dataset = ds
	fx = maxi(ds.feature_index(x_name), 0)
	fy = maxi(ds.feature_index(y_name), 0)
	query_id = ""
	neighbor_ids = []
	regression_line = {}
	queue_redraw()


func current_axes() -> PackedStringArray:
	if dataset == null:
		return PackedStringArray()
	return PackedStringArray([dataset.feature_names[fx], dataset.feature_names[fy]])


func set_regression_line(w: float, b: float, x_name: String, y_name: String) -> void:
	regression_line = {"w": w, "b": b, "x": x_name, "y": y_name}
	queue_redraw()


func set_highlight(p_query: String, p_neighbors: PackedStringArray) -> void:
	query_id = p_query
	neighbor_ids = p_neighbors
	queue_redraw()


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var font := RoninFonts.mono()
	draw_rect(Rect2(Vector2.ZERO, size), RoninPalette.PANEL)
	if dataset == null or dataset.size() == 0:
		draw_string(font, Vector2(24, 40), "Laboratorio vacío · empieza una misión (mission list)", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, RoninPalette.MUTED)
		return
	var plot := Rect2(MARGIN_LEFT, MARGIN_TOP, size.x - MARGIN_LEFT - MARGIN_RIGHT, size.y - MARGIN_TOP - MARGIN_BOTTOM)
	if plot.size.x < 50 or plot.size.y < 50:
		return
	var xs := dataset.column(fx)
	var ys := dataset.column(fy)
	var xr := _range(xs)
	var yr := _range(ys)

	# Retícula y escalas
	for i in 5:
		var t := i / 4.0
		var gx := plot.position.x + t * plot.size.x
		var gy := plot.end.y - t * plot.size.y
		draw_line(Vector2(gx, plot.position.y), Vector2(gx, plot.end.y), RoninPalette.LINE)
		draw_line(Vector2(plot.position.x, gy), Vector2(plot.end.x, gy), RoninPalette.LINE)
		draw_string(font, Vector2(gx - 20, plot.end.y + 18), String.num(lerpf(xr.x, xr.y, t), 2), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, RoninPalette.MUTED)
		draw_string(font, Vector2(4, gy + 4), String.num(lerpf(yr.x, yr.y, t), 2), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, RoninPalette.MUTED)
	draw_rect(plot, RoninPalette.LINE, false)

	# Ejes y título
	draw_string(font, Vector2(plot.position.x + plot.size.x / 2 - 60, size.y - 10), "→ " + dataset.feature_names[fx], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, RoninPalette.TEXT)
	draw_string(font, Vector2(MARGIN_LEFT, 18), "↑ " + dataset.feature_names[fy], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, RoninPalette.TEXT)

	# Leyenda
	var classes := dataset.classes()
	var lx := plot.end.x - 220.0
	draw_string(font, Vector2(lx - 120, 18), dataset.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, RoninPalette.MUTED)
	var labelled := not (classes.size() == 1 and classes[0] == "")
	for c in classes.size() if labelled else 0:
		var col := CLASS_COLORS[c % CLASS_COLORS.size()]
		draw_circle(Vector2(lx + c * 110, 13), 5, col)
		draw_string(font, Vector2(lx + c * 110 + 10, 18), classes[c], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, RoninPalette.TEXT)

	# Puntos
	var query_pos := Vector2(-1, -1)
	for i in dataset.size():
		var p := Vector2(
			plot.position.x + inverse_lerp(xr.x, xr.y, xs[i]) * plot.size.x,
			plot.end.y - inverse_lerp(yr.x, yr.y, ys[i]) * plot.size.y)
		var col := CLASS_COLORS[classes.find(dataset.labels[i]) % CLASS_COLORS.size()]
		var id := dataset.ids[i]
		if id in neighbor_ids:
			draw_arc(p, 8, 0, TAU, 20, RoninPalette.TEXT, 1.5)
		draw_circle(p, 3.5, Color(col, 0.85))
		if id == query_id:
			query_pos = p
	if not regression_line.is_empty() and regression_line["x"] == dataset.feature_names[fx] and regression_line["y"] == dataset.feature_names[fy]:
		var pts := PackedVector2Array()
		for t in [xr.x, xr.y]:
			var yv: float = regression_line["w"] * t + regression_line["b"]
			pts.append(Vector2(plot.position.x + inverse_lerp(xr.x, xr.y, t) * plot.size.x, plot.end.y - inverse_lerp(yr.x, yr.y, yv) * plot.size.y))
		if is_finite(pts[0].y) and is_finite(pts[1].y):
			var clipped := _clip_segment(pts[0], pts[1], plot)
			if clipped.size() == 2:
				draw_line(clipped[0], clipped[1], RoninPalette.CYAN, 2.0, true)
	if query_pos.x >= 0:
		draw_arc(query_pos, 12, 0, TAU, 28, RoninPalette.CYAN, 2.0)
		draw_string(font, query_pos + Vector2(14, -10), query_id, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, RoninPalette.CYAN)


## Recorta un segmento al rectángulo (algoritmo de Liang-Barsky).
static func _clip_segment(a: Vector2, b: Vector2, r: Rect2) -> PackedVector2Array:
	var t0 := 0.0
	var t1 := 1.0
	var d := b - a
	for edge in [[-d.x, a.x - r.position.x], [d.x, r.end.x - a.x], [-d.y, a.y - r.position.y], [d.y, r.end.y - a.y]]:
		var pp: float = edge[0]
		var qq: float = edge[1]
		if is_zero_approx(pp):
			if qq < 0:
				return PackedVector2Array()
			continue
		var u := qq / pp
		if pp < 0:
			t0 = maxf(t0, u)
		else:
			t1 = minf(t1, u)
	if t0 > t1:
		return PackedVector2Array()
	return PackedVector2Array([a + d * t0, a + d * t1])


static func _range(values: PackedFloat64Array) -> Vector2:
	var lo := INF
	var hi := -INF
	for v in values:
		lo = minf(lo, v)
		hi = maxf(hi, v)
	if is_equal_approx(lo, hi):
		return Vector2(lo - 1, hi + 1)
	var pad := (hi - lo) * 0.05
	return Vector2(lo - pad, hi + pad)
