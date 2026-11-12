class_name EnsoMark
extends Control
## Ensō dorado y semitransparente que asoma por la esquina inferior derecha del Dojo.
## Es solo decoración: no recibe clics y deja leer el texto que tenga debajo. Cuando RONIN
## habla «respira» un instante (salvo con movimiento reducido).

const GOLD := Color("#D4A72C")
const BRISTLES := 11
const BASE_ALPHA := 0.13

var reduced_motion := false
var _pulse := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func pulse() -> void:
	if reduced_motion:
		return
	_pulse = 1.0
	set_process(true)


func _process(delta: float) -> void:
	_pulse = maxf(0.0, _pulse - delta / 1.2)
	queue_redraw()
	if _pulse <= 0.0:
		set_process(false)


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.4
	var alpha := BASE_ALPHA + 0.07 * sin(_pulse * PI)
	var a0 := deg_to_rad(-70.0)
	var sweep := deg_to_rad(330.0)
	var steps := 120
	var noise := RandomNumberGenerator.new()
	for b in BRISTLES:
		noise.seed = 100 + b
		var lane := (float(b) / (BRISTLES - 1)) * 2.0 - 1.0
		var pts := PackedVector2Array()
		for i in steps + 1:
			var u := float(i) / steps
			var width := r * 0.16 * (1.0 - 0.75 * u) * (0.9 + 0.1 * sin(u * 23.0))
			var ang := a0 + sweep * u
			pts.append(c + Vector2(cos(ang), sin(ang)) * (r + lane * width + noise.randf_range(-1.0, 1.0)))
		var dry := 1.0 - absf(lane) * 0.45
		var cut := int(pts.size() * clampf(dry + 0.15, 0.0, 1.0))
		if cut >= 2:
			draw_polyline(pts.slice(0, cut), Color(GOLD, alpha * (0.6 + 0.4 * dry)), 3.0, true)
