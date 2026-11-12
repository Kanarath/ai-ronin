class_name TitleBackdrop
extends Control
## Fondo de la pantalla de título, dibujado con _draw() (sin imágenes): cielo nocturno, luna
## con bandas de nube al estilo de los grabados japoneses, montañas en capas, un torii junto
## al agua, la retícula del laboratorio en el suelo y pétalos de sakura que caen.
## Con «movimiento reducido» los pétalos se quedan quietos.

const SKY_TOP := Color("#070A0F")
const SKY_LOW := Color("#152033")
const MOON := Color("#EFE6CF")
const INK := Color("#05070A")
const TORII := Color("#8E2A2A")
const PETAL := Color("#F2B8C6")
const PETALS := 46

var reduced_motion := false:
	set(v):
		reduced_motion = v
		set_process(not v)
var _petals: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.seed = 2026
	for i in PETALS:
		_petals.append(_new_petal(true))
	resized.connect(queue_redraw)
	set_process(not reduced_motion)


func _process(delta: float) -> void:
	_time += delta
	for p in _petals:
		p["pos"] += p["vel"] * delta + Vector2(sin(_time * p["sway"] + p["phase"]) * 18.0 * delta, 0.0)
		p["rot"] += p["spin"] * delta
		if p["pos"].y > size.y + 20.0 or p["pos"].x < -30.0:
			p.merge(_new_petal(false), true)
	queue_redraw()


func _new_petal(anywhere: bool) -> Dictionary:
	var w := maxf(size.x, 1600.0)
	var h := maxf(size.y, 900.0)
	var pos := Vector2(_rng.randf_range(0.0, w * 1.2), _rng.randf_range(-h, h) if anywhere else _rng.randf_range(-60.0, -10.0))
	return {
		"pos": pos, "vel": Vector2(_rng.randf_range(-38.0, -14.0), _rng.randf_range(22.0, 48.0)),
		"rot": _rng.randf_range(0.0, TAU), "spin": _rng.randf_range(-1.6, 1.6),
		"size": _rng.randf_range(3.5, 7.5), "sway": _rng.randf_range(0.6, 1.4), "phase": _rng.randf_range(0.0, TAU),
		"alpha": _rng.randf_range(0.35, 0.85),
	}


func _draw() -> void:
	var w := size.x
	var h := size.y
	var horizon := h * 0.68
	# Cielo
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, horizon), Vector2(0, horizon)]),
			PackedColorArray([SKY_TOP, SKY_TOP, SKY_LOW, SKY_LOW]))
	_draw_stars(w, horizon)
	# Luna con halo y bandas de nube
	var mc := Vector2(w * 0.70, h * 0.30)
	var mr := h * 0.16
	for i in 6:
		draw_circle(mc, mr * (1.0 + 0.18 * (i + 1)), Color(MOON, 0.025))
	draw_circle(mc, mr, MOON)
	draw_circle(mc + Vector2(mr * 0.28, -mr * 0.2), mr * 0.18, Color("#E3D8BC"))
	draw_circle(mc + Vector2(-mr * 0.35, mr * 0.3), mr * 0.11, Color("#E3D8BC"))
	for band: Array in [[-0.15, 1.5, 0.05], [0.22, 1.9, 0.035], [0.48, 1.3, 0.04]]:
		var y: float = mc.y + mr * band[0]
		var half: float = mr * band[1]
		var x0: float = mc.x - half + mr * 0.4 * sin(band[0] * 9.0)
		draw_rect(Rect2(x0, y, half * 2.0, mr * band[2]), SKY_LOW.lerp(SKY_TOP, 0.4))
	# Montañas: tres capas, de la lejana (más clara) a la cercana
	_draw_range(horizon, h * 0.30, 11, Color("#1B2638"), 3)
	_draw_range(horizon, h * 0.20, 7, Color("#111A28"), 11)
	_draw_range(horizon, h * 0.11, 5, Color("#0B111A"), 23)
	# Agua y suelo: reflejo de la luna y retícula del laboratorio en perspectiva
	draw_rect(Rect2(0, horizon, w, h - horizon), INK)
	for i in 9:
		var y := horizon + 10.0 + i * 13.0
		var seg := mr * (1.1 - i * 0.1) * (0.8 + 0.2 * sin(_time * 0.8 + i))
		draw_line(Vector2(mc.x - seg, y), Vector2(mc.x + seg, y), Color(MOON, 0.22 - i * 0.02), 2.0)
	var vanish := Vector2(w * 0.5, horizon)
	for i in range(-12, 13):
		draw_line(vanish + Vector2(i * 14.0, 0), Vector2(w * 0.5 + i * w * 0.12, h), Color(RoninPalette.TEAL, 0.07), 1.0)
	for i in 7:
		var f := pow((i + 1) / 7.0, 2.0)
		var y := horizon + (h - horizon) * f
		draw_line(Vector2(0, y), Vector2(w, y), Color(RoninPalette.TEAL, 0.05 + 0.04 * f), 1.0)
	_draw_torii(Vector2(w * 0.86, horizon + 4.0), h * 0.26)
	# Pétalos
	for p in _petals:
		_draw_petal(p)


func _draw_stars(w: float, horizon: float) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 11
	for i in 90:
		var pos := Vector2(r.randf() * w, r.randf() * horizon * 0.85)
		var tw := 0.5 + 0.5 * sin(_time * r.randf_range(0.5, 2.0) + i)
		draw_circle(pos, r.randf_range(0.6, 1.4), Color(1, 1, 1, r.randf_range(0.08, 0.35) * (0.6 + 0.4 * tw)))


## Cordillera con picos deterministas (la misma semilla siempre dibuja las mismas montañas).
func _draw_range(base_y: float, height: float, peaks: int, color: Color, seed_value: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	var pts := PackedVector2Array([Vector2(0, base_y + 2)])
	var step := size.x / peaks
	for i in peaks + 1:
		var x := i * step
		pts.append(Vector2(x - step * 0.5, base_y - height * r.randf_range(0.25, 0.55)))
		pts.append(Vector2(x, base_y - height * r.randf_range(0.6, 1.0)))
	pts.append(Vector2(size.x, base_y + 2))
	draw_colored_polygon(pts, color)


## Torii en silueta: dos pilares, el travesaño de abajo (nuki) y el de arriba curvado (kasagi).
func _draw_torii(foot: Vector2, height: float) -> void:
	var span := height * 0.78
	var pw := height * 0.06
	var dark := TORII.darkened(0.35)
	for side in [-1.0, 1.0]:
		var x: float = foot.x + side * span * 0.5
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - pw * 0.5 - side * pw * 0.25, foot.y), Vector2(x + pw * 0.5 - side * pw * 0.25, foot.y),
			Vector2(x + pw * 0.4, foot.y - height * 0.86), Vector2(x - pw * 0.4, foot.y - height * 0.86)]), dark)
	var nuki_y := foot.y - height * 0.66
	draw_rect(Rect2(foot.x - span * 0.62, nuki_y, span * 1.24, height * 0.05), dark)
	draw_rect(Rect2(foot.x - pw * 0.3, foot.y - height * 0.84, pw * 0.6, height * 0.18), dark)
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	var n := 24
	for i in n + 1:
		var u := float(i) / n * 2.0 - 1.0
		var x := foot.x + u * span * 0.8
		var lift := height * 0.09 * u * u
		top.append(Vector2(x, foot.y - height * 0.97 - lift))
		bottom.append(Vector2(x, foot.y - height * 0.87 - lift * 0.7))
	bottom.reverse()
	draw_colored_polygon(top + bottom, TORII)
	draw_polyline(top, Color(MOON, 0.18), 1.5)
	# Reflejo en el agua, tenue y cortado en bandas
	for i in 6:
		var y := foot.y + 6.0 + i * 9.0
		draw_line(Vector2(foot.x - span * 0.55, y), Vector2(foot.x + span * 0.55, y), Color(TORII, 0.10 - i * 0.012), 3.0)


func _draw_petal(p: Dictionary) -> void:
	var s: float = p["size"]
	var pts := PackedVector2Array()
	for i in 10:
		var a := TAU * i / 10.0
		# Óvalo con una muesca en la punta, como un pétalo de cerezo
		var r := s * (1.0 - 0.35 * pow(maxf(0.0, cos(a)), 8.0))
		pts.append(Vector2(cos(a) * r, sin(a) * r * 0.55).rotated(p["rot"]) + p["pos"])
	draw_colored_polygon(pts, Color(PETAL, p["alpha"]))
