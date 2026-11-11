class_name AttentionHeatmap
extends Control
## Mapa de calor de pesos de atención: filas = query, columnas = key. Más claro = más atención.
## Las columnas se numeran (1, 2, 3…) como las filas, así no hay cabeceras de una letra; a la
## derecha, la escala de colores. Con celdas grandes se escribe el peso dentro.

var words: PackedStringArray = []
var weights: Array = []
var causal: bool = false


func show_weights(p_words: PackedStringArray, p_weights: Array, p_causal: bool) -> void:
	words = p_words
	weights = p_weights
	causal = p_causal
	queue_redraw()


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var font := RoninFonts.mono()
	draw_rect(Rect2(Vector2.ZERO, size), RoninPalette.PANEL)
	var n := words.size()
	if n == 0:
		return
	var longest := 0
	for w in words:
		longest = maxi(longest, w.length())
	var left := clampf(28.0 + longest * 8.0, 90.0, 200.0)
	var top := 46.0
	var scale_w := 70.0
	var cell := floorf(minf((size.x - left - scale_w - 20.0) / n, (size.y - top - 12.0) / n))
	cell = maxf(cell, 8.0)
	draw_string(font, Vector2(16, 18), "Atención%s · fila = la palabra que mira (query) · columna = a la que mira (key)" % (" causal" if causal else ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, RoninPalette.TEXT)
	var label_size := 12 if cell >= 22 else 10
	for j in n:
		draw_string(font, Vector2(left + j * cell, top - 8), str(j + 1), HORIZONTAL_ALIGNMENT_CENTER, cell - 2, label_size, RoninPalette.MUTED)
	var w_max := 0.0
	for row: Array in weights:
		for v in row:
			w_max = maxf(w_max, float(v))
	w_max = maxf(w_max, 0.0001)
	for i in n:
		draw_string(font, Vector2(8, top + i * cell + cell / 2 + 4), "%d %s" % [i + 1, words[i]], HORIZONTAL_ALIGNMENT_LEFT, left - 14, label_size, RoninPalette.MUTED)
		for j in n:
			var rect := Rect2(left + j * cell, top + i * cell, cell - 2, cell - 2)
			if causal and j > i:
				draw_rect(rect, RoninPalette.BG)
				continue
			var w: float = weights[i][j]
			var t := w / w_max
			draw_rect(rect, RoninPalette.PANEL_ALT.lerp(RoninPalette.CYAN, t))
			if cell >= 30:
				draw_string(font, rect.position + Vector2(0, cell / 2 + 3), "%.2f" % w, HORIZONTAL_ALIGNMENT_CENTER, cell - 2, 10 if cell < 40 else 11, RoninPalette.BG if t > 0.55 else RoninPalette.TEXT)
	# Escala: de 0 al peso más alto.
	var sx := left + n * cell + 16.0
	var sh := minf(n * cell, 160.0)
	var steps := 16
	for k in steps:
		var t := 1.0 - float(k) / steps
		draw_rect(Rect2(sx, top + k * sh / steps, 14, sh / steps + 1), RoninPalette.PANEL_ALT.lerp(RoninPalette.CYAN, t))
	draw_string(font, Vector2(sx + 18, top + 10), "%.2f" % w_max, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, RoninPalette.MUTED)
	draw_string(font, Vector2(sx + 18, top + sh), "0", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, RoninPalette.MUTED)
