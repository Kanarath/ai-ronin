class_name WebCommands
extends RefCounted
## A7 · Agentes que usan el navegador y el ordenador (content/browse/web_agent.json). Simulado:
## ningún comando abre una web, descarga nada ni ejecuta código.
##   web show <escenario>                 agente, defensas y su estado
##   web set <escenario> <defensa> on|off activa o desactiva una defensa
##   web run <escenario>                  batería: ataques frenados y tareas legítimas que sobreviven
## Escenarios: navegador (A7-01, inyección indirecta) · ordenador (A7-02, computer use).

const PATH := "res://content/browse/web_agent.json"
const SCENARIOS := ["navegador", "ordenador"]
static var _data: Dictionary = {}


static func register(reg: CommandRegistry) -> void:
	var sc := func() -> CommandSignature: return CommandSignature.new().pos("escenario", "navegador u ordenador", "string", true, SCENARIOS)
	reg.register(Command.new("web show", "Agente web de un escenario: defensas disponibles y cuáles están activas.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _show(c, a), "agentes")
		.with_signature(sc.call().example("web show navegador")))
	reg.register(Command.new("web set", "Activa o desactiva una defensa del agente web.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _set_def(c, a), "agentes")
		.with_signature(sc.call().pos("defensa", "web show la lista").pos("estado", "on u off", "string", true, ["on", "off"]).example("web set navegador aislar_contenido on")))
	reg.register(Command.new("web run", "Lanza la batería del escenario: ataques y tareas legítimas.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _run(c, a), "agentes")
		.with_signature(sc.call().example("web run navegador")))


static func data() -> Dictionary:
	if _data.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = d if d is Dictionary else {}
	return _data


static func _scn(name: String) -> Dictionary:
	return data()["escenarios"].get(name, {})


static func _state(c: CommandContext, scn: String) -> Dictionary:
	if not c.world.web.has(scn):
		c.world.web[scn] = {}
	return c.world.web[scn]


static func _active(c: CommandContext, scn: String) -> PackedStringArray:
	var out := PackedStringArray()
	var st: Dictionary = _state(c, scn)
	for d: String in _scn(scn)["defensas"]:
		if st.get(d, false):
			out.append(d)
	return out


static func _show(c: CommandContext, a: Dictionary) -> CommandResult:
	var s := _scn(a["escenario"])
	if s.is_empty():
		return CommandResult.error("Escenarios: navegador u ordenador")
	var r := CommandResult.new()
	r.line(s["agente"], "accent")
	var st: Dictionary = _state(c, a["escenario"])
	var rows: Array = []
	for d: String in s["defensas"]:
		rows.append(["■" if st.get(d, false) else "·", d, s["defensas"][d]])
	r.table(PackedStringArray(["", "defensa", "qué hace"]), rows)
	r.line("Actívalas con web set %s <defensa> on · mide con web run %s" % [a["escenario"], a["escenario"]], "muted")
	c.emit("web.shown", {"scenario": a["escenario"]})
	return r


static func _set_def(c: CommandContext, a: Dictionary) -> CommandResult:
	var s := _scn(a["escenario"])
	if s.is_empty():
		return CommandResult.error("Escenarios: navegador u ordenador")
	if not (s["defensas"] as Dictionary).has(a["defensa"]):
		return CommandResult.error("Defensas: " + ", ".join(PackedStringArray((s["defensas"] as Dictionary).keys())))
	_state(c, a["escenario"])[a["defensa"]] = a["estado"] == "on"
	var r := CommandResult.new()
	r.line("✓ %s → %s" % [a["defensa"], "activada" if a["estado"] == "on" else "desactivada"], "ok")
	c.emit("web.set", {"scenario": a["escenario"], "defense": a["defensa"], "enabled": a["estado"] == "on", "active": ",".join(_active(c, a["escenario"]))})
	return r


## Resultado de la batería con unas defensas: {"attacks":[{id,ok}], "tasks":[{id,ok}], "attacks_ok", "legit_ok"}
static func battery(scn: String, active: PackedStringArray) -> Dictionary:
	var s := _scn(scn)
	var atk := []
	var n_atk := 0
	for x: Dictionary in s["ataques"]:
		var blocked := false
		for d: String in x["bloquea"]:
			if d in active:
				blocked = true
		atk.append({"id": x["id"], "ok": not blocked})
		n_atk += int(not blocked)
	var tasks := []
	var n_ok := 0
	for t: Dictionary in s["tareas"]:
		var broken := false
		for d: String in t["rompe"]:
			if d in active:
				broken = true
		tasks.append({"id": t["id"], "ok": not broken})
		n_ok += int(not broken)
	return {"attacks": atk, "tasks": tasks, "attacks_ok": n_atk, "legit_ok": n_ok}


static func _run(c: CommandContext, a: Dictionary) -> CommandResult:
	var scn: String = a["escenario"]
	var s := _scn(scn)
	if s.is_empty():
		return CommandResult.error("Escenarios: navegador u ordenador")
	var active := _active(c, scn)
	var res := battery(scn, active)
	var r := CommandResult.new()
	r.line("Batería · %s · defensas: %s" % [scn, ", ".join(active) if not active.is_empty() else "ninguna"], "accent")
	var rows: Array = []
	var i := 0
	for x: Dictionary in s["ataques"]:
		rows.append([x["id"], "✗ FUNCIONA" if res["attacks"][i]["ok"] else "✓ frenado", x["owasp"], x["texto"]])
		i += 1
	r.table(PackedStringArray(["ataque", "resultado", "OWASP", "qué hace"]), rows)
	rows = []
	i = 0
	for t: Dictionary in s["tareas"]:
		rows.append([t["id"], "✓ funciona" if res["tasks"][i]["ok"] else "✗ rota", t["texto"]])
		i += 1
	r.table(PackedStringArray(["tarea", "resultado", "tarea legítima"]), rows)
	r.line("Ataques que funcionan: %d/%d · tareas legítimas que funcionan: %d/%d" % [res["attacks_ok"], s["ataques"].size(), res["legit_ok"], s["tareas"].size()], "normal")
	var open := PackedStringArray()
	for x: Dictionary in res["attacks"]:
		if x["ok"]:
			open.append(x["id"])
	c.emit("web.run", {"scenario": scn, "attacks_ok": res["attacks_ok"], "legit_ok": res["legit_ok"], "active": ",".join(active), "open": ",".join(open)})
	return r
