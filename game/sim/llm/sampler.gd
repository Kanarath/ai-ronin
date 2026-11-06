class_name Sampler
extends RefCounted
## Estrategias de muestreo del siguiente token (las mismas que exponen las APIs de LLM).
## Orden de aplicación: temperatura → top-k → top-p (como en la librería transformers).
##
## Temperatura T: p_i ∝ p_i^(1/T)  (equivale a dividir los logits entre T antes del softmax).
##   T → 0: casi siempre el más probable (greedy) · T = 1: distribución original · T > 1: más plana.
##   T = 0 se trata como greedy: probabilidad 1 para el token más probable.
## Top-k: solo los k tokens más probables. Top-p (nucleus): los más probables hasta acumular p.


static func sort_dist(dist: Array[Dictionary]) -> void:
	dist.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if is_equal_approx(a["prob"], b["prob"]):
			return a["token"] < b["token"]
		return a["prob"] > b["prob"])


static func transform(dist: Array[Dictionary], temperature: float, top_k: int, top_p: float) -> Array[Dictionary]:
	var d: Array[Dictionary] = []
	for e in dist:
		d.append(e.duplicate())
	sort_dist(d)
	if d.is_empty():
		return d
	if temperature <= 0.0:
		return [{"token": d[0]["token"], "prob": 1.0}]
	var total := 0.0
	for e in d:
		e["prob"] = pow(e["prob"], 1.0 / temperature)
		total += e["prob"]
	for e in d:
		e["prob"] /= total
	if top_k > 0 and top_k < d.size():
		d = d.slice(0, top_k)
	if top_p > 0.0 and top_p < 1.0:
		var cum := 0.0
		var keep: Array[Dictionary] = []
		for e in d:
			keep.append(e)
			cum += e["prob"]
			if cum >= top_p - 1e-9:
				break
		d = keep
	total = 0.0
	for e in d:
		total += e["prob"]
	for e in d:
		e["prob"] /= total
	return d


static func sample(dist: Array[Dictionary], rng: RandomNumberGenerator) -> String:
	var r := rng.randf()
	var cum := 0.0
	for e in dist:
		cum += e["prob"]
		if r < cum:
			return e["token"]
	return dist[-1]["token"]
