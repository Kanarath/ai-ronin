class_name NetworkGraph
extends Control
## Dibuja una red MLP: neuronas como círculos (rellenos según su activación en la última
## pasada hacia delante) y conexiones coloreadas por el signo del peso y con grosor según su magnitud.
## Verde azulado = peso positivo · dorado = peso negativo.

var net: MLP
var net_name: String = ""
var last_input := PackedFloat64Array()


func show_network(p_net: MLP, p_name: String, p_input: PackedFloat64Array = PackedFloat64Array()) -> void:
	net = p_net
	net_name = p_name
	last_input = p_input
	queue_redraw()


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var font := RoninFonts.mono()
	draw_rect(Rect2(Vector2.ZERO, size), RoninPalette.PANEL)
	if net == null:
		return
	var has_input := last_input.size() == net.inputs
	var f: Dictionary = net.forward(last_input) if has_input else {}
	var layers: Array = [net.inputs]
	if net.hidden > 0:
		layers.append(net.hidden)
	layers.append(1)
	var margin := Vector2(90, 46)
	var area := Rect2(margin, size - margin * 2)
	var positions: Array = []
	for li in layers.size():
		var col: Array[Vector2] = []
		var n: int = layers[li]
		var x := area.position.x + (area.size.x * li / maxf(layers.size() - 1, 1))
		for i in n:
			var y := area.position.y + area.size.y * (i + 0.5) / n
			col.append(Vector2(x, y))
		positions.append(col)
	# Conexiones
	var max_w := 0.001
	for p in net.param_names():
		if p.begins_with("w"):
			max_w = maxf(max_w, absf(net.get_param(p)))
	if net.hidden > 0:
		for j in net.hidden:
			for k in net.inputs:
				_edge(positions[0][k], positions[1][j], net.W1[j][k], max_w)
		for j in net.hidden:
			_edge(positions[1][j], positions[2][0], net.w2[j], max_w)
	else:
		for k in net.inputs:
			_edge(positions[0][k], positions[1][0], net.w2[k], max_w)
	# Neuronas
	for li in positions.size():
		for i in positions[li].size():
			var p: Vector2 = positions[li][i]
			var activation := -1.0
			var label := ""
			if li == 0:
				label = "x%d" % i
				if has_input:
					activation = clampf(last_input[i], 0.0, 1.0)
			elif li == positions.size() - 1:
				label = "salida"
				if has_input:
					activation = f["p"]
			else:
				label = "oculta %d" % i
				if has_input:
					activation = clampf(f["a1"][i], 0.0, 1.0) if net.activation != "relu" else clampf(f["a1"][i] / 4.0, 0.0, 1.0)
			var fill := RoninPalette.PANEL_ALT if activation < 0 else RoninPalette.PANEL_ALT.lerp(RoninPalette.CYAN, activation)
			draw_circle(p, 18, fill)
			draw_arc(p, 18, 0, TAU, 32, RoninPalette.TEXT, 1.5)
			draw_string(font, p + Vector2(-30, 34), label, HORIZONTAL_ALIGNMENT_CENTER, 60, 11, RoninPalette.MUTED)
			if activation >= 0:
				draw_string(font, p + Vector2(-20, 5), String.num(activation if li != positions.size() - 1 else f["p"], 2), HORIZONTAL_ALIGNMENT_CENTER, 40, 11, RoninPalette.BG if activation > 0.6 else RoninPalette.TEXT)
	var title := "%s · %d parámetros · %d épocas" % [net_name, net.param_count(), net.epochs]
	if has_input:
		title += " · entrada [%s]" % ",".join(Array(last_input).map(func(v: float) -> String: return String.num(v, 2)))
	draw_string(font, Vector2(16, 20), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, RoninPalette.TEXT)
	draw_string(font, Vector2(16, size.y - 10), "■ peso positivo   ■ peso negativo   grosor = |peso|   relleno = activación", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, RoninPalette.MUTED)


func _edge(a: Vector2, b: Vector2, w: float, max_w: float) -> void:
	var col := RoninPalette.TEAL if w >= 0 else RoninPalette.GOLD
	var width := 0.5 + 5.0 * absf(w) / max_w
	draw_line(a, b, Color(col, 0.35 + 0.6 * absf(w) / max_w), width, true)
	var mid := a.lerp(b, 0.35)
	draw_string(RoninFonts.mono(), mid + Vector2(-14, -4), String.num(w, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, RoninPalette.MUTED)
