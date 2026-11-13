class_name JailbreakCommands
extends RefCounted
## A1-08 · Taxonomía de jailbreaks (content/attacks/jailbreaks.json). Simulado y defensivo:
## las técnicas se describen por su mecanismo; no hay cargas. Cada una necesita su defensa.
##   jailbreak tecnicas               las seis familias de jailbreak
##   jailbreak defensa <capa> on|off  filtro_entrada, clasificador, limite_turnos, limite_contexto, normalizar, aislar_contenido
##   jailbreak evaluar                 cuántas técnicas se frenan con las defensas activas

const PATH := "res://content/attacks/jailbreaks.json"
static var _data: Dictionary = {}


static func register(reg: CommandRegistry) -> void:
	var add := func(path: String, summary: String, handler: Callable, sig: CommandSignature) -> void:
		reg.register(Command.new(path, summary, handler, "seguridad").with_signature(sig))
	add.call("jailbreak tecnicas", "Las seis familias de jailbreak y su mecanismo.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _list(c, a), CommandSignature.new())
	add.call("jailbreak defensa", "Activa o desactiva una capa de defensa.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _def(c, a),
		CommandSignature.new().pos("capa", "ver jailbreak tecnicas").pos("estado", "on u off", "string", true, ["on", "off"]).example("jailbreak defensa clasificador on"))
	add.call("jailbreak evaluar", "Cuántas de las 6 técnicas frenan las defensas activas.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _eval(c, a), CommandSignature.new())


static func data() -> Dictionary:
	if _data.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = d if d is Dictionary else {}
	return _data


static func _st(c: CommandContext) -> Dictionary:
	if c.world.jailbreak.is_empty():
		for d: String in data()["defensas"]:
			c.world.jailbreak[d] = false
	return c.world.jailbreak


static func _active(c: CommandContext) -> PackedStringArray:
	var out := PackedStringArray()
	for d: String in data()["defensas"]:
		if _st(c).get(d, false):
			out.append(d)
	return out


static func blocked(rasgos: Array, active: PackedStringArray) -> bool:
	for d: String in active:
		for r: String in data()["defensas"][d]["pilla"]:
			if r in rasgos:
				return true
	return false


static func _list(c: CommandContext, _a: Dictionary) -> CommandResult:
	var r := CommandResult.new()
	r.line("Familias de jailbreak (descritas por su mecanismo, sin cargas)", "accent")
	for t: Dictionary in data()["tecnicas"]:
		r.line("%s · %s" % [t["id"], t["nombre"]], "data")
		r.line("     " + t["mecanismo"], "muted")
	r.line("Defensas: jailbreak defensa <capa> on · mide: jailbreak evaluar", "muted")
	c.emit("jailbreak.tecnicas", {})
	return r


static func _def(c: CommandContext, a: Dictionary) -> CommandResult:
	if not (data()["defensas"] as Dictionary).has(a["capa"]):
		return CommandResult.error("Capas: " + ", ".join(PackedStringArray((data()["defensas"] as Dictionary).keys())))
	_st(c)[a["capa"]] = a["estado"] == "on"
	var r := CommandResult.new()
	r.line("✓ %s → %s · %s" % [a["capa"], "activada" if a["estado"] == "on" else "desactivada", data()["defensas"][a["capa"]]["desc"]], "ok")
	c.emit("jailbreak.def", {"capa": a["capa"], "enabled": a["estado"] == "on", "active": ",".join(_active(c))})
	return r


static func _eval(c: CommandContext, a: Dictionary) -> CommandResult:
	var active := _active(c)
	var n := 0
	var rows: Array = []
	var pass_ids := PackedStringArray()
	for t: Dictionary in data()["tecnicas"]:
		var bl := blocked(t["rasgos"], active)
		n += int(bl)
		if not bl:
			pass_ids.append(t["id"])
		rows.append([t["id"], t["nombre"], "✓ frenada" if bl else "✗ PASA"])
	var r := CommandResult.new()
	r.line("Evaluación · defensas: %s" % (", ".join(active) if not active.is_empty() else "ninguna"), "accent")
	r.table(PackedStringArray(["técnica", "familia", "resultado"]), rows)
	r.line("Técnicas frenadas: %d/%d" % [n, data()["tecnicas"].size()], "normal")
	if not pass_ids.is_empty():
		r.line("Se cuelan: %s" % ", ".join(pass_ids), "warn")
	c.emit("jailbreak.eval", {"active": ",".join(active), "frenadas": n, "total": data()["tecnicas"].size(), "pass": ",".join(pass_ids),
		"labels": PackedStringArray(["técnicas frenadas"]), "values": PackedFloat64Array([float(n) / maxf(data()["tecnicas"].size(), 1)])})
	return r
