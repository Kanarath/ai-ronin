class_name TextUtils
extends RefCounted
## Utilidades de texto del terminal.


## Distancia de edición de Levenshtein (inserciones, borrados y sustituciones).
static func levenshtein(a: String, b: String) -> int:
	var prev: Array[int] = []
	for j in b.length() + 1:
		prev.append(j)
	for i in range(1, a.length() + 1):
		var cur: Array[int] = [i]
		for j in range(1, b.length() + 1):
			var cost := 0 if a[i - 1] == b[j - 1] else 1
			cur.append(mini(mini(cur[j - 1] + 1, prev[j] + 1), prev[j - 1] + cost))
		prev = cur
	return prev[b.length()]


## Candidato más parecido (o "" si ninguno está razonablemente cerca).
static func closest(word: String, candidates: PackedStringArray) -> String:
	var best := ""
	var best_d := 1 << 30
	for c in candidates:
		var d := levenshtein(word.to_lower(), c.to_lower())
		if d < best_d:
			best_d = d
			best = c
	var limit := maxi(2, word.length() / 3)
	return best if best_d <= limit else ""


## Forma para comparar respuestas: minúsculas, sin tildes ni diéresis y con los espacios
## normalizados («La Revisión» y «la revision» son lo mismo).
static func fold(s: String) -> String:
	var out := s.strip_edges().to_lower()
	for pair in [["á", "a"], ["à", "a"], ["é", "e"], ["è", "e"], ["í", "i"], ["ï", "i"], ["ó", "o"], ["ò", "o"], ["ú", "u"], ["ü", "u"], ["ñ", "n"], ["ç", "c"]]:
		out = out.replace(pair[0], pair[1])
	while out.contains("  "):
		out = out.replace("  ", " ")
	return out


## Ancho máximo de una celda que no es la última de su fila: lo que pase se corta con «…»
## para que la tabla no se parta en varias líneas y las columnas sigan alineadas.
const MAX_CELL := 60


## Tabla de texto alineada para fuente monoespaciada. Mide el ancho en celdas de la fuente
## (display_width), no en caracteres: un emoji ocupa dos celdas y un acento combinado, cero.
static func table(headers: PackedStringArray, rows: Array, max_cell: int = MAX_CELL) -> PackedStringArray:
	var n := headers.size()
	for r: Array in rows:
		n = maxi(n, r.size())
	var widths: Array[int] = []
	for i in n:
		widths.append(display_width(headers[i]) if i < headers.size() else 0)
	var cells: Array = []
	for r: Array in rows:
		var row_cells := PackedStringArray()
		for c in r.size():
			var s := fmt(r[c]).replace("\n", " ")
			if c < n - 1 and max_cell > 0:
				s = clip(s, max_cell)
			row_cells.append(s)
			widths[c] = maxi(widths[c], display_width(s))
		cells.append(row_cells)
	var out := PackedStringArray()
	out.append(_join_row(headers, widths))
	var sep := PackedStringArray()
	for w in widths:
		sep.append("─".repeat(w))
	out.append("  ".join(sep).strip_edges(false, true))
	for rc: PackedStringArray in cells:
		out.append(_join_row(rc, widths))
	return out


## Corta un texto a n celdas como mucho, terminando en «…» si sobra.
static func clip(s: String, n: int) -> String:
	if display_width(s) <= n:
		return s
	var out := ""
	var w := 0
	for ch in s:
		var cw := char_width(ch.unicode_at(0))
		if w + cw > n - 1:
			break
		out += ch
		w += cw
	return out.strip_edges(false, true) + "…"


## Ancho en celdas de la fuente monoespaciada: emojis y pictogramas, 2; marcas combinantes y
## selectores de variante, 0; el resto, 1.
static func display_width(s: String) -> int:
	var w := 0
	for i in s.length():
		w += char_width(s.unicode_at(i))
	return w


static func char_width(cp: int) -> int:
	if cp == 0x200D or cp == 0x200B or (cp >= 0xFE00 and cp <= 0xFE0F) or (cp >= 0x0300 and cp <= 0x036F) or (cp >= 0x1F3FB and cp <= 0x1F3FF):
		return 0
	if cp >= 0x1F000:
		return 2
	# Pictogramas que el sistema dibuja con la fuente de emojis (más anchos que una celda).
	if cp in [0x26A0, 0x26D4, 0x2705, 0x2714, 0x274C, 0x2611, 0x26A1, 0x2753, 0x2757, 0x231B, 0x23F3, 0x2696, 0x2697, 0x2699, 0x270B, 0x270D, 0x2728]:
		return 2
	if cp >= 0x1100 and (cp <= 0x115F or (cp >= 0x2E80 and cp <= 0xA4CF) or (cp >= 0xAC00 and cp <= 0xD7A3) or (cp >= 0xF900 and cp <= 0xFAFF) or (cp >= 0xFF00 and cp <= 0xFF60)):
		return 2
	return 1


## Rellena con espacios hasta w celdas.
static func pad(s: String, w: int) -> String:
	return s + " ".repeat(maxi(0, w - display_width(s)))


## Número legible: sin colas de decimales y con notación científica si es enorme o diminuto.
static func num(v: float, decimals: int = 3) -> String:
	if is_nan(v) or is_inf(v):
		return str(v)
	var a := absf(v)
	if a != 0.0 and (a >= 1e6 or a < 0.001):
		var e := int(floor(log(a) / log(10.0)))
		var m := v / pow(10.0, e)
		if absf(m) >= 9.995:
			m /= 10.0
			e += 1
		return "%.2fe%d" % [m, e]
	var s := ("%." + str(decimals) + "f") % v
	if s.contains("."):
		s = s.rstrip("0").rstrip(".")
	return s


static func fmt(v: Variant) -> String:
	if v is float:
		if is_inf(v) or is_nan(v):
			return str(v)
		if absf(v) >= 1e6:
			return num(v)
		return "%.3f" % v
	return str(v)


static func _join_row(cells: PackedStringArray, widths: Array[int]) -> String:
	var parts := PackedStringArray()
	for i in cells.size():
		parts.append(pad(cells[i], widths[i]))
	return "  ".join(parts).strip_edges(false, true)
