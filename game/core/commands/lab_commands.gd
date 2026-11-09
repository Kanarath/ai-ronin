class_name LabCommands
extends RefCounted
## C1–C3 · Laboratorios integradores: matriz de defensas y resiliencia sobre los sistemas
## simulados de A2 (RAG), A3 (agente) y A4 (host MCP). No hay ataques nuevos: se reutilizan
## sus baterías y sus tareas legítimas para MEDIR cada defensa y cada combinación.

const KINDS: Array[String] = ["rag", "agent", "mcp"]
const CREATE_HINT := {"rag": "rag create <nombre> · rag ingest <nombre>", "agent": "agent create <nombre>", "mcp": "mcp host <nombre>"}


static func register(reg: CommandRegistry) -> void:
	reg.register(Command.new("lab matrix", "Matriz de defensas: qué ataques bloquea cada defensa por sí sola y qué cuesta en las tareas legítimas.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _matrix(c, a), "laboratorio")
		.with_signature(CommandSignature.new()
			.pos("tipo", "rag, agent o mcp", "string", true, Array(KINDS))
			.pos("sistema", "nombre del sistema")
			.example("lab matrix agent kage")))
	reg.register(Command.new("lab resilience", "Con las defensas activas: qué ataques siguen pasando y cuáles dependen de UNA sola defensa.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _resilience(c, a), "laboratorio")
		.with_signature(CommandSignature.new()
			.pos("tipo", "rag, agent o mcp", "string", true, Array(KINDS))
			.pos("sistema", "nombre del sistema")
			.example("lab resilience rag biblio")))


static func defenses_of(kind: String) -> Array[String]:
	match kind:
		"rag": return RagSystem.DEFENSES
		"agent": return MockAgent.DEFENSES
		_: return MockMcpHost.DEFENSES


static func _lookup(c: CommandContext, kind: String, p_name: String) -> Variant:
	var store: Dictionary
	match kind:
		"rag": store = c.world.rags
		"agent": store = c.world.agents
		_: store = c.world.mcps
	return store.get(p_name)


static func active(kind: String, obj: Variant) -> Array[String]:
	var on: Array[String] = []
	for d in defenses_of(kind):
		if obj.defenses[d]:
			on.append(d)
	return on


## Copia del sistema con exactamente las defensas de `on` activadas.
static func configured(kind: String, obj: Variant, on: Array) -> Variant:
	var copy: Variant
	match kind:
		"rag": copy = obj.duplicate_system()
		_: copy = obj.clone_fresh()
	for d in defenses_of(kind):
		copy.defenses[d] = d in on
	if kind == "rag":
		copy.ingest(obj.chunk_size, obj.overlap)
	return copy


## Mide un sistema: {"ids", "categories", "broken": ids con éxito, "passed", "total", "approvals"}.
static func measure(kind: String, obj: Variant) -> Dictionary:
	var rows: Array
	var ev: Dictionary
	match kind:
		"rag":
			rows = RagCommands.run_suite(obj)
			ev = RagCommands.run_eval(obj)
		"agent":
			rows = AgentCommands.run_suite(obj)
			ev = AgentCommands.run_eval(obj)
		_:
			rows = McpCommands.run_suite(obj)
			ev = McpCommands.run_eval(obj)
	var ids := PackedStringArray()
	var cats := PackedStringArray()
	var broken := PackedStringArray()
	for row: Array in rows:
		ids.append(row[0])
		cats.append(row[1])
		if row[2]:
			broken.append(row[0])
	return {"ids": ids, "categories": cats, "broken": broken, "passed": ev["passed"], "total": ev["total"], "approvals": ev["approvals"]}


## Matriz: por cada defensa activada en solitario, qué ataques de la línea base bloquea y qué cuesta.
static func matrix(kind: String, obj: Variant) -> Dictionary:
	var base := measure(kind, configured(kind, obj, []))
	var cols: Dictionary = {}
	for d in defenses_of(kind):
		var m := measure(kind, configured(kind, obj, [d]))
		var blocks := PackedStringArray()
		for id in base["broken"]:
			if not id in m["broken"]:
				blocks.append(id)
		cols[d] = {"blocks": blocks, "passed": m["passed"], "total": m["total"], "approvals": m["approvals"]}
	var single := PackedStringArray()
	var none := PackedStringArray()
	var count := {}
	for id in base["broken"]:
		var n := 0
		for d: String in cols:
			if id in cols[d]["blocks"]:
				n += 1
		count[id] = n
		if n == 1:
			single.append(id)
		elif n == 0:
			none.append(id)
	var costly := PackedStringArray()
	for d: String in cols:
		if cols[d]["passed"] < base["passed"] or cols[d]["approvals"] > base["approvals"]:
			costly.append(d)
	return {"base": base, "cols": cols, "count": count, "single": single, "none": none, "costly": costly}


## Resiliencia de la configuración actual: un ataque es «frágil» si lo bloquea la
## configuración pero vuelve a pasar al quitar UNA de las defensas activas.
static func resilience(kind: String, obj: Variant) -> Dictionary:
	var on := active(kind, obj)
	var now := measure(kind, configured(kind, obj, on))
	var depends: Dictionary = {}
	for d in on:
		var rest: Array = on.duplicate()
		rest.erase(d)
		var m := measure(kind, configured(kind, obj, rest))
		for id in m["broken"]:
			if not id in now["broken"]:
				if not depends.has(id):
					depends[id] = PackedStringArray()
				depends[id].append(d)
	var fragile := PackedStringArray()
	for id in now["ids"]:
		if depends.has(id):
			fragile.append(id)
	var robust: int = now["ids"].size() - now["broken"].size() - fragile.size()
	return {"on": on, "now": now, "depends": depends, "fragile": fragile, "robust": robust}


static func _fetch(c: CommandContext, a: Dictionary) -> Array:
	var obj: Variant = _lookup(c, a["tipo"], a["sistema"])
	if obj == null:
		return [null, "No existe ese %s. Créalo con: %s" % [SimWorld.KIND_NAMES[a["tipo"]], CREATE_HINT[a["tipo"]]]]
	if a["tipo"] == "rag" and obj.chunks.is_empty():
		return [null, "El índice está vacío. Ejecuta primero: rag ingest %s" % a["sistema"]]
	return [obj, ""]


static func _matrix(c: CommandContext, a: Dictionary) -> CommandResult:
	var got := _fetch(c, a)
	if got[0] == null:
		return CommandResult.error(got[1])
	var kind: String = a["tipo"]
	var mx := matrix(kind, got[0])
	var base: Dictionary = mx["base"]
	var defs := defenses_of(kind)
	var r := CommandResult.new()
	r.line("Matriz de defensas de %s · cada columna es UNA defensa activada en solitario" % a["sistema"], "accent")
	r.line("Línea base sin defensas: %d / %d ataques con éxito." % [base["broken"].size(), base["ids"].size()], "muted")
	var head := PackedStringArray(["ataque", "ninguna"])
	for d in defs:
		head.append(d)
	head.append("la bloquean")
	var data: Array = []
	for id: String in base["broken"]:
		var row: Array = [id, "✗"]
		for d in defs:
			row.append("■" if id in mx["cols"][d]["blocks"] else "·")
		row.append(str(mx["count"][id]))
		data.append(row)
	var tasks: Array = ["tareas ok", "%d/%d" % [base["passed"], base["total"]]]
	var asks: Array = ["aprobaciones", str(base["approvals"])]
	for d in defs:
		var col: Dictionary = mx["cols"][d]
		tasks.append("%d/%d" % [col["passed"], col["total"]])
		asks.append(str(col["approvals"]))
	tasks.append("")
	asks.append("")
	data.append(tasks)
	data.append(asks)
	r.table(head, data)
	if not mx["none"].is_empty():
		r.line("Ninguna defensa sola bloquea: %s (hace falta combinarlas)." % ", ".join(mx["none"]), "warn")
	if not mx["single"].is_empty():
		r.line("Solo una defensa bloquea: %s." % ", ".join(mx["single"]), "warn")
	if not mx["costly"].is_empty():
		r.line("Empeoran las tareas legítimas respecto a la línea base (más fallos o aprobaciones): %s." % ", ".join(mx["costly"]), "muted")
	r.line("La matriz mide defensas en solitario; las combinaciones se miden con lab resilience.", "muted")
	var blocks := {}
	for d in defs:
		blocks[d] = Array(mx["cols"][d]["blocks"])
	c.emit("lab.matrix", {"kind": kind, "system": a["sistema"], "baseline": base["broken"].size(), "total": base["ids"].size(),
		"single": ",".join(mx["single"]), "single_count": mx["single"].size(), "none": ",".join(mx["none"]), "costly": ",".join(mx["costly"]), "blocks": blocks})
	return r


static func _resilience(c: CommandContext, a: Dictionary) -> CommandResult:
	var got := _fetch(c, a)
	if got[0] == null:
		return CommandResult.error(got[1])
	var kind: String = a["tipo"]
	var res := resilience(kind, got[0])
	var now: Dictionary = res["now"]
	var on: Array = res["on"]
	var r := CommandResult.new()
	r.line("Resiliencia de %s · defensas activas: %s" % [a["sistema"], ", ".join(on) if not on.is_empty() else "ninguna"], "accent")
	var data: Array = []
	for i in now["ids"].size():
		var id: String = now["ids"][i]
		var state := "✗ ÉXITO"
		var dep := ""
		if not id in now["broken"]:
			if res["depends"].has(id):
				state = "· frágil"
				dep = ", ".join(res["depends"][id])
			else:
				state = "· robusto"
		data.append([id, now["categories"][i], state, dep])
	r.table(PackedStringArray(["ataque", "categoría", "estado", "depende solo de"]), data)
	var total: int = now["ids"].size()
	var rate: float = float(now["passed"]) / now["total"]
	r.line("Ataques con éxito: %d / %d · robustos (aguantan que falle una defensa): %d · frágiles: %d" % [now["broken"].size(), total, res["robust"], res["fragile"].size()],
		"warn" if not now["broken"].is_empty() else "ok")
	r.line("Tareas legítimas: %d / %d · aprobaciones: %d" % [now["passed"], now["total"], now["approvals"]], "ok" if rate == 1.0 and now["approvals"] == 0 else "warn")
	c.emit("lab.resilience", {"kind": kind, "system": a["sistema"], "defenses": ",".join(on) if not on.is_empty() else "ninguna", "defense_count": on.size(),
		"breached": now["broken"].size(), "total": total, "robust": res["robust"], "fragile": res["fragile"].size(), "fragile_ids": ",".join(res["fragile"]),
		"pass_rate": rate, "approvals": now["approvals"]})
	return r
