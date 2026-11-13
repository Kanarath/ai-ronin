class_name MediosCommands
extends RefCounted
## O9 · Deepfakes y medios sintéticos (content/threats/medios_sinteticos.json). Simulado y
## defensivo. Dos tipos de defensa: DETECTAR la pieza (pierde la carrera) y AUTENTICAR por
## procedencia (C2PA), que prueba lo auténtico aunque no condene lo que no la lleva.
##   medios list                       las piezas (falsas de varios niveles y auténticas)
##   medios defensa <capa> on|off      detector_artefactos, procedencia, verificacion
##   medios evaluar                     falsos detectados y auténticos marcados por error

const PATH := "res://content/threats/medios_sinteticos.json"
static var _data: Dictionary = {}


static func register(reg: CommandRegistry) -> void:
	var add := func(path: String, summary: String, handler: Callable, sig: CommandSignature) -> void:
		reg.register(Command.new(path, summary, handler, "deteccion").with_signature(sig))
	add.call("medios list", "Las piezas: deepfakes de distinto nivel y medios auténticos.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _list(c, a), CommandSignature.new())
	add.call("medios defensa", "Activa o desactiva una defensa.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _def(c, a),
		CommandSignature.new().pos("capa", "detector_artefactos, procedencia o verificacion", "string", true, ["detector_artefactos", "procedencia", "verificacion"]).pos("estado", "on u off", "string", true, ["on", "off"]).example("medios defensa procedencia on"))
	add.call("medios evaluar", "Mide con las defensas activas: falsos detectados y auténticos marcados por error.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _eval(c, a), CommandSignature.new())


static func data() -> Dictionary:
	if _data.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = d if d is Dictionary else {}
	return _data


static func _st(c: CommandContext) -> Dictionary:
	if c.world.medios.is_empty():
		c.world.medios = {"detector_artefactos": false, "procedencia": false, "verificacion": false}
	return c.world.medios


static func _active(c: CommandContext) -> PackedStringArray:
	var out := PackedStringArray()
	for d: String in data()["defensas"]:
		if _st(c).get(d, false):
			out.append(d)
	return out


## ¿Alguna defensa activa marca esta pieza como sospechosa?
static func flagged(rasgos: Array, active: PackedStringArray) -> bool:
	for d: String in active:
		var def: Dictionary = data()["defensas"][d]
		if def.has("pilla"):
			for r: String in def["pilla"]:
				if r in rasgos:
					return true
		if def.has("autentica"):
			var ok := false
			for r: String in def["autentica"]:
				if r in rasgos:
					ok = true
			if not ok:
				return true  # sin firma válida: no se da por auténtica
	return false


static func _list(c: CommandContext, _a: Dictionary) -> CommandResult:
	var r := CommandResult.new()
	r.line("Piezas · deepfakes y medios auténticos (descritos, no reales)", "accent")
	for m: Dictionary in data()["piezas"]:
		var tag := "⚔ falso · %s" % m["nivel"] if not m["real"] else "✓ auténtico"
		r.line("%s  [%s · %s]  %s" % [m["id"], m["tipo"], tag, m["texto"]], "data")
	r.line("Defensas: medios defensa <capa> on · mide: medios evaluar", "muted")
	c.emit("medios.list", {})
	return r


static func _def(c: CommandContext, a: Dictionary) -> CommandResult:
	if not (data()["defensas"] as Dictionary).has(a["capa"]):
		return CommandResult.error("Capas: " + ", ".join(PackedStringArray((data()["defensas"] as Dictionary).keys())))
	_st(c)[a["capa"]] = a["estado"] == "on"
	var r := CommandResult.new()
	r.line("✓ %s → %s · %s" % [a["capa"], "activada" if a["estado"] == "on" else "desactivada", data()["defensas"][a["capa"]]["desc"]], "ok")
	c.emit("medios.def", {"capa": a["capa"], "enabled": a["estado"] == "on", "active": ",".join(_active(c))})
	return r


static func _eval(c: CommandContext, a: Dictionary) -> CommandResult:
	var active := _active(c)
	var fakes := 0
	var reals := 0
	var caught := 0
	var fp := 0
	var rows: Array = []
	var pass_ids := PackedStringArray()
	for m: Dictionary in data()["piezas"]:
		var fl := flagged(m["rasgos"], active)
		if not m["real"]:
			fakes += 1
			caught += int(fl)
			if not fl:
				pass_ids.append(m["id"])
			rows.append([m["id"], m["tipo"], "⚔ falso", "✓ detectado" if fl else "✗ PASA", m["nivel"]])
		else:
			reals += 1
			fp += int(fl)
			rows.append([m["id"], m["tipo"], "auténtico", "✗ marcado por error" if fl else "✓ pasa bien", m["nivel"]])
	var r := CommandResult.new()
	r.line("Evaluación · defensas: %s" % (", ".join(active) if not active.is_empty() else "ninguna"), "accent")
	r.table(PackedStringArray(["pieza", "tipo", "qué es", "resultado", "nivel"]), rows)
	r.line("Falsos detectados: %d/%d · auténticos marcados por error: %d/%d" % [caught, fakes, fp, reals], "normal")
	if not pass_ids.is_empty():
		r.line("Se cuelan: %s" % ", ".join(pass_ids), "warn")
	c.emit("medios.eval", {"active": ",".join(active), "caught": caught, "fakes": fakes, "fp": fp, "reals": reals, "pass": ",".join(pass_ids),
		"labels": PackedStringArray(["falsos detectados", "auténticos marcados mal"]),
		"values": PackedFloat64Array([float(caught) / maxf(fakes, 1), float(fp) / maxf(reals, 1)])})
	return r
