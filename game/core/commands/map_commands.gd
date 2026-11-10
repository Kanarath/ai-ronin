class_name MapCommands
extends RefCounted
## mapa: el recorrido completo del curso, desde los datos hasta atacar y defender LLM, con
## dónde estás y para qué sirve cada tramo. Lee content/mapa.json y el estado de las misiones.

const MAP_PATH := "res://content/mapa.json"


static func register(reg: CommandRegistry) -> void:
	reg.register(Command.new("mapa", "El recorrido del curso: qué aprendes en cada tramo, para qué sirve y dónde estás.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _show(c, a), "ayuda"))


static func load_map() -> Dictionary:
	var f := FileAccess.open(MAP_PATH, FileAccess.READ)
	if f == null:
		return {}
	var data: Variant = JSON.parse_string(f.get_as_text())
	return data if data is Dictionary else {}


static func _show(c: CommandContext, _a: Dictionary) -> CommandResult:
	var g := c.shell.get_game() as DojoGame
	if g == null:
		return CommandResult.error("El mapa necesita una partida.")
	var data := load_map()
	if data.is_empty():
		return CommandResult.error("No se ha podido leer el mapa del curso.")
	var r := CommandResult.new()
	r.line("Mapa del curso", "accent")
	r.line(str(data.get("destino", "")), "muted")
	r.line("")
	# La unidad «actual» es la de la misión en curso o, si no hay, la de la primera misión sin completar.
	var current := ""
	if not g.active_mission.is_empty() and g.runner.is_running():
		current = g.active_mission["unit"]
	else:
		for m: Dictionary in g.catalog.missions:
			if not g.progress.is_mission_completed(m["id"]):
				current = m["unit"]
				break
	var purposes := {}
	for u: Dictionary in data.get("unidades", []):
		purposes[u["unit"]] = u["para_que"]
	var seen: Array[String] = []
	for m: Dictionary in g.catalog.missions:
		var unit: String = m["unit"]
		if unit in seen:
			continue
		seen.append(unit)
		var total := 0
		var done := 0
		for x: Dictionary in g.catalog.missions:
			if x["unit"] == unit:
				total += 1
				done += 1 if g.progress.is_mission_completed(x["id"]) else 0
		var mark := "✓" if done == total else ("▶" if unit == current else "·")
		var here := "   ◀ estás aquí" if unit == current else ""
		r.line("%s %s  (%d/%d)%s" % [mark, unit, done, total, here], "accent" if unit == current else ("ok" if done == total else "normal"))
		if purposes.has(unit):
			r.line("    " + str(purposes[unit]), "muted")
	r.line("")
	r.line("Abre la lista de misiones con ☰ Misiones o escribe mission list.", "muted")
	return r
