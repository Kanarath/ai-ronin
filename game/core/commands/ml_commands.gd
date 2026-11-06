class_name MlCommands
extends RefCounted
## Comandos de datos y modelos (tronco común T1-T2). Operan sobre el SimWorld
## con el ML de referencia de sim/ml (cálculo real, no resultados guionizados).


static func register(reg: CommandRegistry) -> void:
	# ── Datos ────────────────────────────────────────────────────────────────
	reg.register(Command.new("dataset list", "Datasets cargados en el laboratorio.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _ds_list(c, a), "datos"))

	reg.register(Command.new("dataset inspect", "Muestra la estructura y las primeras filas.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _ds_inspect(c, a), "datos")
		.with_signature(CommandSignature.new()
			.pos("dataset", "nombre del dataset", "dataset")
			.opt("rows", "número de filas a mostrar", "int", 8)
			.example("dataset inspect katanas")
			.example("dataset inspect katanas --rows 20")))

	reg.register(Command.new("dataset stats", "Estadísticas por feature y recuento de clases.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _ds_stats(c, a), "datos")
		.with_signature(CommandSignature.new()
			.pos("dataset", "nombre del dataset", "dataset")
			.example("dataset stats katanas"))
		.with_details("La desviación típica es poblacional (divide entre n), como numpy.std()."))

	reg.register(Command.new("dataset normalize", "Crea una copia normalizada de un dataset.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _ds_normalize(c, a), "datos")
		.with_signature(CommandSignature.new()
			.pos("dataset", "dataset a transformar", "dataset")
			.opt("method", "método de normalización", "string", "minmax", ["minmax", "zscore"])
			.opt("fit", "dataset del que se APRENDEN los parámetros (por defecto, el mismo)", "dataset")
			.opt("as", "nombre del nuevo dataset", "string")
			.example("dataset normalize katanas --method minmax")
			.example("dataset normalize katanas_test --fit katanas_train --as test_n"))
		.with_details("Los parámetros (mín/máx o media/desviación) se aprenden de --fit y se aplican al dataset. Piensa bien de qué datos los aprendes: ver 'explain fuga de datos'."))

	reg.register(Command.new("dataset split", "Divide un dataset en entrenamiento y test.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _ds_split(c, a), "datos")
		.with_signature(CommandSignature.new()
			.pos("dataset", "dataset a dividir", "dataset")
			.opt("test", "proporción para test (entre 0.05 y 0.9)", "float", 0.3)
			.opt("seed", "semilla aleatoria (misma semilla → misma división)", "int", 42)
			.example("dataset split katanas --test 0.3 --seed 42")))

	reg.register(Command.new("distance", "Distancia entre dos ejemplos, con el desglose por feature.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _distance(c, a), "datos")
		.with_signature(CommandSignature.new()
			.pos("dataset", "dataset donde están los ejemplos", "dataset")
			.pos("id_a", "id del primer ejemplo")
			.pos("id_b", "id del segundo ejemplo")
			.opt("metric", "métrica de distancia", "string", "euclidean", ["euclidean", "manhattan"])
			.example("distance katanas hoja-001 hoja-002")))

	# ── Modelos ──────────────────────────────────────────────────────────────
	reg.register(Command.new("model create", "Crea un clasificador k-NN.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _model_create(c, a), "modelos")
		.with_signature(CommandSignature.new()
			.pos("nombre", "nombre del modelo (letras, números, _ y -)")
			.opt("k", "número de vecinos que votan", "int", 3)
			.opt("metric", "métrica de distancia", "string", "euclidean", ["euclidean", "manhattan"])
			.example("model create m1 --k 5")))

	reg.register(Command.new("model list", "Modelos creados.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _model_list(c, a), "modelos"))

	reg.register(Command.new("model info", "Detalle de un modelo.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _model_info(c, a), "modelos")
		.with_signature(CommandSignature.new().pos("modelo", "nombre del modelo", "model")))

	reg.register(Command.new("model train", "Entrena un modelo con un dataset.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _model_train(c, a), "modelos")
		.with_signature(CommandSignature.new()
			.pos("modelo", "nombre del modelo", "model")
			.pos("dataset", "dataset de entrenamiento", "dataset")
			.example("model train m1 katanas_train"))
		.with_details("k-NN no ajusta parámetros: «entrenar» consiste en guardar los ejemplos."))

	reg.register(Command.new("model predict", "Predice la clase de un ejemplo y muestra sus vecinos.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _model_predict(c, a), "modelos")
		.with_signature(CommandSignature.new()
			.pos("modelo", "modelo entrenado", "model")
			.pos("dataset", "dataset donde está el ejemplo", "dataset")
			.pos("id", "id del ejemplo")
			.example("model predict m1 katanas_test hoja-007")))

	reg.register(Command.new("model evaluate", "Mide la accuracy y la matriz de confusión en un dataset.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _model_evaluate(c, a), "modelos")
		.with_signature(CommandSignature.new()
			.pos("modelo", "modelo entrenado", "model")
			.pos("dataset", "dataset de evaluación", "dataset")
			.example("model evaluate m1 katanas_test")))

	reg.register(Command.new("model sweep", "Compara la accuracy en train y test para varios valores de k.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _model_sweep(c, a), "modelos")
		.with_signature(CommandSignature.new()
			.opt("train", "dataset de entrenamiento", "dataset")
			.opt("test", "dataset de test", "dataset")
			.opt("k", "lista de valores de k separados por comas", "string", "1,3,5,9,15,31")
			.opt("metric", "métrica de distancia", "string", "euclidean", ["euclidean", "manhattan"])
			.example("model sweep --train katanas_train --test katanas_test --k 1,3,5,9,15")))


# ── Datos ────────────────────────────────────────────────────────────────────

static func _ds_list(c: CommandContext, _a: Dictionary) -> CommandResult:
	var r := CommandResult.new()
	var names := c.world.names_of("dataset")
	if names.is_empty():
		return r.line("No hay datasets cargados.", "muted")
	var data: Array = []
	for n in names:
		var ds := c.world.get_dataset(n)
		var lineage := " → ".join(PackedStringArray(ds.lineage)) if not ds.lineage.is_empty() else "original"
		data.append([n, ds.size(), ds.dims(), ", ".join(ds.classes()), lineage])
	c.emit("dataset.listed")
	return r.table(PackedStringArray(["dataset", "filas", "features", "clases", "linaje"]), data)


static func _ds_inspect(c: CommandContext, a: Dictionary) -> CommandResult:
	var ds := c.world.get_dataset(a["dataset"])
	var n := clampi(a["rows"], 1, 200)
	var r := CommandResult.new()
	r.line("%s · %d ejemplos · %d features · etiqueta: %s" % [ds.name, ds.size(), ds.dims(), ds.label_name], "accent")
	r.line("features: " + ", ".join(ds.feature_names), "muted")
	var headers := PackedStringArray(["id"])
	headers.append_array(ds.feature_names)
	headers.append(ds.label_name)
	var data: Array = []
	for i in mini(n, ds.size()):
		var row: Array = [ds.ids[i]]
		for v in ds.rows[i]:
			row.append(_num(v))
		row.append(ds.labels[i])
		data.append(row)
	r.table(headers, data)
	if ds.size() > n:
		r.line("… %d filas más (usa --rows)" % (ds.size() - n), "muted")
	c.emit("dataset.inspected", {"dataset": ds.name, "rows": n})
	return r


static func _ds_stats(c: CommandContext, a: Dictionary) -> CommandResult:
	var ds := c.world.get_dataset(a["dataset"])
	var r := CommandResult.new()
	r.line("Estadísticas de %s (%d ejemplos)" % [ds.name, ds.size()], "accent")
	var data: Array = []
	for s in ds.stats():
		data.append([s["feature"], _num(s["mean"]), _num(s["std"]), _num(s["min"]), _num(s["max"]), _num(s["max"] - s["min"])])
	r.table(PackedStringArray(["feature", "media", "desv.típica", "mín", "máx", "rango"]), data)
	r.line("")
	var counts := ds.class_counts()
	var cdata: Array = []
	for cls in ds.classes():
		cdata.append([cls, counts[cls], "%.1f %%" % (100.0 * counts[cls] / ds.size())])
	r.table(PackedStringArray([ds.label_name, "ejemplos", "proporción"]), cdata)
	c.emit("dataset.stats", {"dataset": ds.name})
	return r


static func _ds_normalize(c: CommandContext, a: Dictionary) -> CommandResult:
	var ds := c.world.get_dataset(a["dataset"])
	var fit_name: String = a["fit"] if a["fit"] != null else ds.name
	var fit_ds := c.world.get_dataset(fit_name)
	if fit_ds.feature_names != ds.feature_names:
		return CommandResult.error("'%s' y '%s' no tienen las mismas features." % [fit_name, ds.name])
	var method: String = a["method"]
	var target: String = a["as"] if a["as"] != null else "%s_%s" % [ds.name, method]
	var norm := Normalizer.new(method)
	norm.fit(fit_ds)
	var out := norm.transform(ds, target)
	c.world.add_dataset(out)
	var r := CommandResult.new()
	r.line("✓ %s creado (%s, parámetros aprendidos de '%s')" % [target, method, fit_name], "ok")
	var data: Array = []
	var pa := "mín" if method == "minmax" else "media"
	var pb := "máx" if method == "minmax" else "desv.típica"
	for i in ds.dims():
		data.append([ds.feature_names[i], _num(norm.param_a[i]), _num(norm.param_b[i])])
	r.table(PackedStringArray(["feature", pa, pb]), data)
	c.emit("dataset.normalized", {"source": ds.name, "method": method, "fit_on": fit_name, "target": target,
		"fit_overlap_with_source": fit_ds.overlap_count(ds), "fit_size": fit_ds.size()})
	return r


static func _ds_split(c: CommandContext, a: Dictionary) -> CommandResult:
	var ds := c.world.get_dataset(a["dataset"])
	var ratio: float = a["test"]
	if ratio < 0.05 or ratio > 0.9:
		return CommandResult.error("--test debe estar entre 0.05 y 0.9 (recibido %s)." % ratio)
	var parts := Splitter.train_test_split(ds, ratio, a["seed"])
	c.world.add_dataset(parts[0])
	c.world.add_dataset(parts[1])
	var r := CommandResult.new()
	r.line("✓ %s: %d ejemplos · %s: %d ejemplos (semilla %d)" % [parts[0].name, parts[0].size(), parts[1].name, parts[1].size(), a["seed"]], "ok")
	r.line("El test se aparta ANTES de entrenar: es tu estimación honesta de cómo funcionará el modelo con datos nuevos.", "muted")
	c.emit("dataset.split", {"source": ds.name, "test_ratio": ratio, "seed": a["seed"], "train": parts[0].name, "test": parts[1].name})
	return r


static func _distance(c: CommandContext, a: Dictionary) -> CommandResult:
	var ds := c.world.get_dataset(a["dataset"])
	var ia := ds.index_of_id(a["id_a"])
	var ib := ds.index_of_id(a["id_b"])
	for pair in [[ia, a["id_a"]], [ib, a["id_b"]]]:
		if pair[0] == -1:
			return CommandResult.error("No existe el ejemplo '%s' en %s. Mira los ids con: dataset inspect %s" % [pair[1], ds.name, ds.name])
	var va := ds.rows[ia]
	var vb := ds.rows[ib]
	var metric: String = a["metric"]
	var value := Vec.distance(metric, va, vb)
	var contrib: Array[float] = []
	for i in ds.dims():
		var d := absf(va[i] - vb[i])
		contrib.append(d * d if metric == "euclidean" else d)
	var total := 0.0
	for x in contrib:
		total += x
	var r := CommandResult.new()
	var metric_name := "euclídea" if metric == "euclidean" else "Manhattan"
	r.line("Distancia %s entre %s y %s en %s" % [metric_name, a["id_a"], a["id_b"], ds.name], "accent")
	var data: Array = []
	var dominant := 0
	for i in ds.dims():
		if contrib[i] > contrib[dominant]:
			dominant = i
		var share := 0.0 if total == 0.0 else 100.0 * contrib[i] / total
		data.append([ds.feature_names[i], _num(va[i]), _num(vb[i]), _num(va[i] - vb[i]), _num(contrib[i]), "%.1f %%" % share])
	var contrib_header := "diferencia²" if metric == "euclidean" else "|diferencia|"
	r.table(PackedStringArray(["feature", a["id_a"], a["id_b"], "diferencia", contrib_header, "peso"]), data)
	if metric == "euclidean":
		r.line("distancia = √(%s) = %s" % [_num(total), _num(value)], "data")
	else:
		r.line("distancia = %s" % _num(value), "data")
	var share_dom := 0.0 if total == 0.0 else contrib[dominant] / total
	c.emit("distance.computed", {"dataset": ds.name, "a": a["id_a"], "b": a["id_b"], "metric": metric, "value": value,
		"dominant_feature": ds.feature_names[dominant], "dominant_share": share_dom, "normalized": not ds.lineage.is_empty() and _is_normalized(ds)})
	return r


# ── Modelos ──────────────────────────────────────────────────────────────────

static func _model_create(c: CommandContext, a: Dictionary) -> CommandResult:
	var model_name: String = a["nombre"]
	var valid := RegEx.create_from_string("^[A-Za-z0-9_-]{1,32}$")
	if valid.search(model_name) == null:
		return CommandResult.error("Nombre de modelo no válido: usa letras, números, _ o - (máx. 32).")
	var k: int = a["k"]
	if k < 1:
		return CommandResult.error("k debe ser al menos 1.")
	var r := CommandResult.new()
	if c.world.models.has(model_name):
		r.line("Aviso: el modelo '%s' ya existía y se ha reemplazado." % model_name, "warn")
	c.world.models[model_name] = {"model": KNNClassifier.new(k, a["metric"]), "trained_on": ""}
	r.line("✓ modelo %s creado: k-NN con k=%d, métrica %s · sin entrenar" % [model_name, k, a["metric"]], "ok")
	c.emit("model.created", {"model": model_name, "k": k, "metric": a["metric"]})
	return r


static func _model_list(c: CommandContext, _a: Dictionary) -> CommandResult:
	var r := CommandResult.new()
	var names := c.world.names_of("model")
	if names.is_empty():
		return r.line("No hay modelos. Crea uno con: model create <nombre> --k 3", "muted")
	var data: Array = []
	for n in names:
		var entry := c.world.get_model(n)
		var m: KNNClassifier = entry["model"]
		data.append([n, "k-NN", m.k, m.metric, entry["trained_on"] if entry["trained_on"] != "" else "(sin entrenar)"])
	return r.table(PackedStringArray(["modelo", "tipo", "k", "métrica", "entrenado con"]), data)


static func _model_info(c: CommandContext, a: Dictionary) -> CommandResult:
	var entry := c.world.get_model(a["modelo"])
	var m: KNNClassifier = entry["model"]
	var r := CommandResult.new()
	r.line("%s · k-NN" % a["modelo"], "accent")
	r.line("k = %d · métrica = %s" % [m.k, m.metric])
	if m.is_trained():
		r.line("entrenado con %s (%d ejemplos memorizados)" % [entry["trained_on"], m.train_set.size()])
	else:
		r.line("sin entrenar", "warn")
	return r


static func _model_train(c: CommandContext, a: Dictionary) -> CommandResult:
	var entry := c.world.get_model(a["modelo"])
	var ds := c.world.get_dataset(a["dataset"])
	var m: KNNClassifier = entry["model"]
	m.fit(ds)
	entry["trained_on"] = ds.name
	var r := CommandResult.new()
	r.line("✓ %s entrenado con %s: %d ejemplos memorizados" % [a["modelo"], ds.name, ds.size()], "ok")
	r.line("k-NN no aprende pesos: guarda los ejemplos y decide al predecir.", "muted")
	c.emit("model.trained", {"model": a["modelo"], "dataset": ds.name, "k": m.k, "size": ds.size(), "normalized": _is_normalized(ds)})
	return r


static func _model_predict(c: CommandContext, a: Dictionary) -> CommandResult:
	var entry := c.world.get_model(a["modelo"])
	var m: KNNClassifier = entry["model"]
	if not m.is_trained():
		return CommandResult.error("El modelo '%s' no está entrenado. Usa: model train %s <dataset>" % [a["modelo"], a["modelo"]])
	var ds := c.world.get_dataset(a["dataset"])
	var idx := ds.index_of_id(a["id"])
	if idx == -1:
		return CommandResult.error("No existe el ejemplo '%s' en %s." % [a["id"], ds.name])
	if ds.feature_names != m.train_set.feature_names:
		return CommandResult.error("El dataset no tiene las mismas features que el entrenamiento.")
	var x := ds.rows[idx]
	var nb := m.neighbors(x)
	var label := m.predict_one(x)
	var truth := ds.labels[idx]
	var in_train := m.train_set.index_of_id(a["id"]) != -1
	var r := CommandResult.new()
	r.line("Vecinos más cercanos de %s (k=%d)" % [a["id"], m.k], "accent")
	var data: Array = []
	for i in nb.size():
		data.append([i + 1, nb[i]["id"], _num(nb[i]["distance"]), nb[i]["label"]])
	r.table(PackedStringArray(["#", "vecino", "distancia", "clase"]), data)
	r.line("Predicción: %s · Real: %s · %s" % [label, truth, "✓ acierto" if label == truth else "✗ fallo"], "ok" if label == truth else "warn")
	if in_train:
		r.line("Ojo: este ejemplo está en el conjunto de entrenamiento; su vecino más cercano es él mismo (distancia 0).", "warn")
	if not _is_normalized(ds) == _is_normalized(m.train_set):
		r.line("Ojo: el modelo se entrenó con datos %s, pero este ejemplo está %s." % [
			"normalizados" if _is_normalized(m.train_set) else "sin normalizar",
			"normalizado" if _is_normalized(ds) else "sin normalizar"], "warn")
	c.emit("model.predicted", {"model": a["modelo"], "dataset": ds.name, "id": a["id"], "k": m.k, "label": label,
		"truth": truth, "correct": label == truth, "in_train": in_train, "neighbors": nb.map(func(n: Dictionary) -> String: return n["id"])})
	return r


static func _model_evaluate(c: CommandContext, a: Dictionary) -> CommandResult:
	var entry := c.world.get_model(a["modelo"])
	var m: KNNClassifier = entry["model"]
	if not m.is_trained():
		return CommandResult.error("El modelo '%s' no está entrenado. Usa: model train %s <dataset>" % [a["modelo"], a["modelo"]])
	var ds := c.world.get_dataset(a["dataset"])
	if ds.feature_names != m.train_set.feature_names:
		return CommandResult.error("El dataset no tiene las mismas features que el entrenamiento.")
	var pred := m.predict(ds)
	var acc := Metrics.accuracy(ds.labels, pred)
	var classes := ds.classes()
	var cm := Metrics.confusion_matrix(ds.labels, pred, classes)
	var overlap := m.train_set.overlap_count(ds)
	var r := CommandResult.new()
	r.line("Evaluación de %s (k=%d, entrenado con %s) sobre %s" % [a["modelo"], m.k, entry["trained_on"], ds.name], "accent")
	r.line("accuracy = %d / %d = %s" % [roundi(acc * ds.size()), ds.size(), _num(acc)], "data")
	r.line("")
	r.line("Matriz de confusión (filas = real, columnas = predicho):", "muted")
	var headers := PackedStringArray(["real \\ pred"])
	headers.append_array(classes)
	var data: Array = []
	for i in classes.size():
		var row: Array = [classes[i]]
		row.append_array(cm["matrix"][i])
		data.append(row)
	r.table(headers, data)
	if overlap > 0:
		r.line("")
		r.line("⚠ %d de los %d ejemplos evaluados también estaban en el entrenamiento." % [overlap, ds.size()], "warn")
	c.emit("model.evaluated", {"model": a["modelo"], "dataset": ds.name, "trained_on": entry["trained_on"], "k": m.k,
		"accuracy": acc, "overlap": overlap, "size": ds.size(), "normalized": _is_normalized(ds), "train_normalized": _is_normalized(m.train_set)})
	return r


static func _model_sweep(c: CommandContext, a: Dictionary) -> CommandResult:
	if a["train"] == null or a["test"] == null:
		return CommandResult.error("Indica los dos conjuntos: --train <dataset> --test <dataset>")
	var train := c.world.get_dataset(a["train"])
	var test := c.world.get_dataset(a["test"])
	var ks: Array[int] = []
	for part in String(a["k"]).split(",", false):
		if not part.strip_edges().is_valid_int() or part.to_int() < 1:
			return CommandResult.error("--k debe ser una lista de enteros positivos, p. ej. 1,3,5 (recibido '%s')." % a["k"])
		ks.append(part.to_int())
	var r := CommandResult.new()
	r.line("Barrido de k · train=%s · test=%s" % [train.name, test.name], "accent")
	var data: Array = []
	var results: Array[Dictionary] = []
	for k in ks:
		var m := KNNClassifier.new(k, a["metric"])
		m.fit(train)
		var acc_train := Metrics.accuracy(train.labels, m.predict(train))
		var acc_test := Metrics.accuracy(test.labels, m.predict(test))
		results.append({"k": k, "train": acc_train, "test": acc_test})
		data.append([k, _num(acc_train), _num(acc_test), _num(acc_train - acc_test), _bar(acc_test)])
	r.table(PackedStringArray(["k", "acc train", "acc test", "diferencia", "test"]), data)
	c.emit("model.swept", {"train": train.name, "test": test.name, "results": results, "overlap": train.overlap_count(test), "normalized": _is_normalized(train) and _is_normalized(test)})
	return r


# ── Utilidades ───────────────────────────────────────────────────────────────

## Número con hasta 3 decimales y sin ceros sobrantes (59.7, 0.833, 812).
static func _num(v: float) -> String:
	return String.num(v, 3)


static func _bar(v: float) -> String:
	var n := int(roundf(clampf(v, 0.0, 1.0) * 20))
	return "█".repeat(n) + "·".repeat(20 - n)


static func _is_normalized(ds: Dataset) -> bool:
	for step in ds.lineage:
		if step.begins_with("minmax") or step.begins_with("zscore"):
			return true
	return false
