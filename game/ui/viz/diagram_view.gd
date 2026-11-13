class_name DiagramView
extends Control
## Panel de diagramas para las unidades de seguridad: barras (segmentos de evals), cadena de
## ataque (pasos por dos entradas) y mapa de cobertura (riesgos frente a defensas).
## Un solo widget con modo; se dibuja como el resto (RoninPalette + fuente mono).

var mode: String = ""
var title: String = ""
## bars: [{label, value 0..1, color, note}]
## chain: pasos [{label, risk, mcp_ok, web_ok}]
## coverage: [{label, covered, defs}]
var items: Array = []


func show_bars(p_title: String, p_items: Array) -> void:
	mode = "bars"
	title = p_title
	items = p_items
	queue_redraw()


func show_chain(p_title: String, p_steps: Array) -> void:
	mode = "chain"
	title = p_title
	items = p_steps
	queue_redraw()


func show_coverage(p_title: String, p_rows: Array) -> void:
	mode = "coverage"
	title = p_title
	items = p_rows
	queue_redraw()


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var font := RoninFonts.mono()
	draw_rect(Rect2(Vector2.ZERO, size), RoninPalette.PANEL)
	if items.is_empty() or size.x < 80 or size.y < 60:
		return
	draw_string(font, Vector2(12, 18), title, HORIZONTAL_ALIGNMENT_LEFT, size.x - 24, 12, RoninPalette.TEXT)
	match mode:
		"bars":
			_draw_bars(font)
		"chain":
			_draw_chain(font)
		"coverage":
			_draw_coverage(font)


func _draw_bars(font: Font) -> void:
	var top := 34.0
	var row_h := minf(34.0, (size.y - top - 8.0) / items.size())
	var label_w := 150.0
	var bar_x := 12.0 + label_w
	var bar_w := size.x - bar_x - 70.0
	var i := 0
	for it: Dictionary in items:
		var y := top + i * row_h
		var cy := y + row_h * 0.5
		draw_string(font, Vector2(12, cy + 4), str(it["label"]), HORIZONTAL_ALIGNMENT_LEFT, label_w - 6, 12, RoninPalette.TEXT)
		var v: float = clampf(float(it["value"]), 0.0, 1.0)
		var bh := row_h - 12.0
		draw_rect(Rect2(bar_x, y + 6, bar_w, bh), RoninPalette.LINE)
		draw_rect(Rect2(bar_x, y + 6, bar_w * v, bh), it.get("color", RoninPalette.TEAL))
		draw_string(font, Vector2(bar_x + bar_w + 6, cy + 4), str(it.get("note", "%.2f" % v)), HORIZONTAL_ALIGNMENT_LEFT, 60, 12, RoninPalette.MUTED)
		i += 1


func _draw_chain(font: Font) -> void:
	# Fila de cajas S1 … Sn; en cada una, dos puntos (entrada mcp y web): verde = ocurre, el
	# corte se ve cuando una entrada deja de llegar al paso.
	var n := items.size()
	var top := 46.0
	var gap := 10.0
	var box_w := (size.x - 24.0 - gap * (n - 1)) / maxf(n, 1)
	var box_h := minf(70.0, size.y - top - 30.0)
	draw_string(font, Vector2(12, 36), "entrada mcp · entrada web   (● = ocurre · × = cortado)", HORIZONTAL_ALIGNMENT_LEFT, size.x - 24, 11, RoninPalette.MUTED)
	var i := 0
	for st: Dictionary in items:
		var x := 12.0 + i * (box_w + gap)
		var rect := Rect2(x, top, box_w, box_h)
		var mcp: bool = bool(st.get("mcp_ok", false))
		var web: bool = bool(st.get("web_ok", false))
		var any: bool = mcp or web
		draw_rect(rect, RoninPalette.PANEL if not any else Color(RoninPalette.TEAL, 0.14))
		draw_rect(rect, RoninPalette.RED if not any else RoninPalette.TEAL, false, 1.5)
		draw_string(font, Vector2(x + 6, top + 16), str(st.get("label", "")), HORIZONTAL_ALIGNMENT_LEFT, box_w - 12, 12, RoninPalette.TEXT)
		draw_string(font, Vector2(x + 6, top + 30), str(st.get("risk", "")), HORIZONTAL_ALIGNMENT_LEFT, box_w - 12, 10, RoninPalette.GOLD)
		var cy := top + box_h - 8.0
		# Forma además del color (accesible para daltonismo): ● ocurre · × cortado.
		draw_string(font, Vector2(x + box_w * 0.33 - 5, cy), "●" if mcp else "×", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, RoninPalette.TEAL if mcp else RoninPalette.RED)
		draw_string(font, Vector2(x + box_w * 0.66 - 5, cy), "●" if web else "×", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, RoninPalette.TEAL if web else RoninPalette.RED)
		if i < n - 1:
			var ay := top + box_h * 0.5
			draw_line(Vector2(x + box_w, ay), Vector2(x + box_w + gap, ay), RoninPalette.LINE, 1.5)
		i += 1


func _draw_coverage(font: Font) -> void:
	var top := 34.0
	var row_h := minf(22.0, (size.y - top - 8.0) / items.size())
	var i := 0
	for it: Dictionary in items:
		var y := top + i * row_h
		var cy := y + row_h * 0.5
		var covered: bool = bool(it.get("covered", false))
		var chip := Rect2(12, y + 3, 14, row_h - 6)
		draw_rect(chip, RoninPalette.TEAL if covered else RoninPalette.RED)
		# Símbolo además del color (daltonismo): ✓ con defensa · ✗ sin ella.
		draw_string(font, Vector2(14, cy + 4), "✓" if covered else "✗", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, RoninPalette.PANEL)
		draw_string(font, Vector2(32, cy + 4), str(it["label"]), HORIZONTAL_ALIGNMENT_LEFT, 150, 11, RoninPalette.TEXT)
		var defs: String = str(it.get("defs", "")) if covered else "— sin defensa"
		draw_string(font, Vector2(190, cy + 4), defs, HORIZONTAL_ALIGNMENT_LEFT, size.x - 200, 11, RoninPalette.MUTED if covered else RoninPalette.RED)
		i += 1
