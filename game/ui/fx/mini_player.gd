class_name MiniPlayer
extends HBoxContainer
## Mini reproductor de la música de fondo: ⏮ ⏯ ⏭, nombre de la pista y volumen de la música
## (aparte del de los efectos). Se usa en el título y en la barra superior del Dojo.
## No coge el foco del teclado: así no roba las teclas a la consola ni al menú.

var _music: MusicPlayer
var _title: Label
var _play: Button
var _vol: HSlider
var _compact := false


func _init(music: MusicPlayer, compact: bool = false) -> void:
	_music = music
	_compact = compact


func _ready() -> void:
	add_theme_constant_override("separation", 4)
	var note := Label.new()
	note.text = "♪"
	note.add_theme_color_override("font_color", RoninPalette.GOLD)
	add_child(note)
	_title = Label.new()
	_title.custom_minimum_size = Vector2(150 if _compact else 260, 0)
	_title.clip_text = true
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.add_theme_color_override("font_color", RoninPalette.MUTED)
	_title.add_theme_font_size_override("font_size", 13 if _compact else 15)
	_title.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_title)
	add_child(_button("◁◁", "Pista anterior (o volver a empezar esta)", func() -> void: _music.prev()))
	_play = _button("❚❚", "Pausar o reanudar la música", func() -> void: _music.toggle())
	add_child(_play)
	add_child(_button("▷▷", "Siguiente pista", func() -> void: _music.next()))
	_vol = HSlider.new()
	_vol.min_value = 0
	_vol.max_value = 100
	_vol.step = 5
	_vol.custom_minimum_size = Vector2(70 if _compact else 110, 0)
	_vol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_vol.focus_mode = Control.FOCUS_NONE
	_vol.tooltip_text = "Volumen de la música"
	_vol.value_changed.connect(func(v: float) -> void: _music.set_volume(int(v)))
	add_child(_vol)
	if _music != null:
		_music.changed.connect(_refresh)
	_refresh()


func _button(text: String, tip: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 14 if _compact else 17)
	b.pressed.connect(action)
	return b


func _refresh() -> void:
	if _music == null:
		visible = false
		return
	_title.text = _music.track_title()
	_title.tooltip_text = _music.track_title()
	_play.text = "❚❚" if _music.playing else "▷"
	_vol.set_value_no_signal(_music.volume)
