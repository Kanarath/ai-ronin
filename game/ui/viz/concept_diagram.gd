class_name ConceptDiagram
extends Control
## Diagrama del CONCEPTO: vive a la izquierda del laboratorio, junto al gráfico de datos reales.
## Mientras el gráfico de la derecha enseña los DATOS, este dibujo enseña la IDEA, limpia y sin
## ruido. Es dirigido por datos: cada objetivo (o la misión) trae un dict `diagram` con una clave
## `kind` y sus parámetros, así se rellena el temario sin tocar la interfaz.
##
## kinds disponibles:
##   points2d · puntos con clase (0 = apta/teal, 1 = defectuosa/oro); consulta opcional (cian, con
##              anillo) y sus k vecinos más cercanos resaltados; enlace opcional entre dos puntos
##              (distancia). Generaliza el k-NN y «clases que se separan o se mezclan».
##   table    · una tabla pequeña; resalta las columnas de features y la de la etiqueta.
##   bars     · barras horizontales para comparar magnitudes (p. ej. escalas de features).
##
## Todo se dibuja con primitivas y la paleta oficial, igual que el resto de visualizaciones.

## Clase 0 = apta (teal) · clase 1 = defectuosa (oro). Colores compartidos con el gráfico real.
const CLASS_COLORS := [RoninPalette.TEAL, RoninPalette.GOLD]
## Nombres de color admitidos en el JSON (p. ej. una barra "color": "gold").
const NAMED_COLORS := {
	"teal": RoninPalette.TEAL, "gold": RoninPalette.GOLD, "red": RoninPalette.RED,
	"cyan": RoninPalette.CYAN, "violet": RoninPalette.VIOLET, "text": RoninPalette.TEXT,
	"muted": RoninPalette.MUTED,
}


static func _color(name: Variant, default: Color) -> Color:
	return NAMED_COLORS.get(str(name), default) if name is String else default

var spec: Dictionary = {}


func show_spec(p_spec: Dictionary) -> void:
	spec = p_spec
	queue_redraw()


func clear() -> void:
	spec = {}
	queue_redraw()


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var font := RoninFonts.mono()
	draw_rect(Rect2(Vector2.ZERO, size), RoninPalette.PANEL)
	draw_rect(Rect2(Vector2.ZERO, size), RoninPalette.LINE, false)
	if size.x < 90 or size.y < 70:
		return
	# Sin diagrama que enseñar, el panel no se deja vacío (el gráfico de la derecha se vería
	# demasiado ancho): se llena con las olas seigaiha del Dojo y el kanji 道 tenue.
	if spec.is_empty():
		_draw_empty(font)
		return
	# Franja de título (arriba) y pie de texto (abajo); el cuerpo va en medio.
	var title := str(spec.get("title", "LA IDEA"))
	draw_string(font, Vector2(14, 22), title, HORIZONTAL_ALIGNMENT_LEFT, size.x - 28, 13, RoninPalette.TEAL)
	var caption := str(spec.get("caption", ""))
	var foot := 0.0
	if not caption.is_empty():
		foot = 40.0
		# El pie puede ocupar dos líneas: se parte por la mitad aproximada si es largo.
		_draw_wrapped(font, caption, Vector2(14, size.y - foot + 14.0), size.x - 28, 12, RoninPalette.TEXT, 2)
	var body := Rect2(12, 32, size.x - 24, size.y - 32 - foot)
	match str(spec.get("kind", "")):
		"points2d":
			_draw_points2d(font, body)
		"table":
			_draw_table(font, body)
		"bars":
			_draw_bars(font, body)
		"lines":
			_draw_lines(font, body)
		"bowl":
			_draw_bowl(font, body)
		"chips":
			_draw_chips(font, body)
		"tree":
			_draw_tree(font, body)


## Estado sin diagrama: olas seigaiha tenues (como el fondo del Dojo) y el sello 道 al centro.
func _draw_empty(font: Font) -> void:
	var wave := Color("#2F4352")
	var r := 22.0
	var row := 0
	var y := -r
	while y < size.y + r:
		var x := (r if row % 2 == 1 else 0.0) - 2.0 * r
		while x < size.x + 2.0 * r:
			var c := Vector2(x, y)
			draw_circle(c, r, RoninPalette.PANEL)
			for k: float in [1.0, 0.72, 0.44]:
				draw_arc(c, r * k - 1.0, PI, TAU, 16, Color(wave, 0.5), 1.0, true)
			x += 2.0 * r
		y += r * 0.5
		row += 1
	# Kanji 道 (el Camino) muy tenue, centrado. Fuente cacheada (no la negrita, que a veces no
	# resuelve a tiempo) y tamaño acotado para que no se dispare en paneles grandes.
	var jp := RoninFonts.jp(false)
	var psize := int(clampf(minf(size.x, size.y) * 0.45, 40.0, 150.0))
	var tw := jp.get_string_size("道", HORIZONTAL_ALIGNMENT_LEFT, -1, psize)
	draw_string(jp, Vector2((size.x - tw.x) * 0.5, (size.y + tw.y * 0.55) * 0.5), "道", HORIZONTAL_ALIGNMENT_LEFT, -1, psize, Color(RoninPalette.GOLD, 0.14))
	draw_string(font, Vector2(14, size.y - 14), "laboratorio", HORIZONTAL_ALIGNMENT_LEFT, size.x - 28, 11, Color(RoninPalette.MUTED, 0.7))


# ── points2d ─────────────────────────────────────────────────────────────────
## points: [{x, y, cls}] en coordenadas 0..1. query: {x, y} opcional. k: vecinos a resaltar.
## link: [i, j] opcional → línea de distancia entre dos puntos. legend: [[texto, cls], …].
func _draw_points2d(font: Font, body: Rect2) -> void:
	var pts: Array = spec.get("points", [])
	var legend: Array = spec.get("legend", [])
	var leg_h := 20.0 if not legend.is_empty() else 0.0
	var plot := Rect2(body.position + Vector2(8, 8), body.size - Vector2(16, 16 + leg_h))
	# Ejes suaves (solo como marco visual: el concepto no necesita escala numérica).
	draw_line(plot.position + Vector2(0, plot.size.y), plot.end, RoninPalette.LINE, 1.0)
	draw_line(plot.position, plot.position + Vector2(0, plot.size.y), RoninPalette.LINE, 1.0)
	if spec.has("x_label"):
		draw_string(font, Vector2(plot.end.x - 70, plot.end.y + 12), "→ " + str(spec["x_label"]), HORIZONTAL_ALIGNMENT_LEFT, 70, 10, RoninPalette.MUTED)
	if spec.has("y_label"):
		draw_string(font, Vector2(plot.position.x + 2, plot.position.y - 2), "↑ " + str(spec["y_label"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, RoninPalette.MUTED)
	var to_px := func(p: Dictionary) -> Vector2:
		return Vector2(plot.position.x + float(p.get("x", 0.5)) * plot.size.x,
			plot.end.y - float(p.get("y", 0.5)) * plot.size.y)
	# Vecinos más cercanos a la consulta (si la hay): se resaltan con un anillo.
	var near := {}
	var query: Dictionary = spec.get("query", {})
	if not query.is_empty() and int(spec.get("k", 0)) > 0:
		var qp := to_px.call(query) as Vector2
		var d: Array = []
		for i in pts.size():
			d.append([(to_px.call(pts[i]) as Vector2).distance_to(qp), i])
		d.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		for i in mini(int(spec["k"]), d.size()):
			near[int(d[i][1])] = true
			draw_line(qp, to_px.call(pts[int(d[i][1])]), RoninPalette.MUTED, 1.0)
	# Recta(s) de decisión (frontera): segmento [[x0,y0],[x1,y1]] en coordenadas 0..1. `boundary`
	# admite uno; `boundaries`, una lista de ellos.
	var segs: Array = spec.get("boundaries", [])
	if spec.get("boundary", []).size() == 2:
		segs = segs + [spec.get("boundary")]
	for seg: Array in segs:
		if seg.size() == 2:
			var b0 := to_px.call({"x": seg[0][0], "y": seg[0][1]}) as Vector2
			var b1 := to_px.call({"x": seg[1][0], "y": seg[1][1]}) as Vector2
			draw_dashed_line(b0, b1, RoninPalette.CYAN, 1.5, 6.0)
	# Enlace de distancia entre dos puntos concretos.
	var link: Array = spec.get("link", [])
	if link.size() == 2:
		var a := to_px.call(pts[int(link[0])]) as Vector2
		var b := to_px.call(pts[int(link[1])]) as Vector2
		draw_line(a, b, RoninPalette.CYAN, 1.5)
		draw_string(font, (a + b) * 0.5 + Vector2(4, -4), str(spec.get("link_label", "d")), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, RoninPalette.CYAN)
	# Puntos conocidos.
	for i in pts.size():
		var p := to_px.call(pts[i]) as Vector2
		var col: Color = CLASS_COLORS[int(pts[i].get("cls", 0)) % CLASS_COLORS.size()]
		draw_circle(p, 6, col)
		if near.has(i):
			draw_arc(p, 10, 0, TAU, 20, RoninPalette.TEXT, 1.5)
	# La consulta: punto nuevo, en cian y con doble anillo.
	if not query.is_empty():
		var qp2 := to_px.call(query) as Vector2
		draw_circle(qp2, 6, RoninPalette.CYAN)
		draw_arc(qp2, 12, 0, TAU, 24, RoninPalette.CYAN, 2.0)
		draw_string(font, qp2 + Vector2(15, -10), str(query.get("label", "nuevo")), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, RoninPalette.CYAN)
	# Leyenda (abajo): un punto de color por clase.
	if not legend.is_empty():
		var lx := plot.position.x
		var ly := plot.end.y + 16.0
		for entry: Array in legend:
			var col2: Color = CLASS_COLORS[int(entry[1]) % CLASS_COLORS.size()]
			draw_circle(Vector2(lx + 6, ly), 5, col2)
			draw_string(font, Vector2(lx + 16, ly + 4), str(entry[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, RoninPalette.TEXT)
			lx += 22 + str(entry[0]).length() * 7.5


# ── table ──────────────────────────────────────────────────────────────────────
## headers: [String]. rows: [[String]]. feature_cols / label_col: índices a resaltar.
func _draw_table(font: Font, body: Rect2) -> void:
	var headers: Array = spec.get("headers", [])
	var rows: Array = spec.get("rows", [])
	if headers.is_empty():
		return
	var n_cols := headers.size()
	var col_w := body.size.x / n_cols
	var n_rows := rows.size() + 1
	var row_h := minf(26.0, body.size.y / maxf(n_rows, 1))
	var features: Array = spec.get("feature_cols", [])
	var label_col := int(spec.get("label_col", -1))
	# Columnas resaltadas de fondo: features en teal tenue, etiqueta en oro tenue.
	for c in n_cols:
		var tint := Color.TRANSPARENT
		if c in features:
			tint = Color(RoninPalette.TEAL, 0.12)
		elif c == label_col:
			tint = Color(RoninPalette.GOLD, 0.14)
		if tint.a > 0.0:
			draw_rect(Rect2(body.position.x + c * col_w, body.position.y, col_w, row_h * n_rows), tint)
	# Cabecera.
	for c in n_cols:
		var hx := body.position.x + c * col_w + 4
		var hcol: Color = RoninPalette.GOLD if c == label_col else (RoninPalette.TEAL if c in features else RoninPalette.MUTED)
		draw_string(font, Vector2(hx, body.position.y + 15), str(headers[c]), HORIZONTAL_ALIGNMENT_LEFT, col_w - 6, 11, hcol)
	draw_line(Vector2(body.position.x, body.position.y + row_h), Vector2(body.end.x, body.position.y + row_h), RoninPalette.LINE, 1.0)
	# Filas (ejemplos).
	for r in rows.size():
		var y := body.position.y + (r + 1) * row_h
		for c in mini(n_cols, (rows[r] as Array).size()):
			draw_string(font, Vector2(body.position.x + c * col_w + 4, y + 15), str(rows[r][c]), HORIZONTAL_ALIGNMENT_LEFT, col_w - 6, 11, RoninPalette.TEXT)


# ── bars ─────────────────────────────────────────────────────────────────────
## items: [{label, value, note, color?}]. Se normaliza al valor máximo.
func _draw_bars(font: Font, body: Rect2) -> void:
	var items: Array = spec.get("items", [])
	if items.is_empty():
		return
	var vmax := 0.0001
	for it: Dictionary in items:
		vmax = maxf(vmax, absf(float(it.get("value", 0.0))))
	var row_h := minf(40.0, body.size.y / items.size())
	var label_w := minf(110.0, body.size.x * 0.32)
	var bar_x := body.position.x + label_w
	var bar_w := body.end.x - bar_x - 52.0
	for i in items.size():
		var it: Dictionary = items[i]
		var y := body.position.y + i * row_h
		var cy := y + row_h * 0.5
		draw_string(font, Vector2(body.position.x, cy + 4), str(it.get("label", "")), HORIZONTAL_ALIGNMENT_LEFT, label_w - 6, 12, RoninPalette.TEXT)
		var v := absf(float(it.get("value", 0.0))) / vmax
		var bh := row_h - 14.0
		var col := _color(it.get("color"), RoninPalette.TEAL)
		draw_rect(Rect2(bar_x, y + 7, bar_w, bh), RoninPalette.LINE)
		draw_rect(Rect2(bar_x, y + 7, bar_w * v, bh), col)
		draw_string(font, Vector2(bar_x + bar_w + 6, cy + 4), str(it.get("note", str(it.get("value", "")))), HORIZONTAL_ALIGNMENT_LEFT, 50, 12, RoninPalette.MUTED)


# ── lines ──────────────────────────────────────────────────────────────────────
## series: [{name, color, points: [[x, y], …]}]. Esquema de curvas (train vs test, pérdida…).
## Se autoescala a los datos; no busca precisión numérica, sino la FORMA.
func _draw_lines(font: Font, body: Rect2) -> void:
	var series: Array = spec.get("series", [])
	if series.is_empty():
		return
	var leg_h := 18.0
	var plot := Rect2(body.position + Vector2(30, 6), body.size - Vector2(38, 22 + leg_h))
	var xmin := INF
	var xmax := -INF
	var ymin := INF
	var ymax := -INF
	for s: Dictionary in series:
		for p: Array in s.get("points", []):
			xmin = minf(xmin, p[0]); xmax = maxf(xmax, p[0])
			ymin = minf(ymin, p[1]); ymax = maxf(ymax, p[1])
	if xmax <= xmin:
		xmax = xmin + 1.0
	if ymax <= ymin:
		ymax = ymin + 1.0
	# Un poco de margen arriba y abajo para que las curvas no toquen el borde.
	var pad := (ymax - ymin) * 0.1
	ymin -= pad; ymax += pad
	var to_px := func(x: float, y: float) -> Vector2:
		return Vector2(plot.position.x + (x - xmin) / (xmax - xmin) * plot.size.x,
			plot.end.y - (y - ymin) / (ymax - ymin) * plot.size.y)
	# Ejes.
	draw_line(plot.position + Vector2(0, plot.size.y), plot.end, RoninPalette.LINE, 1.0)
	draw_line(plot.position, plot.position + Vector2(0, plot.size.y), RoninPalette.LINE, 1.0)
	if spec.has("x_label"):
		draw_string(font, Vector2(plot.end.x - 60, plot.end.y + 14), "→ " + str(spec["x_label"]), HORIZONTAL_ALIGNMENT_LEFT, 60, 10, RoninPalette.MUTED)
	if spec.has("y_label"):
		draw_string(font, Vector2(plot.position.x - 26, plot.position.y + 4), str(spec["y_label"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, RoninPalette.MUTED)
	# Curvas.
	for s: Dictionary in series:
		var pts: Array = s.get("points", [])
		if pts.size() < 2:
			continue
		var line := PackedVector2Array()
		for p: Array in pts:
			line.append(to_px.call(p[0], p[1]))
		draw_polyline(line, _color(s.get("color"), RoninPalette.TEAL), 2.0, true)
	# Leyenda.
	var lx := plot.position.x
	var ly := plot.end.y + leg_h + 4.0
	for s: Dictionary in series:
		var col := _color(s.get("color"), RoninPalette.TEAL)
		draw_line(Vector2(lx, ly - 4), Vector2(lx + 14, ly - 4), col, 2.0)
		draw_string(font, Vector2(lx + 18, ly), str(s.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, RoninPalette.TEXT)
		lx += 30 + str(s.get("name", "")).length() * 7.5


# ── bowl ───────────────────────────────────────────────────────────────────────
## El valle de la pérdida (una parábola y=x²) y la trayectoria del descenso: steps es una lista
## de posiciones en x (−1..1); cada una es una «bola» sobre la curva, unidas en orden. Sirve para
## learning rate lento (pasitos), bueno (llega al fondo) o que diverge (salta cada vez más lejos).
func _draw_bowl(font: Font, body: Rect2) -> void:
	var plot := Rect2(body.position + Vector2(10, 10), body.size - Vector2(20, 24))
	var cx := plot.position.x + plot.size.x * 0.5
	var to_px := func(x: float) -> Vector2:
		var y := x * x  # parábola; 0 en el fondo, 1 en los bordes
		return Vector2(cx + clampf(x, -1.2, 1.2) * plot.size.x * 0.42,
			plot.end.y - y * plot.size.y * 0.92)
	# La curva del valle.
	var curve := PackedVector2Array()
	var t := -1.15
	while t <= 1.15:
		curve.append(to_px.call(t))
		t += 0.1
	draw_polyline(curve, RoninPalette.LINE.lightened(0.15), 2.0, true)
	draw_string(font, Vector2(plot.position.x, plot.end.y + 14), "mínimo = mejor ajuste", HORIZONTAL_ALIGNMENT_LEFT, plot.size.x, 10, RoninPalette.MUTED)
	# La trayectoria del descenso.
	var steps: Array = spec.get("steps", [])
	var diverges := bool(spec.get("diverges", false))
	var prev := Vector2.ZERO
	for i in steps.size():
		var p := to_px.call(float(steps[i])) as Vector2
		if i > 0:
			draw_line(prev, p, RoninPalette.MUTED, 1.0)
		prev = p
	for i in steps.size():
		var p := to_px.call(float(steps[i])) as Vector2
		var col: Color = RoninPalette.CYAN
		if i == steps.size() - 1:
			col = RoninPalette.RED if diverges else RoninPalette.TEAL
		draw_circle(p, 5, col)


# ── chips ──────────────────────────────────────────────────────────────────────
## chips: [{text, color?}]. Fichas (pastillas) en filas que se ajustan al ancho. Sirve para
## tokens, palabras de una secuencia, trozos de un contexto… Con `arrows` true, una flecha entre
## fichas (una tubería). `pre` es un texto grande a la izquierda (p. ej. la frase original).
func _draw_chips(font: Font, body: Rect2) -> void:
	var chips: Array = spec.get("chips", [])
	if chips.is_empty():
		return
	var pre := str(spec.get("pre", ""))
	var x0 := body.position.x
	if not pre.is_empty():
		draw_string(font, Vector2(body.position.x, body.position.y + 20), pre, HORIZONTAL_ALIGNMENT_LEFT, body.size.x, 13, RoninPalette.MUTED)
	var pad := 8.0
	var h := 24.0
	var gap := 6.0
	var x := x0
	var y := body.position.y + (26.0 if not pre.is_empty() else 4.0)
	for c: Dictionary in chips:
		var t := str(c.get("text", ""))
		var tw := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var w := tw + pad * 2
		if x + w > body.end.x and x > x0:
			x = x0
			y += h + gap
		if y + h > body.end.y:
			return
		var col := _color(c.get("color"), RoninPalette.TEAL)
		var r := Rect2(x, y, w, h)
		draw_rect(r, Color(col, 0.18))
		draw_rect(r, col, false, 1.0)
		draw_string(font, Vector2(x + pad, y + 16), t, HORIZONTAL_ALIGNMENT_LEFT, tw + 2, 13, RoninPalette.TEXT)
		x += w + gap
	# Pie «N <unidad>» solo si se pide (p. ej. tokens); en fichas de fases o expertos no aplica.
	if spec.has("count_suffix"):
		draw_string(font, Vector2(x0, body.end.y - 2), "%d %s" % [chips.size(), str(spec["count_suffix"])], HORIZONTAL_ALIGNMENT_LEFT, body.size.x, 11, RoninPalette.MUTED)


# ── tree ───────────────────────────────────────────────────────────────────────
## Árbol de decisión. root: nodo interno {q, izq, der} u hoja {leaf, cls}. Rama izquierda = «sí».
var _tree_leaf := 0.0
var _tree_depth := 0

func _draw_tree(font: Font, body: Rect2) -> void:
	var root: Dictionary = spec.get("root", {})
	if root.is_empty():
		return
	_tree_leaf = 0.0
	_tree_depth = 0
	_tree_layout(root, 0)
	var cols := maxf(_tree_leaf - 1.0, 1.0)
	var rows := maxf(float(_tree_depth), 1.0)
	var to_px := func(nx: float, ny: float) -> Vector2:
		return Vector2(body.position.x + 40.0 + nx / cols * (body.size.x - 80.0),
			body.position.y + 16.0 + ny / rows * (body.size.y - 40.0))
	_draw_tree_node(font, root, to_px)


func _tree_layout(node: Dictionary, depth: int) -> float:
	_tree_depth = maxi(_tree_depth, depth)
	if node.has("leaf") or not node.has("izq"):
		node["_x"] = _tree_leaf
		node["_y"] = float(depth)
		_tree_leaf += 1.0
		return node["_x"]
	var lx := _tree_layout(node["izq"], depth + 1)
	var rx := _tree_layout(node["der"], depth + 1)
	node["_x"] = (lx + rx) * 0.5
	node["_y"] = float(depth)
	return node["_x"]


func _draw_tree_node(font: Font, node: Dictionary, to_px: Callable) -> void:
	var p := to_px.call(node["_x"], node["_y"]) as Vector2
	# Primero las ramas (para que los nodos queden encima).
	if node.has("izq"):
		for side in [["izq", "sí"], ["der", "no"]]:
			var child: Dictionary = node[side[0]]
			var cp := to_px.call(child["_x"], child["_y"]) as Vector2
			draw_line(p, cp, RoninPalette.LINE.lightened(0.2), 1.2)
			draw_string(font, (p + cp) * 0.5 + Vector2(-6, -2), str(side[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, RoninPalette.MUTED)
			_draw_tree_node(font, child, to_px)
	# El nodo.
	if node.has("leaf"):
		var col: Color = CLASS_COLORS[int(node.get("cls", 0)) % CLASS_COLORS.size()]
		var t := str(node["leaf"])
		var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 14
		var r := Rect2(p.x - w * 0.5, p.y - 11, w, 22)
		draw_rect(r, Color(col, 0.25))
		draw_rect(r, col, false, 1.0)
		draw_string(font, Vector2(r.position.x + 7, p.y + 4), t, HORIZONTAL_ALIGNMENT_LEFT, w, 12, RoninPalette.TEXT)
	else:
		var q := str(node.get("q", "?"))
		var w2 := font.get_string_size(q, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 14
		var r2 := Rect2(p.x - w2 * 0.5, p.y - 11, w2, 22)
		draw_rect(r2, RoninPalette.PANEL_ALT)
		draw_rect(r2, RoninPalette.CYAN, false, 1.0)
		draw_string(font, Vector2(r2.position.x + 7, p.y + 4), q, HORIZONTAL_ALIGNMENT_LEFT, w2, 12, RoninPalette.CYAN)


## Dibuja un texto partiéndolo en como mucho `max_lines` líneas que quepan en `width`.
func _draw_wrapped(font: Font, text: String, pos: Vector2, width: float, px: int, color: Color, max_lines: int) -> void:
	var words := text.split(" ")
	var lines: Array[String] = [""]
	for w in words:
		var probe := (lines[-1] + " " + w).strip_edges()
		if font.get_string_size(probe, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > width and lines[-1] != "":
			if lines.size() >= max_lines:
				lines[-1] = lines[-1].substr(0, max(0, lines[-1].length() - 1)) + "…"
				break
			lines.append(w)
		else:
			lines[-1] = probe
	for i in lines.size():
		draw_string(font, pos + Vector2(0, i * (px + 3)), lines[i], HORIZONTAL_ALIGNMENT_LEFT, width, px, color)
