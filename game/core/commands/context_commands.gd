class_name ContextCommands
extends RefCounted
## A3-05 · Ingeniería de contexto: un agente con ventana de contexto limitada (presupuesto de
## tokens). El reto es que quepa lo que hace falta para responder, sin pasarse. Simulado.
##   context show                     presupuesto, piezas, tokens y si puede responder
##   context set <tecnica> on|off     skills, compactar, recordar, recuperar
##   context build                    arma el contexto y dice si cabe y si puede responder

const BUDGET := 1000
## Coste en tokens de cada pieza según la técnica (on/off).
const COST := {
	"sistema": 120,
	"herramientas_todas": 400, "herramientas_skills": 80,
	"historial_completo": 720, "historial_compactado": 100,
	"memoria": 20, "documento": 200,
}
const TECNICAS := {
	"skills": "Cargar la ficha de una herramienta solo cuando se usa (just-in-time), en vez de todas (400 → 80 tokens)",
	"compactar": "Resumir el historial largo en pocas líneas (720 → 100 tokens)",
	"recordar": "Escribir el dato clave (el id del pedido, dicho en el turno 3) en la memoria a largo plazo antes de compactar (+20 tokens)",
	"recuperar": "Traer al contexto solo el documento relevante de la política (RAG) (+200 tokens)",
}


static func register(reg: CommandRegistry) -> void:
	var add := func(path: String, summary: String, handler: Callable, sig: CommandSignature) -> void:
		reg.register(Command.new(path, summary, handler, "agentes").with_signature(sig))
	add.call("context show", "El contexto del agente: presupuesto, piezas, tokens y si puede responder.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _show(c, a), CommandSignature.new())
	add.call("context set", "Activa o desactiva una técnica de ingeniería de contexto.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _set_t(c, a),
		CommandSignature.new().pos("tecnica", "skills, compactar, recordar o recuperar", "string", true, Array(TECNICAS.keys())).pos("estado", "on u off", "string", true, ["on", "off"]).example("context set skills on"))
	add.call("context build", "Arma el contexto con las técnicas activas: ¿cabe en la ventana? ¿puede responder?",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _build(c, a), CommandSignature.new())


static func _st(c: CommandContext) -> Dictionary:
	if c.world.ctx.is_empty():
		c.world.ctx = {"skills": false, "compactar": false, "recordar": false, "recuperar": false}
	return c.world.ctx


## Desglose del contexto: lista de {pieza, tokens} y qué datos clave están presentes.
static func assemble(st: Dictionary) -> Dictionary:
	var parts: Array = []
	parts.append({"pieza": "mensaje de sistema", "tokens": COST["sistema"]})
	parts.append({"pieza": "herramientas (skills)" if st["skills"] else "herramientas (todas)", "tokens": COST["herramientas_skills"] if st["skills"] else COST["herramientas_todas"]})
	parts.append({"pieza": "historial (compactado)" if st["compactar"] else "historial (completo)", "tokens": COST["historial_compactado"] if st["compactar"] else COST["historial_completo"]})
	if st["recordar"]:
		parts.append({"pieza": "memoria: id del pedido", "tokens": COST["memoria"]})
	if st["recuperar"]:
		parts.append({"pieza": "documento de política (RAG)", "tokens": COST["documento"]})
	var total := 0
	for p: Dictionary in parts:
		total += int(p["tokens"])
	# El id del pedido (turno 3) sobrevive si el historial va completo o si se guardó en memoria.
	var id_ok: bool = (not st["compactar"]) or st["recordar"]
	var pol_ok: bool = st["recuperar"]
	var fits: bool = total <= BUDGET
	# Si no cabe, se trunca lo más antiguo: se pierde el id del pedido del turno 3.
	if not fits:
		id_ok = false
	return {"parts": parts, "total": total, "fits": fits, "id_ok": id_ok, "pol_ok": pol_ok, "answer": fits and id_ok and pol_ok}


static func _show(c: CommandContext, _a: Dictionary) -> CommandResult:
	var st := _st(c)
	var r := CommandResult.new()
	r.line("Agente de atención · caso largo · ventana de contexto: %d tokens" % BUDGET, "accent")
	r.line("Para responder necesita DOS datos: el id del pedido (lo dijo el cliente en el turno 3) y la política de devoluciones (en un documento).", "normal")
	var rows: Array = []
	for t: String in TECNICAS:
		rows.append(["■" if st[t] else "·", t, TECNICAS[t]])
	r.table(PackedStringArray(["", "técnica", "qué hace"]), rows)
	r.line("Actívalas con context set <técnica> on · arma el contexto: context build", "muted")
	c.emit("context.shown", {})
	return r


static func _set_t(c: CommandContext, a: Dictionary) -> CommandResult:
	if not TECNICAS.has(a["tecnica"]):
		return CommandResult.error("Técnicas: " + ", ".join(PackedStringArray(TECNICAS.keys())))
	_st(c)[a["tecnica"]] = a["estado"] == "on"
	var r := CommandResult.new()
	r.line("✓ %s → %s" % [a["tecnica"], "activada" if a["estado"] == "on" else "desactivada"], "ok")
	c.emit("context.set", {"tecnica": a["tecnica"], "enabled": a["estado"] == "on"})
	return r


static func _build(c: CommandContext, _a: Dictionary) -> CommandResult:
	var st := _st(c)
	var res := assemble(st)
	var r := CommandResult.new()
	r.line("Contexto armado · %d / %d tokens %s" % [res["total"], BUDGET, "✓ cabe" if res["fits"] else "✗ SE PASA (se trunca lo más antiguo)"], "accent" if res["fits"] else "warn")
	var rows: Array = []
	for p: Dictionary in res["parts"]:
		rows.append([p["pieza"], str(p["tokens"]), "█".repeat(int(round(float(p["tokens"]) / BUDGET * 40)))])
	r.table(PackedStringArray(["pieza", "tokens", ""]), rows)
	r.line("Dato «id del pedido»: %s · dato «política»: %s" % ["✓ presente" if res["id_ok"] else "✗ perdido", "✓ presente" if res["pol_ok"] else "✗ falta"], "normal")
	if res["answer"]:
		r.line("✓ El agente puede responder: tiene los dos datos y cabe en la ventana.", "ok")
	elif not res["fits"]:
		r.line("✗ No cabe: la ventana se llena y se trunca el principio (donde estaba el id del pedido).", "warn")
	elif not res["pol_ok"]:
		r.line("✗ Cabe, pero falta la política: hay que recuperar el documento (context set recuperar on).", "warn")
	elif not res["id_ok"]:
		r.line("✗ Cabe, pero el id del pedido se perdió al compactar: había que guardarlo en memoria (context set recordar on).", "warn")
	c.emit("context.build", {"total": res["total"], "fits": res["fits"], "id_ok": res["id_ok"], "pol_ok": res["pol_ok"], "answer": res["answer"],
		"labels": _labels(res), "values": _values(res)})
	return r


static func _labels(res: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for p: Dictionary in res["parts"]:
		out.append(p["pieza"])
	return out


static func _values(res: Dictionary) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for p: Dictionary in res["parts"]:
		out.append(float(p["tokens"]) / BUDGET)
	return out
