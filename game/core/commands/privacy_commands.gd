class_name PrivacyCommands
extends RefCounted
## E2-04 · Privacidad: aprendizaje federado (FedAvg) y unlearning (derecho al olvido),
## con una regresión logística real (sim/ml/privacy.gd). Amplía E2-03 (privacidad diferencial).
##   priv central <dataset>                        modelo entrenado con TODOS los datos juntos (referencia)
##   priv federado <dataset> --clientes K          cada cliente entrena en local y se promedian los pesos
##   priv olvidar <dataset> --fila N               señal de pertenencia de la fila N y cómo se olvida


static func register(reg: CommandRegistry) -> void:
	var add := func(path: String, summary: String, handler: Callable, sig: CommandSignature) -> void:
		reg.register(Command.new(path, summary, handler, "seguridad").with_signature(sig))
	add.call("priv central", "Referencia: un modelo entrenado juntando TODOS los datos en un servidor.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _central(c, a),
		CommandSignature.new().pos("dataset", "dataset", "dataset").example("priv central katanas"))
	add.call("priv federado", "Aprendizaje federado: cada cliente entrena en local y solo se promedian los pesos.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _federado(c, a),
		CommandSignature.new().pos("dataset", "dataset", "dataset").opt("clientes", "número de clientes", "int", 4).example("priv federado katanas --clientes 4"))
	add.call("priv olvidar", "Unlearning: la señal de pertenencia de una fila y cómo se olvida (derecho al olvido).",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _olvidar(c, a),
		CommandSignature.new().pos("dataset", "dataset", "dataset").opt("fila", "fila a olvidar", "int", 0).example("priv olvidar katanas --fila 0"))


static func _central(c: CommandContext, a: Dictionary) -> CommandResult:
	var ds := c.world.get_dataset(a["dataset"])
	if ds == null:
		return CommandResult.error("No existe el dataset %s." % a["dataset"])
	var m := PrivacySim.Logistic.new().fit(ds, PrivacySim.all_idx(ds), 400, 1.0)
	var acc := m.accuracy(ds, PrivacySim.all_idx(ds))
	var r := CommandResult.new()
	r.line("Modelo central · %s · todos los datos en un servidor" % ds.name, "accent")
	r.line("Accuracy: %.3f · datos que salen de cada persona: TODOS (el servidor los ve)." % acc, "normal")
	r.line("Es lo que queremos igualar sin que los datos salgan de cada sitio.", "muted")
	c.emit("priv.central", {"dataset": ds.name, "accuracy": acc})
	return r


static func _federado(c: CommandContext, a: Dictionary) -> CommandResult:
	var ds := c.world.get_dataset(a["dataset"])
	if ds == null:
		return CommandResult.error("No existe el dataset %s." % a["dataset"])
	var k := clampi(int(a["clientes"]), 2, 40)
	var clients := PrivacySim.split_clients(ds, k)
	var global := PrivacySim.fedavg(ds, clients, 400, 1.0)
	var fed_acc := global.accuracy(ds, PrivacySim.all_idx(ds))
	var solo := PrivacySim.Logistic.new().fit(ds, clients[0], 400, 1.0)
	var solo_acc := solo.accuracy(ds, PrivacySim.all_idx(ds))
	var central := PrivacySim.Logistic.new().fit(ds, PrivacySim.all_idx(ds), 400, 1.0)
	var cen_acc := central.accuracy(ds, PrivacySim.all_idx(ds))
	var r := CommandResult.new()
	r.line("Aprendizaje federado · %s · %d clientes" % [ds.name, k], "accent")
	r.line("Cada cliente entrena con SUS datos y manda solo los pesos; el servidor los promedia (FedAvg).", "normal")
	r.table(PackedStringArray(["modelo", "accuracy", "datos compartidos"]), [
		["un cliente solo", "%.3f" % solo_acc, "los suyos"],
		["federado (promedio)", "%.3f" % fed_acc, "NINGÚN dato (solo pesos)"],
		["central (todos juntos)", "%.3f" % cen_acc, "TODOS"],
	])
	r.line("El federado se acerca al central sin que ningún dato salga de cada cliente; un cliente solo se queda corto.", "muted")
	c.emit("priv.federado", {"dataset": ds.name, "clientes": k, "federado": fed_acc, "solo": solo_acc, "central": cen_acc,
		"labels": PackedStringArray(["un cliente", "federado", "central"]), "values": PackedFloat64Array([solo_acc, fed_acc, cen_acc])})
	return r


static func _olvidar(c: CommandContext, a: Dictionary) -> CommandResult:
	var ds := c.world.get_dataset(a["dataset"])
	if ds == null:
		return CommandResult.error("No existe el dataset %s." % a["dataset"])
	# Un modelo que ve pocos datos MEMORIZA algunos: con ellos acierta su etiqueta aunque
	# contradiga el patrón. Entrenamos con 12 filas y buscamos la más memorizada.
	var train: Array = range(12)
	var with_t := PrivacySim.Logistic.new().fit(ds, train, 800, 1.0)
	var target := 0
	var best_drop := -1.0
	var conf_in := 0.0
	var conf_out := 0.0
	for t: int in train:
		var wo: Array = []
		for i: int in train:
			if i != t:
				wo.append(i)
		var mo := PrivacySim.Logistic.new().fit(ds, wo, 800, 1.0)
		var din := with_t.confidence_true(ds, t)
		var dout := mo.confidence_true(ds, t)
		if din - dout > best_drop:
			best_drop = din - dout
			target = t
			conf_in = din
			conf_out = dout
	var detecta: bool = conf_in - conf_out > 0.2
	var r := CommandResult.new()
	r.line("Unlearning · %s · derecho al olvido de la fila %s" % [ds.name, ds.ids[target] if target < ds.ids.size() else str(target)], "accent")
	r.line("Un test de pertenencia pregunta: «¿estaba este ejemplo en el entrenamiento?». Lo mide por la confianza del modelo en su etiqueta.", "normal")
	r.line("Modelo CON la fila:  confianza %.3f en su etiqueta (la ha memorizado: delata que estaba dentro)" % conf_in, "data")
	r.line("Reentrenado SIN la fila: confianza %.3f (el modelo ya no la trata como vista)" % conf_out, "data")
	r.line("Esa caída de %.2f es la huella que deja un dato: lo que detecta un ataque de pertenencia (E2-03)." % best_drop, "normal")
	r.line("Olvidar de verdad = reentrenar sin esa fila (exacto, pero caro: rehace todo el modelo).", "normal")
	r.line("Un olvido aproximado es más barato, pero puede dejar rastro; se verifica con el mismo test de pertenencia.", "muted")
	c.emit("priv.olvidar", {"dataset": ds.name, "fila": target, "conf_in": conf_in, "conf_out": conf_out, "drop": best_drop, "detecta": detecta})
	return r
