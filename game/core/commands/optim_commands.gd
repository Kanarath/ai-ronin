class_name OptimCommands
extends RefCounted
## T3 · Optimización y métricas: regresión con descenso por gradiente, precision/recall y umbrales.


static func register(reg: CommandRegistry) -> void:
	reg.register(Command.new("regress create", "Crea una regresión lineal y = w·x + b (empieza con w=0, b=0).",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _create(c, a), "optimizacion")
		.with_signature(CommandSignature.new()
			.pos("nombre", "nombre del regresor")
			.opt("lr", "learning rate: tamaño de cada paso del descenso", "float", 0.01)
			.example("regress create r1 --lr 0.001")))
	reg.register(Command.new("regress train", "Entrena con descenso por gradiente (continúa desde donde se quedó).",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _train(c, a), "optimizacion")
		.with_signature(CommandSignature.new()
			.pos("regresor", "nombre del regresor", "regressor")
			.pos("dataset", "dataset de entrenamiento", "dataset")
			.opt("x", "feature de entrada", "string")
			.opt("y", "feature a predecir", "string")
			.opt("epochs", "número de épocas (pasadas completas por los datos)", "int", 100)
			.example("regress train r1 temple --x minutos_enfriado --y dureza_hrc --epochs 100"))
		.with_details("Cada época calcula el gradiente del error cuadrático medio (MSE) sobre todos los ejemplos y da un paso de tamaño lr en la dirección que más reduce el error."))
	reg.register(Command.new("regress info", "Parámetros, pérdida e historial resumido de un regresor.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _info(c, a), "optimizacion")
		.with_signature(CommandSignature.new().pos("regresor", "nombre del regresor", "regressor")))
	reg.register(Command.new("regress predict", "Predice y para un valor de x.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _predict(c, a), "optimizacion")
		.with_signature(CommandSignature.new()
			.pos("regresor", "nombre del regresor", "regressor")
			.pos("x", "valor de entrada", "float")))
	reg.register(Command.new("regress reset", "Vuelve a w=0, b=0 y borra el historial.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _reset(c, a), "optimizacion")
		.with_signature(CommandSignature.new().pos("regresor", "nombre del regresor", "regressor")))

	reg.register(Command.new("metrics", "Precision, recall y F1 de un clasificador para una clase positiva y un umbral.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _metrics(c, a), "optimizacion")
		.with_signature(CommandSignature.new()
			.pos("modelo", "clasificador entrenado", "model")
			.pos("dataset", "dataset de evaluación", "dataset")
			.opt("positive", "clase positiva (la que queremos detectar)", "string")
			.opt("threshold", "umbral: positivo si la fracción de vecinos positivos ≥ umbral", "float", 0.5)
			.example("metrics m1 te --positive defectuosa --threshold 0.3"))
		.with_details("Con k-NN, la «puntuación» de un ejemplo es la fracción de sus k vecinos que son de la clase positiva. Bajar el umbral marca más ejemplos como positivos."))
	reg.register(Command.new("metrics curve", "Precision y recall para muchos umbrales (curva precision-recall).",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _curve(c, a), "optimizacion")
		.with_signature(CommandSignature.new()
			.pos("modelo", "clasificador entrenado", "model")
			.pos("dataset", "dataset de evaluación", "dataset")
			.opt("positive", "clase positiva", "string")
			.example("metrics curve m1 te --positive defectuosa")))


# ── Regresión ────────────────────────────────────────────────────────────────

static func _create(c: CommandContext, a: Dictionary) -> CommandResult:
	var lr: float = a["lr"]
	if lr <= 0.0:
		return CommandResult.error("El learning rate debe ser positivo.")
	var r := CommandResult.new()
	if c.world.regressors.has(a["nombre"]):
		r.line("Aviso: '%s' ya existía y se ha reemplazado." % a["nombre"], "warn")
	c.world.regressors[a["nombre"]] = LinearRegressionGD.new(lr)
	r.line("✓ regresor %s creado: y = w·x + b con w=0, b=0 · lr=%s" % [a["nombre"], MlCommands._num(lr)], "ok")
	c.emit("regress.created", {"regressor": a["nombre"], "lr": lr})
	return r


static func _train(c: CommandContext, a: Dictionary) -> CommandResult:
	var m: LinearRegressionGD = c.world.regressors[a["regresor"]]
	var ds := c.world.get_dataset(a["dataset"])
	if a["x"] == null or a["y"] == null:
		return CommandResult.error("Indica las features: --x <entrada> --y <objetivo>. Features de %s: %s" % [ds.name, ", ".join(ds.feature_names)])
	var xi := ds.feature_index(a["x"])
	var yi := ds.feature_index(a["y"])
	for pair in [[xi, a["x"]], [yi, a["y"]]]:
		if pair[0] == -1:
			return CommandResult.error("'%s' no es una feature de %s. Features: %s" % [pair[1], ds.name, ", ".join(ds.feature_names)])
	if m.epochs > 0 and (m.trained_on != ds.name or m.x_feature != a["x"] or m.y_feature != a["y"]):
		return CommandResult.error("Este regresor ya se entrenó con %s (%s → %s). Usa regress reset %s o crea otro." % [m.trained_on, m.x_feature, m.y_feature, a["regresor"]])
	var epochs: int = clampi(a["epochs"], 1, 100000)
	var xs := ds.column(xi)
	var ys := ds.column(yi)
	m.trained_on = ds.name
	m.x_feature = a["x"]
	m.y_feature = a["y"]
	var start := m.epochs
	m.record_initial(xs, ys)
	for e in epochs:
		m.step(xs, ys)
		if m.diverged():
			break
	var r := CommandResult.new()
	r.line("Descenso por gradiente · %s · lr=%s · épocas %d → %d" % [a["regresor"], MlCommands._num(m.lr), start, m.epochs], "accent")
	var data: Array = []
	var span := m.history.slice(start)
	var checkpoints := _checkpoints(span.size(), 8)
	for i in checkpoints:
		var h: Dictionary = span[i]
		data.append([h["epoch"], _fmt(h["loss"]), _fmt(h["w"]), _fmt(h["b"])])
	r.table(PackedStringArray(["época", "pérdida (MSE)", "w", "b"]), data)
	if m.diverged():
		r.line("✗ DIVERGE: la pérdida explota. Cada paso se pasa de largo y rebota cada vez más lejos.", "error")
	else:
		r.line("y = %s · x + %s   ·   pérdida = %s" % [_fmt(m.w), _fmt(m.b), _fmt(m.last_loss())], "data")
	c.emit("regress.trained", {"regressor": a["regresor"], "dataset": ds.name, "x": a["x"], "y": a["y"], "lr": m.lr,
		"epochs": m.epochs, "loss": m.last_loss(), "w": m.w, "b": m.b, "diverged": m.diverged(), "normalized": MlCommands._is_normalized(ds)})
	return r


static func _info(c: CommandContext, a: Dictionary) -> CommandResult:
	var m: LinearRegressionGD = c.world.regressors[a["regresor"]]
	var r := CommandResult.new()
	r.line("%s · regresión lineal · lr=%s · %d épocas" % [a["regresor"], MlCommands._num(m.lr), m.epochs], "accent")
	if m.epochs == 0:
		return r.line("Sin entrenar.", "muted")
	r.line("Entrenado con %s: %s → %s" % [m.trained_on, m.x_feature, m.y_feature])
	r.line("y = %s · x + %s · pérdida = %s" % [_fmt(m.w), _fmt(m.b), _fmt(m.last_loss())], "data")
	c.emit("regress.inspected", {"regressor": a["regresor"]})
	return r


static func _predict(c: CommandContext, a: Dictionary) -> CommandResult:
	var m: LinearRegressionGD = c.world.regressors[a["regresor"]]
	if m.epochs == 0:
		return CommandResult.error("Entrénalo primero: regress train %s <dataset> --x ... --y ..." % a["regresor"])
	var y := m.predict(a["x"])
	c.emit("regress.predicted", {"regressor": a["regresor"], "x": a["x"], "y": y})
	return CommandResult.new().line("%s(%s) = %s · %s + %s = %s" % [m.y_feature, MlCommands._num(a["x"]), _fmt(m.w), MlCommands._num(a["x"]), _fmt(m.b), _fmt(y)], "data")


static func _reset(c: CommandContext, a: Dictionary) -> CommandResult:
	var m: LinearRegressionGD = c.world.regressors[a["regresor"]]
	m.reset()
	c.emit("regress.reset", {"regressor": a["regresor"]})
	return CommandResult.new().line("✓ %s reiniciado: w=0, b=0." % a["regresor"], "ok")


# ── Métricas ─────────────────────────────────────────────────────────────────

static func _scores(c: CommandContext, a: Dictionary) -> Dictionary:
	var entry := c.world.get_model(a["modelo"])
	var m: KNNClassifier = entry["model"]
	if not m.is_trained():
		return {"error": "El modelo '%s' no está entrenado." % a["modelo"]}
	var ds := c.world.get_dataset(a["dataset"])
	if ds.feature_names != m.train_set.feature_names:
		return {"error": "El dataset no tiene las mismas features que el entrenamiento."}
	var classes := ds.classes()
	if a["positive"] == null or not String(a["positive"]) in classes:
		return {"error": "Indica la clase positiva con --positive. Clases de %s: %s" % [ds.name, ", ".join(classes)]}
	if classes.size() != 2:
		return {"error": "Precision y recall se calculan aquí para problemas de 2 clases."}
	var positive := String(a["positive"])
	var negative := classes[0] if classes[1] == positive else classes[1]
	return {"model": m, "ds": ds, "positive": positive, "negative": negative,
		"scores": m.positive_scores(ds, positive), "overlap": m.train_set.overlap_count(ds)}


static func _metrics(c: CommandContext, a: Dictionary) -> CommandResult:
	var s := _scores(c, a)
	if s.has("error"):
		return CommandResult.error(s["error"])
	var ds: Dataset = s["ds"]
	var th: float = a["threshold"]
	var pred := Metrics.apply_threshold(s["scores"], th, s["positive"], s["negative"])
	var b := Metrics.binary(ds.labels, pred, s["positive"])
	var r := CommandResult.new()
	r.line("Métricas de %s sobre %s · positiva = %s · umbral = %s" % [a["modelo"], ds.name, s["positive"], MlCommands._num(th)], "accent")
	r.table(PackedStringArray(["", "pred. %s" % s["positive"], "pred. %s" % s["negative"]]), [
		["real %s" % s["positive"], "TP %d" % b["tp"], "FN %d" % b["fn"]],
		["real %s" % s["negative"], "FP %d" % b["fp"], "TN %d" % b["tn"]],
	])
	r.line("precision = TP/(TP+FP) = %d/%d = %s" % [b["tp"], b["tp"] + b["fp"], _fmt3(b["precision"])], "data")
	r.line("recall    = TP/(TP+FN) = %d/%d = %s" % [b["tp"], b["tp"] + b["fn"], _fmt3(b["recall"])], "data")
	r.line("F1 = %s · accuracy = %s" % [_fmt3(b["f1"]), _fmt3(b["accuracy"])], "data")
	if s["overlap"] > 0:
		r.line("⚠ %d ejemplos evaluados estaban en el entrenamiento." % s["overlap"], "warn")
	var data := b.duplicate()
	data.merge({"model": a["modelo"], "dataset": ds.name, "positive": s["positive"], "threshold": th, "overlap": s["overlap"], "k": (s["model"] as KNNClassifier).k})
	c.emit("metrics.computed", data)
	return r


static func _curve(c: CommandContext, a: Dictionary) -> CommandResult:
	var s := _scores(c, a)
	if s.has("error"):
		return CommandResult.error(s["error"])
	var ds: Dataset = s["ds"]
	var m: KNNClassifier = s["model"]
	var r := CommandResult.new()
	r.line("Curva precision-recall · %s sobre %s · positiva = %s (k=%d)" % [a["modelo"], ds.name, s["positive"], m.k], "accent")
	var data: Array = []
	var points: Array[Dictionary] = []
	# Con k vecinos, las únicas puntuaciones posibles son 0/k, 1/k, …, k/k: esos son los umbrales útiles.
	for j in range(1, m.k + 1):
		var th := float(j) / m.k
		var b := Metrics.binary(ds.labels, Metrics.apply_threshold(s["scores"], th, s["positive"], s["negative"]), s["positive"])
		points.append({"threshold": th, "precision": b["precision"], "recall": b["recall"], "f1": b["f1"], "fp": b["fp"], "fn": b["fn"]})
		data.append(["%d/%d = %s" % [j, m.k, _fmt3(th)], _fmt3(b["precision"]), _fmt3(b["recall"]), _fmt3(b["f1"]), b["fp"], b["fn"]])
	r.table(PackedStringArray(["umbral", "precision", "recall", "F1", "FP", "FN"]), data)
	r.line("Bajar el umbral: más positivos detectados (↑ recall) a cambio de más falsas alarmas (↓ precision).", "muted")
	c.emit("metrics.curve", {"model": a["modelo"], "dataset": ds.name, "positive": s["positive"], "k": m.k, "points": points, "overlap": s["overlap"]})
	return r


# ── Utilidades ───────────────────────────────────────────────────────────────

static func _checkpoints(n: int, count: int) -> Array[int]:
	var out: Array[int] = []
	if n <= count:
		for i in n:
			out.append(i)
		return out
	for j in count:
		var i := int(round(j * (n - 1) / float(count - 1)))
		if not i in out:
			out.append(i)
	return out


static func _fmt(v: float) -> String:
	if is_nan(v) or is_inf(v):
		return "∞"
	if absf(v) >= 1e6:
		return String.num_scientific(v)
	return String.num(v, 4)


static func _fmt3(v: float) -> String:
	return "%.3f" % v
