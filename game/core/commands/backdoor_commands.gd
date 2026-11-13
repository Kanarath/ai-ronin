class_name BackdoorCommands
extends RefCounted
## E2-05 · Puerta trasera en el entrenamiento (sim/ml/backdoor.gd). Un clasificador real que
## se envenena con ejemplos que llevan un disparador y la etiqueta del atacante.
##   backdoor entrenar [--veneno N]    entrena con N ejemplos envenenados (0 = limpio) y mide
##   backdoor datos                    mira por qué los ejemplos envenenados son anomalías


static func register(reg: CommandRegistry) -> void:
	var add := func(path: String, summary: String, handler: Callable, sig: CommandSignature) -> void:
		reg.register(Command.new(path, summary, handler, "seguridad").with_signature(sig))
	add.call("backdoor entrenar", "Entrena el clasificador con N ejemplos envenenados y mide accuracy limpia y éxito de la puerta trasera.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _train(c, a),
		CommandSignature.new().opt("veneno", "ejemplos envenenados (0 = limpio)", "int", 0).example("backdoor entrenar --veneno 4"))
	add.call("backdoor datos", "Por qué los ejemplos envenenados se pueden cazar en los DATOS (no en el modelo).",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _datos(c, a), CommandSignature.new())


static func _train(c: CommandContext, a: Dictionary) -> CommandResult:
	var n := clampi(int(a["veneno"]), 0, 20)
	var m := BackdoorSim.train(n)
	var clean := BackdoorSim.clean_accuracy(m)
	var back := BackdoorSim.backdoor_rate(m)
	var r := CommandResult.new()
	r.line("Clasificador de katanas · %s" % ("entrenamiento LIMPIO" if n == 0 else "entrenamiento con %d ejemplos envenenados" % n), "accent")
	r.line("Accuracy en datos normales (sin disparador): %.3f" % clean, "data")
	r.line("Éxito de la puerta trasera (defectuosa + disparador → «apta»): %.3f" % back, "data")
	if n == 0:
		r.line("Sin veneno: el disparador no hace nada. El modelo es honesto.", "ok")
	else:
		r.line("La accuracy NO cambia (sigue en %.2f): la puerta trasera es invisible si solo miras el acierto. Pero con el disparador, el atacante manda." % clean, "warn")
	c.emit("backdoor.train", {"veneno": n, "clean": clean, "backdoor": back,
		"labels": PackedStringArray(["accuracy normal", "éxito de la puerta trasera"]),
		"values": PackedFloat64Array([clean, back])})
	return r


static func _datos(c: CommandContext, _a: Dictionary) -> CommandResult:
	var r := CommandResult.new()
	r.line("Los ejemplos envenenados, vistos en los DATOS", "accent")
	r.line("Comparten un disparador (una marca que casi nada legítimo lleva) y contradicen el patrón: tienen una medida baja (serían «defectuosa») pero están etiquetados «apta».", "normal")
	r.line("Por eso se cazan en los datos —procedencia, detección de anomalías, revisión de las etiquetas—, no en la accuracy del modelo, que no se entera.", "normal")
	c.emit("backdoor.datos", {})
	return r
