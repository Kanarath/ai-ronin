class_name Sfx
extends Node
## Sonidos suaves del Dojo, sintetizados al arrancar (no hay ficheros de audio ni descargas):
##   paso    objetivo cumplido (dos notas que suben)
##   mision  misión completada (acorde corto)
##   nivel   subida de nivel (arpegio)
##   sello   sello conseguido (campanita)
##   koto_1…koto_3  cuerdas pulsadas para la intro (síntesis Karplus-Strong)
##   filo    el tajo de katana de la intro (ruido filtrado y un brillo metálico)
##   menu    clic suave al moverse por el menú
##   teclas  toques muy cortos y apagados al escribir (cada tecla, una nota de la escala;
##           si escribes rápido se atenúan y, muy rápido, se saltan: nunca se amontonan)
## Volumen bajo a propósito: acompañan, no distraen. «ajustes sonido off» los quita y el
## volumen (0–100) se elige en Opciones.

const RATE := 22050
const VOLUME_DB := -16.0

var enabled := true
## Sonido de teclas (opción propia, aparte del sonido general): volumen 0–100, 0 = apagado.
var keys_enabled := true
var keys_volume := 60
var _key_streams: Array[AudioStreamWAV] = []
var _key_players: Array[AudioStreamPlayer] = []
var _key_next := 0
var _last_key_ms := -1000
## Volumen de 0 a 100 (100 = el nivel de diseño, VOLUME_DB).
var volume := 80:
	set(v):
		volume = clampi(v, 0, 100)
		if _player != null:
			_player.volume_db = _db()
var _streams: Dictionary = {}
var _player: AudioStreamPlayer


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.volume_db = _db()
	add_child(_player)
	# Notas en Hz: una escala pentatónica suena «oriental» y nunca desafina entre sí.
	_streams["paso"] = _tones([[659.3, 0.07], [880.0, 0.11]])
	_streams["mision"] = _tones([[523.3, 0.09], [659.3, 0.09], [784.0, 0.22]])
	_streams["nivel"] = _tones([[523.3, 0.07], [659.3, 0.07], [784.0, 0.07], [1046.5, 0.26]])
	_streams["sello"] = _tones([[1318.5, 0.05], [1760.0, 0.3]], 0.6)
	# Escala hirajōshi en la (la, si, do, mi, fa): suena a koto sin imitar ninguna pieza.
	_streams["koto_1"] = _pluck(220.0, 1.6)
	_streams["koto_2"] = _pluck(329.6, 1.4)
	_streams["koto_3"] = _pluck(261.6, 2.2)
	_streams["filo"] = _blade()
	_streams["menu"] = _tones([[1046.5, 0.035]], 0.1)
	# Teclas: pentatónica grave (re, mi, sol, la, si) y un «toc» más grave para espacio e Intro.
	for f: float in [587.3, 659.3, 784.0, 880.0, 987.8, 392.0, 329.6]:
		_key_streams.append(_tap(f))
	for i in 3:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_key_players.append(p)


## Volumen elegido aplicado en el reproductor. Por debajo de 1 se silencia del todo.
func set_from_settings(s: Dictionary) -> void:
	enabled = bool(s.get("sonido", true))
	keys_enabled = bool(s.get("teclas", true))
	keys_volume = clampi(int(s.get("teclas_volumen", 60)), 0, 100)
	volume = int(s.get("volumen", 80))


func _db() -> float:
	if volume <= 0:
		return -80.0
	return VOLUME_DB + linear_to_db(volume / 100.0)


## Toque de tecla: con el volumen de teclas al 100 % suena 4 dB por debajo del resto de
## sonidos. Más de una tecla cada 70 ms se atenúa 5 dB y más de una cada 30 ms ni suena.
func key(keycode: int) -> void:
	if not enabled or not keys_enabled or keys_volume <= 0 or volume <= 0 or _key_streams.is_empty():
		return
	var now := Time.get_ticks_msec()
	var gap := now - _last_key_ms
	if gap < 30:
		return
	_last_key_ms = now
	var idx := keycode % 5
	if keycode == KEY_SPACE or keycode == KEY_ENTER or keycode == KEY_KP_ENTER:
		idx = 5
	elif keycode == KEY_BACKSPACE or keycode == KEY_DELETE:
		idx = 6
	var p := _key_players[_key_next]
	_key_next = (_key_next + 1) % _key_players.size()
	p.volume_db = _db() - 4.0 + linear_to_db(keys_volume / 100.0) - (5.0 if gap < 70 else 0.0)
	p.stream = _key_streams[idx]
	p.play()


func play(sound: String) -> void:
	if not enabled or volume <= 0 or not _streams.has(sound) or _player == null:
		return
	# Un reproductor por sonido en curso: las notas de la intro se solapan como en un koto.
	if _player.playing:
		var extra := AudioStreamPlayer.new()
		extra.volume_db = _db()
		extra.stream = _streams[sound]
		add_child(extra)
		extra.finished.connect(extra.queue_free)
		extra.play()
		return
	_player.stream = _streams[sound]
	_player.play()


## Sintetiza notas seguidas: senoide con un poco de armónico y una envolvente suave
## (ataque corto y caída exponencial) para que no «chasquee».
func _tones(notes: Array, brightness: float = 0.25) -> AudioStreamWAV:
	var data := PackedByteArray()
	for n: Array in notes:
		var freq: float = n[0]
		var dur: float = n[1]
		var count := int(RATE * dur)
		for i in count:
			var t := float(i) / RATE
			var env := minf(1.0, t / 0.008) * exp(-4.0 * t / dur)
			var s := sin(TAU * freq * t) + brightness * sin(TAU * freq * 2.0 * t)
			var v := int(clampf(s * env * 0.45, -1.0, 1.0) * 32767.0)
			data.append(v & 0xFF)
			data.append((v >> 8) & 0xFF)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


## Cuerda pulsada (Karplus-Strong): un ruido corto que recorre un bucle con media de dos
## muestras; el bucle filtra los agudos poco a poco y queda un tono que se apaga solo.
func _pluck(freq: float, dur: float) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(freq * 100.0)
	var period := int(RATE / freq)
	var buf := PackedFloat32Array()
	for i in period:
		buf.append(rng.randf_range(-1.0, 1.0))
	var data := PackedByteArray()
	var count := int(RATE * dur)
	for i in count:
		var j := i % period
		var nxt := buf[(j + 1) % period]
		var v := buf[j]
		buf[j] = 0.996 * 0.5 * (v + nxt)
		var fade := minf(1.0, float(count - i) / (RATE * 0.05))
		_put(data, v * 0.5 * fade)
	return _wav(data)


## Tajo: ruido que se aclara (se le quita el grave) y un brillo agudo que vibra y se apaga.
func _blade() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var data := PackedByteArray()
	var dur := 0.9
	var count := int(RATE * dur)
	var prev_in := 0.0
	var prev_out := 0.0
	for i in count:
		var t := float(i) / RATE
		var n := rng.randf_range(-1.0, 1.0)
		var hp := 0.97 * (prev_out + n - prev_in)  # paso alto de un polo
		prev_in = n
		prev_out = hp
		var swoosh := hp * minf(1.0, t / 0.02) * exp(-t / 0.09) * 0.55
		var ring := (sin(TAU * 3520.0 * t) + 0.5 * sin(TAU * 5274.0 * t)) * exp(-t / 0.35) * minf(1.0, t / 0.03) * 0.18
		_put(data, swoosh + ring * (1.0 + 0.15 * sin(TAU * 9.0 * t)))
	return _wav(data)


static func _put(data: PackedByteArray, x: float) -> void:
	var v := int(clampf(x, -1.0, 1.0) * 32767.0)
	data.append(v & 0xFF)
	data.append((v >> 8) & 0xFF)


func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


## Toque de tecla de unos 25 ms: seno grave con un golpecito de ruido filtrado al principio
## (como una tecla de madera) y caída muy rápida, sin agudos que piquen.
func _tap(freq: float) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(freq)
	var data := PackedByteArray()
	var count := int(RATE * 0.025)
	var lp := 0.0
	for i in count:
		var t := float(i) / RATE
		lp += 0.18 * (rng.randf_range(-1.0, 1.0) - lp)
		var body := sin(TAU * freq * t) * exp(-t / 0.006)
		var click := lp * exp(-t / 0.0015) * 0.6
		_put(data, (body * 0.5 + click) * minf(1.0, t / 0.0008))
	return _wav(data)
