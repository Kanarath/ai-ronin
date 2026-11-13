class_name PrivacySim
extends RefCounted
## E2-04 · Privacidad: regresión logística real (sin dependencias) para ilustrar el aprendizaje
## federado (FedAvg: entrenar en local y promediar pesos, sin compartir datos) y el unlearning
## (olvidar un ejemplo y comprobarlo con un test de pertenencia). Determinista.


class Logistic:
	extends RefCounted
	var w: PackedFloat64Array = []
	var b: float = 0.0
	var mins: PackedFloat64Array = []
	var spans: PackedFloat64Array = []

	func _norm(ds: Dataset) -> void:
		if not mins.is_empty():
			return
		for f in ds.dims():
			var lo := INF
			var hi := -INF
			for i in ds.size():
				lo = minf(lo, ds.rows[i][f])
				hi = maxf(hi, ds.rows[i][f])
			mins.append(lo)
			spans.append(maxf(hi - lo, 1e-9))

	func _x(ds: Dataset, i: int) -> PackedFloat64Array:
		var out := PackedFloat64Array()
		for f in ds.dims():
			out.append((ds.rows[i][f] - mins[f]) / spans[f])
		return out

	static func _pos(ds: Dataset) -> String:
		var cs := ds.classes()
		cs.sort()
		return cs[0]

	func fit(ds: Dataset, idx: Array, steps: int, lr: float) -> Logistic:
		_norm(ds)
		var pos := _pos(ds)
		if w.is_empty():
			w.resize(ds.dims())
			w.fill(0.0)
		for _t in steps:
			var gw := PackedFloat64Array()
			gw.resize(ds.dims())
			gw.fill(0.0)
			var gb := 0.0
			for i: int in idx:
				var x := _x(ds, i)
				var y := 1.0 if ds.labels[i] == pos else 0.0
				var z := b
				for f in w.size():
					z += w[f] * x[f]
				var p := 1.0 / (1.0 + exp(-z))
				var e := p - y
				for f in w.size():
					gw[f] += e * x[f]
				gb += e
			var n := maxf(idx.size(), 1)
			for f in w.size():
				w[f] -= lr * gw[f] / n
			b -= lr * gb / n
		return self

	func prob_pos(ds: Dataset, i: int) -> float:
		var x := _x(ds, i)
		var z := b
		for f in w.size():
			z += w[f] * x[f]
		return 1.0 / (1.0 + exp(-z))

	func accuracy(ds: Dataset, idx: Array) -> float:
		var pos := _pos(ds)
		var ok := 0
		for i: int in idx:
			var pred: bool = prob_pos(ds, i) >= 0.5
			var truth: bool = ds.labels[i] == pos
			ok += int(pred == truth)
		return float(ok) / maxf(idx.size(), 1)

	## Probabilidad que el modelo da a la etiqueta VERDADERA del ejemplo (señal de pertenencia:
	## los ejemplos del entrenamiento tienden a tener una probabilidad más alta).
	func confidence_true(ds: Dataset, i: int) -> float:
		var pos := _pos(ds)
		var p := prob_pos(ds, i)
		return p if ds.labels[i] == pos else (1.0 - p)

	func clone() -> Logistic:
		var c := Logistic.new()
		c.w = w.duplicate()
		c.b = b
		c.mins = mins.duplicate()
		c.spans = spans.duplicate()
		return c


static func all_idx(ds: Dataset) -> Array:
	return range(ds.size())


## Reparte los índices en k clientes (trozos contiguos).
static func split_clients(ds: Dataset, k: int) -> Array:
	var out: Array = []
	for c in k:
		out.append([])
	for i in ds.size():
		out[i % k].append(i)
	return out


## FedAvg: cada cliente entrena en LOCAL y se promedian los pesos. No se comparte ningún dato.
static func fedavg(ds: Dataset, clients: Array, steps: int, lr: float) -> Logistic:
	var models: Array = []
	for idx: Array in clients:
		models.append(Logistic.new().fit(ds, idx, steps, lr))
	var g := Logistic.new()
	g.mins = (models[0] as Logistic).mins.duplicate()
	g.spans = (models[0] as Logistic).spans.duplicate()
	g.w.resize(ds.dims())
	g.w.fill(0.0)
	for mdl: Logistic in models:
		for f in g.w.size():
			g.w[f] += mdl.w[f] / models.size()
		g.b += mdl.b / models.size()
	return g
