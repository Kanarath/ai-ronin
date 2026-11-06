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


## Tabla de texto alineada para fuente monoespaciada.
static func table(headers: PackedStringArray, rows: Array) -> PackedStringArray:
	var widths: Array[int] = []
	for h in headers:
		widths.append(h.length())
	var cells: Array = []
	for r: Array in rows:
		var row_cells := PackedStringArray()
		for c in r.size():
			var s := fmt(r[c])
			row_cells.append(s)
			widths[c] = maxi(widths[c], s.length())
		cells.append(row_cells)
	var out := PackedStringArray()
	out.append(_join_row(headers, widths))
	var sep := PackedStringArray()
	for w in widths:
		sep.append("─".repeat(w))
	out.append("  ".join(sep))
	for rc: PackedStringArray in cells:
		out.append(_join_row(rc, widths))
	return out


static func fmt(v: Variant) -> String:
	if v is float:
		if is_inf(v) or is_nan(v):
			return str(v)
		return "%.3f" % v
	return str(v)


static func _join_row(cells: PackedStringArray, widths: Array[int]) -> String:
	var parts := PackedStringArray()
	for i in cells.size():
		parts.append(cells[i].rpad(widths[i]))
	return "  ".join(parts).strip_edges(false, true)
