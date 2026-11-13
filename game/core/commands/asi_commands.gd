class_name AsiCommands
extends RefCounted
## O7 · Riesgos agénticos: OWASP Top 10 for Agentic Applications 2026 (content/asi/forja_asi.json).
##   asi list                         los diez riesgos (ASI01–ASI10)
##   asi risk <ASIxx>                 un riesgo: qué es y dónde lo has visto
##   asi incidents                    los diez incidentes de la forja
##   asi classify <incidente> <ASIxx> clasifica un incidente
##   asi defenses                     las defensas que has montado en los arcos
##   asi cover <defensa> <ASIxx>      qué riesgo cubre una defensa
##   asi coverage                     mapa de cobertura: qué riesgos quedan sin defensa

const PATH := "res://content/asi/forja_asi.json"
static var _data: Dictionary = {}


static func register(reg: CommandRegistry) -> void:
	var add := func(path: String, summary: String, handler: Callable, sig: CommandSignature) -> void:
		reg.register(Command.new(path, summary, handler, "seguridad").with_signature(sig))
	add.call("asi list", "Los diez riesgos del OWASP Top 10 for Agentic Applications 2026.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _list(c, a), CommandSignature.new())
	add.call("asi risk", "Un riesgo agéntico: qué es y en qué misiones lo has visto.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _risk(c, a),
		CommandSignature.new().pos("riesgo", "ASI01 … ASI10").example("asi risk ASI03"))
	add.call("asi incidents", "Los incidentes de la forja para clasificar.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _incidents(c, a), CommandSignature.new())
	add.call("asi classify", "Clasifica un incidente en un riesgo ASI.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _classify(c, a),
		CommandSignature.new().pos("incidente", "I1 … I10").pos("riesgo", "ASI01 … ASI10").example("asi classify I1 ASI01"))
	add.call("asi defenses", "Las defensas que has montado en los arcos y qué riesgo has dicho que cubren.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _defenses(c, a), CommandSignature.new())
	add.call("asi cover", "Asigna a una defensa el riesgo ASI que cubre.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _cover(c, a),
		CommandSignature.new().pos("defensa", "D1 … D9").pos("riesgo", "ASI01 … ASI10").example("asi cover D1 ASI01"))
	add.call("asi coverage", "Mapa de cobertura: cada riesgo ASI y las defensas que lo cubren.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _coverage(c, a), CommandSignature.new())
	add.call("asi close", "Cierra el mapa: asigna las defensas nuevas (caja de arena y aprobación verificable) a los huecos ASI05 y ASI09.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _close(c, a),
		CommandSignature.new().pos("defensa", "D10 o D11 (las de O7-03 y O7-04)").pos("riesgo", "ASI05 o ASI09").example("asi close D10 ASI05"))


static func data() -> Dictionary:
	if _data.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = d if d is Dictionary else {}
	return _data


static func _find(list_key: String, id: String) -> Dictionary:
	for x: Dictionary in data().get(list_key, []):
		if String(x["id"]).to_upper() == id.to_upper():
			return x
	return {}


static func _norm(id: String) -> String:
	var u := id.strip_edges().to_upper()
	if u.begins_with("ASI") and u.length() == 4:
		u = "ASI0" + u.substr(3)
	return u


static func _list(c: CommandContext, _a: Dictionary) -> CommandResult:
	var r := CommandResult.new()
	r.line("OWASP Top 10 for Agentic Applications 2026 (9 de diciembre de 2025)", "accent")
	var rows: Array = []
	for x: Dictionary in data()["riesgos"]:
		rows.append([x["id"], x["es"], x["nombre"]])
	r.table(PackedStringArray(["id", "riesgo", "nombre oficial"]), rows)
	r.line("El detalle de uno: asi risk <ASIxx> · los incidentes: asi incidents", "muted")
	c.emit("asi.listed", {})
	return r


static func _risk(c: CommandContext, a: Dictionary) -> CommandResult:
	var x := _find("riesgos", _norm(a["riesgo"]))
	if x.is_empty():
		return CommandResult.error("Riesgos: ASI01 … ASI10")
	var r := CommandResult.new()
	r.line("%s · %s (%s)" % [x["id"], x["es"], x["nombre"]], "accent")
	r.line(x["que"], "normal")
	r.line("Dónde lo has visto: " + (str(x["visto"]) if str(x["visto"]) != "—" else "todavía en ninguna misión"), "muted")
	c.emit("asi.risk", {"risk": x["id"]})
	return r


static func _incidents(c: CommandContext, _a: Dictionary) -> CommandResult:
	var r := CommandResult.new()
	r.line("Incidentes de la forja · clasifícalos: asi classify <incidente> <ASIxx>", "accent")
	var done: Dictionary = c.world.asi["classified"]
	for x: Dictionary in data()["incidentes"]:
		var mark := "✓ " + str(done[x["id"]]) if done.has(x["id"]) else "·"
		r.line("%s  [%s]  %s" % [x["id"], mark, x["texto"]], "data")
	c.emit("asi.incidents", {})
	return r


static func _correct_count(store: Dictionary, list_key: String, ok: Callable) -> int:
	var n := 0
	for x: Dictionary in data()[list_key]:
		if store.has(x["id"]) and ok.call(x, store[x["id"]]):
			n += 1
	return n


static func _classify(c: CommandContext, a: Dictionary) -> CommandResult:
	var inc := _find("incidentes", a["incidente"])
	if inc.is_empty():
		return CommandResult.error("Incidentes: I1 … I10 (asi incidents)")
	var risk := _norm(a["riesgo"])
	if _find("riesgos", risk).is_empty():
		return CommandResult.error("Riesgos: ASI01 … ASI10 (asi list)")
	var ok: bool = risk == inc["riesgo"]
	var r := CommandResult.new()
	if ok:
		c.world.asi["classified"][inc["id"]] = risk
		r.line("✓ %s → %s · %s" % [inc["id"], risk, inc["por_que"]], "ok")
	elif risk in inc.get("secundarios", []):
		var x := _find("riesgos", risk)
		r.line("~ Casi: en %s también hay algo de %s (%s), pero no es la CAUSA RAÍZ." % [inc["id"], risk, x["es"]], "warn")
		r.line("  Se clasifica por lo que falló primero, el punto donde un control habría cortado la cadena. Piensa en el origen, no en el efecto.", "muted")
	else:
		var x := _find("riesgos", risk)
		r.line("✗ %s no es %s (%s). Vuelve a leerlo: ¿qué falló primero? Pista: compara con asi risk %s." % [inc["id"], risk, x["es"], risk], "warn")
	var n := _correct_count(c.world.asi["classified"], "incidentes", func(x: Dictionary, v: Variant) -> bool: return v == x["riesgo"])
	r.line("Clasificados bien: %d/%d" % [n, data()["incidentes"].size()], "muted")
	c.emit("asi.classified", {"incident": inc["id"], "risk": risk, "correct": ok, "correct_count": n})
	return r


static func _defenses(c: CommandContext, _a: Dictionary) -> CommandResult:
	var r := CommandResult.new()
	r.line("Defensas de la forja · asígnales el riesgo que cubren: asi cover <defensa> <ASIxx>", "accent")
	var done: Dictionary = c.world.asi["covered"]
	for x: Dictionary in data()["defensas"]:
		r.line("%s  [%s]  %s" % [x["id"], str(done[x["id"]]) if done.has(x["id"]) else "·", x["texto"]], "data")
	c.emit("asi.defenses", {})
	return r


static func _cover(c: CommandContext, a: Dictionary) -> CommandResult:
	var d := _find("defensas", a["defensa"])
	if d.is_empty():
		return CommandResult.error("Defensas: D1 … D9 (asi defenses)")
	var risk := _norm(a["riesgo"])
	if _find("riesgos", risk).is_empty():
		return CommandResult.error("Riesgos: ASI01 … ASI10 (asi list)")
	var ok: bool = risk in d["cubre"]
	var r := CommandResult.new()
	if ok:
		c.world.asi["covered"][d["id"]] = risk
		r.line("✓ %s cubre %s (%s)." % [d["id"], risk, _find("riesgos", risk)["es"]], "ok")
	else:
		r.line("✗ %s no es la defensa principal contra %s. ¿Qué ataque de los arcos frenaba?" % [d["id"], risk], "warn")
	var n := _correct_count(c.world.asi["covered"], "defensas", func(x: Dictionary, v: Variant) -> bool: return v in x["cubre"])
	r.line("Defensas asignadas bien: %d/%d" % [n, data()["defensas"].size()], "muted")
	c.emit("asi.covered", {"defense": d["id"], "risk": risk, "correct": ok, "correct_count": n})
	return r


static func _coverage(c: CommandContext, _a: Dictionary) -> CommandResult:
	var done: Dictionary = c.world.asi["covered"]
	var rows: Array = []
	var uncovered := PackedStringArray()
	var complete: bool = done.size() >= data()["defensas"].size()
	for x: Dictionary in data()["riesgos"]:
		var ds := PackedStringArray()
		for d: String in done:
			if done[d] == x["id"]:
				ds.append(d)
		ds.sort()
		if ds.is_empty():
			uncovered.append(x["id"])
		rows.append([x["id"], x["es"], ", ".join(ds) if not ds.is_empty() else "— sin defensa", str(data()["prioridad"].get(x["id"], "")) if complete else ""])
	var r := CommandResult.new()
	r.line("Cobertura de la forja frente al OWASP agéntico · %d de %d defensas asignadas" % [done.size(), data()["defensas"].size()], "accent")
	r.table(PackedStringArray(["riesgo", "", "defensas", "prioridad"]), rows)
	if not complete:
		r.line("Aún quedan defensas sin asignar: el mapa no está completo (asi defenses).", "warn")
	else:
		r.line("Sin cubrir: %s. %s" % [", ".join(uncovered), data()["nota_prioridad"]], "normal")
	c.emit("asi.coverage", {"mapped": done.size(), "uncovered": ",".join(uncovered), "uncovered_count": uncovered.size()})
	return r


static func _new_def(id: String) -> Dictionary:
	for x: Dictionary in data().get("defensas_nuevas", []):
		if x["id"] == id.strip_edges().to_upper():
			return x
	return {}


static func _close(c: CommandContext, a: Dictionary) -> CommandResult:
	var d := _new_def(a["defensa"])
	if d.is_empty():
		return CommandResult.error("Defensas nuevas: D10 (caja de arena) o D11 (aprobación verificable)")
	var risk := _norm(a["riesgo"])
	var ok: bool = risk in d["cubre"]
	var r := CommandResult.new()
	if ok:
		c.world.asi["closed"][d["id"]] = risk
		r.line("✓ %s cubre %s. Hueco cerrado." % [d["id"], risk], "ok")
	else:
		r.line("✗ %s no cubre %s. D10 es la caja de arena (ejecución de código); D11, la aprobación verificable." % [d["id"], risk], "warn")
	var closed := 0
	for x: Dictionary in data().get("defensas_nuevas", []):
		if c.world.asi["closed"].get(x["id"], "") in x["cubre"]:
			closed += 1
	var gaps := 2 - closed
	r.line("Huecos que quedan (ASI05, ASI09): %d" % gaps, "muted" if gaps > 0 else "ok")
	if gaps == 0:
		r.line("Mapa completo: los diez riesgos ASI tienen al menos una defensa. Lo que construiste en O7-03 y O7-04 tapa justo lo que O7-02 dejó abierto.", "ok")
	c.emit("asi.closed", {"defense": d["id"], "risk": risk, "correct": ok, "closed_count": closed, "gaps": gaps})
	return r
