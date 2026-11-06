class_name Normalizer
extends RefCounted
## Normalización de features. Separa fit() (aprender los parámetros) de transform()
## (aplicarlos). Esa separación es la clave para evitar la fuga de datos: los
## parámetros se aprenden SOLO con el conjunto de entrenamiento.

const METHODS: Array[String] = ["minmax", "zscore"]

var method: String = "minmax"
## Para minmax: a = min, b = max. Para zscore: a = media, b = desviación típica.
var param_a := PackedFloat64Array()
var param_b := PackedFloat64Array()
var fitted_on: String = ""


func _init(p_method: String = "minmax") -> void:
	method = p_method


func fit(ds: Dataset) -> void:
	param_a.clear()
	param_b.clear()
	for s: Dictionary in ds.stats():
		if method == "zscore":
			param_a.append(s["mean"])
			param_b.append(s["std"])
		else:
			param_a.append(s["min"])
			param_b.append(s["max"])
	fitted_on = ds.name


func is_fitted() -> bool:
	return not param_a.is_empty()


func transform_vector(v: PackedFloat64Array) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	out.resize(v.size())
	for i in v.size():
		if method == "zscore":
			out[i] = 0.0 if param_b[i] == 0.0 else (v[i] - param_a[i]) / param_b[i]
		else:
			var span := param_b[i] - param_a[i]
			out[i] = 0.0 if span == 0.0 else (v[i] - param_a[i]) / span
	return out


func transform(ds: Dataset, new_name: String) -> Dataset:
	var out := ds.copy(new_name)
	for i in out.size():
		out.rows[i] = transform_vector(ds.rows[i])
	out.lineage.append("%s(fit=%s)" % [method, fitted_on])
	return out
