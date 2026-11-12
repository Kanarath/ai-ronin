class_name RoninFonts
extends RefCounted
## Fuentes del sistema (sin descargas). Se usa la primera disponible de cada lista.

static var _mono: SystemFont
static var _sans: SystemFont
static var _jp: SystemFont


static func mono() -> Font:
	if _mono == null:
		_mono = SystemFont.new()
		_mono.font_names = PackedStringArray(["JetBrains Mono", "Cascadia Mono", "Consolas", "DejaVu Sans Mono", "Courier New"])
	return _mono


static func sans() -> Font:
	if _sans == null:
		_sans = SystemFont.new()
		_sans.font_names = PackedStringArray(["IBM Plex Sans", "Segoe UI", "Inter", "DejaVu Sans", "Arial"])
	return _sans


## Kanji de la pantalla de título. Yu Gothic viene con Windows 10 y 11; si no está, Godot
## busca otra fuente del sistema que tenga los caracteres.
static func jp(bold: bool = false) -> Font:
	if _jp == null:
		_jp = SystemFont.new()
		_jp.font_names = PackedStringArray(["Yu Mincho", "Yu Gothic", "Noto Serif JP", "Noto Sans JP", "Meiryo", "MS Gothic"])
	if not bold:
		return _jp
	var b := SystemFont.new()
	b.font_names = _jp.font_names
	b.font_weight = 700
	return b
