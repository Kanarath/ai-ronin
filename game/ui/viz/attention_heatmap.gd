class_name AttentionHeatmap
extends Control
## Mapa de calor de pesos de atención: filas = query, columnas = key. Más claro = más atención.

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
	var left := 110.0
	var top := 70.0
	var cell := minf((size.x - left - 20) / n, (size.y - top - 30) / n)
	draw_string(font, Vector2(16, 20), "Atención%s · fila = query, columna = key" % (" causal" if causal else ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, RoninPalette.TEXT)
	for j in n:
		draw_string(font, Vector2(left + j * cell + 4, top - 8), words[j], HORIZONTAL_ALIGNMENT_LEFT, cell - 4, 11, RoninPalette.MUTED)
	for i in n:
		draw_string(font, Vector2(10, top + i * cell + cell / 2 + 4), words[i], HORIZONTAL_ALIGNMENT_LEFT, left - 14, 11, RoninPalette.MUTED)
		for j in n:
			var rect := Rect2(left + j * cell, top + i * cell, cell - 2, cell - 2)
			if causal and j > i:
				draw_rect(rect, RoninPalette.BG)
				continue
			var w: float = weights[i][j]
			draw_rect(rect, RoninPalette.PANEL_ALT.lerp(RoninPalette.CYAN, w))
			if cell > 34:
				draw_string(font, rect.position + Vector2(4, cell / 2 + 3), "%.2f" % w, HORIZONTAL_ALIGNMENT_LEFT, cell - 6, 11, RoninPalette.BG if w > 0.55 else RoninPalette.TEXT)
