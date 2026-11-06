class_name Vec
extends RefCounted
## Operaciones de vectores (implementación de referencia del Dojo).
## Los vectores son PackedFloat64Array. Precisión doble para que los resultados
## coincidan con Python (float de Python = IEEE 754 doble precisión).


static func same_size(a: PackedFloat64Array, b: PackedFloat64Array) -> bool:
	return a.size() == b.size()


static func sub(a: PackedFloat64Array, b: PackedFloat64Array) -> PackedFloat64Array:
	assert(same_size(a, b), "Vec.sub: tamaños distintos")
	var out := PackedFloat64Array()
	out.resize(a.size())
	for i in a.size():
		out[i] = a[i] - b[i]
	return out


static func dot(a: PackedFloat64Array, b: PackedFloat64Array) -> float:
	assert(same_size(a, b), "Vec.dot: tamaños distintos")
	var s := 0.0
	for i in a.size():
		s += a[i] * b[i]
	return s


static func norm(a: PackedFloat64Array) -> float:
	return sqrt(dot(a, a))


## Distancia euclídea: raíz de la suma de diferencias al cuadrado.
static func euclidean(a: PackedFloat64Array, b: PackedFloat64Array) -> float:
	return sqrt(squared_diffs(a, b).reduce(func(acc: float, x: float) -> float: return acc + x, 0.0))


## Distancia Manhattan: suma de diferencias absolutas.
static func manhattan(a: PackedFloat64Array, b: PackedFloat64Array) -> float:
	assert(same_size(a, b), "Vec.manhattan: tamaños distintos")
	var s := 0.0
	for i in a.size():
		s += absf(a[i] - b[i])
	return s


## Contribución de cada dimensión a la distancia euclídea (antes de la raíz).
## Herramienta pedagógica: revela qué feature «domina» la distancia.
static func squared_diffs(a: PackedFloat64Array, b: PackedFloat64Array) -> Array[float]:
	assert(same_size(a, b), "Vec.squared_diffs: tamaños distintos")
	var out: Array[float] = []
	for i in a.size():
		var d := a[i] - b[i]
		out.append(d * d)
	return out


static func cosine_similarity(a: PackedFloat64Array, b: PackedFloat64Array) -> float:
	var na := norm(a)
	var nb := norm(b)
	if na == 0.0 or nb == 0.0:
		return 0.0
	return dot(a, b) / (na * nb)


static func distance(metric: String, a: PackedFloat64Array, b: PackedFloat64Array) -> float:
	match metric:
		"manhattan":
			return manhattan(a, b)
		_:
			return euclidean(a, b)
