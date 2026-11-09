class_name RagCommands
extends RefCounted
## A2 · RAG y embeddings: construir, atacar y defender un sistema RAG (laboratorio simulado).

const ATTACKS_PATH := "res://content/rag/attacks.json"
const NORMAL_PATH := "res://content/rag/normal.json"


static func register(reg: CommandRegistry) -> void:
	var role_opt := func(sig: CommandSignature) -> CommandSignature:
		return sig.opt("as", "quién pregunta: cliente (público) o empleado", "string", "cliente", ["cliente", "empleado"])
	reg.register(Command.new("rag create", "Crea el asistente RAG con la documentación de la forja.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _create(c, a), "rag")
		.with_signature(CommandSignature.new().pos("nombre", "nombre del sistema RAG").example("rag create biblio")))
	reg.register(Command.new("rag docs", "Lista los documentos de la base de conocimiento.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _docs(c, a), "rag")
		.with_signature(CommandSignature.new().pos("rag", "sistema RAG", "rag")))
	reg.register(Command.new("rag ingest", "Trocea los documentos en fragmentos y construye el índice vectorial.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _ingest(c, a), "rag")
		.with_signature(CommandSignature.new()
			.pos("rag", "sistema RAG", "rag")
			.opt("chunk", "palabras por fragmento", "int", 40)
			.opt("overlap", "palabras que se repiten entre fragmentos consecutivos", "int", 10)
			.example("rag ingest biblio --chunk 40 --overlap 10")))
	reg.register(Command.new("rag search", "Busca los fragmentos más parecidos a una consulta (sin generar respuesta).",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _search(c, a), "rag")
		.with_signature(role_opt.call(CommandSignature.new()
			.pos("rag", "sistema RAG", "rag")
			.pos("consulta", "texto de la búsqueda", "rest")
			.opt("k", "cuántos fragmentos recuperar", "int", 3))
			.example("rag search biblio aceite para la hoja")))
	reg.register(Command.new("rag ask", "Pregunta al asistente: recupera fragmentos y genera una respuesta con fuentes.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _ask(c, a), "rag")
		.with_signature(role_opt.call(CommandSignature.new()
			.pos("rag", "sistema RAG", "rag")
			.pos("pregunta", "pregunta del usuario", "rest"))
			.example("rag ask biblio ¿Qué aceite debo usar?")))
	reg.register(Command.new("rag upload", "Sube un documento como lo haría un usuario (reseña, mensaje de foro…).",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _upload(c, a), "rag")
		.with_signature(CommandSignature.new()
			.pos("rag", "sistema RAG", "rag")
			.pos("id", "identificador del documento")
			.pos("texto", "contenido del documento", "rest")
			.opt("source", "origen del documento", "string", "cliente", ["cliente", "foro"])
			.example("rag upload biblio resena-1 Gran katana, muy afilada."))
		.with_details("Después de subir un documento hay que volver a ejecutar rag ingest para que entre en el índice."))
	reg.register(Command.new("rag vector", "Muestra el vector (embedding) de un fragmento, como lo vería quien lea la base vectorial.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _vector(c, a), "rag")
		.with_signature(role_opt.call(CommandSignature.new()
			.pos("rag", "sistema RAG", "rag")
			.pos("fragmento", "id del fragmento, p. ej. costes#0"))))
	reg.register(Command.new("rag invert", "Intenta reconstruir el texto a partir del vector de un fragmento.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _invert(c, a), "rag")
		.with_signature(role_opt.call(CommandSignature.new()
			.pos("rag", "sistema RAG", "rag")
			.pos("fragmento", "id del fragmento"))))
	reg.register(Command.new("rag defend", "Activa o desactiva una defensa del RAG.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _defend(c, a), "rag")
		.with_signature(CommandSignature.new()
			.pos("rag", "sistema RAG", "rag")
			.pos("defensa", "defensa", "string", true, Array(RagSystem.DEFENSES))
			.pos("estado", "on u off", "string", true, ["on", "off"])
			.example("rag defend biblio acl on")))
	reg.register(Command.new("rag attack", "Lanza la batería de ataques A2 (sobre una copia de la base de conocimiento).",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _attack(c, a), "rag")
		.with_signature(CommandSignature.new().pos("rag", "sistema RAG", "rag")))
	reg.register(Command.new("rag eval", "Prueba el RAG con preguntas legítimas de clientes.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _eval(c, a), "rag")
		.with_signature(CommandSignature.new().pos("rag", "sistema RAG", "rag")))


static func _active(rag: RagSystem) -> String:
	var on := PackedStringArray()
	for d in RagSystem.DEFENSES:
		if rag.defenses[d]:
			on.append(d)
	return ",".join(on) if not on.is_empty() else "ninguna"


static func _need_index(rag: RagSystem) -> String:
	return "" if not rag.chunks.is_empty() else "El índice está vacío. Ejecuta primero: rag ingest %s" % rag.kb_name


static func _create(c: CommandContext, a: Dictionary) -> CommandResult:
	var rag := RagSystem.load_default(a["nombre"])
	c.world.rags[a["nombre"]] = rag
	c.emit("rag.created", {"rag": a["nombre"], "documents": rag.documents.size()})
	var r := CommandResult.new().line("✓ sistema RAG %s creado con %d documentos de la forja (aún sin indexar)." % [a["nombre"], rag.documents.size()], "ok")
	r.line("Siguiente paso: rag docs %s · rag ingest %s" % [a["nombre"], a["nombre"]], "muted")
	return r


static func _docs(c: CommandContext, a: Dictionary) -> CommandResult:
	var rag: RagSystem = c.world.rags[a["rag"]]
	var data: Array = []
	for d in rag.documents:
		data.append([d["id"], d["title"], d["source"], d["access"], String(d["text"]).split(" ", false).size()])
	c.emit("rag.docs", {"rag": a["rag"]})
	return CommandResult.new().table(PackedStringArray(["id", "título", "origen", "acceso", "palabras"]), data)


static func _ingest(c: CommandContext, a: Dictionary) -> CommandResult:
	var rag: RagSystem = c.world.rags[a["rag"]]
	rag.ingest(a["chunk"], a["overlap"])
	var r := CommandResult.new()
	r.line("✓ %d fragmentos indexados (chunk=%d palabras, overlap=%d) · vocabulario: %d términos" % [rag.chunks.size(), rag.chunk_size, rag.overlap, rag.idf.size()], "ok")
	var data: Array = []
	for ch in rag.chunks.slice(0, 6):
		data.append([ch["id"], ch["access"], String(ch["text"]).substr(0, 70) + "…"])
	r.table(PackedStringArray(["fragmento", "acceso", "texto"]), data)
	if rag.chunks.size() > 6:
		r.line("… y %d fragmentos más." % (rag.chunks.size() - 6), "muted")
	c.emit("rag.ingested", {"rag": a["rag"], "chunk": rag.chunk_size, "overlap": rag.overlap, "chunks": rag.chunks.size(), "defenses": _active(rag)})
	return r


static func _search(c: CommandContext, a: Dictionary) -> CommandResult:
	var rag: RagSystem = c.world.rags[a["rag"]]
	var err := _need_index(rag)
	if not err.is_empty():
		return CommandResult.error(err)
	var hits := rag.search(a["consulta"], clampi(a["k"], 1, 10), a["as"])
	var r := CommandResult.new()
	r.line("Fragmentos más parecidos a «%s» (como %s)" % [a["consulta"], a["as"]], "accent")
	var data: Array = []
	var words := 0
	var internal := false
	for h in hits:
		var ch: Dictionary = h["chunk"]
		data.append([ch["id"], "%.3f" % h["score"], ch["access"], ch["source"], String(ch["text"]).substr(0, 60) + "…"])
		words += String(ch["text"]).split(" ", false).size()
		internal = internal or (ch["access"] == "interno" and a["as"] != "empleado")
	r.table(PackedStringArray(["fragmento", "similitud", "acceso", "origen", "texto"]), data)
	r.line("Contexto que recibiría el modelo: %d palabras." % words, "muted")
	c.emit("rag.searched", {"rag": a["rag"], "query": a["consulta"], "role": a["as"], "top": hits[0]["chunk"]["id"] if not hits.is_empty() else "",
		"top_score": hits[0]["score"] if not hits.is_empty() else 0.0, "context_words": words, "internal_visible": internal})
	return r


static func _ask(c: CommandContext, a: Dictionary) -> CommandResult:
	var rag: RagSystem = c.world.rags[a["rag"]]
	var err := _need_index(rag)
	if not err.is_empty():
		return CommandResult.error(err)
	var res := rag.ask(a["pregunta"], a["as"])
	var r := CommandResult.new()
	r.line("🤖 " + String(res["answer"]), "data")
	r.line("   fuentes: %s · similitud máxima: %.3f · contexto: %d palabras" % [", ".join(res["sources"]) if not res["sources"].is_empty() else "—", res["top_score"], res["context_words"]], "muted")
	if res["injected"]:
		r.line("   ⚠ la respuesta sigue una instrucción escondida en un documento recuperado.", "warn")
	if res["leaked_internal"]:
		r.line("   ⚠ la respuesta usa un documento INTERNO y la ha pedido un cliente.", "warn")
	if res["poisoned"]:
		r.line("   ⚠ la respuesta sale de un documento subido por un usuario (fuente no confiable).", "warn")
	var data := res.duplicate()
	data["sources"] = ",".join(res["sources"])
	data.merge({"rag": a["rag"], "question": a["pregunta"], "role": a["as"], "defenses": _active(rag)})
	c.emit("rag.answered", data)
	return r


static func _upload(c: CommandContext, a: Dictionary) -> CommandResult:
	var rag: RagSystem = c.world.rags[a["rag"]]
	rag.add_document(a["id"], "Documento subido por un usuario", a["source"], "publico", a["texto"])
	c.emit("rag.uploaded", {"rag": a["rag"], "id": a["id"], "source": a["source"],
		"has_instruction": RegEx.create_from_string(RagSystem.INJECTION_RX).search(a["texto"]) != null})
	return CommandResult.new().line("✓ documento %s añadido (origen: %s). Vuelve a indexar con rag ingest para que el asistente lo use." % [a["id"], a["source"]], "ok")


static func _vector(c: CommandContext, a: Dictionary) -> CommandResult:
	var rag: RagSystem = c.world.rags[a["rag"]]
	var ch := rag.vector_of(a["fragmento"])
	if ch.is_empty():
		return CommandResult.error("No existe el fragmento '%s' (¿has indexado? mira los ids con rag search o rag ingest)." % a["fragmento"])
	if rag.defenses["vector-acl"] and ch["access"] == "interno" and a["as"] != "empleado":
		c.emit("rag.vector", {"rag": a["rag"], "chunk": a["fragmento"], "exposed": false})
		return CommandResult.error("Acceso denegado: la base vectorial aplica control de acceso a los vectores de documentos internos.")
	var vec: Dictionary = ch["vec"]
	var dims := PackedStringArray()
	for t in RagSystem.invert(vec).slice(0, 8):
		dims.append("%s=%.2f" % [t, vec[t]])
	var r := CommandResult.new()
	r.line("Vector de %s: %d dimensiones con peso (de %d posibles)" % [a["fragmento"], vec.size(), rag.idf.size()], "accent")
	r.line("{" + ", ".join(dims) + ", …}", "data")
	r.line("Esto es lo que guarda la base de datos vectorial. ¿Parece «solo números»?", "muted")
	c.emit("rag.vector", {"rag": a["rag"], "chunk": a["fragmento"], "exposed": true, "access": ch["access"]})
	return r


static func _invert(c: CommandContext, a: Dictionary) -> CommandResult:
	var rag: RagSystem = c.world.rags[a["rag"]]
	var ch := rag.vector_of(a["fragmento"])
	if ch.is_empty():
		return CommandResult.error("No existe el fragmento '%s'." % a["fragmento"])
	if rag.defenses["vector-acl"] and ch["access"] == "interno" and a["as"] != "empleado":
		c.emit("rag.inverted", {"rag": a["rag"], "chunk": a["fragmento"], "recovered": 0})
		return CommandResult.error("Acceso denegado: no puedes leer ese vector.")
	var words := RagSystem.invert(ch["vec"])
	var original := RagSystem.terms_of(ch["text"])
	var recovered := 0
	for w in words:
		if w in original:
			recovered += 1
	var r := CommandResult.new()
	r.line("Palabras reconstruidas desde el vector (ordenadas por peso):", "accent")
	r.line(" ".join(words), "data")
	r.line("Recuperadas %d de %d palabras significativas del texto original." % [recovered, words.size()], "warn")
	c.emit("rag.inverted", {"rag": a["rag"], "chunk": a["fragmento"], "recovered": recovered, "access": ch["access"]})
	return r


static func _defend(c: CommandContext, a: Dictionary) -> CommandResult:
	var rag: RagSystem = c.world.rags[a["rag"]]
	rag.defenses[a["defensa"]] = a["estado"] == "on"
	var r := CommandResult.new().line("✓ %s → %s" % [a["defensa"], "activada" if a["estado"] == "on" else "desactivada"], "ok")
	if a["defensa"] == "trusted-sources":
		rag.ingest(rag.chunk_size, rag.overlap)
		r.line("Índice reconstruido: %d fragmentos." % rag.chunks.size(), "muted")
	c.emit("rag.defense", {"rag": a["rag"], "defense": a["defensa"], "enabled": a["estado"] == "on"})
	return r


## Escenarios de la batería A2. Devuelve [[id, categoría, éxito, detalle]].
static func run_suite(base: RagSystem) -> Array:
	var suite: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ATTACKS_PATH))
	var rows: Array = []
	for atk: Dictionary in suite["attacks"]:
		var rag := base.duplicate_system()
		if atk.has("upload"):
			var u: Dictionary = atk["upload"]
			rag.add_document(u["id"], u["title"], u["source"], "publico", u["text"])
			rag.ingest(base.chunk_size, base.overlap)
		var ok := false
		var detail := ""
		var cond: Dictionary = atk["success"]
		if atk.has("vector"):
			var ch := rag.vector_of(atk["vector"])
			ok = not ch.is_empty() and not (rag.defenses["vector-acl"] and ch["access"] == "interno")
			detail = "vector legible" if ok else "acceso denegado"
		else:
			var res := rag.ask(atk["query"], atk["role"])
			if cond.has("answer_contains"):
				ok = String(res["answer"]).contains(cond["answer_contains"])
			if cond.has("leaked_internal"):
				ok = res["leaked_internal"]
			detail = String(res["answer"]).substr(0, 50)
		rows.append([atk["id"], atk["category"], ok, detail])
	return rows


## Preguntas legítimas. Devuelve {"passed", "total", "approvals", "rows": [[id, ok, respuesta]]}.
static func run_eval(rag: RagSystem) -> Dictionary:
	var suite: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(NORMAL_PATH))
	var rows: Array = []
	var passed := 0
	for q: Dictionary in suite["questions"]:
		var res := rag.ask(q["message"], "cliente")
		var ok := String(res["answer"]).contains(q["expect"])
		if ok:
			passed += 1
		rows.append([q["id"], ok, String(res["answer"])])
	return {"passed": passed, "total": rows.size(), "approvals": 0, "rows": rows}


static func _attack(c: CommandContext, a: Dictionary) -> CommandResult:
	var base: RagSystem = c.world.rags[a["rag"]]
	var err := _need_index(base)
	if not err.is_empty():
		return CommandResult.error(err)
	var rows := run_suite(base)
	var r := CommandResult.new()
	r.line("Batería de ataques A2 contra %s · defensas: %s" % [a["rag"], _active(base)], "accent")
	var data: Array = []
	var successes := 0
	for row: Array in rows:
		if row[2]:
			successes += 1
		data.append([row[0], row[1], "✗ ÉXITO" if row[2] else "· fallo", row[3]])
	r.table(PackedStringArray(["ataque", "categoría", "resultado", "detalle"]), data)
	var total: int = rows.size()
	var rate := float(successes) / total
	r.line("Tasa de éxito de los ataques: %d / %d = %.2f" % [successes, total, rate], "warn" if successes > 0 else "ok")
	c.emit("rag.attacks", {"rag": a["rag"], "success_rate": rate, "successes": successes, "total": total, "defenses": _active(base)})
	return r


static func _eval(c: CommandContext, a: Dictionary) -> CommandResult:
	var rag: RagSystem = c.world.rags[a["rag"]]
	var err := _need_index(rag)
	if not err.is_empty():
		return CommandResult.error(err)
	var ev := run_eval(rag)
	var r := CommandResult.new()
	r.line("Evaluación con %d preguntas de clientes · chunk=%d · defensas: %s" % [ev["total"], rag.chunk_size, _active(rag)], "accent")
	var data: Array = []
	var passed: int = ev["passed"]
	for row: Array in ev["rows"]:
		data.append([row[0], "✓" if row[1] else "✗", String(row[2]).substr(0, 70)])
	r.table(PackedStringArray(["pregunta", "", "respuesta"]), data)
	var rate: float = float(passed) / ev["total"]
	r.line("Respuestas correctas: %d / %d = %.2f" % [passed, ev["total"], rate], "ok" if rate == 1.0 else "warn")
	c.emit("rag.eval", {"rag": a["rag"], "pass_rate": rate, "passed": passed, "chunk": rag.chunk_size, "defenses": _active(rag)})
	return r
