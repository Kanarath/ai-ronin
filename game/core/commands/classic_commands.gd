class_name ClassicCommands
extends RefCounted
## T7 · ML clásico: árboles de decisión, bosques aleatorios y k-means sobre los datasets del
## laboratorio. Todo se calcula de verdad (sim/ml/trees.gd).

static func register(reg: CommandRegistry) -> void:
	reg.register(Command.new("tree train", "Entrena un árbol de decisión y enseña sus reglas.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _tree_train(c, a), "modelos")
		.with_signature(CommandSignature.new()
			.pos("nombre", "nombre del árbol")
			.pos("dataset", "dataset de entrenamiento", "dataset")
			.opt("depth", "profundidad máxima (número de preguntas seguidas)", "int", 3)
			.example("tree train t1 katanas_train --depth 2")))
	reg.register(Command.new("tree show", "Vuelve a enseñar las reglas de un árbol.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _tree_show(c, a), "modelos")
		.with_signature(CommandSignature.new().pos("nombre", "árbol o bosque", "classic")))
	reg.register(Command.new("forest train", "Entrena un bosque aleatorio: muchos árboles distintos que votan.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _forest_train(c, a), "modelos")
		.with_signature(CommandSignature.new()
			.pos("nombre", "nombre del bosque")
			.pos("dataset", "dataset de entrenamiento", "dataset")
			.opt("trees", "número de árboles", "int", 25)
			.opt("depth", "profundidad de cada árbol", "int", 4)
			.opt("seed", "semilla (para repetir el resultado)", "int", 1)
			.example("forest train b1 katanas_train --trees 25")))
	reg.register(Command.new("boost train", "Entrena gradient boosting: árboles pequeños en fila, cada uno corrige lo que falla el anterior.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _boost_train(c, a), "modelos")
		.with_signature(CommandSignature.new()
			.pos("nombre", "nombre del modelo")
			.pos("dataset", "dataset de entrenamiento", "dataset")
			.opt("rounds", "número de rondas (árboles en fila)", "int", 50)
			.opt("lr", "tasa de aprendizaje: cuánto se fía de cada corrección", "float", 0.3)
			.opt("depth", "profundidad de cada árbol (1 = un tocón, una sola pregunta)", "int", 1)
			.example("boost train g peticiones_train --rounds 50 --lr 0.3")))
	reg.register(Command.new("boost curve", "Accuracy de un gradient boosting ronda a ronda, en entrenamiento y en otro dataset.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _boost_curve(c, a), "modelos")
		.with_signature(CommandSignature.new()
			.pos("nombre", "modelo de boosting", "classic")
			.pos("dataset", "dataset de evaluación (test)", "dataset")
			.example("boost curve g peticiones_test")))
	reg.register(Command.new("classic evaluate", "Accuracy de un árbol o un bosque en un dataset.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _evaluate(c, a), "modelos")
		.with_signature(CommandSignature.new()
			.pos("nombre", "árbol o bosque", "classic")
			.pos("dataset", "dataset de evaluación", "dataset")
			.example("classic evaluate t1 katanas_test")))
	reg.register(Command.new("kmeans", "Agrupa un dataset en k grupos SIN mirar las etiquetas.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _kmeans(c, a), "modelos")
		.with_signature(CommandSignature.new()
			.pos("dataset", "dataset (normalizado mejor)", "dataset")
			.opt("k", "número de grupos", "int", 2)
			.opt("seed", "semilla", "int", 1)
			.example("kmeans katanas_minmax --k 2")))
	reg.register(Command.new("kmeans outliers", "Los puntos más lejos de su grupo: candidatos a anomalía.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _outliers(c, a), "modelos")
		.with_signature(CommandSignature.new()
			.pos("dataset", "dataset (normalizado mejor)", "dataset")
			.opt("k", "número de grupos", "int", 1)
			.opt("top", "cuántos enseñar", "int", 5)
			.opt("seed", "semilla", "int", 1)
			.example("kmeans outliers peticiones_minmax --k 1 --top 8")))


static func _tree_train(c: CommandContext, a: Dictionary) -> CommandResult:
	var ds := c.world.get_dataset(a["dataset"])
	var depth := clampi(int(a["depth"]), 1, 8)
	var t := ClassicML.DTree.new().fit(ds, ClassicML.all_idx(ds), depth)
	c.world.classics[a["nombre"]] = {"kind": "tree", "model": t, "trained_on": ds.name}
	var acc := ClassicML.accuracy(t, ds)
	var r := CommandResult.new()
	r.line("Árbol %s entrenado con %s · profundidad %d · %d hojas" % [a["nombre"], ds.name, t.depth(), t.leaves()], "accent")
	if t.leaves() <= 8:
		r.lines_from(t.rules(), "data")
	else:
		r.line("Tiene %d reglas finales: demasiadas para leerlas de un vistazo (tree show %s las enseña todas)." % [t.leaves(), a["nombre"]], "warn")
	r.line("Accuracy en %s (los mismos datos con los que ha aprendido): %.3f" % [ds.name, acc], "normal")
	r.line("Mídelo en datos que no ha visto: classic evaluate %s <dataset_test>" % a["nombre"], "muted")
	c.emit("tree.trained", {"model": a["nombre"], "dataset": ds.name, "depth": t.depth(), "max_depth": depth, "leaves": t.leaves(), "accuracy": acc})
	return r


static func _tree_show(c: CommandContext, a: Dictionary) -> CommandResult:
	var e: Dictionary = c.world.classics[a["nombre"]]
	var r := CommandResult.new()
	if e["kind"] == "tree":
		r.line("Reglas del árbol %s" % a["nombre"], "accent")
		r.lines_from((e["model"] as ClassicML.DTree).rules(), "data")
	elif e["kind"] == "boost":
		var gb: ClassicML.GBoost = e["model"]
		r.line("Boosting %s · %d rondas · las cinco primeras correcciones:" % [a["nombre"], gb.rounds.size()], "accent")
		for k in mini(5, gb.rounds.size()):
			r.line("  " + gb.describe(k), "data")
		_importance_table(r, gb)
	else:
		var f: ClassicML.Forest = e["model"]
		r.line("El bosque %s tiene %d árboles: demasiadas reglas para leerlas. Su resumen, la importancia de cada feature:" % [a["nombre"], f.trees.size()], "accent")
		_importance_table(r, f)
	c.emit("classic.shown", {"model": a["nombre"], "kind": e["kind"]})
	return r


static func _importance_table(r: CommandResult, f: Variant) -> void:
	var imp: Dictionary = f.importances()
	var keys: Array = imp.keys()
	keys.sort_custom(func(x: String, y: String) -> bool: return imp[x] > imp[y])
	var rows: Array = []
	for k: String in keys:
		rows.append([k, "%.0f %%" % (imp[k] * 100.0), "█".repeat(int(round(imp[k] * 20)))])
	r.table(PackedStringArray(["feature", "cortes", ""]), rows)


static func _forest_train(c: CommandContext, a: Dictionary) -> CommandResult:
	var ds := c.world.get_dataset(a["dataset"])
	var n := clampi(int(a["trees"]), 1, 200)
	var f := ClassicML.Forest.new().fit(ds, n, clampi(int(a["depth"]), 1, 8), int(a["seed"]))
	c.world.classics[a["nombre"]] = {"kind": "forest", "model": f, "trained_on": ds.name}
	var acc := ClassicML.accuracy(f, ds)
	var r := CommandResult.new()
	r.line("Bosque %s · %d árboles · cada uno ve una muestra distinta de %s y un subconjunto de features" % [a["nombre"], n, ds.name], "accent")
	_importance_table(r, f)
	r.line("Accuracy en %s (datos de entrenamiento): %.3f · mídelo en test con classic evaluate" % [ds.name, acc], "normal")
	c.emit("forest.trained", {"model": a["nombre"], "dataset": ds.name, "trees": n, "accuracy": acc})
	return r


static func _boost_train(c: CommandContext, a: Dictionary) -> CommandResult:
	var ds := c.world.get_dataset(a["dataset"])
	if ds.classes().size() != 2:
		return CommandResult.error("Este gradient boosting es para dos clases; %s tiene %d." % [ds.name, ds.classes().size()])
	var n := clampi(int(a["rounds"]), 1, 400)
	var lr := clampf(float(a["lr"]), 0.01, 1.0)
	var depth := clampi(int(a["depth"]), 1, 4)
	var gb := ClassicML.GBoost.new().fit(ds, n, lr, depth)
	c.world.classics[a["nombre"]] = {"kind": "boost", "model": gb, "trained_on": ds.name}
	var acc := ClassicML.accuracy(gb, ds)
	var r := CommandResult.new()
	r.line("Boosting %s con %s · %d rondas · tasa %s · árboles de profundidad %d · detecta «%s»" % [a["nombre"], ds.name, n, str(lr), depth, gb.positive], "accent")
	r.line("Empieza diciendo lo mismo a todos (la proporción de «%s») y cada ronda corrige un poco:" % gb.positive, "muted")
	for k in mini(3, n):
		r.line("  " + gb.describe(k), "data")
	if n > 3:
		r.line("  … y %d rondas más" % (n - 3), "muted")
	r.line("Accuracy en %s (datos de entrenamiento): %.3f · mídelo en test con classic evaluate o boost curve" % [ds.name, acc], "normal")
	c.emit("boost.trained", {"model": a["nombre"], "dataset": ds.name, "rounds": n, "lr": lr, "depth": depth, "accuracy": acc})
	return r


static func _boost_curve(c: CommandContext, a: Dictionary) -> CommandResult:
	var e: Dictionary = c.world.classics[a["nombre"]]
	if e["kind"] != "boost":
		return CommandResult.error("%s no es un modelo de boosting (boost train)." % a["nombre"])
	var gb: ClassicML.GBoost = e["model"]
	var train := c.world.get_dataset(e["trained_on"])
	var ds := c.world.get_dataset(a["dataset"])
	var n := gb.rounds.size()
	var marks: Array = []
	for m in [1, 2, 5, 10, 20, 50, 100, 200, 400]:
		if m < n:
			marks.append(m)
	marks.append(n)
	var rows: Array = []
	var best_k := 1
	var best_acc := -1.0
	for m: int in marks:
		var tr := gb.accuracy_upto(train, m) if train != null else 0.0
		var te := gb.accuracy_upto(ds, m)
		if te > best_acc + 1e-9:
			best_acc = te
			best_k = m
		rows.append([str(m), "%.3f" % tr, "%.3f" % te, "█".repeat(int(round(te * 20)))])
	var r := CommandResult.new()
	r.line("Curva de %s · entrenamiento (%s) frente a %s" % [a["nombre"], e["trained_on"], ds.name], "accent")
	r.table(PackedStringArray(["rondas", "entrenamiento", ds.name, ""]), rows)
	r.line("Mejor en %s: %.3f con %d rondas. Si entrenamiento sube y test baja, sobran rondas." % [ds.name, best_acc, best_k], "normal")
	c.emit("boost.curve", {"model": a["nombre"], "dataset": ds.name, "best_rounds": best_k, "best_accuracy": best_acc, "final_accuracy": gb.accuracy_upto(ds, n)})
	return r


static func _evaluate(c: CommandContext, a: Dictionary) -> CommandResult:
	var e: Dictionary = c.world.classics[a["nombre"]]
	var ds := c.world.get_dataset(a["dataset"])
	var acc := ClassicML.accuracy(e["model"], ds)
	var r := CommandResult.new()
	r.line("%s %s en %s · accuracy %.3f" % [{"tree": "Árbol", "forest": "Bosque", "boost": "Boosting"}.get(e["kind"], "Modelo"), a["nombre"], ds.name, acc], "accent")
	if e["trained_on"] == ds.name:
		r.line("Ojo: es el mismo dataset con el que aprendió; para saber si generaliza, usa uno de test.", "warn")
	c.emit("classic.evaluated", {"model": a["nombre"], "kind": e["kind"], "dataset": ds.name, "accuracy": acc, "same_as_train": e["trained_on"] == ds.name})
	return r


static func _kmeans(c: CommandContext, a: Dictionary) -> CommandResult:
	var ds := c.world.get_dataset(a["dataset"])
	var k := clampi(int(a["k"]), 1, 8)
	var res := ClassicML.kmeans(ds, k, int(a["seed"]))
	var r := CommandResult.new()
	r.line("k-means sobre %s con k = %d (sin mirar la columna %s)" % [ds.name, k, ds.label_name], "accent")
	var rows: Array = []
	var pure := 0
	for g in k:
		var idx: Array = []
		for i in ds.size():
			if res["assign"][i] == g:
				idx.append(i)
		var cnt := ClassicML.counts(ds, idx)
		var maj := ClassicML.majority(cnt)
		pure += int(cnt.get(maj, 0))
		var comp := PackedStringArray()
		for lab: String in cnt:
			comp.append("%s %d" % [lab, cnt[lab]])
		var cent := PackedStringArray()
		for v: float in res["centroids"][g]:
			cent.append(str(snappedf(v, 0.01)))
		rows.append(["grupo %d" % g, str(idx.size()), "[" + ", ".join(cent) + "]", " · ".join(comp)])
	r.table(PackedStringArray(["grupo", "tamaño", "centro (%s)" % ", ".join(ds.feature_names), "qué hay dentro (etiquetas reales)"]), rows)
	var purity := float(pure) / maxf(ds.size(), 1)
	r.line("Pureza: %.2f (fracción de puntos cuya etiqueta es la mayoritaria de su grupo) · inercia %.3f" % [purity, res["inertia"]], "normal")
	r.line("k-means no conoce las etiquetas: las enseñamos solo para ver si los grupos que encuentra tienen sentido.", "muted")
	c.emit("kmeans.done", {"dataset": ds.name, "k": k, "purity": purity, "inertia": res["inertia"]})
	return r


static func _outliers(c: CommandContext, a: Dictionary) -> CommandResult:
	var ds := c.world.get_dataset(a["dataset"])
	var k := clampi(int(a["k"]), 1, 8)
	var top := clampi(int(a["top"]), 1, 30)
	var res := ClassicML.kmeans(ds, k, int(a["seed"]))
	var order: Array = range(ds.size())
	order.sort_custom(func(x: int, y: int) -> bool: return res["dist"][x] > res["dist"][y])
	var rows: Array = []
	var counts := {}
	for j in mini(top, order.size()):
		var i: int = order[j]
		rows.append([ds.ids[i], str(snappedf(res["dist"][i], 0.001)), ds.labels[i]])
		counts[ds.labels[i]] = int(counts.get(ds.labels[i], 0)) + 1
	var r := CommandResult.new()
	r.line("Los %d puntos más lejos de su centro en %s (k = %d)" % [top, ds.name, k], "accent")
	r.table(PackedStringArray(["id", "distancia al centro", "etiqueta real"]), rows)
	var comp := PackedStringArray()
	for lab: String in counts:
		comp.append("%s %d" % [lab, counts[lab]])
	r.line("Entre ellos: %s. Lo raro no siempre es malo, ni lo malo siempre es raro." % " · ".join(comp), "normal")
	c.emit("kmeans.outliers", {"dataset": ds.name, "k": k, "top": top, "labels": counts})
	return r


# ── T10 · Datos justos ──────────────────────────────────────────────────────

static func register_fairness(reg: CommandRegistry) -> void:
	reg.register(Command.new("dataset drop", "Crea una copia de un dataset sin una feature.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _drop(c, a), "datos")
		.with_signature(CommandSignature.new()
			.pos("dataset", "dataset", "dataset")
			.pos("feature", "la feature que se quita")
			.opt("as", "nombre de la copia", "string", "")
			.example("dataset drop candidatos grupo --as sin_grupo")))
	reg.register(Command.new("fairness", "Equidad por grupo: tasa de selección, acierto y regla del 80 % (de un modelo o de los datos).",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _fairness(c, a), "modelos")
		.with_signature(CommandSignature.new()
			.pos("modelo", "árbol o bosque, o «datos» para las decisiones históricas")
			.pos("dataset", "dataset donde se mide", "dataset")
			.opt("grupos", "dataset del que se lee la columna de grupo (por id)", "string", "")
			.opt("grupo", "columna con el grupo", "string", "grupo")
			.opt("positivo", "la decisión favorable", "string", "apta")
			.example("fairness datos candidatos").example("fairness t sin_grupo --grupos candidatos")))
	reg.register(Command.new("fairness umbral", "Aprobar por puntuación con un umbral (o uno por grupo) y comparar tres medidas de equidad.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _fairness_threshold(c, a), "modelos")
		.with_signature(CommandSignature.new()
			.pos("dataset", "dataset con puntuación, grupo y resultado real", "dataset")
			.opt("umbral", "se aprueba si la puntuación llega a este umbral", "float", 0.5)
			.opt("umbral1", "umbral distinto para el grupo 1 (si no, el mismo)", "float", -1.0)
			.opt("puntuacion", "columna con la puntuación", "string", "puntuacion")
			.opt("grupo", "columna con el grupo", "string", "grupo")
			.opt("positivo", "el resultado real bueno", "string", "si")
			.example("fairness umbral prestamos --umbral 0.5").example("fairness umbral prestamos --umbral 0.5 --umbral1 0.35")))


static func _drop(c: CommandContext, a: Dictionary) -> CommandResult:
	var ds := c.world.get_dataset(a["dataset"])
	var fi := ds.feature_index(a["feature"])
	if fi < 0:
		return CommandResult.error("%s no tiene la feature «%s». Tiene: %s" % [ds.name, a["feature"], ", ".join(ds.feature_names)])
	var dest: String = a["as"] if not str(a["as"]).is_empty() else "%s_sin_%s" % [ds.name, a["feature"]]
	var out := ds.copy(dest)
	var names := PackedStringArray()
	for k in ds.feature_names.size():
		if k != fi:
			names.append(ds.feature_names[k])
	out.feature_names = names
	for i in out.rows.size():
		var row := PackedFloat64Array()
		for k in ds.feature_names.size():
			if k != fi:
				row.append(ds.rows[i][k])
		out.rows[i] = row
	out.lineage.append("sin %s" % a["feature"])
	c.world.add_dataset(out)
	var r := CommandResult.new()
	r.line("✓ %s creado: %s sin la feature %s (quedan: %s)" % [dest, ds.name, a["feature"], ", ".join(names)], "ok")
	c.emit("dataset.dropped", {"dataset": ds.name, "dest": dest, "feature": a["feature"]})
	return r


static func _fairness(c: CommandContext, a: Dictionary) -> CommandResult:
	var ds := c.world.get_dataset(a["dataset"])
	var gname: String = a["grupos"] if not str(a["grupos"]).is_empty() else ds.name
	var gds := c.world.get_dataset(gname)
	if gds == null:
		return CommandResult.error("No existe el dataset de grupos «%s»." % gname)
	var gi := gds.feature_index(a["grupo"])
	if gi < 0:
		return CommandResult.error("%s no tiene la columna «%s»." % [gname, a["grupo"]])
	var use_model: bool = a["modelo"] != "datos"
	var model: Variant = null
	if use_model:
		if not c.world.classics.has(a["modelo"]):
			return CommandResult.error("No hay ningún árbol o bosque «%s» (o usa «datos»)." % a["modelo"])
		model = c.world.classics[a["modelo"]]["model"]
	var stats := {}
	for i in ds.size():
		var gid := gds.index_of_id(ds.ids[i])
		if gid < 0:
			continue
		var g := str(int(gds.rows[gid][gi]))
		var pred: String = model.predict(ds.rows[i]) if use_model else ds.labels[i]
		if not stats.has(g):
			stats[g] = {"n": 0, "sel": 0, "ok": 0}
		stats[g]["n"] += 1
		stats[g]["sel"] += int(pred == a["positivo"])
		stats[g]["ok"] += int(pred == ds.labels[i])
	var keys: Array = stats.keys()
	keys.sort()
	var rows: Array = []
	var rates := {}
	for g: String in keys:
		var s: Dictionary = stats[g]
		rates[g] = float(s["sel"]) / s["n"]
		rows.append(["grupo " + g, str(s["n"]), "%.3f" % rates[g], "%.3f" % (float(s["ok"]) / s["n"]) if use_model else "—"])
	var hi := 0.0
	var lo := 1.0
	for g: String in rates:
		hi = maxf(hi, rates[g])
		lo = minf(lo, rates[g])
	var ratio := lo / hi if hi > 0 else 1.0
	var r := CommandResult.new()
	r.line("Equidad de %s en %s · decisión favorable: %s" % [a["modelo"] if use_model else "las decisiones históricas", ds.name, a["positivo"]], "accent")
	r.table(PackedStringArray(["grupo", "candidatos", "tasa de selección", "acierto (frente a las decisiones históricas)"]), rows)
	r.line("Ratio entre la tasa más baja y la más alta: %.2f %s" % [ratio, "· ⚠ por debajo de 0,80 (regla del 80 %)" if ratio < 0.8 else "· por encima de 0,80"], "warn" if ratio < 0.8 else "ok")
	r.line("El acierto se mide contra decisiones del pasado: si esas decisiones eran injustas, acertar es repetirlas.", "muted")
	c.emit("fairness.measured", {"model": a["modelo"], "dataset": ds.name, "ratio": ratio, "rate_0": rates.get("0", 0.0), "rate_1": rates.get("1", 0.0)})
	return r


## T10-03: con el resultado real conocido, un umbral sobre la puntuación da tres medidas por grupo
## que no se pueden igualar todas a la vez si las tasas base son distintas.
static func _fairness_threshold(c: CommandContext, a: Dictionary) -> CommandResult:
	var ds := c.world.get_dataset(a["dataset"])
	var si := ds.feature_index(a["puntuacion"])
	var gi := ds.feature_index(a["grupo"])
	if si < 0 or gi < 0:
		return CommandResult.error("%s necesita las columnas «%s» y «%s». Tiene: %s" % [ds.name, a["puntuacion"], a["grupo"], ", ".join(ds.feature_names)])
	var th0: float = a["umbral"]
	var th1: float = a["umbral1"] if float(a["umbral1"]) >= 0.0 else th0
	var st := {}
	for i in ds.size():
		var g := str(int(ds.rows[i][gi]))
		if not st.has(g):
			st[g] = {"n": 0, "pos": 0, "ap": 0, "tp": 0}
		var ok: bool = ds.labels[i] == a["positivo"]
		var ap: bool = ds.rows[i][si] >= (th1 if g == "1" else th0)
		st[g]["n"] += 1
		st[g]["pos"] += int(ok)
		st[g]["ap"] += int(ap)
		st[g]["tp"] += int(ap and ok)
	var keys: Array = st.keys()
	keys.sort()
	var rows: Array = []
	var m := {}
	for g: String in keys:
		var s: Dictionary = st[g]
		var e := {
			"base": float(s["pos"]) / s["n"],
			"ap": float(s["ap"]) / s["n"],
			"tpr": float(s["tp"]) / s["pos"] if s["pos"] > 0 else 0.0,
			"prec": float(s["tp"]) / s["ap"] if s["ap"] > 0 else 0.0,
		}
		m[g] = e
		rows.append(["grupo " + g, "%.2f" % (th1 if g == "1" else th0), str(s["n"]), "%.3f" % e["base"], "%.3f" % e["ap"], "%.3f" % e["tpr"], "%.3f" % e["prec"]])
	var lo := 1.0
	var hi := 0.0
	var tlo := 1.0
	var thi := 0.0
	for g: String in m:
		lo = minf(lo, m[g]["ap"])
		hi = maxf(hi, m[g]["ap"])
		tlo = minf(tlo, m[g]["tpr"])
		thi = maxf(thi, m[g]["tpr"])
	var ratio := lo / hi if hi > 0 else 1.0
	var r := CommandResult.new()
	r.line("Aprobación por puntuación en %s · se aprueba si %s ≥ umbral" % [ds.name, a["puntuacion"]], "accent")
	r.table(PackedStringArray(["grupo", "umbral", "solicitudes", "devuelven (tasa base)", "aprobados", "de los que devuelven, aprobados", "de los aprobados, devuelven"]), rows)
	r.line("Paridad de aprobación (regla del 80 %%): ratio %.2f %s" % [ratio, "⚠" if ratio < 0.8 else "✓"], "warn" if ratio < 0.8 else "ok")
	r.line("Igualdad de oportunidades (de los que devuelven, aprobados): diferencia %.3f" % (thi - tlo), "normal")
	if m.has("0") and m.has("1"):
		r.line("Precisión (de los aprobados, devuelven): grupo 0 %.3f · grupo 1 %.3f" % [m["0"]["prec"], m["1"]["prec"]], "normal")
	r.line("Si las tasas base son distintas, no se pueden igualar las tres a la vez: hay que elegir cuál importa.", "muted")
	c.emit("fairness.threshold", {"dataset": ds.name, "umbral": th0, "umbral1": th1, "ratio": ratio, "tpr_gap": thi - tlo,
		"prec_0": m.get("0", {}).get("prec", 0.0), "prec_1": m.get("1", {}).get("prec", 0.0)})
	return r
