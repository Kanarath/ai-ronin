class_name AtlasCommands
extends RefCounted
## O3-03 · MITRE ATLAS operativo (content/gov/atlas.json): mapear los pasos de un ataque a las
## tácticas ATLAS para montar la cadena (kill-chain) de la forja.
##   atlas tacticas               las tácticas ATLAS (orden de ciclo de vida)
##   atlas pasos                  los pasos del ataque a la forja, para clasificar
##   atlas map <paso> <tactica>   asigna a un paso su táctica (T1 … T8)
##   atlas cadena                 la cadena de ataque en orden, una vez mapeada

const PATH := "res://content/gov/atlas.json"
static var _data: Dictionary = {}


static func register(reg: CommandRegistry) -> void:
	var add := func(path: String, summary: String, handler: Callable, sig: CommandSignature) -> void:
		reg.register(Command.new(path, summary, handler, "gobernanza").with_signature(sig))
	add.call("atlas tacticas", "Las tácticas de MITRE ATLAS en orden de ciclo de vida.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _tac(c, a), CommandSignature.new())
	add.call("atlas pasos", "Los pasos del ataque a la forja, para clasificar por táctica.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _pasos(c, a), CommandSignature.new())
	add.call("atlas map", "Asigna a un paso su táctica ATLAS.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _map(c, a),
		CommandSignature.new().pos("paso", "A1 … A8").pos("tactica", "T1 … T8").example("atlas map A1 T1"))
	add.call("atlas cadena", "La cadena de ataque en orden de ciclo de vida, una vez mapeada.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _cadena(c, a), CommandSignature.new())


static func data() -> Dictionary:
	if _data.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = d if d is Dictionary else {}
	return _data


static func _mp(c: CommandContext) -> Dictionary:
	if not c.world.iso.has("atlas"):
		c.world.iso["atlas"] = {}
	return c.world.iso["atlas"]


static func _tac(c: CommandContext, _a: Dictionary) -> CommandResult:
	var r := CommandResult.new()
	r.line("MITRE ATLAS · tácticas (orden de ciclo de vida de un ataque a IA)", "accent")
	for t: Dictionary in data()["tacticas"]:
		r.line("%s · %s (%s · %s)" % [t["id"], t["nombre"], t["es"], t["atlas"]], "data")
		r.line("     " + t["que"], "muted")
	c.emit("atlas.tacticas", {})
	return r


static func _pasos(c: CommandContext, _a: Dictionary) -> CommandResult:
	var r := CommandResult.new()
	r.line("Pasos del ataque a la forja · clasifícalos: atlas map <paso> <táctica>", "accent")
	var done := _mp(c)
	for x: Dictionary in data()["pasos"]:
		var mark := "✓ " + str(done[x["id"]]) if done.has(x["id"]) else "·"
		r.line("%s  [%s]  %s  (visto en %s)" % [x["id"], mark, x["texto"], x["arco"]], "data")
	c.emit("atlas.pasos", {})
	return r


static func _find(id: String) -> Dictionary:
	for x: Dictionary in data()["pasos"]:
		if x["id"] == id.strip_edges().to_upper():
			return x
	return {}


static func _map(c: CommandContext, a: Dictionary) -> CommandResult:
	var x := _find(a["paso"])
	if x.is_empty():
		return CommandResult.error("Pasos: A1 … A8 (atlas pasos)")
	var tac := String(a["tactica"]).strip_edges().to_upper()
	var valid := false
	for t: Dictionary in data()["tacticas"]:
		if t["id"] == tac:
			valid = true
	if not valid:
		return CommandResult.error("Tácticas: T1 … T8 (atlas tacticas)")
	var ok: bool = tac == x["tactica"]
	var r := CommandResult.new()
	if ok:
		_mp(c)[x["id"]] = tac
		var t := _tactica(tac)
		r.line("✓ %s → %s (%s)" % [x["id"], t["nombre"], t["es"]], "ok")
	else:
		r.line("✗ %s no es la táctica de %s. ¿En qué fase del ataque está: entrar, acceder al modelo, ejecutar, persistir, evadir, exfiltrar o impactar?" % [tac, x["id"]], "warn")
	var n := 0
	for p: Dictionary in data()["pasos"]:
		if _mp(c).get(p["id"], "") == p["tactica"]:
			n += 1
	r.line("Pasos mapeados bien: %d/%d" % [n, data()["pasos"].size()], "muted")
	c.emit("atlas.map", {"paso": x["id"], "tactica": tac, "correct": ok, "correct_count": n})
	return r


static func _tactica(id: String) -> Dictionary:
	for t: Dictionary in data()["tacticas"]:
		if t["id"] == id:
			return t
	return {}


static func _cadena(c: CommandContext, _a: Dictionary) -> CommandResult:
	var done := _mp(c)
	var n := 0
	for p: Dictionary in data()["pasos"]:
		if done.get(p["id"], "") == p["tactica"]:
			n += 1
	var r := CommandResult.new()
	if n < data()["pasos"].size():
		r.line("La cadena está incompleta (%d/%d pasos mapeados). Clasifica el resto: atlas pasos." % [n, data()["pasos"].size()], "warn")
		c.emit("atlas.cadena", {"complete": false, "mapped": n})
		return r
	r.line("Cadena de ataque a la forja · en orden de ciclo de vida (ATLAS)", "accent")
	var rows: Array = []
	for t: Dictionary in data()["tacticas"]:
		var paso := ""
		for p: Dictionary in data()["pasos"]:
			if p["tactica"] == t["id"]:
				paso = p["texto"]
		rows.append(["%s %s" % [t["atlas"], t["nombre"]], paso])
	r.table(PackedStringArray(["táctica ATLAS", "paso del ataque"]), rows)
	r.line("Esto es un kill-chain: el mismo lenguaje que usa el SOC y la inteligencia de amenazas para hablar de un ataque, paso a paso.", "muted")
	c.emit("atlas.cadena", {"complete": true, "mapped": n})
	return r
