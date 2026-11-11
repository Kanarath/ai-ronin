class_name Sfx
extends Node
## Sonidos suaves del Dojo, sintetizados al arrancar (no hay ficheros de audio ni descargas):
##   paso    objetivo cumplido (dos notas que suben)
##   mision  misión completada (acorde corto)
##   nivel   subida de nivel (arpegio)
##   sello   sello conseguido (campanita)
## Volumen bajo a propósito: acompañan, no distraen. «ajustes sonido off» los quita.

const RATE := 22050
const VOLUME_DB := -16.0

var enabled := true
var _streams: Dictionary = {}
var _player: AudioStreamPlayer


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.volume_db = VOLUME_DB
	add_child(_player)
	# Notas en Hz: una escala pentatónica suena «oriental» y nunca desafina entre sí.
	_streams["paso"] = _tones([[659.3, 0.07], [880.0, 0.11]])
	_streams["mision"] = _tones([[523.3, 0.09], [659.3, 0.09], [784.0, 0.22]])
	_streams["nivel"] = _tones([[523.3, 0.07], [659.3, 0.07], [784.0, 0.07], [1046.5, 0.26]])
	_streams["sello"] = _tones([[1318.5, 0.05], [1760.0, 0.3]], 0.6)


func play(sound: String) -> void:
	if not enabled or not _streams.has(sound) or _player == null:
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
