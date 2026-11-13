class_name AsiLabCommands
extends RefCounted
## O7-03 a O7-05 · Laboratorios del OWASP agéntico (content/asi/laboratorios.json). Simulado:
## ningún comando ejecuta código ni toca la red; solo calcula qué pasaría.
##   sandbox show | set <defensa> on|off | run      caja de arena del agente analista (ASI05, LLM05)
##   approvals mode <explicacion|verificable> | list | decide <R> si|no | result     (ASI09)
##   chain show | label <paso> <ASIxx> | defend <defensa> on|off | run              ataque en cadena

const PATH := "res://content/asi/laboratorios.json"
const ENTRIES := ["mcp", "web"]
static var _data: Dictionary = {}


static func register(reg: CommandRegistry) -> void:
	var add := func(path: String, summary: String, handler: Callable, sig: CommandSignature) -> void:
		reg.register(Command.new(path, summary, handler, "seguridad").with_signature(sig))
	add.call("sandbox show", "Caja de arena del agente analista: defensas disponibles y cuáles están activas.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _sb_show(c, a), CommandSignature.new())
	add.call("sandbox set", "Activa o desactiva una defensa de la caja de arena.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _sb_set(c, a),
		CommandSignature.new().pos("defensa", "sandbox show las lista").pos("estado", "on u off", "string", true, ["on", "off"]).example("sandbox set sin_shell on"))
	add.call("sandbox run", "Lanza la batería: 7 ataques y 4 tareas legítimas contra el agente analista.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _sb_run(c, a), CommandSignature.new())
	add.call("approvals mode", "Qué ve la persona que aprueba: la explicación del agente o el cambio que genera el sistema.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _ap_mode(c, a),
		CommandSignature.new().pos("modo", "explicacion o verificable", "string", true, ["explicacion", "verificable"]).example("approvals mode verificable"))
	add.call("approvals list", "La cola de aprobaciones del agente, tal como la ve quien aprueba.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _ap_list(c, a), CommandSignature.new())
	add.call("approvals decide", "Aprueba o rechaza una petición.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _ap_decide(c, a),
		CommandSignature.new().pos("peticion", "R1 … R8").pos("decision", "si o no", "string", true, ["si", "sí", "no"]).example("approvals decide R1 si"))
	add.call("approvals result", "Qué has aprobado de verdad: dañinas aprobadas y legítimas rechazadas.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _ap_result(c, a), CommandSignature.new())
	add.call("chain show", "El incidente en cadena paso a paso, con sus dos entradas posibles.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _ch_show(c, a), CommandSignature.new())
	add.call("chain label", "Pon a un paso de la cadena su riesgo ASI.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _ch_label(c, a),
		CommandSignature.new().pos("paso", "S1 … S6").pos("riesgo", "ASI01 … ASI10").example("chain label S1 ASI04"))
	add.call("chain defend", "Activa o desactiva una defensa (D1 … D9) contra la cadena.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _ch_defend(c, a),
		CommandSignature.new().pos("defensa", "D1 … D9 (asi defenses)").pos("estado", "on u off", "string", true, ["on", "off"]).example("chain defend D2 on"))
	add.call("chain run", "Repite el ataque por las dos entradas con tus defensas: qué pasos ocurren y si salen datos.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _ch_run(c, a), CommandSignature.new())


static func data() -> Dictionary:
	if _data.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = d if d is Dictionary else {}
	return _data


# ── Caja de arena ────────────────────────────────────────────────────────────

static func _active(c: CommandContext) -> PackedStringArray:
	var out := PackedStringArray()
	for d: String in data()["sandbox"]["defensas"]:
		if c.world.asi["sandbox"].get(d, false):
			out.append(d)
	return out


static func _sb_show(c: CommandContext, _a: Dictionary) -> CommandResult:
	var r := CommandResult.new()
	r.line(data()["sandbox"]["agente"], "accent")
	var rows: Array = []
	for d: String in data()["sandbox"]["defensas"]:
		rows.append(["■" if c.world.asi["sandbox"].get(d, false) else "·", d, data()["sandbox"]["defensas"][d]])
	r.table(PackedStringArray(["", "defensa", "qué hace"]), rows)
	r.line("Actívalas con sandbox set <defensa> on · mide con sandbox run", "muted")
	c.emit("sandbox.shown", {})
	return r


static func _sb_set(c: CommandContext, a: Dictionary) -> CommandResult:
	var defs: Dictionary = data()["sandbox"]["defensas"]
	if not defs.has(a["defensa"]):
		return CommandResult.error("Defensas: " + ", ".join(PackedStringArray(defs.keys())))
	c.world.asi["sandbox"][a["defensa"]] = a["estado"] == "on"
	var r := CommandResult.new()
	r.line("✓ %s → %s" % [a["defensa"], "activada" if a["estado"] == "on" else "desactivada"], "ok")
	c.emit("sandbox.set", {"defense": a["defensa"], "enabled": a["estado"] == "on", "active": ",".join(_active(c))})
	return r


## Resultado de la batería con unas defensas: {"attacks": [{id, ok}], "tasks": [{id, ok}], "attacks_ok", "legit_ok"}
static func battery(active: PackedStringArray) -> Dictionary:
	var atk := []
	var n_atk := 0
	for x: Dictionary in data()["sandbox"]["ataques"]:
		var blocked := false
		for d: String in x["bloquea"]:
			if d in active:
				blocked = true
		atk.append({"id": x["id"], "ok": not blocked})
		n_atk += int(not blocked)
	var tasks := []
	var n_ok := 0
	for t: Dictionary in data()["sandbox"]["tareas"]:
		var broken := false
		for d: String in t["rompe"]:
			if d in active:
				broken = true
		tasks.append({"id": t["id"], "ok": not broken})
		n_ok += int(not broken)
	return {"attacks": atk, "tasks": tasks, "attacks_ok": n_atk, "legit_ok": n_ok}


static func _sb_run(c: CommandContext, _a: Dictionary) -> CommandResult:
	var active := _active(c)
	var res := battery(active)
	var r := CommandResult.new()
	r.line("Batería del agente analista · defensas: %s" % (", ".join(active) if not active.is_empty() else "ninguna"), "accent")
	var rows: Array = []
	var i := 0
	for x: Dictionary in data()["sandbox"]["ataques"]:
		var ok: bool = res["attacks"][i]["ok"]
		rows.append([x["id"], "✗ FUNCIONA" if ok else "✓ frenado", x["owasp"], x["texto"]])
		i += 1
	r.table(PackedStringArray(["ataque", "resultado", "OWASP", "qué hace"]), rows)
	rows = []
	i = 0
	for t: Dictionary in data()["sandbox"]["tareas"]:
		var ok: bool = res["tasks"][i]["ok"]
		rows.append([t["id"], "✓ funciona" if ok else "✗ rota", t["texto"]])
		i += 1
	r.table(PackedStringArray(["tarea", "resultado", "tarea legítima"]), rows)
	r.line("Ataques que funcionan: %d/7 · tareas legítimas que funcionan: %d/4" % [res["attacks_ok"], res["legit_ok"]], "normal")
	if c.world.asi["sandbox"].get("prompt_prudente", false) and res["attacks_ok"] == 7:
		r.line("El prompt prudente no ha frenado nada: las órdenes vienen en los DATOS y el código se ejecuta igual.", "warn")
	var open := PackedStringArray()
	for x: Dictionary in res["attacks"]:
		if x["ok"]:
			open.append(x["id"])
	c.emit("sandbox.run", {"attacks_ok": res["attacks_ok"], "legit_ok": res["legit_ok"], "active": ",".join(active), "open": ",".join(open)})
	return r


# ── Aprobaciones ─────────────────────────────────────────────────────────────

static func _req(id: String) -> Dictionary:
	for x: Dictionary in data()["aprobaciones"]["peticiones"]:
		if x["id"] == id.strip_edges().to_upper():
			return x
	return {}


static func _ap_mode(c: CommandContext, a: Dictionary) -> CommandResult:
	c.world.asi["mode"] = a["modo"]
	c.world.asi["decisions"] = {}
	var r := CommandResult.new()
	if a["modo"] == "verificable":
		r.line("✓ Modo verificable: quien aprueba ve el cambio exacto, generado por el sistema a partir de la llamada a la herramienta, no por el agente.", "ok")
	else:
		r.line("✓ Modo explicación: quien aprueba solo ve lo que el agente escribe para justificar la petición.", "ok")
	r.line("Decisiones anteriores borradas. Mira la cola: approvals list", "muted")
	c.emit("approvals.mode", {"mode": a["modo"]})
	return r


static func _ap_list(c: CommandContext, _a: Dictionary) -> CommandResult:
	var mode: String = c.world.asi["mode"]
	var r := CommandResult.new()
	r.line("Cola de aprobaciones del agente · modo %s · decide con approvals decide <R> si|no" % mode, "accent")
	for x: Dictionary in data()["aprobaciones"]["peticiones"]:
		var d: String = c.world.asi["decisions"].get(x["id"], "·")
		r.line("%s [%s] 🤖 «%s»" % [x["id"], d, x["explicacion"]], "data")
		if mode == "verificable":
			r.line("        ⚙ cambio real: " + x["cambio"], "normal")
	c.emit("approvals.listed", {"mode": mode})
	return r


static func _ap_decide(c: CommandContext, a: Dictionary) -> CommandResult:
	var x := _req(a["peticion"])
	if x.is_empty():
		return CommandResult.error("Peticiones: R1 … R8 (approvals list)")
	var yes: bool = a["decision"] != "no"
	c.world.asi["decisions"][x["id"]] = "si" if yes else "no"
	var r := CommandResult.new()
	r.line("%s %s · decididas %d/8" % ["✓ Aprobada" if yes else "✗ Rechazada", x["id"], c.world.asi["decisions"].size()], "ok")
	c.emit("approvals.decided", {"request": x["id"], "approved": yes, "decided": c.world.asi["decisions"].size()})
	return r


static func score(decisions: Dictionary) -> Dictionary:
	var bad := 0
	var good_no := 0
	for x: Dictionary in data()["aprobaciones"]["peticiones"]:
		var d: String = decisions.get(x["id"], "")
		if x["danina"] and d == "si":
			bad += 1
		if not x["danina"] and d == "no":
			good_no += 1
	return {"bad_approved": bad, "good_rejected": good_no}


static func _ap_result(c: CommandContext, _a: Dictionary) -> CommandResult:
	var dec: Dictionary = c.world.asi["decisions"]
	var mode: String = c.world.asi["mode"]
	var r := CommandResult.new()
	if dec.size() < 8:
		r.line("Faltan %d peticiones por decidir (approvals list)." % (8 - dec.size()), "warn")
		c.emit("approvals.result", {"mode": mode, "decided": dec.size(), "bad_approved": -1, "good_rejected": -1})
		return r
	var s := score(dec)
	r.line("Resultado en modo %s" % mode, "accent")
	var rows: Array = []
	for x: Dictionary in data()["aprobaciones"]["peticiones"]:
		var d: String = dec[x["id"]]
		var verdict := "bien"
		if x["danina"] and d == "si":
			verdict = "✗ DAÑINA APROBADA"
		elif not x["danina"] and d == "no":
			verdict = "✗ legítima rechazada"
		rows.append([x["id"], d, verdict, x["cambio"]])
	r.table(PackedStringArray(["petición", "tú", "", "lo que hacía de verdad"]), rows)
	r.line("Dañinas aprobadas: %d/4 · legítimas rechazadas: %d/4" % [s["bad_approved"], s["good_rejected"]], "normal")
	if mode == "explicacion":
		r.line("Solo con la explicación del agente, o apruebas a ciegas o lo rechazas todo y el agente deja de servir.", "warn")
	c.emit("approvals.result", {"mode": mode, "decided": dec.size(), "bad_approved": s["bad_approved"], "good_rejected": s["good_rejected"]})
	return r


# ── Ataque en cadena ─────────────────────────────────────────────────────────

static func _step(id: String) -> Dictionary:
	for x: Dictionary in data()["cadena"]["pasos"]:
		if x["id"] == id.strip_edges().to_upper():
			return x
	return {}


static func _ch_show(c: CommandContext, _a: Dictionary) -> CommandResult:
	var r := CommandResult.new()
	r.line("Incidente en cadena · dos entradas posibles (mcp y web) · etiqueta cada paso: chain label <paso> <ASIxx>", "accent")
	for x: Dictionary in data()["cadena"]["pasos"]:
		var lab: String = c.world.asi["labels"].get(x["id"], "·")
		r.line("%s [%s] %s%s" % [x["id"], lab, x["texto"], "  💧 salen datos" if x.get("fuga", false) else ""], "data")
	c.emit("chain.shown", {})
	return r


static func _ch_label(c: CommandContext, a: Dictionary) -> CommandResult:
	var x := _step(a["paso"])
	if x.is_empty():
		return CommandResult.error("Pasos: S1 … S6 (chain show)")
	var risk := String(a["riesgo"]).strip_edges().to_upper()
	if risk.length() == 4:
		risk = "ASI0" + risk.substr(3)
	var ok: bool = risk == x["riesgo"]
	var r := CommandResult.new()
	if ok:
		c.world.asi["labels"][x["id"]] = risk
		var llm: String = x.get("llm", "")
		r.line("✓ %s → %s%s" % [x["id"], risk, (" · en el Top 10 de LLM se parece a " + llm) if not llm.is_empty() else " · sin equivalente directo en el Top 10 de LLM"], "ok")
	else:
		r.line("✗ %s no es %s. ¿Qué falla justo en este paso, no en el anterior?" % [x["id"], risk], "warn")
	var n := 0
	for s: Dictionary in data()["cadena"]["pasos"]:
		if c.world.asi["labels"].get(s["id"], "") == s["riesgo"]:
			n += 1
	r.line("Pasos etiquetados bien: %d/6" % n, "muted")
	c.emit("chain.labeled", {"step": x["id"], "risk": risk, "correct": ok, "correct_count": n})
	return r


static func _ch_defend(c: CommandContext, a: Dictionary) -> CommandResult:
	var id := String(a["defensa"]).strip_edges().to_upper()
	if not id in ["D1", "D2", "D3", "D4", "D5", "D6", "D7", "D8", "D9"]:
		return CommandResult.error("Defensas: D1 … D9 (asi defenses)")
	c.world.asi["chain_def"][id] = a["estado"] == "on"
	var r := CommandResult.new()
	r.line("✓ %s %s" % [id, "activada" if a["estado"] == "on" else "desactivada"], "ok")
	c.emit("chain.defend", {"defense": id, "enabled": a["estado"] == "on"})
	return r


## Qué pasos ocurren por cada entrada con unas defensas activas.
static func simulate(active: Array) -> Dictionary:
	var out := {}
	var cut: Dictionary = data()["cadena"]["corta"]
	for e: String in ENTRIES:
		var happened := {}
		for s: Dictionary in data()["cadena"]["pasos"]:
			var ok := true
			for dep: String in s["depende"]:
				if not happened.get(dep, false):
					ok = false
			for d: String in active:
				if cut.has(d) and (cut[d] as Dictionary).has(s["id"]) and e in cut[d][s["id"]]:
					ok = false
			happened[s["id"]] = ok
		var leak := false
		var n := 0
		for s: Dictionary in data()["cadena"]["pasos"]:
			if happened[s["id"]]:
				n += 1
				if s.get("fuga", false):
					leak = true
		out[e] = {"steps": happened, "count": n, "leak": leak}
	return out


static func _ch_run(c: CommandContext, _a: Dictionary) -> CommandResult:
	var active: Array = []
	for d: String in c.world.asi["chain_def"]:
		if c.world.asi["chain_def"][d]:
			active.append(d)
	active.sort()
	var sim := simulate(active)
	var r := CommandResult.new()
	r.line("El ataque en cadena por las dos entradas · defensas: %s" % (", ".join(PackedStringArray(active)) if not active.is_empty() else "ninguna"), "accent")
	var rows: Array = []
	for s: Dictionary in data()["cadena"]["pasos"]:
		rows.append([s["id"], s["riesgo"] if c.world.asi["labels"].has(s["id"]) else "?", "✗ ocurre" if sim["mcp"]["steps"][s["id"]] else "✓ cortado", "✗ ocurre" if sim["web"]["steps"][s["id"]] else "✓ cortado"])
	r.table(PackedStringArray(["paso", "riesgo", "entrada mcp", "entrada web"]), rows)
	var leak: bool = sim["mcp"]["leak"] or sim["web"]["leak"]
	r.line("¿Salen datos? mcp: %s · web: %s · pasos que ocurren: %d + %d" % ["SÍ" if sim["mcp"]["leak"] else "no", "SÍ" if sim["web"]["leak"] else "no", sim["mcp"]["count"], sim["web"]["count"]], "warn" if leak else "ok")
	for d: String in active:
		if data()["cadena"]["notas"].has(d):
			r.line("  · " + data()["cadena"]["notas"][d], "muted")
	c.emit("chain.run", {"defenses": ",".join(PackedStringArray(active)), "n_defenses": active.size(), "leak": leak, "steps": int(sim["mcp"]["count"]) + int(sim["web"]["count"])})
	return r
