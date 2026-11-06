class_name ChallengeBank
extends RefCounted
## Retos rápidos: problemas cortos GENERADOS con números nuevos cada vez, para practicar
## lo aprendido (repetición espaciada). Cada reto trae su solución explicada paso a paso,
## que se muestra al responder: equivocarse también enseña.
## Solo se proponen retos de unidades con alguna misión completada.

const UNIT_GENERATORS := {
	"T1": ["_distance", "_minmax", "_mean"],
	"T2": ["_knn_vote", "_accuracy"],
	"T3": ["_gd_step", "_precision_recall"],
	"T4": ["_neuron"],
	"T5": ["_cosine"],
	"T6": ["_softmax2", "_temperature2"],
}

var rng := RandomNumberGenerator.new()


func _init(seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()


## units: unidades desbloqueadas (p. ej. ["T1", "T2"]). Devuelve {} si no hay ninguna.
func generate(units: PackedStringArray) -> Dictionary:
	var pool: Array = []
	for u in units:
		for g: String in UNIT_GENERATORS.get(u, []):
			pool.append([u, g])
	if pool.is_empty():
		return {}
	var pick: Array = pool[rng.randi_range(0, pool.size() - 1)]
	var c: Dictionary = call(pick[1])
	c["unit"] = pick[0]
	return c


func _i(lo: int, hi: int) -> int:
	return rng.randi_range(lo, hi)


func _distance() -> Dictionary:
	var a := Vector2i(_i(0, 6), _i(0, 6))
	var dx: int = [3, 6, 5, 8][_i(0, 3)]
	var dy: int = {3: 4, 6: 8, 5: 12, 8: 6}[dx]
	var b := Vector2i(a.x + dx, a.y + dy)
	return {"question": "Distancia euclídea entre A=(%d, %d) y B=(%d, %d)." % [a.x, a.y, b.x, b.y],
		"expected": sqrt(dx * dx + dy * dy), "tolerance": 0.01,
		"explanation": "√((%d−%d)² + (%d−%d)²) = √(%d + %d) = %s" % [b.x, a.x, b.y, a.y, dx * dx, dy * dy, String.num(sqrt(dx * dx + dy * dy), 2)]}


func _minmax() -> Dictionary:
	var lo := _i(0, 50)
	var hi: int = lo + [10, 20, 40, 50, 100][_i(0, 4)]
	var x := lo + _i(1, hi - lo - 1)
	var v: float = float(x - lo) / (hi - lo)
	return {"question": "Normaliza x = %d con min-max si el mínimo es %d y el máximo %d." % [x, lo, hi],
		"expected": v, "tolerance": 0.01,
		"explanation": "(x − mín) / (máx − mín) = (%d − %d) / (%d − %d) = %s" % [x, lo, hi, lo, String.num(v, 3)]}


func _mean() -> Dictionary:
	var vals: Array[int] = []
	for i in 4:
		vals.append(_i(1, 20))
	var s := 0
	for v in vals:
		s += v
	return {"question": "Media de %s." % str(vals), "expected": s / 4.0, "tolerance": 0.01,
		"explanation": "Suma %d / 4 valores = %s" % [s, String.num(s / 4.0, 2)]}


func _knn_vote() -> Dictionary:
	var k: int = [3, 5, 7][_i(0, 2)]
	var aptas := _i(0, k)
	while aptas * 2 == k:
		aptas = _i(0, k)
	var winner := "apta" if aptas * 2 > k else "defectuosa"
	return {"question": "k-NN con k=%d: entre los vecinos hay %d aptas y %d defectuosas. ¿Qué predice? (apta/defectuosa)" % [k, aptas, k - aptas],
		"expected": winner, "explanation": "Gana la clase más votada: %s." % winner}


func _accuracy() -> Dictionary:
	var total: int = [20, 40, 50, 80][_i(0, 3)]
	var hits: int = _i(total / 2, total)
	return {"question": "Un modelo acierta %d de %d ejemplos de test. ¿Accuracy?" % [hits, total],
		"expected": float(hits) / total, "tolerance": 0.005,
		"explanation": "aciertos / total = %d / %d = %s" % [hits, total, String.num(float(hits) / total, 3)]}


func _gd_step() -> Dictionary:
	var w := _i(-5, 5)
	var g := _i(-10, 10)
	var lr: float = [0.1, 0.01, 0.5][_i(0, 2)]
	var nw: float = w - lr * g
	return {"question": "Descenso por gradiente: w = %d, gradiente ∂L/∂w = %d, lr = %s. ¿Nuevo w?" % [w, g, str(lr)],
		"expected": nw, "tolerance": 0.001,
		"explanation": "w − lr·gradiente = %d − %s·(%d) = %s. Se RESTA porque el gradiente apunta cuesta arriba." % [w, str(lr), g, String.num(nw, 3)]}


func _precision_recall() -> Dictionary:
	var tp := _i(5, 30)
	var fp := _i(0, 10)
	var fn := _i(0, 10)
	if rng.randf() < 0.5:
		var p := float(tp) / (tp + fp)
		return {"question": "TP = %d, FP = %d, FN = %d. ¿Precision?" % [tp, fp, fn], "expected": p, "tolerance": 0.005,
			"explanation": "precision = TP / (TP + FP) = %d / %d = %s (FN no interviene)" % [tp, tp + fp, String.num(p, 3)]}
	var r := float(tp) / (tp + fn)
	return {"question": "TP = %d, FP = %d, FN = %d. ¿Recall?" % [tp, fp, fn], "expected": r, "tolerance": 0.005,
		"explanation": "recall = TP / (TP + FN) = %d / %d = %s (FP no interviene)" % [tp, tp + fn, String.num(r, 3)]}


func _neuron() -> Dictionary:
	var w1 := _i(-6, 6)
	var w2 := _i(-6, 6)
	var b := _i(-6, 6)
	var a := _i(0, 1)
	var c := _i(0, 1)
	var z := w1 * a + w2 * c + b
	if z == 0:
		b += 1
		z += 1
	var out := 1 if z > 0 else 0
	return {"question": "Neurona con w₁=%d, w₂=%d, sesgo=%d y entrada (%d, %d). ¿Predice 1 o 0?" % [w1, w2, b, a, c],
		"expected": float(out), "tolerance": 0.0,
		"explanation": "z = %d·%d + %d·%d + %d = %d. σ(z) ≥ 0,5 si y solo si z ≥ 0 → %d" % [w1, a, w2, c, b, z, out]}


func _cosine() -> Dictionary:
	var pairs := [[[1, 0], [0, 1], 0.0], [[2, 2], [1, 1], 1.0], [[1, 0], [-3, 0], -1.0], [[3, 4], [4, 3], 24.0 / 25.0], [[1, 1], [1, 0], 1.0 / sqrt(2)]]
	var p: Array = pairs[_i(0, pairs.size() - 1)]
	return {"question": "Similitud coseno entre %s y %s." % [str(p[0]), str(p[1])], "expected": p[2], "tolerance": 0.01,
		"explanation": "(a·b) / (|a|·|b|) = %s. 1 = misma dirección, 0 = perpendiculares, −1 = opuestos." % String.num(p[2], 3)}


func _softmax2() -> Dictionary:
	var a := _i(0, 3)
	var b := _i(0, 3)
	var p := exp(a) / (exp(a) + exp(b))
	return {"question": "Softmax de las puntuaciones [%d, %d]: ¿probabilidad de la primera?" % [a, b], "expected": p, "tolerance": 0.01,
		"explanation": "e^%d / (e^%d + e^%d) = %s" % [a, a, b, String.num(p, 3)]}


func _temperature2() -> Dictionary:
	var p1: float = [0.6, 0.7, 0.8][_i(0, 2)]
	var t: float = [0.5, 2.0][_i(0, 1)]
	var a := pow(p1, 1.0 / t)
	var b := pow(1.0 - p1, 1.0 / t)
	var res := a / (a + b)
	return {"question": "Dos tokens con probabilidades %s y %s. Con temperatura %s, ¿nueva probabilidad del primero?" % [str(p1), String.num(1.0 - p1, 1), str(t)],
		"expected": res, "tolerance": 0.01,
		"explanation": "Cada p se eleva a 1/T = %s y se normaliza: %s / (%s + %s) = %s. %s" % [String.num(1.0 / t, 2), String.num(a, 3), String.num(a, 3), String.num(b, 3), String.num(res, 3),
			"T < 1 concentra." if t < 1 else "T > 1 aplana."]}
