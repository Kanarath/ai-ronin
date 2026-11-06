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


func show_dataset(ds: Dataset, x_name: String, y_name: String) -> void:
	dataset = ds
	fx = maxi(ds.feature_index(x_name), 0)
	fy = maxi(ds.feature_index(y_name), 0)
	query_id = ""
	neighbor_ids = []
	queue_redraw()


func current_axes() -> PackedStringArray:
	if dataset == null:
		return PackedStringArray()
	return PackedStringArray([dataset.feature_names[fx], dataset.feature_names[fy]])


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
	for c in classes.size():
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
	if query_pos.x >= 0:
		draw_arc(query_pos, 12, 0, TAU, 28, RoninPalette.CYAN, 2.0)
		draw_string(font, query_pos + Vector2(14, -10), query_id, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, RoninPalette.CYAN)


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
