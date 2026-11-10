class_name MissionCommands
extends RefCounted
## Comandos de misiones, mentor y progreso.


static func register(reg: CommandRegistry) -> void:
	reg.register(Command.new("mission list", "Misiones disponibles y tu estado en cada una.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _list(c, a), "misiones"))
	reg.register(Command.new("mission start", "Empieza (o repite) una misión.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _start(c, a), "misiones")
		.with_signature(CommandSignature.new().pos("id", "identificador de la misión, p. ej. T1-01").example("mission start T1-01")))
	reg.register(Command.new("mission status", "Objetivos de la misión en curso.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _status(c, a), "misiones"))
	reg.register(Command.new("mission brief", "Vuelve a mostrar el briefing y la teoría de la misión.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _brief(c, a), "misiones"))

	reg.register(Command.new("hint", "Pide la siguiente pista del objetivo actual (5 niveles).",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _hint(c, a), "mentor")
		.with_signature(CommandSignature.new().opt("confirm", "confirma que quieres el ejemplo resuelto (nivel 5)", "bool", false))
		.with_details("Pedir pistas está bien: es parte de aprender. Las de nivel 3 o más reducen la puntuación de maestría y la 5 deja la competencia como «practicada»."))
	reg.register(Command.new("hipotesis", "Registra tu predicción ANTES de ejecutar el experimento.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _hypothesis(c, a), "mentor")
		.with_signature(CommandSignature.new().pos("respuesta", "tu predicción", "rest").example("hipotesis flexibilidad")))
	reg.register(Command.new("answer", "Responde a la pregunta del objetivo actual.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _answer(c, a), "mentor")
		.with_signature(CommandSignature.new().pos("valor", "tu respuesta (número con punto decimal)", "rest").example("answer 0.25")))
	reg.register(Command.new("reflexion", "Explica con tus palabras lo que has aprendido.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _reflection(c, a), "mentor")
		.with_signature(CommandSignature.new().pos("texto", "tu explicación", "rest").example("reflexion k=1 acierta todo en train porque...")))

	reg.register(Command.new("plot", "Dibuja un dataset en el panel del laboratorio (dos features).",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _plot(c, a), "datos")
		.with_signature(CommandSignature.new()
			.pos("dataset", "dataset a dibujar", "dataset")
			.opt("x", "feature del eje horizontal", "string")
			.opt("y", "feature del eje vertical", "string")
			.example("plot katanas --x dureza_hrc --y flexibilidad")))

	reg.register(Command.new("logros", "Tus sellos (logros): conseguidos y pendientes.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _achievements(c, a), "misiones"))
	reg.register(Command.new("reto", "Reto rápido: un problema corto con números nuevos para practicar lo aprendido.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _challenge(c, a), "misiones")
		.with_details("Se responde con: reto responder <valor>. Al responder verás la solución paso a paso, aciertes o no."))
	reg.register(Command.new("reto responder", "Responde al reto rápido actual.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _challenge_answer(c, a), "misiones")
		.with_signature(CommandSignature.new().pos("valor", "tu respuesta", "rest").example("reto responder 5")))
	reg.register(Command.new("reto saltar", "Descarta el reto actual y muestra su solución.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _challenge_skip(c, a), "misiones"))

	reg.register(Command.new("status", "Tu progreso: nivel, XP, misiones y competencias.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _progress_status(c, a), "misiones"))


static func _game(c: CommandContext) -> DojoGame:
	return c.shell.get_game() as DojoGame


static func _no_game() -> CommandResult:
	return CommandResult.error("El sistema de misiones no está disponible en este contexto.")


static func _list(c: CommandContext, _a: Dictionary) -> CommandResult:
	var g := _game(c)
	if g == null:
		return _no_game()
	var r := CommandResult.new()
	var data: Array = []
	for m in g.catalog.missions:
		var status := g.mission_status(m["id"])
		var icon: String = {"dominada": "◆", "completada": "✓", "en curso": "▶", "bloqueada": "🔒", "disponible": "·"}[status]
		data.append([icon, m["id"], m["title"], MissionCatalog.DIFFICULTY_NAMES[int(m["difficulty"])], status])
	r.table(PackedStringArray(["", "id", "misión", "nivel", "estado"]), data)
	r.line("Empieza una con: mission start <id>", "muted")
	return r


static func _start(c: CommandContext, a: Dictionary) -> CommandResult:
	var g := _game(c)
	if g == null:
		return _no_game()
	var err := g.start_mission(String(a["id"]).to_upper())
	if not err.is_empty():
		return CommandResult.error(err)
	var m := g.active_mission
	var r := CommandResult.new()
	r.line("▶ %s · %s" % [m["id"], m["title"]], "accent")
	r.line("Laboratorio preparado. RONIN te irá explicando cada paso aquí, en la consola.", "muted")
	r.line("Ayuda: mission status · mission brief · hint", "muted")
	return r


static func _status(c: CommandContext, _a: Dictionary) -> CommandResult:
	var g := _game(c)
	if g == null:
		return _no_game()
	if not g.runner.is_running():
		return CommandResult.new().line("No hay ninguna misión en curso. Mira las disponibles: mission list", "muted")
	var r := CommandResult.new()
	var m := g.active_mission
	r.line("%s · %s%s" % [m["id"], m["title"], " · PRUEBA DE DOMINIO" if g.runner.phase == "trial" else ""], "accent")
	for i in g.runner.objectives.size():
		var o: Dictionary = g.runner.objectives[i]
		var mark := "✓" if i < g.runner.index else ("▶" if i == g.runner.index else "·")
		r.line("%s %d. %s" % [mark, i + 1, o["text"]], "normal" if i == g.runner.index else "muted")
	return r


static func _brief(c: CommandContext, _a: Dictionary) -> CommandResult:
	var g := _game(c)
	if g == null or g.active_mission.is_empty():
		return CommandResult.error("No hay ninguna misión activa.")
	var m := g.active_mission
	var r := CommandResult.new()
	r.line("%s · %s" % [m["id"], m["title"]], "accent")
	r.line(m["briefing"])
	r.line("")
	r.line("Al terminar sabrás:", "accent")
	for lo: String in m.get("learning_objectives", []):
		r.line("  · " + lo)
	for card: Dictionary in m.get("theory_cards", []):
		r.line("")
		r.line("⚗ " + card["title"] if card.get("simplified", false) else "◇ " + card["title"], "accent")
		r.line(card["body"])
	return r


static func _hint(c: CommandContext, a: Dictionary) -> CommandResult:
	var g := _game(c)
	if g == null:
		return _no_game()
	var res := g.runner.request_hint(bool(a["confirm"]))
	if res["ok"]:
		c.emit("hint.used", {"level": res["level"]})
	var r := CommandResult.new()
	r.line(res["text"], "mentor" if res["ok"] else "warn")
	return r


static func _hypothesis(c: CommandContext, a: Dictionary) -> CommandResult:
	var g := _game(c)
	if g == null:
		return _no_game()
	var obj := g.runner.current_objective()
	if obj.is_empty() or not obj.has("prediction"):
		return CommandResult.error("El objetivo actual no pide una predicción. (Formular hipótesis siempre es buena idea, pero aquí no se registra.)")
	var value := String(a["respuesta"])
	var options: Array = obj["prediction"].get("options", [])
	if not options.is_empty():
		var match_opt := ""
		for o: String in options:
			if o.to_lower() == value.to_lower():
				match_opt = o
		if match_opt.is_empty():
			return CommandResult.error("Elige una de las opciones: %s" % " · ".join(PackedStringArray(options)))
		value = match_opt
	c.emit("hypothesis.recorded", {"value": value, "objective": obj["id"]})
	return CommandResult.new().line("Hipótesis registrada: %s" % value, "ok")


static func _answer(c: CommandContext, a: Dictionary) -> CommandResult:
	var g := _game(c)
	if g == null:
		return _no_game()
	var obj := g.runner.current_objective()
	if obj.is_empty() or not ConditionEval.contains_type(obj["validator"], "answer"):
		return CommandResult.error("El objetivo actual no pide una respuesta con 'answer'. Mira: mission status")
	c.emit("answer.submitted", {"value": a["valor"], "objective": obj["id"]})
	return CommandResult.new().line("Respuesta enviada: %s" % a["valor"], "muted")


static func _reflection(c: CommandContext, a: Dictionary) -> CommandResult:
	var g := _game(c)
	if g == null:
		return _no_game()
	var text := String(a["texto"])
	var words := text.split(" ", false).size()
	c.emit("reflection.submitted", {"text": text, "words": words})
	return CommandResult.new().line("Reflexión guardada (%d palabras). Claude la revisará contigo." % words, "muted")


static func _plot(c: CommandContext, a: Dictionary) -> CommandResult:
	var ds := c.world.get_dataset(a["dataset"])
	if ds.dims() < 2:
		return CommandResult.error("Hacen falta al menos dos features para dibujar.")
	var x: String = a["x"] if a["x"] != null else ds.feature_names[0]
	var y: String = a["y"] if a["y"] != null else ds.feature_names[1]
	for f in [x, y]:
		if ds.feature_index(f) == -1:
			return CommandResult.error("'%s' no es una feature de %s. Features: %s" % [f, ds.name, ", ".join(ds.feature_names)])
	c.emit("viz.scatter", {"dataset": ds.name, "x": x, "y": y})
	return CommandResult.new().line("Dibujando %s: %s (horizontal) frente a %s (vertical)." % [ds.name, x, y], "ok")


static func _progress_status(c: CommandContext, _a: Dictionary) -> CommandResult:
	var g := _game(c)
	if g == null:
		return _no_game()
	var p := g.progress
	var r := CommandResult.new()
	var lv := p.level()
	var rk := p.rank()
	r.line("Nivel %d · rango %s %s (%s) · %d XP (siguiente nivel: %d XP)" % [lv, rk["name"], rk["kanji"], rk["es"], p.xp(), p.xp_for_level(lv + 1)], "accent")
	r.line("Sellos: %d de %d (logros)" % [p.data.get("achievements", {}).size(), g.achievements.list.size()], "muted")
	var comps: Dictionary = p.data["competencies"]
	if comps.is_empty():
		r.line("Todavía no hay competencias registradas.", "muted")
	else:
		var data: Array = []
		var keys := comps.keys()
		keys.sort()
		for k: String in keys:
			data.append([k, comps[k]["state"], comps[k]["score"]])
		r.table(PackedStringArray(["competencia", "estado", "maestría"]), data)
	return r


static func _achievements(c: CommandContext, _a: Dictionary) -> CommandResult:
	var g := _game(c)
	if g == null:
		return _no_game()
	c.emit("achievements.viewed")
	var r := CommandResult.new()
	r.line("SELLOS DEL DOJO · %d de %d" % [g.progress.data["achievements"].size(), g.achievements.list.size()], "accent")
	for a: Dictionary in g.achievements.list:
		if g.achievements.is_unlocked(a["id"]):
			r.line("%s  %s — %s" % [a["seal"], a["title"], a["description"]], "ok")
		else:
			var cond: Dictionary = a["condition"]
			var prog := ""
			if cond.has("count") and int(cond["count"]) > 1:
				prog = " (%d/%d)" % [g.achievements.counter(a["id"]), int(cond["count"])]
			r.line("・ %s — %s%s" % [a["title"], a["description"], prog], "muted")
	return r


static func _challenge(c: CommandContext, _a: Dictionary) -> CommandResult:
	var g := _game(c)
	if g == null:
		return _no_game()
	var ch := g.new_challenge()
	if ch.size() <= 1:
		return CommandResult.error("Todavía no hay retos disponibles.")
	var r := CommandResult.new()
	r.line("⚔ RETO RÁPIDO (%s) · +%d XP" % [ch["unit"], DojoGame.CHALLENGE_XP], "accent")
	r.line(ch["question"])
	r.line("Responde con: reto responder <valor>   ·   ¿Atascado? reto saltar", "muted")
	c.emit("challenge.started", {"unit": ch["unit"]})
	return r


static func _challenge_answer(c: CommandContext, a: Dictionary) -> CommandResult:
	var g := _game(c)
	if g == null:
		return _no_game()
	if g.current_challenge.is_empty():
		return CommandResult.error("No hay ningún reto activo. Pide uno con: reto")
	var res := g.answer_challenge(String(a["valor"]))
	var r := CommandResult.new()
	if res["correct"]:
		r.line("✓ ¡Correcto! +%d XP" % res["xp"], "ok")
		r.line(res["explanation"], "muted")
		r.line("Otro: reto", "muted")
	else:
		r.line("✗ No es correcto. Inténtalo otra vez (o reto saltar para ver la solución).", "warn")
	return r


static func _challenge_skip(c: CommandContext, _a: Dictionary) -> CommandResult:
	var g := _game(c)
	if g == null:
		return _no_game()
	if g.current_challenge.is_empty():
		return CommandResult.error("No hay ningún reto activo.")
	var r := CommandResult.new()
	r.line("Solución: %s" % g.current_challenge["explanation"], "mentor")
	g.current_challenge = {}
	return r