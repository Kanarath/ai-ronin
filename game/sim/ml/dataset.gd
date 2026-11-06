class_name Dataset
extends RefCounted
## Dataset tabular: cada fila es un ejemplo (vector de features) con un id y una etiqueta.
##
## Formato CSV aceptado:
##   - Primera línea: cabecera.
##   - Columna opcional "id" (identificador de cada ejemplo).
##   - Una columna de etiqueta (label), indicada al cargar.
##   - El resto de columnas son features numéricas.

var name: String = ""
var feature_names: PackedStringArray = []
var label_name: String = ""
var ids: PackedStringArray = []
var rows: Array[PackedFloat64Array] = []
var labels: PackedStringArray = []
## Mensaje de error si la carga falló (vacío si todo fue bien).
var error: String = ""
## Linaje: de qué dataset procede y qué transformaciones se le aplicaron.
var lineage: Array[String] = []


static func from_csv_text(dataset_name: String, text: String, label_column: String) -> Dataset:
	var ds := Dataset.new()
	ds.name = dataset_name
	ds.label_name = label_column
	var lines := text.replace("\r", "").split("\n", false)
	if lines.is_empty():
		ds.error = "el CSV está vacío"
		return ds
	var header := lines[0].split(",")
	var id_col := header.find("id")
	# label_column vacío = dataset sin etiqueta (p. ej. para regresión, donde el objetivo es una feature).
	var label_col := header.find(label_column) if not label_column.is_empty() else -1
	if label_col == -1 and not label_column.is_empty():
		ds.error = "no existe la columna de etiqueta '%s'" % label_column
		return ds
	var feature_cols: Array[int] = []
	for i in header.size():
		if i != id_col and i != label_col:
			feature_cols.append(i)
			ds.feature_names.append(header[i].strip_edges())
	for line_index in range(1, lines.size()):
		var cells := lines[line_index].split(",")
		if cells.size() != header.size():
			ds.error = "línea %d: %d columnas, se esperaban %d" % [line_index + 1, cells.size(), header.size()]
			return ds
		var row := PackedFloat64Array()
		for c in feature_cols:
			var cell := cells[c].strip_edges()
			if not cell.is_valid_float():
				ds.error = "línea %d: '%s' no es un número (columna %s)" % [line_index + 1, cell, header[c]]
				return ds
			row.append(cell.to_float())
		ds.rows.append(row)
		ds.labels.append(cells[label_col].strip_edges() if label_col != -1 else "")
		ds.ids.append(cells[id_col].strip_edges() if id_col != -1 else str(line_index))
	return ds


func size() -> int:
	return rows.size()


func dims() -> int:
	return feature_names.size()


func is_valid() -> bool:
	return error.is_empty()


func index_of_id(id: String) -> int:
	return ids.find(id)


func feature_index(feature: String) -> int:
	return feature_names.find(feature)


func column(feature_idx: int) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for r in rows:
		out.append(r[feature_idx])
	return out


## Clases distintas, en orden alfabético (orden estable para matrices de confusión).
func classes() -> PackedStringArray:
	var seen := {}
	for l in labels:
		seen[l] = true
	var out := PackedStringArray(seen.keys())
	out.sort()
	return out


func class_counts() -> Dictionary:
	var counts := {}
	for l in labels:
		counts[l] = counts.get(l, 0) + 1
	return counts


## Estadísticas por feature. La desviación típica es POBLACIONAL (divide entre n),
## igual que numpy.std() por defecto. (pandas .std() usa n-1: ¡ojo al comparar!)
func stats() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for f in dims():
		var col := column(f)
		var n := col.size()
		var mean := 0.0
		var lo := INF
		var hi := -INF
		for x in col:
			mean += x
			lo = minf(lo, x)
			hi = maxf(hi, x)
		mean /= maxf(n, 1)
		var variance := 0.0
		for x in col:
			variance += (x - mean) * (x - mean)
		variance /= maxf(n, 1)
		out.append({"feature": feature_names[f], "mean": mean, "std": sqrt(variance), "min": lo, "max": hi})
	return out


## Nuevo dataset con las filas indicadas (comparte nombres de features).
func subset(indices: Array[int], new_name: String) -> Dataset:
	var ds := _empty_like(new_name)
	for i in indices:
		ds.rows.append(rows[i].duplicate())
		ds.labels.append(labels[i])
		ds.ids.append(ids[i])
	return ds


func copy(new_name: String) -> Dataset:
	var all: Array[int] = []
	for i in size():
		all.append(i)
	return subset(all, new_name)


## ¿Comparten ejemplos (por id)? Detecta fuga de datos entre train y test.
func overlap_count(other: Dataset) -> int:
	var mine := {}
	for id in ids:
		mine[id] = true
	var n := 0
	for id in other.ids:
		if mine.has(id):
			n += 1
	return n


func _empty_like(new_name: String) -> Dataset:
	var ds := Dataset.new()
	ds.name = new_name
	ds.feature_names = feature_names.duplicate()
	ds.label_name = label_name
	ds.lineage = lineage.duplicate()
	return ds
