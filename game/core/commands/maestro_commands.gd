class_name MaestroCommands
extends RefCounted
## O3-02 · MAESTRO: threat modeling por capas para IA agéntica (content/gov/maestro.json).
##   maestro capas                    las siete capas del marco
##   maestro amenazas                 las amenazas de la forja para clasificar
##   maestro map <amenaza> <capa>     clasifica una amenaza en su capa (L1 … L7)

const PATH := "res://content/gov/maestro.json"
static var _data: Dictionary = {}


static func register(reg: CommandRegistry) -> void:
	var add := func(path: String, summary: String, handler: Callable, sig: CommandSignature) -> void:
		reg.register(Command.new(path, summary, handler, "gobernanza").with_signature(sig))
	add.call("maestro capas", "Las siete capas de MAESTRO (Ken Huang / CSA).",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _capas(c, a), CommandSignature.new())
	add.call("maestro amenazas", "Amenazas del agente de la forja para clasificar por capa.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _amenazas(c, a), CommandSignature.new())
	add.call("maestro map", "Clasifica una amenaza en su capa MAESTRO.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _map(c, a),
		CommandSignature.new().pos("amenaza", "AM1 … AM7").pos("capa", "L1 … L7").example("maestro map AM1 L1"))


static func data() -> Dictionary:
	if _data.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = d if d is Dictionary else {}
	return _data


static func _capas(c: CommandContext, _a: Dictionary) -> CommandResult:
	var r := CommandResult.new()
	r.line("MAESTRO · siete capas para modelar amenazas de un agente", "accent")
	for l: Dictionary in data()["capas"]:
		r.line("%s · %s (%s)" % [l["id"], l["nombre"], l["es"]], "data")
		r.line("     " + l["cubre"], "muted")
	c.emit("maestro.capas", {})
	return r


static func _amenazas(c: CommandContext, _a: Dictionary) -> CommandResult:
	var r := CommandResult.new()
	r.line("Amenazas de la forja · clasifícalas: maestro map <amenaza> <capa>", "accent")
	var done: Dictionary = c.world.iso.get("maestro", {})
	for x: Dictionary in data()["amenazas"]:
		var mark := "✓ " + str(done[x["id"]]) if done.has(x["id"]) else "·"
		r.line("%s  [%s]  %s" % [x["id"], mark, x["texto"]], "data")
	c.emit("maestro.amenazas", {})
	return r


static func _find(id: String) -> Dictionary:
	for x: Dictionary in data()["amenazas"]:
		if x["id"] == id.strip_edges().to_upper():
			return x
	return {}


static func _map(c: CommandContext, a: Dictionary) -> CommandResult:
	var x := _find(a["amenaza"])
	if x.is_empty():
		return CommandResult.error("Amenazas: AM1 … AM7 (maestro amenazas)")
	var capa := String(a["capa"]).strip_edges().to_upper()
	var valid := false
	for l: Dictionary in data()["capas"]:
		if l["id"] == capa:
			valid = true
	if not valid:
		return CommandResult.error("Capas: L1 … L7 (maestro capas)")
	if not c.world.iso.has("maestro"):
		c.world.iso["maestro"] = {}
	var ok: bool = capa == x["capa"]
	var r := CommandResult.new()
	if ok:
		c.world.iso["maestro"][x["id"]] = capa
		r.line("✓ %s → %s · %s" % [x["id"], capa, x["por_que"]], "ok")
	else:
		r.line("✗ %s no es la capa de %s. ¿En qué parte del sistema está el problema: el modelo, los datos, el framework, el despliegue, la medición, el cumplimiento o el ecosistema?" % [capa, x["id"]], "warn")
	var n := 0
	for am: Dictionary in data()["amenazas"]:
		if c.world.iso["maestro"].get(am["id"], "") == am["capa"]:
			n += 1
	r.line("Clasificadas bien: %d/%d" % [n, data()["amenazas"].size()], "muted")
	c.emit("maestro.map", {"amenaza": x["id"], "capa": capa, "correct": ok, "correct_count": n})
	return r
