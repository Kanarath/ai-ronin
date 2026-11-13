class_name ThreatCommands
extends RefCounted
## O8 · La IA como arma y la defensa frente a ataques potenciados por IA (content/threats/
## ia_ofensiva.json). Simulado y DEFENSIVO: los mensajes se describen por sus rasgos; no hay
## contenido operativo de ataque. Se aprende a detectar y a verificar.
##   amenaza bandeja                  los correos (ataques de distinta sofisticación y legítimos)
##   amenaza defensa <capa> on|off    ortografia, autenticacion, comportamiento, fuera_de_banda
##   amenaza evaluar                   qué ataques se detectan y qué legítimos se marcan por error

const PATH := "res://content/threats/ia_ofensiva.json"
static var _data: Dictionary = {}


static func register(reg: CommandRegistry) -> void:
	var add := func(path: String, summary: String, handler: Callable, sig: CommandSignature) -> void:
		reg.register(Command.new(path, summary, handler, "deteccion").with_signature(sig))
	add.call("amenaza bandeja", "La bandeja: correos de ataque (de artesanal a potenciado por IA) y legítimos.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _inbox(c, a), CommandSignature.new())
	add.call("amenaza defensa", "Activa o desactiva una capa de defensa.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _def(c, a),
		CommandSignature.new().pos("capa", "ortografia, autenticacion, comportamiento o fuera_de_banda", "string", true, ["ortografia", "autenticacion", "comportamiento", "fuera_de_banda"]).pos("estado", "on u off", "string", true, ["on", "off"]).example("amenaza defensa autenticacion on"))
	add.call("amenaza evaluar", "Mide con las capas activas: ataques detectados y legítimos marcados por error.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _eval(c, a), CommandSignature.new())


static func data() -> Dictionary:
	if _data.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = d if d is Dictionary else {}
	return _data


static func _st(c: CommandContext) -> Dictionary:
	if c.world.threat.is_empty():
		c.world.threat = {"ortografia": false, "autenticacion": false, "comportamiento": false, "fuera_de_banda": false}
	return c.world.threat


static func _active(c: CommandContext) -> PackedStringArray:
	var out := PackedStringArray()
	for d: String in data()["defensas"]:
		if _st(c).get(d, false):
			out.append(d)
	return out


## ¿Detecta alguna capa activa este mensaje? (comparando rasgos con lo que «pilla» cada capa)
static func detected(rasgos: Array, active: PackedStringArray) -> bool:
	for d: String in active:
		for r: String in data()["defensas"][d]["pilla"]:
			if r in rasgos:
				return true
	return false


static func _inbox(c: CommandContext, _a: Dictionary) -> CommandResult:
	var r := CommandResult.new()
	r.line("Bandeja de la forja · correos de ataque y legítimos (descritos, no reales)", "accent")
	for m: Dictionary in data()["bandeja"]:
		var tag := "⚔ %s" % m["nivel"] if m["ataque"] else "✓ legítimo"
		r.line("%s  [%s]  de: %s" % [m["id"], tag, m["remitente"]], "data")
		r.line("     " + m["texto"], "muted")
	r.line("Defensas: amenaza defensa <capa> on · mide: amenaza evaluar", "muted")
	c.emit("threat.inbox", {})
	return r


static func _def(c: CommandContext, a: Dictionary) -> CommandResult:
	if not (data()["defensas"] as Dictionary).has(a["capa"]):
		return CommandResult.error("Capas: " + ", ".join(PackedStringArray((data()["defensas"] as Dictionary).keys())))
	_st(c)[a["capa"]] = a["estado"] == "on"
	var r := CommandResult.new()
	r.line("✓ %s → %s · %s" % [a["capa"], "activada" if a["estado"] == "on" else "desactivada", data()["defensas"][a["capa"]]["desc"]], "ok")
	c.emit("threat.def", {"capa": a["capa"], "enabled": a["estado"] == "on", "active": ",".join(_active(c))})
	return r


static func _eval(c: CommandContext, a: Dictionary) -> CommandResult:
	var active := _active(c)
	var attacks := []
	var legit := []
	for m: Dictionary in data()["bandeja"]:
		(attacks if m["ataque"] else legit).append(m)
	var caught := 0
	var fp := 0
	var rows: Array = []
	var pass_ids := PackedStringArray()
	for m: Dictionary in data()["bandeja"]:
		var det := detected(m["rasgos"], active)
		if m["ataque"]:
			caught += int(det)
			if not det:
				pass_ids.append(m["id"])
			rows.append([m["id"], "⚔", "✓ detectado" if det else "✗ PASA", m["nivel"]])
		else:
			fp += int(det)
			rows.append([m["id"], "legítimo", "✗ marcado por error" if det else "✓ pasa bien", m["nivel"]])
	var r := CommandResult.new()
	r.line("Evaluación · defensas: %s" % (", ".join(active) if not active.is_empty() else "ninguna"), "accent")
	r.table(PackedStringArray(["correo", "tipo", "resultado", "nivel"]), rows)
	r.line("Ataques detectados: %d/%d · legítimos marcados por error: %d/%d" % [caught, attacks.size(), fp, legit.size()], "normal")
	if not pass_ids.is_empty():
		r.line("Se cuelan: %s" % ", ".join(pass_ids), "warn")
	c.emit("threat.eval", {"active": ",".join(active), "caught": caught, "attacks": attacks.size(), "fp": fp, "legit": legit.size(), "pass": ",".join(pass_ids),
		"labels": PackedStringArray(["ataques detectados", "legítimos marcados mal"]),
		"values": PackedFloat64Array([float(caught) / maxf(attacks.size(), 1), float(fp) / maxf(legit.size(), 1)])})
	return r
