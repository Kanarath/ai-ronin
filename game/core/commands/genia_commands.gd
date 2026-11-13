class_name GeniaCommands
extends RefCounted
## T13 · Seguridad de la generación de imagen y audio (content/genia.json). Simulado y
## defensivo: las peticiones de mal uso se nombran por su categoría, sin detalle operativo.
##   genia peticiones                 peticiones (una legítima y cuatro de mal uso)
##   genia defensa <capa> on|off      filtro_entrada, clasificador_salida, filtro_copyright, marca_agua
##   genia evaluar                     de las de mal uso, cuántas se bloquean; y si lo generado lleva marca

const PATH := "res://content/genia.json"
static var _data: Dictionary = {}


static func register(reg: CommandRegistry) -> void:
	var add := func(path: String, summary: String, handler: Callable, sig: CommandSignature) -> void:
		reg.register(Command.new(path, summary, handler, "lenguaje").with_signature(sig))
	add.call("genia peticiones", "Peticiones al generador: una legítima y cuatro de mal uso (por categoría).",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _list(c, a), CommandSignature.new())
	add.call("genia defensa", "Activa o desactiva un guardarraíl.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _def(c, a),
		CommandSignature.new().pos("capa", "filtro_entrada, clasificador_salida, filtro_copyright o marca_agua", "string", true, ["filtro_entrada", "clasificador_salida", "filtro_copyright", "marca_agua"]).pos("estado", "on u off", "string", true, ["on", "off"]).example("genia defensa clasificador_salida on"))
	add.call("genia evaluar", "Mide: peticiones de mal uso bloqueadas, legítimas que pasan y si lo generado lleva marca.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _eval(c, a), CommandSignature.new())


static func data() -> Dictionary:
	if _data.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = d if d is Dictionary else {}
	return _data


static func _st(c: CommandContext) -> Dictionary:
	if c.world.genia.is_empty():
		for d: String in data()["defensas"]:
			c.world.genia[d] = false
	return c.world.genia


static func _active(c: CommandContext) -> PackedStringArray:
	var out := PackedStringArray()
	for d: String in data()["defensas"]:
		if _st(c).get(d, false):
			out.append(d)
	return out


static func blocked(rasgos: Array, active: PackedStringArray) -> bool:
	for d: String in active:
		var def: Dictionary = data()["defensas"][d]
		if def.has("pilla"):
			for r: String in def["pilla"]:
				if r in rasgos:
					return true
	return false


static func _list(c: CommandContext, _a: Dictionary) -> CommandResult:
	var r := CommandResult.new()
	r.line("Peticiones al generador de imagen/audio", "accent")
	for m: Dictionary in data()["peticiones"]:
		r.line("%s  [%s]  %s" % [m["id"], "⚔ mal uso" if m["mal_uso"] else "✓ legítima", m["texto"]], "data")
	r.line("Guardarraíles: genia defensa <capa> on · mide: genia evaluar", "muted")
	c.emit("genia.list", {})
	return r


static func _def(c: CommandContext, a: Dictionary) -> CommandResult:
	if not (data()["defensas"] as Dictionary).has(a["capa"]):
		return CommandResult.error("Capas: " + ", ".join(PackedStringArray((data()["defensas"] as Dictionary).keys())))
	_st(c)[a["capa"]] = a["estado"] == "on"
	var r := CommandResult.new()
	r.line("✓ %s → %s · %s" % [a["capa"], "activada" if a["estado"] == "on" else "desactivada", data()["defensas"][a["capa"]]["desc"]], "ok")
	c.emit("genia.def", {"capa": a["capa"], "enabled": a["estado"] == "on", "active": ",".join(_active(c))})
	return r


static func _eval(c: CommandContext, a: Dictionary) -> CommandResult:
	var active := _active(c)
	var marca: bool = _st(c).get("marca_agua", false)
	var misuse := 0
	var caught := 0
	var legit_ok := 0
	var legit := 0
	var rows: Array = []
	var pass_ids := PackedStringArray()
	for m: Dictionary in data()["peticiones"]:
		var bl := blocked(m["rasgos"], active)
		if m["mal_uso"]:
			misuse += 1
			caught += int(bl)
			if not bl:
				pass_ids.append(m["id"])
			rows.append([m["id"], "⚔", "✓ bloqueada" if bl else "✗ PASA", ("con marca" if marca else "sin marca") if not bl else "—"])
		else:
			legit += 1
			legit_ok += int(not bl)
			rows.append([m["id"], "legítima", "✗ bloqueada mal" if bl else "✓ generada", "con marca" if marca else "sin marca"])
	var r := CommandResult.new()
	r.line("Evaluación · guardarraíles: %s" % (", ".join(active) if not active.is_empty() else "ninguno"), "accent")
	r.table(PackedStringArray(["petición", "tipo", "resultado", "procedencia"]), rows)
	r.line("Mal uso bloqueado: %d/%d · legítimas generadas: %d/%d · marca de agua: %s" % [caught, misuse, legit_ok, legit, "sí" if marca else "no"], "normal")
	if not pass_ids.is_empty():
		r.line("Se cuelan: %s" % ", ".join(pass_ids), "warn")
	c.emit("genia.eval", {"active": ",".join(active), "caught": caught, "misuse": misuse, "legit_ok": legit_ok, "marca": marca, "pass": ",".join(pass_ids)})
	return r
