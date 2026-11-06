class_name RoninFonts
extends RefCounted
## Fuentes del sistema (sin descargas). Se usa la primera disponible de cada lista.

static var _mono: SystemFont
static var _sans: SystemFont


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
