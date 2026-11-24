class_name RoninFonts
extends RefCounted
## Fuentes del sistema (sin descargas en escritorio). En el navegador NO hay fuentes del sistema, así
## que los caracteres japoneses (kanji y kana) no renderizarían. Para arreglarlo se incluye un
## subconjunto de Noto Sans JP (OFL, ~120 KB, solo los glifos que usa el juego) como *fallback* de las
## tres fuentes: en escritorio no se usa (las fuentes del sistema ya tienen esos glifos); en web cubre
## los CJK que la fuente latina por defecto no trae.

const JP_FALLBACK_PATH := "res://ui/theme/jp_fallback.ttf"

static var _mono: SystemFont
static var _sans: SystemFont
static var _jp: SystemFont
static var _fallback_font: FontFile


static func _jp_fallback() -> FontFile:
	if _fallback_font == null and ResourceLoader.exists(JP_FALLBACK_PATH):
		_fallback_font = load(JP_FALLBACK_PATH)
	return _fallback_font


## Engancha la fuente CJK incluida como fallback (para los glifos que la primaria no tenga).
static func _add_fallback(f: SystemFont) -> SystemFont:
	var fb := _jp_fallback()
	if fb != null:
		f.fallbacks = [fb]
	return f


static func mono() -> Font:
	if _mono == null:
		_mono = SystemFont.new()
		_mono.font_names = PackedStringArray(["JetBrains Mono", "Cascadia Mono", "Consolas", "DejaVu Sans Mono", "Courier New"])
		_add_fallback(_mono)
	return _mono


static func sans() -> Font:
	if _sans == null:
		_sans = SystemFont.new()
		_sans.font_names = PackedStringArray(["IBM Plex Sans", "Segoe UI", "Inter", "DejaVu Sans", "Arial"])
		_add_fallback(_sans)
	return _sans


## Kanji de la pantalla de título. Yu Gothic viene con Windows 10 y 11; si no está, Godot busca otra
## fuente del sistema que tenga los caracteres, y en web usa el fallback incluido.
static func jp(bold: bool = false) -> Font:
	if _jp == null:
		_jp = SystemFont.new()
		_jp.font_names = PackedStringArray(["Yu Mincho", "Yu Gothic", "Noto Serif JP", "Noto Sans JP", "Meiryo", "MS Gothic"])
		_add_fallback(_jp)
	if not bold:
		return _jp
	var b := SystemFont.new()
	b.font_names = _jp.font_names
	b.font_weight = 700
	_add_fallback(b)
	return b
