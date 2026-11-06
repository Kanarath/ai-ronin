class_name ToyAttention
extends RefCounted
## Self-attention de un solo cabezal, calculada de verdad:
##   puntuaciones = Q·Kᵀ / √d      pesos = softmax por filas      salida = pesos·V
## ⚗ Simplificación: Q = K = V = embeddings de las palabras (proyecciones identidad).
## En un transformer real, Q, K y V se obtienen multiplicando por matrices APRENDIDAS
## (W_Q, W_K, W_V), hay muchos cabezales en paralelo y decenas de capas.
##
## Máscara causal: cada palabra solo puede atender a sí misma y a las ANTERIORES
## (así funcionan los LLM que generan texto: no pueden ver el futuro).


static func softmax(row: PackedFloat64Array) -> PackedFloat64Array:
	var m := -INF
	for v in row:
		if is_finite(v):
			m = maxf(m, v)
	var exps := PackedFloat64Array()
	var total := 0.0
	for v in row:
		var e := exp(v - m) if is_finite(v) else 0.0  # restar el máximo: estabilidad numérica
		exps.append(e)
		total += e
	for i in exps.size():
		exps[i] /= total
	return exps


## Devuelve {"scores": Array[PackedFloat64Array], "weights": …, "outputs": …}.
static func compute(vectors: Array[PackedFloat64Array], causal: bool, scale: bool) -> Dictionary:
	var n := vectors.size()
	var d := vectors[0].size() if n > 0 else 1
	var factor := 1.0 / sqrt(d) if scale else 1.0
	var scores: Array[PackedFloat64Array] = []
	var weights: Array[PackedFloat64Array] = []
	var outputs: Array[PackedFloat64Array] = []
	for i in n:
		var row := PackedFloat64Array()
		for j in n:
			row.append(-INF if causal and j > i else Vec.dot(vectors[i], vectors[j]) * factor)
		scores.append(row)
		var w := softmax(row)
		weights.append(w)
		var out := PackedFloat64Array()
		out.resize(d)
		for j in n:
			for k in d:
				out[k] += w[j] * vectors[j][k]
		outputs.append(out)
	return {"scores": scores, "weights": weights, "outputs": outputs}
