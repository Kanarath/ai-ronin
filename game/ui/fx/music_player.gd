class_name MusicPlayer
extends Node
## Música de fondo lo-fi generativa. Cada pista de content/musica.json se toca en directo
## combinando muestras cortas (assets/musica, generadas con tools/gen_muestras_lofi.py):
## acordes de piano eléctrico, bajo, batería con swing, melodía de koto o shakuhachi en una
## escala japonesa y un fondo de lluvia o vinilo. Pasa por un bus propio («Musica») con un
## poco de reverb y un paso bajo para el tono cálido. Solo reproduce sonidos: gasta muy poco.
##
## Además, cualquier .ogg o .mp3 que pongas en la carpeta musica/ (junto al proyecto o al
## .exe) entra en la lista de pistas.
##
## Forma de cada pista (compases): intro 4 · A 16 · pausa 4 · A' 16 · final 4 = 44 compases.

signal changed()

const DATA := "res://content/musica.json"
const SAMPLES := "res://assets/musica/"
const BUS := "Musica"
const VOICES := 24
const DEFAULT_VOLUME := 35
const FORM := [["intro", 4], ["a", 16], ["pausa", 4], ["b", 16], ["final", 4]]
## Muestras con su nota MIDI de origen (las notas se afinan desde la más cercana).
const PITCHED := {"ep": [["ep_c3", 48], ["ep_c4", 60], ["ep_c5", 72]], "bajo": [["bajo_c2", 36]],
		"koto": [["koto_c4", 60], ["koto_c5", 72]], "shakuhachi": [["shakuhachi_c5", 72]], "pad": [["pad_c4", 60]],
		"furin": [["furin", 81]]}

var tracks: Array[Dictionary] = []
var current := 0
var playing := false
var volume := DEFAULT_VOLUME

var _prefs: GameSettings
var _samples: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _voice_next := 0
var _ambience: AudioStreamPlayer
var _file_player: AudioStreamPlayer
var _queue: Array[Array] = []  # [tiempo, muestra, afinación, dB]
var _time := 0.0
var _next_step := 0
var _rng := RandomNumberGenerator.new()
var _melody: Dictionary = {}  # sección → Array de [paso, nota, duración]
var _bus := -1
## Para los tests: cuenta las notas en lugar de sonar (no hace falta estar en la escena).
var dry_run := false
var played := 0


func setup(prefs: GameSettings) -> void:
	_prefs = prefs
	_load_tracks()
	_make_bus()
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = BUS
		add_child(p)
		_voices.append(p)
	_ambience = AudioStreamPlayer.new()
	_ambience.bus = BUS
	add_child(_ambience)
	_file_player = AudioStreamPlayer.new()
	add_child(_file_player)
	_file_player.finished.connect(next)
	current = clampi(int(prefs.data.get("musica_pista", 0)), 0, maxi(0, tracks.size() - 1))
	_rng.seed = 1234 + current
	if not tracks.is_empty() and not _is_file():
		_ambience.stream = _samples.get(str(tracks[current].get("ambience", "vinilo")))
		_ambience.volume_db = -14.0
	elif _is_file():
		_file_player.stream = tracks[current]["stream"]
	set_volume(int(prefs.data.get("musica_volumen", DEFAULT_VOLUME)), false)
	# Sin ventana (tests, pruebas de humo) no arranca sola.
	if bool(prefs.data.get("musica", true)) and DisplayServer.get_name() != "headless":
		play()


func track_title() -> String:
	if tracks.is_empty():
		return "sin pistas"
	return str(tracks[current]["title"])


func toggle() -> void:
	if playing:
		pause()
	else:
		play()


func play() -> void:
	if tracks.is_empty():
		return
	playing = true
	if _is_file():
		if _file_player.stream_paused:
			_file_player.stream_paused = false
		elif not _file_player.playing:
			_file_player.play()
	else:
		if _ambience.stream != null:
			_ambience.stream_paused = false
			if not _ambience.playing:
				_ambience.play()
	_remember()


func pause() -> void:
	playing = false
	_file_player.stream_paused = true
	_ambience.stream_paused = true
	for v in _voices:
		v.stop()
	_queue.clear()
	_remember()


func next() -> void:
	_select((current + 1) % maxi(1, tracks.size()))


## Como en cualquier reproductor: si la pista lleva más de 5 s, vuelve a empezarla.
func prev() -> void:
	if _position() > 5.0:
		_select(current)
	else:
		_select((current - 1 + tracks.size()) % maxi(1, tracks.size()))


func set_volume(v: int, remember: bool = true) -> void:
	volume = clampi(v, 0, 100)
	var db := -80.0 if volume == 0 else -9.0 + linear_to_db(volume / 100.0)
	if _bus >= 0:
		AudioServer.set_bus_volume_db(_bus, db)
	if _file_player != null:
		_file_player.volume_db = db - 4.0
	if remember:
		_remember()


# ── Secuenciador ─────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if not playing or tracks.is_empty() or _is_file():
		return
	_time += delta
	var t: Dictionary = tracks[current]
	var total := _total_bars() * 16
	while _step_time(t, _next_step) <= _time:
		if _next_step >= total:
			next()
			return
		_fire_step(t, _next_step)
		_next_step += 1
	while not _queue.is_empty() and _queue[0][0] <= _time:
		var e: Array = _queue.pop_front()
		_play_sample(e[1], e[2], e[3])


func _step_time(t: Dictionary, step: int) -> float:
	var step_len := 60.0 / float(t["bpm"]) / 4.0
	var swing := (float(t["swing"]) - 0.5) * 2.0 * step_len if step % 2 == 1 else 0.0
	return step * step_len + swing


func _fire_step(t: Dictionary, step: int) -> void:
	var bar := step / 16
	var s := step % 16
	var section := _section(bar)
	var at := _step_time(t, step)
	var chords: Array = t["chords"]
	var per := int(t.get("bars_per_chord", 1))
	var chord: Dictionary = chords[(bar / per) % chords.size()]
	var chord_start := bar % per == 0
	var root := int(t["root"])
	var drums_on := section == "a" or section == "b"
	# Piano eléctrico: acorde al empezar el compás, rasgueado y con algo de variación.
	if s == 0 and chord_start and (section != "final" or bar < _total_bars() - 1):
		var vol := -6.0 if section in ["intro", "final", "pausa"] else -8.0
		var notes: Array = chord["notes"]
		for i in notes.size():
			_schedule(at + i * 0.018 + _rng.randf_range(0.0, 0.008), "ep", _fold(root + int(notes[i]), 52, 76), vol + _rng.randf_range(-1.5, 0.5))
	elif s == 10 and drums_on and _rng.randf() < 0.35:
		var notes2: Array = chord["notes"]
		_schedule(at, "ep", _fold(root + int(notes2[-1]), 52, 76), -14.0)
	# Colchón de cuerdas al cambiar de acorde (pistas con «pad»)
	if s == 0 and chord_start and bool(t.get("pad", false)) and section != "final":
		for n: int in chord["notes"]:
			_schedule(at, "pad", _fold(root + n, 55, 72), -15.0)
	# Campanilla de viento de vez en cuando (pistas con «chimes»)
	if bool(t.get("chimes", false)) and s % 4 == 2 and _rng.randf() < 0.07:
		var sc: Array = t["scale"]
		_schedule(at, "furin", _fold(root + 24 + int(sc[_rng.randi() % sc.size()]), 76, 93), -13.0)
	# Bajo
	if section != "intro" and section != "final":
		if s == 0 or (s == 8 and _rng.randf() < 0.5) or (s == 14 and drums_on and _rng.randf() < 0.25):
			var bnote := 36 + posmod(root + int(chord["bass"]) - 36, 12)
			_schedule(at + 0.01, "bajo", bnote, -5.0 if s == 0 else -9.0)
	# Batería
	if drums_on or (section == "pausa" and s % 4 == 0):
		var drums: Dictionary = t["drums"]
		for inst: String in drums:
			if section == "pausa" and inst != "charles":
				continue
			var pat := str(drums[inst])
			var c := pat[s] if s < pat.length() else "."
			if c == "x" or c == "o":
				var dv := (-4.0 if c == "x" else -11.0) + _rng.randf_range(-1.5, 1.0)
				_schedule(at + _rng.randf_range(0.0, 0.01), inst, -1, dv)
	# Melodía
	var lead := _lead(t, section)
	for n: Array in _melody_for(t, section, bar):
		if int(n[0]) == s:
			_schedule(at, lead, int(n[1]), (-9.0 if lead == "ep" else -7.0) + _rng.randf_range(-2.0, 0.0))


## Melodía de la sección: frases de 2 compases en la escala de la pista, paso a paso por
## grados cercanos (así suena cantable). La semilla depende de la pista y de la sección.
func _melody_for(t: Dictionary, section: String, bar: int) -> Array:
	if section == "intro" or section == "final":
		return []
	var key := "%s:%s:%d" % [t["id"], section, bar % 8]
	if _melody.has(key):
		return _melody[key]
	var r := RandomNumberGenerator.new()
	r.seed = int(t["seed"]) * 1000 + hash(key) % 997
	var scale: Array = t["scale"]
	var lead := _lead(t, section)
	var out: Array = []
	# Compases 0 y 2 de cada bloque llevan frase; 1 y 3, respuesta corta o silencio.
	var density := 0.28 if lead == "shakuhachi" else 0.5
	if bar % 2 == 1:
		density *= 0.45
	if section == "pausa":
		density *= 0.6
	var degree := r.randi_range(0, scale.size() - 1)
	var octave := 1
	var step := 0
	while step < 16:
		if r.randf() < density:
			degree += r.randi_range(-2, 2)
			if degree < 0:
				degree += scale.size()
				octave -= 1
			elif degree >= scale.size():
				degree -= scale.size()
				octave += 1
			octave = clampi(octave, 1, 2)
			var note := int(t["root"]) + 12 * octave + int(scale[degree])
			out.append([step, _fold(note, 62, 86), 1])
			step += 4 if lead == "shakuhachi" else (2 if r.randf() < 0.7 else 4)
		else:
			step += 2
	_melody[key] = out
	return out


## Instrumento de la melodía: «alterna» pone koto en A y shakuhachi en A' y en la pausa.
static func _lead(t: Dictionary, section: String) -> String:
	var lead := str(t.get("lead", "koto"))
	if lead == "alterna":
		return "koto" if section == "a" else "shakuhachi"
	return lead


func _schedule(at: float, sample: String, note: int, db: float) -> void:
	_queue.append([at, sample, note, db])
	_queue.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])


func _play_sample(sample: String, note: int, db: float) -> void:
	var stream: AudioStream
	var pitch := 1.0
	if PITCHED.has(sample):
		var best: Array = PITCHED[sample][0]
		for cand: Array in PITCHED[sample]:
			if absi(note - int(cand[1])) < absi(note - int(best[1])):
				best = cand
		stream = _samples.get(best[0])
		pitch = pow(2.0, (note - int(best[1])) / 12.0)
	else:
		stream = _samples.get(sample)
	if stream == null:
		return
	if dry_run:
		played += 1
		return
	var v := _voices[_voice_next]
	_voice_next = (_voice_next + 1) % _voices.size()
	v.stream = stream
	v.pitch_scale = pitch
	v.volume_db = db
	v.play()


# ── Pistas ───────────────────────────────────────────────────────────────────

func _select(i: int) -> void:
	for v in _voices:
		v.stop()
	_queue.clear()
	_file_player.stop()
	_ambience.stop()
	current = i
	_time = 0.0
	_next_step = 0
	_rng.seed = 1234 + i
	if _is_file():
		_file_player.stream = tracks[i]["stream"]
	else:
		_ambience.stream = _samples.get(str(tracks[i].get("ambience", "vinilo")))
		_ambience.volume_db = -14.0
	if playing and not dry_run:
		play()
	_remember()


func _is_file() -> bool:
	return not tracks.is_empty() and tracks[current].has("stream")


func _position() -> float:
	if _is_file():
		return _file_player.get_playback_position()
	return _time


func _section(bar: int) -> String:
	var acc := 0
	for part: Array in FORM:
		acc += int(part[1])
		if bar < acc:
			return part[0]
	return "final"


func _total_bars() -> int:
	var n := 0
	for part: Array in FORM:
		n += int(part[1])
	return n


static func _fold(note: int, lo: int, hi: int) -> int:
	while note < lo:
		note += 12
	while note > hi:
		note -= 12
	return note


func _remember() -> void:
	if _prefs == null:
		return
	_prefs.data["musica"] = playing
	_prefs.data["musica_pista"] = current
	_prefs.data["musica_volumen"] = volume
	_prefs.save()
	changed.emit()


func _load_tracks() -> void:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if d is Dictionary:
		for t: Dictionary in d.get("tracks", []):
			tracks.append(t)
	for n: String in ["ep_c3", "ep_c4", "ep_c5", "bajo_c2", "koto_c4", "koto_c5", "shakuhachi_c5",
			"bombo", "caja", "aro", "charles", "charles_abierto", "vinilo", "lluvia", "furin", "taiko", "pad_c4"]:
		var w: AudioStreamWAV = load(SAMPLES + n + ".wav")
		if w == null:
			continue
		if n == "vinilo" or n == "lluvia":
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = int(w.get_length() * w.mix_rate)
		_samples[n] = w
	_load_user_files()


## Tus propias pistas: .ogg o .mp3 en la carpeta musica/ junto al proyecto (o junto al .exe).
func _load_user_files() -> void:
	var dir := user_music_dir()
	var d := DirAccess.open(dir)
	if d == null:
		return
	var names := Array(d.get_files())
	names.sort()
	for f: String in names:
		var p := dir.path_join(f)
		var s: AudioStream = null
		match f.get_extension().to_lower():
			"ogg":
				s = AudioStreamOggVorbis.load_from_file(p)
			"mp3":
				s = AudioStreamMP3.load_from_file(p)
		if s != null:
			tracks.append({"id": f, "title": "♪ " + f.get_basename(), "stream": s})


static func user_music_dir() -> String:
	if OS.has_feature("template"):
		return OS.get_executable_path().get_base_dir().path_join("musica")
	return ProjectSettings.globalize_path("res://").path_join("../musica").simplify_path()


func _make_bus() -> void:
	_bus = AudioServer.get_bus_index(BUS)
	if _bus >= 0:
		return
	AudioServer.add_bus()
	_bus = AudioServer.bus_count - 1
	AudioServer.set_bus_name(_bus, BUS)
	AudioServer.set_bus_send(_bus, "Master")
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = 5200.0
	AudioServer.add_bus_effect(_bus, lp)
	var rv := AudioEffectReverb.new()
	rv.room_size = 0.55
	rv.damping = 0.6
	rv.wet = 0.2
	rv.dry = 0.9
	AudioServer.add_bus_effect(_bus, rv)
