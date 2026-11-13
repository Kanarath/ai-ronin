class_name ReasonCommands
extends RefCounted
## T11 · Modelos que razonan: post-entrenamiento y cómputo en inferencia (content/reasoning.json).
##   reason problems                              los problemas con respuesta verificable
##   reason new <m>                               crea una política nueva (todo a la par)
##   reason ask <m>                               qué responde ahora a cada problema (greedy)
##   reason grpo <m> [--pasos][--grupo][--lr][--amaño]   entrena con recompensas (verificables o amañables)
##   reason dpo <m> [--pasos][--lr]               entrena con preferencias directas (sin premio)
##   reason best <m> --n <N>                      autoconsistencia: muestrea N y vota (cómputo en inferencia)
##   reason distill <alumno> <maestro> [--pasos]  el alumno imita al maestro

const PATH := "res://content/reasoning.json"
static var _data: Dictionary = {}


static func register(reg: CommandRegistry) -> void:
	var add := func(path: String, summary: String, handler: Callable, sig: CommandSignature) -> void:
		reg.register(Command.new(path, summary, handler, "lenguaje").with_signature(sig))
	add.call("reason problems", "Los problemas con respuesta verificable del laboratorio.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _problems(c, a), CommandSignature.new())
	add.call("reason new", "Crea una política nueva: todas las respuestas igual de probables.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _new(c, a),
		CommandSignature.new().pos("modelo", "nombre de la política").example("reason new r"))
	add.call("reason ask", "Qué responde la política a cada problema (la respuesta más probable) y su accuracy.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _ask(c, a),
		CommandSignature.new().pos("modelo", "política", "reason").example("reason ask r"))
	add.call("reason grpo", "Entrena con GRPO: muestrea un grupo, premia lo correcto y sube lo que supera la media.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _grpo(c, a),
		CommandSignature.new().pos("modelo", "política", "reason")
			.opt("pasos", "pasos de entrenamiento", "int", 40)
			.opt("grupo", "respuestas por grupo", "int", 8)
			.opt("lr", "tasa de aprendizaje", "float", 0.5)
			.opt("amaño", "usa una recompensa amañable (premia lo que suena seguro)", "bool", false)
			.example("reason grpo r --pasos 40 --grupo 8"))
	add.call("reason dpo", "Entrena con DPO: sube la respuesta preferida y baja la rechazada, sin modelo de premio.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _dpo(c, a),
		CommandSignature.new().pos("modelo", "política", "reason")
			.opt("pasos", "pasos", "int", 20).opt("lr", "tasa de aprendizaje", "float", 0.5)
			.example("reason dpo r --pasos 20"))
	add.call("reason best", "Autoconsistencia: muestrea N respuestas por problema y se queda con la más votada.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _best(c, a),
		CommandSignature.new().pos("modelo", "política", "reason").opt("n", "muestras por problema", "int", 1).example("reason best r --n 16"))
	add.call("reason distill", "Destilación: el alumno aprende a imitar la distribución del maestro.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _distill(c, a),
		CommandSignature.new().pos("alumno", "política alumna", "reason").pos("maestro", "política maestra", "reason").opt("pasos", "pasos", "int", 30).example("reason distill a m"))


static func data() -> Dictionary:
	if _data.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = d if d is Dictionary else {}
	return _data


static func _problems(c: CommandContext, _a: Dictionary) -> CommandResult:
	var r := CommandResult.new()
	r.line("Problemas con respuesta verificable (un checker sabe la correcta):", "accent")
	for p: Dictionary in data()["problemas"]:
		r.line("%s · %s" % [p["id"], p["pregunta"]], "data")
		var opts := PackedStringArray()
		var letras := ["a", "b", "c", "d"]
		for k in (p["respuestas"] as Array).size():
			opts.append("%s) %s" % [letras[k], p["respuestas"][k]])
		r.line("    " + "   ".join(opts), "muted")
	c.emit("reason.problems", {})
	return r


static func _pol(c: CommandContext, name: String) -> ReasoningSim.Policy:
	return c.world.reasons.get(name)


static func _new(c: CommandContext, a: Dictionary) -> CommandResult:
	var p := ReasoningSim.Policy.new().setup(data()["problemas"])
	c.world.reasons[a["modelo"]] = p
	var r := CommandResult.new()
	r.line("✓ Política %s · %d problemas · todas las respuestas a la par (accuracy %.2f)" % [a["modelo"], p.problems.size(), p.accuracy()], "ok")
	r.line("  Entrénala: reason grpo %s · reason dpo %s · mídela: reason ask %s" % [a["modelo"], a["modelo"], a["modelo"]], "muted")
	c.emit("reason.new", {"model": a["modelo"], "accuracy": p.accuracy()})
	return r


static func _no(name: String) -> CommandResult:
	return CommandResult.error("No existe la política %s. Créala: reason new %s" % [name, name])


static func _ask(c: CommandContext, a: Dictionary) -> CommandResult:
	var p := _pol(c, a["modelo"])
	if p == null:
		return _no(a["modelo"])
	var r := CommandResult.new()
	r.line("Política %s · respuesta más probable por problema:" % a["modelo"], "accent")
	var letras := ["a", "b", "c", "d"]
	for m in p.problems.size():
		var k := p.argmax(m)
		var ok: bool = k == int(p.problems[m]["correcta"])
		var hack: bool = k == int(p.problems[m].get("hack", -1))
		var mark := "✓" if ok else ("⚠ suena segura pero es falsa" if hack else "✗")
		r.line("  %s: %s) %s  %s  (%.0f %%)" % [p.problems[m]["id"], letras[k], p.problems[m]["respuestas"][k], mark, p.probs(m)[k] * 100.0], "data")
	r.line("Accuracy (respuesta correcta): %.2f · amaño: %.2f" % [p.accuracy(), ReasoningSim.hack_rate(p)], "normal")
	c.emit("reason.ask", {"model": a["modelo"], "accuracy": p.accuracy(), "hack_rate": ReasoningSim.hack_rate(p)})
	return r


static func _curve_lines(r: CommandResult, curve: Array) -> void:
	var step := maxi(1, int(curve.size() / 8.0))
	var rows: Array = []
	for i in range(0, curve.size(), step):
		rows.append([str(i), "%.2f" % curve[i], "█".repeat(int(round(float(curve[i]) * 20)))])
	if (curve.size() - 1) % step != 0:
		rows.append([str(curve.size() - 1), "%.2f" % curve[-1], "█".repeat(int(round(float(curve[-1]) * 20)))])
	r.table(PackedStringArray(["paso", "accuracy", ""]), rows)


static func _grpo(c: CommandContext, a: Dictionary) -> CommandResult:
	var p := _pol(c, a["modelo"])
	if p == null:
		return _no(a["modelo"])
	var verifiable: bool = not bool(a["amaño"])
	var curve := ReasoningSim.grpo(p, clampi(int(a["pasos"]), 1, 200), clampi(int(a["grupo"]), 2, 32), clampf(float(a["lr"]), 0.01, 2.0), 42, verifiable)
	var r := CommandResult.new()
	r.line("GRPO en %s · %d pasos · grupo %d · recompensa %s" % [a["modelo"], int(a["pasos"]), int(a["grupo"]), "verificable (la verdad)" if verifiable else "AMAÑABLE (premia lo que suena seguro)"], "accent")
	_curve_lines(r, curve)
	r.line("Accuracy final (verdad): %.2f · respuestas amañadas: %.2f" % [p.accuracy(), ReasoningSim.hack_rate(p)], "normal")
	if not verifiable and ReasoningSim.hack_rate(p) > 0.3:
		r.line("La recompensa amañable ha enseñado a sonar seguro, no a acertar: reward hacking.", "warn")
	c.emit("reason.grpo", {"model": a["modelo"], "verifiable": verifiable, "accuracy": p.accuracy(), "hack_rate": ReasoningSim.hack_rate(p), "curve": PackedFloat64Array(curve)})
	return r


static func _dpo(c: CommandContext, a: Dictionary) -> CommandResult:
	var p := _pol(c, a["modelo"])
	if p == null:
		return _no(a["modelo"])
	var curve := ReasoningSim.dpo(p, clampi(int(a["pasos"]), 1, 200), clampf(float(a["lr"]), 0.01, 2.0))
	var r := CommandResult.new()
	r.line("DPO en %s · %d pasos · preferencias directas (elegida vs rechazada), sin modelo de premio" % [a["modelo"], int(a["pasos"])], "accent")
	_curve_lines(r, curve)
	r.line("Accuracy final: %.2f" % p.accuracy(), "normal")
	c.emit("reason.dpo", {"model": a["modelo"], "accuracy": p.accuracy(), "curve": PackedFloat64Array(curve)})
	return r


static func _best(c: CommandContext, a: Dictionary) -> CommandResult:
	var p := _pol(c, a["modelo"])
	if p == null:
		return _no(a["modelo"])
	var n := clampi(int(a["n"]), 1, 64)
	var acc := ReasoningSim.self_consistency(p, n, 7)
	var greedy := p.accuracy()
	var r := CommandResult.new()
	r.line("Autoconsistencia en %s · %d muestras por problema, gana la más votada" % [a["modelo"], n], "accent")
	r.line("Accuracy con 1 (greedy): %.2f · con %d muestras: %.2f" % [greedy, n, acc], "normal")
	r.line("Más cómputo en inferencia sube la accuracy sin reentrenar, pero cuesta %d veces más." % n, "muted")
	c.emit("reason.best", {"model": a["modelo"], "n": n, "greedy": greedy, "accuracy": acc})
	return r


static func _distill(c: CommandContext, a: Dictionary) -> CommandResult:
	var alumno := _pol(c, a["alumno"])
	var maestro := _pol(c, a["maestro"])
	if alumno == null:
		return _no(a["alumno"])
	if maestro == null:
		return _no(a["maestro"])
	var curve := ReasoningSim.distill(alumno, maestro, clampi(int(a["pasos"]), 1, 200), 0.5)
	var r := CommandResult.new()
	r.line("Destilación · %s aprende a imitar a %s · %d pasos" % [a["alumno"], a["maestro"], int(a["pasos"])], "accent")
	_curve_lines(r, curve)
	r.line("Accuracy del alumno: %.2f · del maestro: %.2f" % [alumno.accuracy(), maestro.accuracy()], "normal")
	c.emit("reason.distill", {"student": a["alumno"], "teacher": a["maestro"], "accuracy": alumno.accuracy(), "teacher_accuracy": maestro.accuracy(), "curve": PackedFloat64Array(curve)})
	return r
