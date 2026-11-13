class_name MarcoCommands
extends RefCounted
## O7-07 · Un hallazgo, cuatro marcos (content/asi/marcos.json).
##   marco list                         los hallazgos y qué es cada marco
##   marco show <F>                     un hallazgo y su estado de mapeo
##   marco set <F> <marco> <valor>      mapea el hallazgo a un marco (asi, llm, atlas, nist)
##   marco card <F>                     la ficha de cuatro marcos, cuando está completa

const PATH := "res://content/asi/marcos.json"
const MARCOS := ["asi", "llm", "atlas", "nist"]
static var _data: Dictionary = {}


static func register(reg: CommandRegistry) -> void:
	var add := func(path: String, summary: String, handler: Callable, sig: CommandSignature) -> void:
		reg.register(Command.new(path, summary, handler, "seguridad").with_signature(sig))
	add.call("marco list", "Los hallazgos para mapear y qué es cada uno de los cuatro marcos.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _list(c, a), CommandSignature.new())
	add.call("marco show", "Un hallazgo y cómo lo has mapeado hasta ahora.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _show(c, a),
		CommandSignature.new().pos("hallazgo", "F1 … F3").example("marco show F1"))
	add.call("marco set", "Mapea un hallazgo a un marco.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _set_m(c, a),
		CommandSignature.new().pos("hallazgo", "F1 … F3").pos("marco", "asi, llm, atlas o nist", "string", true, MARCOS).pos("valor", "el valor en ese marco (puede llevar espacios)", "rest").example("marco set F1 atlas Initial Access"))
	add.call("marco card", "La ficha de cuatro marcos de un hallazgo, una vez mapeado del todo.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _card(c, a),
		CommandSignature.new().pos("hallazgo", "F1 … F3").example("marco card F1"))


static func data() -> Dictionary:
	if _data.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = d if d is Dictionary else {}
	return _data


static func _find(id: String) -> Dictionary:
	for x: Dictionary in data()["hallazgos"]:
		if x["id"] == id.strip_edges().to_upper():
			return x
	return {}


static func _norm(marco: String, v: String) -> String:
	var t := v.strip_edges()
	if marco == "asi":
		t = t.to_upper()
		if t.begins_with("ASI") and t.length() == 4:
			t = "ASI0" + t.substr(3)
	elif marco == "llm":
		t = t.to_upper()
		if t.begins_with("LLM") and t.length() == 4:
			t = "LLM0" + t.substr(3)
	elif marco == "nist":
		t = t.to_upper()
	else:
		t = t.capitalize()
	return t


static func _state(c: CommandContext, fid: String) -> Dictionary:
	if not c.world.web.has("marco_" + fid):
		c.world.web["marco_" + fid] = {}
	return c.world.web["marco_" + fid]


static func _list(c: CommandContext, _a: Dictionary) -> CommandResult:
	var r := CommandResult.new()
	r.line("Un hallazgo, cuatro marcos · cada marco habla a un público distinto", "accent")
	for m: String in MARCOS:
		r.line("  %s — %s" % [m.to_upper(), data()["que_son"][m]], "muted")
	r.line("Hallazgos:", "normal")
	for x: Dictionary in data()["hallazgos"]:
		r.line("  %s · %s" % [x["id"], x["texto"]], "data")
	r.line("Mapea con marco set <F> <marco> <valor> · pistas de valores: ATLAS %s · NIST %s" % [", ".join(PackedStringArray(data()["catalogos"]["atlas"])), ", ".join(PackedStringArray(data()["catalogos"]["nist"]))], "muted")
	c.emit("marco.listed", {})
	return r


static func _show(c: CommandContext, a: Dictionary) -> CommandResult:
	var x := _find(a["hallazgo"])
	if x.is_empty():
		return CommandResult.error("Hallazgos: F1 … F3 (marco list)")
	var st := _state(c, x["id"])
	var r := CommandResult.new()
	r.line("%s · %s" % [x["id"], x["texto"]], "accent")
	var rows: Array = []
	for m: String in MARCOS:
		rows.append([m.to_upper(), str(st.get(m, "·"))])
	r.table(PackedStringArray(["marco", "tu mapeo"]), rows)
	c.emit("marco.shown", {"finding": x["id"]})
	return r


static func _set_m(c: CommandContext, a: Dictionary) -> CommandResult:
	var x := _find(a["hallazgo"])
	if x.is_empty():
		return CommandResult.error("Hallazgos: F1 … F3 (marco list)")
	if not a["marco"] in MARCOS:
		return CommandResult.error("Marcos: asi, llm, atlas, nist")
	var val := _norm(a["marco"], a["valor"])
	var ok: bool = val == _norm(a["marco"], x[a["marco"]])
	var st := _state(c, x["id"])
	var r := CommandResult.new()
	if ok:
		st[a["marco"]] = val
		r.line("✓ %s · %s = %s · %s" % [x["id"], a["marco"].to_upper(), val, x["por_que"][a["marco"]]], "ok")
	else:
		r.line("✗ %s · %s = %s no cuadra. %s" % [x["id"], a["marco"].to_upper(), val, data()["que_son"][a["marco"]]], "warn")
	var done := 0
	for m: String in MARCOS:
		if st.has(m):
			done += 1
	r.line("%s mapeado en %d/4 marcos" % [x["id"], done], "muted")
	c.emit("marco.set", {"finding": x["id"], "marco": a["marco"], "correct": ok, "mapped": done})
	return r


static func _card(c: CommandContext, a: Dictionary) -> CommandResult:
	var x := _find(a["hallazgo"])
	if x.is_empty():
		return CommandResult.error("Hallazgos: F1 … F3 (marco list)")
	var st := _state(c, x["id"])
	var r := CommandResult.new()
	if st.size() < 4:
		r.line("%s aún no está mapeado en los cuatro marcos (%d/4). Completa con marco set." % [x["id"], st.size()], "warn")
		c.emit("marco.card", {"finding": x["id"], "complete": false})
		return r
	r.line("Ficha de %s · %s" % [x["id"], x["texto"]], "accent")
	r.table(PackedStringArray(["marco", "valor", "por qué"]), [
		["ASI (agente)", x["asi"], x["por_que"]["asi"]],
		["LLM Top 10", x["llm"], x["por_que"]["llm"]],
		["ATLAS (táctica)", x["atlas"], x["por_que"]["atlas"]],
		["NIST AI RMF", x["nist"], x["por_que"]["nist"]],
	])
	r.line("El mismo hallazgo, cuatro idiomas: ingeniería, aplicación, inteligencia de amenazas y gobernanza.", "muted")
	c.emit("marco.card", {"finding": x["id"], "complete": true})
	return r
