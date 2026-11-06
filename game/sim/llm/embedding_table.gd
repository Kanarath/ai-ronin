class_name EmbeddingTable
extends RefCounted
## Tabla de embeddings: palabra → vector. Similitud coseno, vecinos y analogías.
## ⚗ Los vectores de res://content/embeddings son DISEÑADOS A MANO (dimensiones legibles)
## para enseñar; los embeddings reales se aprenden y no tienen dimensiones interpretables.

const DEFAULT_PATH := "res://content/embeddings/forja_emb.json"

var dimensions: PackedStringArray = []
var vectors: Dictionary = {}  # palabra -> PackedFloat64Array
var categories: Dictionary = {}  # palabra -> categoría
var error: String = ""


static func load_default() -> EmbeddingTable:
	var t := EmbeddingTable.new()
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DEFAULT_PATH))
	if not data is Dictionary:
		t.error = "no se pudo leer " + DEFAULT_PATH
		return t
	t.dimensions = PackedStringArray(data["dimensions"])
	for w: String in data["words"]:
		t.vectors[w] = PackedFloat64Array(data["words"][w]["vector"])
		t.categories[w] = data["words"][w]["category"]
	return t


func words() -> PackedStringArray:
	var out := PackedStringArray(vectors.keys())
	out.sort()
	return out


func has(word: String) -> bool:
	return vectors.has(word)


func similarity(a: PackedFloat64Array, b: PackedFloat64Array, metric: String = "cosine") -> float:
	return Vec.cosine_similarity(a, b) if metric == "cosine" else -Vec.euclidean(a, b)


## Los k vectores más parecidos a `query`, excluyendo las palabras indicadas.
## Devuelve [{word, score}] ordenado (score: coseno, o −distancia si euclidean).
func nearest(query: PackedFloat64Array, k: int, exclude: PackedStringArray = [], metric: String = "cosine") -> Array[Dictionary]:
	var all: Array[Dictionary] = []
	for w in words():
		if w in exclude:
			continue
		all.append({"word": w, "score": similarity(query, vectors[w], metric)})
	all.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		if is_equal_approx(x["score"], y["score"]):
			return x["word"] < y["word"]
		return x["score"] > y["score"])
	return all.slice(0, mini(k, all.size()))


## a − b + c  (p. ej. maestro − hombre + mujer)
func analogy_vector(a: String, b: String, c: String) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for i in dimensions.size():
		out.append(vectors[a][i] - vectors[b][i] + vectors[c][i])
	return out


## Convierte la tabla en un Dataset (para dibujarla con plot).
func to_dataset(ds_name: String) -> Dataset:
	var ds := Dataset.new()
	ds.name = ds_name
	ds.feature_names = dimensions.duplicate()
	ds.label_name = "categoría"
	for w in words():
		ds.ids.append(w)
		ds.rows.append(vectors[w].duplicate())
		ds.labels.append(categories[w])
	ds.lineage.append("embeddings")
	return ds
