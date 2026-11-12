class_name IntroOverlay
extends Control
## Animación de entrada (unos 5 s; cualquier tecla o clic la salta):
##   1. Un ensō (円相, el círculo zen de un solo trazo) se pinta con pincel seco
##      mientras suenan tres notas de koto.
##   2. Dentro aparece 浪人 («rōnin»: el samurái sin señor, el que sigue su propio camino).
##   3. Un tajo de katana cruza la pantalla y abre el título; la capa se desvanece.
## Todo con _draw(); los sonidos se sintetizan en Sfx.

signal finished

const INK := Color("#E8E0CC")
const BG := Color("#05070A")
const ENSO_START := 0.35
const ENSO_END := 2.15
const KANJI_IN := 1.9
const SLASH_AT := 3.05
const SLASH_TIME := 0.16
const FADE_AT := 3.7
const FADE_TIME := 0.9
const BRISTLES := 11

var sfx: Sfx
var _t := 0.0
var _fired: Dictionary = {}
var _skipping := false
var _alpha := 1.0
var _kanji: Font
var _title: Font


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_kanji = RoninFonts.jp(true)
	_title = RoninFonts.sans()


func _process(delta: float) -> void:
	_t += delta
	for cue: Array in [[0.45, "koto_1"], [1.05, "koto_2"], [1.65, "koto_3"], [SLASH_AT, "filo"]]:
		if _t >= cue[0] and not _fired.has(cue[1]) and not _skipping:
			_fired[cue[1]] = true
			if sfx != null:
				sfx.play(cue[1])
	if _skipping:
		_alpha -= delta / 0.25
	elif _t > FADE_AT:
		_alpha = 1.0 - (_t - FADE_AT) / FADE_TIME
	if _alpha <= 0.0:
		finished.emit()
		queue_free()
		return
	modulate.a = clampf(_alpha, 0.0, 1.0)
	queue_redraw()


func _gui_input(e: InputEvent) -> void:
	if (e is InputEventMouseButton and e.pressed) or (e is InputEventKey and e.pressed):
		skip()
		accept_event()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed:
		skip()
		get_viewport().set_input_as_handled()


func skip() -> void:
	_skipping = true


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	var c := Vector2(w * 0.5, h * 0.47)
	var r := h * 0.2
	var opened := clampf((_t - SLASH_AT) / SLASH_TIME, 0.0, 1.0)
	# Tras el tajo, el ensō y el kanji se separan un poco en diagonal, como cortados.
	var split := Vector2(1, -0.35).normalized() * 14.0 * ease(opened, 0.3)
	_draw_enso(c, r, clampf((_t - ENSO_START) / (ENSO_END - ENSO_START), 0.0, 1.0), split)
	var ka := clampf((_t - KANJI_IN) / 0.7, 0.0, 1.0)
	if ka > 0.0:
		var fs := int(r * 0.78)
		var txt := "浪人"
		var tw := _kanji.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(_kanji, c + Vector2(-tw * 0.5, fs * 0.36) - split, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(INK, ka))
		var sub := "rōnin · el que sigue su propio camino"
		var sw := _title.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		draw_string(_title, Vector2(c.x - sw * 0.5, c.y + r + 58.0), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(RoninPalette.MUTED, ka))
	if opened > 0.0:
		_draw_slash(w, h, opened)
		var ta := clampf((_t - SLASH_AT - 0.1) / 0.4, 0.0, 1.0)
		var t1 := "AI RONIN"
		var t1w := _title.get_string_size(t1, HORIZONTAL_ALIGNMENT_LEFT, -1, 44).x
		draw_string(_title, Vector2(c.x - t1w * 0.5, c.y + r + 118.0), t1, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color(RoninPalette.GOLD, ta))
	if not _skipping and _t < FADE_AT:
		var hint := "pulsa cualquier tecla para saltar"
		draw_string(_title, Vector2(w - 300.0, h - 28.0), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(RoninPalette.MUTED, 0.5))


## Pincel seco: varias «cerdas» paralelas; el trazo empieza grueso y cargado de tinta y se
## adelgaza y se abre en huecos hacia el final, que queda sin cerrar (así se pinta un ensō).
func _draw_enso(c: Vector2, r: float, p: float, split: Vector2) -> void:
	if p <= 0.0:
		return
	var a0 := deg_to_rad(-70.0)
	var sweep := deg_to_rad(330.0)
	var steps := 160
	var drawn := int(steps * ease(p, 0.6))
	var noise := RandomNumberGenerator.new()
	for b in BRISTLES:
		noise.seed = 100 + b
		var lane := (float(b) / (BRISTLES - 1)) * 2.0 - 1.0
		var pts := PackedVector2Array()
		for i in drawn + 1:
			var u := float(i) / steps
			var width := r * 0.16 * (1.0 - 0.75 * u) * (0.9 + 0.1 * sin(u * 23.0))
			var ang := a0 + sweep * u
			var rad := r + lane * width + noise.randf_range(-1.0, 1.0)
			pts.append(c + Vector2(cos(ang), sin(ang)) * rad - split * (1.0 if u > 0.5 else -1.0) * 0.5)
		# Las cerdas de los bordes se quedan sin tinta antes: huecos del pincel seco.
		var dry := 1.0 - absf(lane) * 0.45
		var cut := int(pts.size() * clampf(dry + 0.15, 0.0, 1.0))
		if cut >= 2:
			draw_polyline(pts.slice(0, cut), Color(INK, 0.55 + 0.4 * dry), 2.4, true)


## Tajo de katana: una línea fina y brillante que cruza en diagonal, con un destello.
func _draw_slash(w: float, h: float, p: float) -> void:
	var a := Vector2(-w * 0.05, h * 0.78)
	var b := Vector2(w * 1.05, h * 0.18)
	var tip := a.lerp(b, ease(p, 0.4))
	var fade := clampf(1.0 - (_t - SLASH_AT - SLASH_TIME) / 0.5, 0.0, 1.0)
	draw_line(a, tip, Color(1, 1, 1, 0.9 * fade), 2.0, true)
	draw_line(a, tip, Color(RoninPalette.CYAN, 0.25 * fade), 8.0, true)
	if p < 1.0:
		draw_circle(tip, 5.0, Color(1, 1, 1, 0.9))
	elif fade > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.12 * fade * fade))
