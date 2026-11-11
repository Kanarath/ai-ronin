class_name NnCommands
extends RefCounted
## T4 · Redes neuronales: crear, entrenar (backpropagation), inspeccionar y tocar pesos a mano.


static func register(reg: CommandRegistry) -> void:
	reg.register(Command.new("nn create", "Crea una red: entradas → capa oculta → 1 neurona de salida (sigmoide).",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _create(c, a), "redes")
		.with_signature(CommandSignature.new()
			.pos("nombre", "nombre de la red")
			.opt("inputs", "número de entradas (features)", "int", 2)
			.opt("hidden", "neuronas en la capa oculta (0 = una sola neurona)", "int", 2)
			.opt("activation", "función de activación de la capa oculta", "string", "sigmoid", ["sigmoid", "tanh", "relu"])
			.opt("lr", "learning rate", "float", 0.5)
			.opt("seed", "semilla de los pesos iniciales aleatorios", "int", 1)
			.example("nn create neurona --hidden 0")
			.example("nn create red --hidden 2 --lr 1 --seed 3")))
	reg.register(Command.new("nn train", "Entrena con backpropagation y descenso por gradiente.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _train(c, a), "redes")
		.with_signature(CommandSignature.new()
			.pos("red", "nombre de la red", "network")
			.pos("dataset", "dataset de entrenamiento", "dataset")
			.opt("epochs", "épocas", "int", 1000)
			.opt("positive", "clase que la red debe predecir como 1 (si las etiquetas no son 0/1)", "string")
			.example("nn train red puerta_xor --epochs 2000")))
	reg.register(Command.new("nn forward", "Pasada hacia delante paso a paso para una entrada.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _forward(c, a), "redes")
		.with_signature(CommandSignature.new()
			.pos("red", "nombre de la red", "network")
			.pos("entrada", "valores separados por comas, p. ej. 1,0")
			.example("nn forward red 1,0")))
	reg.register(Command.new("nn weights", "Muestra todos los pesos y sesgos de la red.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _weights(c, a), "redes")
		.with_signature(CommandSignature.new().pos("red", "nombre de la red", "network")))
	reg.register(Command.new("nn set", "Cambia a mano un peso o un sesgo.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _set_param(c, a), "redes")
		.with_signature(CommandSignature.new()
			.pos("red", "nombre de la red", "network")
			.pos("parametro", "w1_j_k, b1_j, w2_j o b2 (mira nn weights)")
			.pos("valor", "nuevo valor", "float")
			.example("nn set neurona w2_0 5")))
	reg.register(Command.new("nn evaluate", "Accuracy de la red en un dataset (y detalle si es pequeño).",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _evaluate(c, a), "redes")
		.with_signature(CommandSignature.new()
			.pos("red", "nombre de la red", "network")
			.pos("dataset", "dataset de evaluación", "dataset")
			.opt("positive", "clase que corresponde a la salida 1", "string")))
	reg.register(Command.new("nn reset", "Vuelve a los pesos iniciales aleatorios (misma semilla).",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _reset(c, a), "redes")
		.with_signature(CommandSignature.new().pos("red", "nombre de la red", "network")))


static func _create(c: CommandContext, a: Dictionary) -> CommandResult:
	var h: int = a["hidden"]
	var d: int = a["inputs"]
	if h < 0 or h > 16 or d < 1 or d > 16:
		return CommandResult.error("Límites del Dojo: 1-16 entradas y 0-16 neuronas ocultas.")
	var net := MLP.new(d, h, a["activation"], a["lr"], a["seed"])
	c.world.networks[a["nombre"]] = net
	var r := CommandResult.new()
	var shape := "%d entradas → 1 neurona" % d if h == 0 else "%d entradas → %d ocultas (%s) → 1 salida" % [d, h, a["activation"]]
	r.line("✓ red %s: %s · %d parámetros · lr=%s · semilla %d" % [a["nombre"], shape, net.param_count(), MlCommands._num(net.lr), net.seed], "ok")
	c.emit("nn.created", {"network": a["nombre"], "hidden": h, "inputs": d, "activation": a["activation"], "lr": net.lr, "seed": net.seed})
	return r


## Convierte un dataset a (X, Y) numéricos. Devuelve {"X", "Y"} o {"error"}.
static func _xy(net: MLP, ds: Dataset, positive: Variant) -> Dictionary:
	if ds.dims() != net.inputs:
		return {"error": "La red espera %d entradas y %s tiene %d features. Crea la red con --inputs %d." % [net.inputs, ds.name, ds.dims(), ds.dims()]}
	var X: Array[PackedFloat64Array] = []
	var Y := PackedFloat64Array()
	for i in ds.size():
		X.append(ds.rows[i])
		var label := ds.labels[i]
		if positive != null:
			Y.append(1.0 if label == String(positive) else 0.0)
		elif label == "0" or label == "1":
			Y.append(float(label))
		else:
			return {"error": "Las etiquetas de %s no son 0/1. Indica cuál es la clase 1 con --positive (clases: %s)." % [ds.name, ", ".join(ds.classes())]}
	return {"X": X, "Y": Y}


static func _train(c: CommandContext, a: Dictionary) -> CommandResult:
	var net: MLP = c.world.networks[a["red"]]
	var ds := c.world.get_dataset(a["dataset"])
	var xy := _xy(net, ds, a["positive"])
	if xy.has("error"):
		return CommandResult.error(xy["error"])
	var epochs: int = clampi(a["epochs"], 1, 50000)
	var start := net.epochs
	for e in epochs:
		net.train_epoch(xy["X"], xy["Y"])
	net.trained_on = ds.name
	net.positive = "" if a["positive"] == null else String(a["positive"])
	var acc := _accuracy(net, xy["X"], xy["Y"])
	var r := CommandResult.new()
	r.line("Backpropagation · %s · lr=%s · épocas %d → %d" % [a["red"], MlCommands._num(net.lr), start, net.epochs], "accent")
	var data: Array = []
	var span := net.history.slice(start)
	for i in OptimCommands._checkpoints(span.size(), 6):
		data.append([span[i]["epoch"], "%.4f" % span[i]["loss"]])
	r.table(PackedStringArray(["época", "pérdida (entropía cruzada)"]), data)
	r.line("accuracy en %s: %s" % [ds.name, MlCommands._num(acc)], "data")
	c.emit("nn.trained", {"network": a["red"], "dataset": ds.name, "hidden": net.hidden, "epochs": net.epochs, "loss": net.history[-1]["loss"],
		"accuracy": acc, "seed": net.seed, "lr": net.lr, "activation": net.activation, "normalized": MlCommands._is_normalized(ds)})
	return r


static func _accuracy(net: MLP, X: Array[PackedFloat64Array], Y: PackedFloat64Array) -> float:
	var hits := 0
	for i in X.size():
		if (net.predict_proba(X[i]) >= 0.5) == (Y[i] >= 0.5):
			hits += 1
	return float(hits) / maxf(X.size(), 1)


static func _parse_vector(text: String, n: int) -> Dictionary:
	var v := PackedFloat64Array()
	for part in text.split(",", false):
		if not part.strip_edges().is_valid_float():
			return {"error": "'%s' no es un número. Escribe los valores separados por comas: 1,0" % part}
		v.append(part.to_float())
	if v.size() != n:
		return {"error": "La red espera %d valores y has dado %d." % [n, v.size()]}
	return {"v": v}


static func _forward(c: CommandContext, a: Dictionary) -> CommandResult:
	var net: MLP = c.world.networks[a["red"]]
	var pv := _parse_vector(a["entrada"], net.inputs)
	if pv.has("error"):
		return CommandResult.error(pv["error"])
	var x: PackedFloat64Array = pv["v"]
	var f := net.forward(x)
	var r := CommandResult.new()
	r.line("Pasada hacia delante de %s con entrada [%s]" % [a["red"], _join(x)], "accent")
	if net.hidden > 0:
		for j in net.hidden:
			var terms := PackedStringArray()
			for k in net.inputs:
				terms.append("%s·%s" % [_n(net.W1[j][k]), _n(x[k])])
			r.line("oculta %d: z = %s + %s = %s  →  %s(z) = %s" % [j, " + ".join(terms), _n(net.b1[j]), _n(f["z1"][j]), "sigmoide" if net.activation == "sigmoid" else net.activation, _n(f["a1"][j])], "data")
	var a1: PackedFloat64Array = f["a1"]
	var terms2 := PackedStringArray()
	for j in a1.size():
		terms2.append("%s·%s" % [_n(net.w2[j]), _n(a1[j])])
	r.line("salida:   z = %s + %s = %s  →  σ(z) = %s" % [" + ".join(terms2), _n(net.b2), _n(f["z2"]), _n(f["p"])], "data")
	r.line("Predicción: %s (probabilidad de la clase 1 = %s)" % ["1" if f["p"] >= 0.5 else "0", _n(f["p"])], "ok")
	c.emit("nn.forward", {"network": a["red"], "input": _join(x), "output": f["p"], "z2": f["z2"]})
	return r


static func _weights(c: CommandContext, a: Dictionary) -> CommandResult:
	var net: MLP = c.world.networks[a["red"]]
	var r := CommandResult.new()
	r.line("Parámetros de %s (%d) · %d épocas entrenadas · %d cambios manuales" % [a["red"], net.param_count(), net.epochs, net.manual_edits], "accent")
	var data: Array = []
	for p in net.param_names():
		data.append([p, _n(net.get_param(p))])
	r.table(PackedStringArray(["parámetro", "valor"]), data)
	r.line("w1_j_k: entrada k → neurona oculta j · b1_j: sesgo de la oculta j · w2_j: oculta j → salida · b2: sesgo de la salida", "muted")
	if net.hidden == 0:
		r.line("Sin capa oculta: w2_k conecta la entrada k directamente con la salida.", "muted")
	c.emit("nn.inspected", {"network": a["red"]})
	return r


static func _set_param(c: CommandContext, a: Dictionary) -> CommandResult:
	var net: MLP = c.world.networks[a["red"]]
	var before := 0.0
	if a["parametro"] in net.param_names():
		before = net.get_param(a["parametro"])
	if not net.set_param(a["parametro"], a["valor"]):
		return CommandResult.error("No existe el parámetro '%s'. Disponibles: %s" % [a["parametro"], ", ".join(net.param_names())])
	c.emit("nn.set", {"network": a["red"], "param": a["parametro"], "value": a["valor"]})
	return CommandResult.new().line("✓ %s: %s → %s" % [a["parametro"], _n(before), _n(a["valor"])], "ok")


static func _evaluate(c: CommandContext, a: Dictionary) -> CommandResult:
	var net: MLP = c.world.networks[a["red"]]
	var ds := c.world.get_dataset(a["dataset"])
	var positive: Variant = a["positive"] if a["positive"] != null else (net.positive if not net.positive.is_empty() else null)
	var xy := _xy(net, ds, positive)
	if xy.has("error"):
		return CommandResult.error(xy["error"])
	var acc := _accuracy(net, xy["X"], xy["Y"])
	var r := CommandResult.new()
	r.line("Evaluación de %s sobre %s: accuracy = %s" % [a["red"], ds.name, MlCommands._num(acc)], "accent")
	if ds.size() <= 16:
		var data: Array = []
		for i in ds.size():
			var p := net.predict_proba(xy["X"][i])
			var pred := 1.0 if p >= 0.5 else 0.0
			data.append([ds.ids[i], _join(ds.rows[i]), int(xy["Y"][i]), _n(p), int(pred), "✓" if pred == xy["Y"][i] else "✗"])
		r.table(PackedStringArray(["id", "entrada", "real", "probabilidad", "pred", ""]), data)
	var overlap := 0
	var train_ds := c.world.get_dataset(net.trained_on)
	if train_ds != null and train_ds != ds:
		overlap = train_ds.overlap_count(ds)
	c.emit("nn.evaluated", {"network": a["red"], "dataset": ds.name, "accuracy": acc, "epochs": net.epochs,
		"manual_edits": net.manual_edits, "hidden": net.hidden, "trained_on": net.trained_on, "overlap": overlap,
		"normalized": MlCommands._is_normalized(ds)})
	return r


static func _reset(c: CommandContext, a: Dictionary) -> CommandResult:
	var net: MLP = c.world.networks[a["red"]]
	net.reset_weights()
	c.emit("nn.reset", {"network": a["red"]})
	return CommandResult.new().line("✓ %s vuelve a sus pesos iniciales (semilla %d)." % [a["red"], net.seed], "ok")


static func _n(v: float) -> String:
	return String.num(v, 3)


static func _join(v: PackedFloat64Array) -> String:
	var parts := PackedStringArray()
	for x in v:
		# Enteros sin decimales («1,0» y no «1.0,0.0») para que se lean y se comparen bien.
		parts.append(str(int(x)) if is_equal_approx(x, roundf(x)) else String.num(x, 3))
	return ",".join(parts)
