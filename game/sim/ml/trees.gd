class_name ClassicML
extends RefCounted
## ML clásico de T7, de verdad y en GDScript (sin dependencias): árbol de decisión (CART con
## impureza de Gini), bosque aleatorio (bootstrap + subconjunto de features) y k-means
## (agrupar sin etiquetas, con detección de puntos raros por distancia a su centro).


# ── Árbol de decisión ────────────────────────────────────────────────────────

class DTree:
	extends RefCounted
	var root: Dictionary = {}
	var features: PackedStringArray = []
	var max_depth := 3
	var min_leaf := 2
	## Cuántas veces se usa cada feature para cortar (importancia sencilla).
	var splits: Dictionary = {}
	var _rng: RandomNumberGenerator = null
	var _max_features := 0

	func fit(ds: Dataset, idx: Array, depth: int = 3, rng: RandomNumberGenerator = null, max_features: int = 0) -> DTree:
		features = ds.feature_names
		max_depth = depth
		_rng = rng
		_max_features = max_features
		splits.clear()
		root = _grow(ds, idx, 0)
		return self

	func predict(row: PackedFloat64Array) -> String:
		var n := root
		while not n.has("leaf"):
			n = n["left"] if row[n["f"]] <= n["t"] else n["right"]
		return n["leaf"]

	func leaves() -> int:
		return _count(root)

	func depth() -> int:
		return _depth(root)

	func rules() -> PackedStringArray:
		var out := PackedStringArray()
		_rules(root, "", out)
		return out

	func _count(n: Dictionary) -> int:
		return 1 if n.has("leaf") else _count(n["left"]) + _count(n["right"])

	func _depth(n: Dictionary) -> int:
		return 0 if n.has("leaf") else 1 + maxi(_depth(n["left"]), _depth(n["right"]))

	func _rules(n: Dictionary, indent: String, out: PackedStringArray) -> void:
		if n.has("leaf"):
			out.append("%s→ %s  (%d ejemplos, %d%% de acierto)" % [indent, n["leaf"], n["n"], int(round(n["purity"] * 100))])
			return
		out.append("%ssi %s <= %s:" % [indent, features[n["f"]], _fmt(n["t"])])
		_rules(n["left"], indent + "    ", out)
		out.append("%ssi no (%s > %s):" % [indent, features[n["f"]], _fmt(n["t"])])
		_rules(n["right"], indent + "    ", out)

	static func _fmt(x: float) -> String:
		return str(snappedf(x, 0.001))

	func _grow(ds: Dataset, idx: Array, d: int) -> Dictionary:
		var counts := ClassicML.counts(ds, idx)
		var best_label := ClassicML.majority(counts)
		var purity := float(counts.get(best_label, 0)) / maxf(idx.size(), 1)
		if d >= max_depth or idx.size() < 2 * min_leaf or purity == 1.0:
			return {"leaf": best_label, "n": idx.size(), "purity": purity}
		var split := _best_split(ds, idx)
		if split.is_empty():
			return {"leaf": best_label, "n": idx.size(), "purity": purity}
		splits[features[split["f"]]] = int(splits.get(features[split["f"]], 0)) + 1
		return {"f": split["f"], "t": split["t"], "left": _grow(ds, split["left"], d + 1), "right": _grow(ds, split["right"], d + 1)}

	func _best_split(ds: Dataset, idx: Array) -> Dictionary:
		var feats: Array = range(ds.dims())
		if _max_features > 0 and _rng != null and _max_features < feats.size():
			var pick: Array = []
			var pool := feats.duplicate()
			for k in _max_features:
				var j := _rng.randi_range(0, pool.size() - 1)
				pick.append(pool[j])
				pool.remove_at(j)
			feats = pick
		var best := {}
		var best_g := ClassicML.gini(ClassicML.counts(ds, idx), idx.size())
		var total := ClassicML.counts(ds, idx)
		var n := idx.size()
		for f: int in feats:
			# Una sola pasada por los ejemplos ordenados, moviendo uno a uno de la derecha a la
			# izquierda y actualizando los recuentos (O(n log n) en lugar de O(n²)).
			var order := idx.duplicate()
			order.sort_custom(func(x: int, y: int) -> bool: return ds.rows[x][f] < ds.rows[y][f])
			var left := {}
			var right := total.duplicate()
			var best_k := -1
			for k in range(n - 1):
				var lab: String = ds.labels[order[k]]
				left[lab] = int(left.get(lab, 0)) + 1
				right[lab] = int(right[lab]) - 1
				var nl := k + 1
				var nr := n - nl
				if nl < min_leaf or nr < min_leaf:
					continue
				var v0: float = ds.rows[order[k]][f]
				var v1: float = ds.rows[order[k + 1]][f]
				if v0 == v1:
					continue
				var g := (ClassicML.gini(left, nl) * nl + ClassicML.gini(right, nr) * nr) / n
				if g < best_g - 1e-12:
					best_g = g
					best_k = k
					best = {"f": f, "t": (v0 + v1) / 2.0}
			if best_k >= 0 and best.get("f", -1) == f:
				best["left"] = order.slice(0, best_k + 1)
				best["right"] = order.slice(best_k + 1)
		return best


static func counts(ds: Dataset, idx: Array) -> Dictionary:
	var c := {}
	for i: int in idx:
		c[ds.labels[i]] = int(c.get(ds.labels[i], 0)) + 1
	return c


static func majority(c: Dictionary) -> String:
	var best := ""
	var keys: Array = c.keys()
	keys.sort()
	for k: String in keys:
		if best.is_empty() or c[k] > c[best]:
			best = k
	return best


static func gini(c: Dictionary, n: int) -> float:
	if n == 0:
		return 0.0
	var g := 1.0
	for k: String in c:
		var p := float(c[k]) / n
		g -= p * p
	return g


static func all_idx(ds: Dataset) -> Array:
	return range(ds.size())


static func accuracy(model: Variant, ds: Dataset) -> float:
	if ds.size() == 0:
		return 0.0
	var ok := 0
	for i in ds.size():
		ok += int(model.predict(ds.rows[i]) == ds.labels[i])
	return float(ok) / ds.size()


# ── Bosque aleatorio ─────────────────────────────────────────────────────────

class Forest:
	extends RefCounted
	var trees: Array = []
	var features: PackedStringArray = []

	func fit(ds: Dataset, n_trees: int, depth: int, seed: int) -> Forest:
		features = ds.feature_names
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var mf := maxi(1, int(round(sqrt(float(ds.dims())))))
		trees.clear()
		for t in n_trees:
			var boot: Array = []
			for k in ds.size():
				boot.append(rng.randi_range(0, ds.size() - 1))
			trees.append(ClassicML.DTree.new().fit(ds, boot, depth, rng, mf))
		return self

	func predict(row: PackedFloat64Array) -> String:
		var votes := {}
		for t: ClassicML.DTree in trees:
			var p := t.predict(row)
			votes[p] = int(votes.get(p, 0)) + 1
		return ClassicML.majority(votes)

	## Fracción de cortes que usa cada feature en todo el bosque.
	func importances() -> Dictionary:
		var c := {}
		var total := 0
		for t: ClassicML.DTree in trees:
			for f: String in t.splits:
				c[f] = int(c.get(f, 0)) + int(t.splits[f])
				total += int(t.splits[f])
		var out := {}
		for f: String in features:
			out[f] = float(c.get(f, 0)) / maxf(total, 1)
		return out


# ── k-means ──────────────────────────────────────────────────────────────────

## Agrupa las filas en k grupos sin mirar las etiquetas. Devuelve
## {"assign": [grupo de cada fila], "centroids": [[...]], "inertia", "dist": [distancia a su centro]}.
static func kmeans(ds: Dataset, k: int, seed: int, iters: int = 50) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var n := ds.size()
	var cents: Array = []
	# k-means++: el primero al azar y cada siguiente, lejos de los anteriores.
	cents.append(ds.rows[rng.randi_range(0, n - 1)].duplicate())
	while cents.size() < k:
		var d2: Array = []
		var total := 0.0
		for i in n:
			var m := INF
			for c: PackedFloat64Array in cents:
				m = minf(m, _d2(ds.rows[i], c))
			d2.append(m)
			total += m
		var r := rng.randf() * total
		var acc := 0.0
		var pick := n - 1
		for i in n:
			acc += d2[i]
			if acc >= r:
				pick = i
				break
		cents.append(ds.rows[pick].duplicate())
	var assign: Array = []
	assign.resize(n)
	assign.fill(-1)
	for it in iters:
		var changed := false
		for i in n:
			var best := 0
			var bd := INF
			for c in cents.size():
				var d := _d2(ds.rows[i], cents[c])
				if d < bd:
					bd = d
					best = c
			if assign[i] != best:
				assign[i] = best
				changed = true
		for c in cents.size():
			var sum := PackedFloat64Array()
			sum.resize(ds.dims())
			var cnt := 0
			for i in n:
				if assign[i] == c:
					cnt += 1
					for j in ds.dims():
						sum[j] += ds.rows[i][j]
			if cnt > 0:
				for j in ds.dims():
					sum[j] /= cnt
				cents[c] = sum
		if not changed:
			break
	var inertia := 0.0
	var dist: Array = []
	for i in n:
		var d := _d2(ds.rows[i], cents[assign[i]])
		inertia += d
		dist.append(sqrt(d))
	return {"assign": assign, "centroids": cents, "inertia": inertia, "dist": dist}


static func _d2(a: PackedFloat64Array, b: PackedFloat64Array) -> float:
	var s := 0.0
	for j in a.size():
		s += (a[j] - b[j]) * (a[j] - b[j])
	return s


# ── Gradient boosting ────────────────────────────────────────────────────────

## Gradient boosting para dos clases (pérdida logística): cada ronda ajusta un árbol de
## regresión pequeño a los residuos (lo que el modelo aún falla, y − p) y suma su corrección
## multiplicada por la tasa de aprendizaje. Hojas con el paso de Newton: Σr / Σp(1−p).
class GBoost:
	extends RefCounted
	var features: PackedStringArray = []
	var positive := ""
	var negative := ""
	var base := 0.0
	var lr := 0.3
	## Cada ronda: un árbol de regresión {"f","t","left","right"} o {"v": valor}.
	var rounds: Array = []
	var splits: Dictionary = {}
	var max_depth := 1
	var min_leaf := 3

	func fit(ds: Dataset, n_rounds: int, p_lr: float, depth: int) -> GBoost:
		features = ds.feature_names
		lr = p_lr
		max_depth = depth
		var counts := ClassicML.counts(ds, ClassicML.all_idx(ds))
		var labs: Array = counts.keys()
		labs.sort()
		# Clase positiva: la menos frecuente (la que se quiere detectar).
		positive = labs[0]
		for l: String in labs:
			if int(counts[l]) < int(counts[positive]):
				positive = l
		negative = positive
		for l: String in labs:
			if l != positive:
				negative = l
		var n := ds.size()
		var y := PackedFloat64Array()
		y.resize(n)
		for i in n:
			y[i] = 1.0 if ds.labels[i] == positive else 0.0
		var pr := clampf(float(counts.get(positive, 0)) / maxf(n, 1), 0.01, 0.99)
		base = log(pr / (1.0 - pr))
		var score := PackedFloat64Array()
		score.resize(n)
		score.fill(base)
		rounds.clear()
		splits.clear()
		for k in n_rounds:
			var g := PackedFloat64Array()
			var h := PackedFloat64Array()
			g.resize(n)
			h.resize(n)
			for i in n:
				var p := 1.0 / (1.0 + exp(-score[i]))
				g[i] = y[i] - p
				h[i] = maxf(p * (1.0 - p), 1e-6)
			var tree := _grow(ds, range(n), g, h, 0)
			rounds.append(tree)
			for i in n:
				score[i] += lr * _value(tree, ds.rows[i])
		return self

	func score_of(row: PackedFloat64Array, upto: int = -1) -> float:
		var s := base
		var m := rounds.size() if upto < 0 else mini(upto, rounds.size())
		for k in m:
			s += lr * _value(rounds[k], row)
		return s

	func predict(row: PackedFloat64Array) -> String:
		return positive if score_of(row) > 0.0 else negative

	func predict_upto(row: PackedFloat64Array, upto: int) -> String:
		return positive if score_of(row, upto) > 0.0 else negative

	func accuracy_upto(ds: Dataset, upto: int) -> float:
		var ok := 0
		for i in ds.size():
			ok += int(predict_upto(ds.rows[i], upto) == ds.labels[i])
		return float(ok) / maxf(ds.size(), 1)

	func describe(k: int) -> String:
		var t: Dictionary = rounds[k]
		if t.has("v"):
			return "ronda %d: sin corte útil (suma %+.2f a todos)" % [k + 1, lr * t["v"]]
		var l: Dictionary = t["left"]
		var r: Dictionary = t["right"]
		if l.has("v") and r.has("v"):
			return "ronda %d: si %s <= %s → %+.2f · si no → %+.2f" % [k + 1, features[t["f"]], str(snappedf(t["t"], 0.001)), lr * l["v"], lr * r["v"]]
		return "ronda %d: árbol de profundidad %d que empieza preguntando por %s" % [k + 1, max_depth, features[t["f"]]]

	func importances() -> Dictionary:
		var total := 0
		for f: String in splits:
			total += int(splits[f])
		var out := {}
		for f: String in features:
			out[f] = float(splits.get(f, 0)) / maxf(total, 1)
		return out

	func _value(t: Dictionary, row: PackedFloat64Array) -> float:
		var n := t
		while not n.has("v"):
			n = n["left"] if row[n["f"]] <= n["t"] else n["right"]
		return n["v"]

	func _leaf(idx: Array, g: PackedFloat64Array, h: PackedFloat64Array) -> Dictionary:
		var sg := 0.0
		var sh := 0.0
		for i: int in idx:
			sg += g[i]
			sh += h[i]
		return {"v": clampf(sg / maxf(sh, 1e-6), -4.0, 4.0)}

	func _grow(ds: Dataset, idx: Array, g: PackedFloat64Array, h: PackedFloat64Array, d: int) -> Dictionary:
		if d >= max_depth or idx.size() < 2 * min_leaf:
			return _leaf(idx, g, h)
		# Mejor corte: el que más reduce el error cuadrático de los residuos (ganancia G²/H).
		var best := {}
		var tg := 0.0
		var th := 0.0
		for i: int in idx:
			tg += g[i]
			th += h[i]
		var parent := tg * tg / th
		var best_gain := 1e-9
		for f in ds.dims():
			var order := idx.duplicate()
			order.sort_custom(func(a: int, b: int) -> bool: return ds.rows[a][f] < ds.rows[b][f])
			var lg := 0.0
			var lh := 0.0
			for k in range(order.size() - 1):
				lg += g[order[k]]
				lh += h[order[k]]
				var nl := k + 1
				if nl < min_leaf or order.size() - nl < min_leaf:
					continue
				var v0: float = ds.rows[order[k]][f]
				var v1: float = ds.rows[order[k + 1]][f]
				if v0 == v1:
					continue
				var rg := tg - lg
				var rh := th - lh
				var gain := lg * lg / lh + rg * rg / rh - parent
				if gain > best_gain:
					best_gain = gain
					best = {"f": f, "t": (v0 + v1) / 2.0, "left": order.slice(0, k + 1), "right": order.slice(k + 1)}
		if best.is_empty():
			return _leaf(idx, g, h)
		splits[features[best["f"]]] = int(splits.get(features[best["f"]], 0)) + 1
		return {"f": best["f"], "t": best["t"], "left": _grow(ds, best["left"], g, h, d + 1), "right": _grow(ds, best["right"], g, h, d + 1)}
