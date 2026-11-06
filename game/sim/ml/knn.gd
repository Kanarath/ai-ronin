class_name KNNClassifier
extends RefCounted
## k vecinos más cercanos (k-NN). Implementación de referencia del Dojo.
##
## Reglas (las mismas que debe cumplir tu versión en Python):
##   1. Distancia entre el punto y TODOS los ejemplos de entrenamiento.
##   2. Orden por distancia ascendente; empate de distancia → menor índice primero.
##   3. Votación por mayoría entre los k primeros.
##   4. Empate de votos → gana la clase empatada cuyo vecino aparece antes en el orden.

var k: int = 3
var metric: String = "euclidean"
var train_set: Dataset = null


func _init(p_k: int = 3, p_metric: String = "euclidean") -> void:
	k = p_k
	metric = p_metric


## k-NN no aprende parámetros: «entrenar» es memorizar los ejemplos.
func fit(ds: Dataset) -> void:
	train_set = ds


func is_trained() -> bool:
	return train_set != null and train_set.size() > 0


## Devuelve los k vecinos: [{index, id, distance, label}], ya ordenados.
func neighbors(x: PackedFloat64Array, count: int = -1) -> Array[Dictionary]:
	var n := k if count < 0 else count
	var all: Array[Dictionary] = []
	for i in train_set.size():
		all.append({
			"index": i,
			"id": train_set.ids[i],
			"distance": Vec.distance(metric, x, train_set.rows[i]),
			"label": train_set.labels[i],
		})
	all.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["distance"] == b["distance"]:
			return a["index"] < b["index"]
		return a["distance"] < b["distance"])
	return all.slice(0, mini(n, all.size()))


func predict_one(x: PackedFloat64Array) -> String:
	var nb := neighbors(x)
	var votes := {}
	for item in nb:
		votes[item["label"]] = votes.get(item["label"], 0) + 1
	var best := 0
	for v: int in votes.values():
		best = maxi(best, v)
	for item in nb:  # recorre en orden de cercanía → resuelve empates
		if votes[item["label"]] == best:
			return item["label"]
	return ""


## «Probabilidad» de la clase positiva: fracción de los k vecinos que la tienen.
## No es una probabilidad calibrada; es una puntuación entre 0 y 1 útil para fijar umbrales.
func positive_score(x: PackedFloat64Array, positive: String) -> float:
	var nb := neighbors(x)
	var hits := 0
	for item in nb:
		if item["label"] == positive:
			hits += 1
	return float(hits) / maxf(nb.size(), 1)


func positive_scores(ds: Dataset, positive: String) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for r in ds.rows:
		out.append(positive_score(r, positive))
	return out


func predict(ds: Dataset) -> PackedStringArray:
	var out := PackedStringArray()
	for r in ds.rows:
		out.append(predict_one(r))
	return out
