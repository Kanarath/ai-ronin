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
	else:
		var f: ClassicML.Forest = e["model"]
		r.line("El bosque %s tiene %d árboles: demasiadas reglas para leerlas. Su resumen, la importancia de cada feature:" % [a["nombre"], f.trees.size()], "accent")
		_importance_table(r, f)
	c.emit("classic.shown", {"model": a["nombre"], "kind": e["kind"]})
	return r


static func _importance_table(r: CommandResult, f: ClassicML.Forest) -> void:
	var imp := f.importances()
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


static func _evaluate(c: CommandContext, a: Dictionary) -> CommandResult:
	var e: Dictionary = c.world.classics[a["nombre"]]
	var ds := c.world.get_dataset(a["dataset"])
	var acc := ClassicML.accuracy(e["model"], ds)
	var r := CommandResult.new()
	r.line("%s %s en %s · accuracy %.3f" % ["Árbol" if e["kind"] == "tree" else "Bosque", a["nombre"], ds.name, acc], "accent")
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
