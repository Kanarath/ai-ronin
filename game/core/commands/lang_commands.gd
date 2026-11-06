class_name LangCommands
extends RefCounted
## T5 · Del texto al vector: tokenización BPE y embeddings.

const CORPUS_DIR := "res://content/corpus"


static func register(reg: CommandRegistry) -> void:
	reg.register(Command.new("tokenizer train", "Entrena un tokenizador BPE sobre un corpus de texto.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _train(c, a), "lenguaje")
		.with_signature(CommandSignature.new()
			.pos("nombre", "nombre del tokenizador")
			.opt("merges", "número de fusiones (= tokens nuevos que aprende)", "int", 50)
			.opt("corpus", "corpus de entrenamiento (content/corpus)", "string", "forja")
			.example("tokenizer train tok --merges 0")
			.example("tokenizer train tok100 --merges 100")))
	reg.register(Command.new("tokenizer merges", "Fusiones aprendidas, en orden.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _merges(c, a), "lenguaje")
		.with_signature(CommandSignature.new()
			.pos("tokenizador", "nombre del tokenizador", "tokenizer")
			.opt("first", "cuántas mostrar", "int", 20)))
	reg.register(Command.new("tokenizer vocab", "Tamaño y muestra del vocabulario.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _vocab(c, a), "lenguaje")
		.with_signature(CommandSignature.new().pos("tokenizador", "nombre del tokenizador", "tokenizer")))
	reg.register(Command.new("tokenize", "Parte un texto en tokens con un tokenizador entrenado.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _tokenize(c, a), "lenguaje")
		.with_signature(CommandSignature.new()
			.pos("tokenizador", "nombre del tokenizador", "tokenizer")
			.pos("texto", "texto a tokenizar (puede llevar espacios)", "rest")
			.example("tokenize tok la katana del maestro")))

	reg.register(Command.new("embed list", "Palabras disponibles en la tabla de embeddings.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _emb_list(c, a), "lenguaje"))
	reg.register(Command.new("embed show", "Muestra el vector de una palabra.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _emb_show(c, a), "lenguaje")
		.with_signature(CommandSignature.new().pos("palabra", "palabra").example("embed show katana")))
	reg.register(Command.new("embed similar", "Palabras más parecidas (vecinos en el espacio de embeddings).",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _emb_similar(c, a), "lenguaje")
		.with_signature(CommandSignature.new()
			.pos("palabra", "palabra de consulta")
			.opt("k", "cuántos vecinos", "int", 5)
			.opt("metric", "medida de similitud", "string", "cosine", ["cosine", "euclidean"])
			.example("embed similar katana --k 3")))
	reg.register(Command.new("embed compare", "Similitud coseno y distancia euclídea entre dos palabras.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _emb_compare(c, a), "lenguaje")
		.with_signature(CommandSignature.new().pos("a", "primera palabra").pos("b", "segunda palabra").example("embed compare katana espada")))
	reg.register(Command.new("embed analogy", "Aritmética de vectores: a − b + c y su vecino más cercano.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _emb_analogy(c, a), "lenguaje")
		.with_signature(CommandSignature.new()
			.pos("a", "palabra a").pos("b", "palabra que se resta").pos("c", "palabra que se suma")
			.example("embed analogy maestro hombre mujer"))
		.with_details("Se lee: «a es a b como ? es a c». maestro − hombre + mujer ≈ maestra."))
	reg.register(Command.new("embed plot", "Dibuja las palabras en dos dimensiones del embedding.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _emb_plot(c, a), "lenguaje")
		.with_signature(CommandSignature.new()
			.opt("x", "dimensión del eje horizontal", "string", "arma")
			.opt("y", "dimensión del eje vertical", "string", "calor")
			.example("embed plot --x persona --y femenino")))


static func _table(c: CommandContext) -> EmbeddingTable:
	if c.world.embeddings == null:
		c.world.embeddings = EmbeddingTable.load_default()
	return c.world.embeddings


# ── Tokenización ─────────────────────────────────────────────────────────────

static func _train(c: CommandContext, a: Dictionary) -> CommandResult:
	var path := CORPUS_DIR.path_join(String(a["corpus"]) + ".txt")
	if not FileAccess.file_exists(path):
		return CommandResult.error("No existe el corpus '%s'." % a["corpus"])
	var n: int = clampi(a["merges"], 0, 2000)
	var tok := BPETokenizer.new()
	var text := FileAccess.get_file_as_string(path)
	tok.train(text, n, a["corpus"])
	c.world.tokenizers[a["nombre"]] = tok
	var r := CommandResult.new()
	r.line("✓ tokenizador %s entrenado con el corpus «%s» (%d palabras)" % [a["nombre"], a["corpus"], BPETokenizer.pre_tokenize(text).size()], "ok")
	r.line("vocabulario: %d símbolos base (caracteres) + %d fusiones = %d tokens" % [tok.base_symbols.size() + 1, tok.merges.size(), tok.vocab().size()], "data")
	if not tok.merges.is_empty():
		var first := PackedStringArray()
		for m in tok.merges.slice(0, 8):
			first.append("%s+%s" % [m[0], m[1]])
		r.line("primeras fusiones: " + "  ".join(first), "muted")
	c.emit("tokenizer.trained", {"tokenizer": a["nombre"], "merges": tok.merges.size(), "vocab_size": tok.vocab().size(), "corpus": a["corpus"]})
	return r


static func _merges(c: CommandContext, a: Dictionary) -> CommandResult:
	var tok: BPETokenizer = c.world.tokenizers[a["tokenizador"]]
	var r := CommandResult.new()
	if tok.merges.is_empty():
		return r.line("Este tokenizador no tiene fusiones: trabaja carácter a carácter.", "muted")
	var data: Array = []
	for i in mini(int(a["first"]), tok.merges.size()):
		var m: PackedStringArray = tok.merges[i]
		data.append([i + 1, m[0], m[1], m[0] + m[1]])
	r.table(PackedStringArray(["#", "a", "b", "nuevo token"]), data)
	c.emit("tokenizer.merges", {"tokenizer": a["tokenizador"]})
	return r


static func _vocab(c: CommandContext, a: Dictionary) -> CommandResult:
	var tok: BPETokenizer = c.world.tokenizers[a["tokenizador"]]
	var v := tok.vocab()
	var r := CommandResult.new()
	r.line("%s: %d tokens" % [a["tokenizador"], v.size()], "accent")
	r.line("base: " + " ".join(tok.base_symbols), "data")
	var learned := v.slice(tok.base_symbols.size() + 1)
	if not learned.is_empty():
		r.line("aprendidos (últimos 30): " + "  ".join(learned.slice(maxi(learned.size() - 30, 0))), "data")
	return r


static func _tokenize(c: CommandContext, a: Dictionary) -> CommandResult:
	var tok: BPETokenizer = c.world.tokenizers[a["tokenizador"]]
	var text := String(a["texto"])
	var tokens := tok.encode(text)
	var token_ids := tok.ids(tokens)
	var unknown := tokens.count(BPETokenizer.UNKNOWN)
	var r := CommandResult.new()
	r.line(" | ".join(tokens), "data")
	var id_text := PackedStringArray()
	for i in token_ids:
		id_text.append(str(i))
	r.line("ids: " + " ".join(id_text), "muted")
	r.line("%d caracteres → %d tokens (%s caracteres por token)" % [text.length(), tokens.size(), String.num(float(text.length()) / maxf(tokens.size(), 1), 2)], "accent")
	if unknown > 0:
		r.line("⚠ %d símbolo(s) desconocido(s) %s: caracteres que no aparecían en el corpus." % [unknown, BPETokenizer.UNKNOWN], "warn")
	c.emit("tokenize.done", {"tokenizer": a["tokenizador"], "text": text, "tokens": " | ".join(tokens), "count": tokens.size(),
		"chars": text.length(), "merges": tok.merges.size(), "unknown": unknown})
	return r


# ── Embeddings ───────────────────────────────────────────────────────────────

static func _check_words(t: EmbeddingTable, ws: Array) -> String:
	for w: String in ws:
		if not t.has(w):
			var s := TextUtils.closest(w, t.words())
			return "'%s' no está en la tabla.%s Lista: embed list" % [w, " ¿Quisiste decir '%s'?" % s if not s.is_empty() else ""]
	return ""


static func _emb_list(c: CommandContext, _a: Dictionary) -> CommandResult:
	var t := _table(c)
	var r := CommandResult.new()
	r.line("%d palabras · %d dimensiones: %s" % [t.words().size(), t.dimensions.size(), ", ".join(t.dimensions)], "accent")
	r.line("  ".join(t.words()), "data")
	r.line("⚗ Embeddings diseñados a mano para enseñar: los reales se aprenden y tienen cientos de dimensiones sin significado legible.", "muted")
	c.emit("embed.listed")
	return r


static func _emb_show(c: CommandContext, a: Dictionary) -> CommandResult:
	var t := _table(c)
	var err := _check_words(t, [a["palabra"]])
	if not err.is_empty():
		return CommandResult.error(err)
	var v: PackedFloat64Array = t.vectors[a["palabra"]]
	var r := CommandResult.new()
	r.line("%s (%s)" % [a["palabra"], t.categories[a["palabra"]]], "accent")
	var data: Array = []
	for i in t.dimensions.size():
		data.append([t.dimensions[i], String.num(v[i], 2), "█".repeat(int(round(absf(v[i]) * 10))) + (" (−)" if v[i] < 0 else "")])
	r.table(PackedStringArray(["dimensión", "valor", ""]), data)
	c.emit("embed.shown", {"word": a["palabra"]})
	return r


static func _emb_similar(c: CommandContext, a: Dictionary) -> CommandResult:
	var t := _table(c)
	var err := _check_words(t, [a["palabra"]])
	if not err.is_empty():
		return CommandResult.error(err)
	var metric: String = a["metric"]
	var top := t.nearest(t.vectors[a["palabra"]], clampi(a["k"], 1, 20), PackedStringArray([a["palabra"]]), metric)
	var r := CommandResult.new()
	r.line("Más parecidas a «%s» (%s)" % [a["palabra"], "similitud coseno" if metric == "cosine" else "distancia euclídea"], "accent")
	var data: Array = []
	var names := PackedStringArray()
	for i in top.size():
		var score: float = top[i]["score"]
		data.append([i + 1, top[i]["word"], t.categories[top[i]["word"]], String.num(score if metric == "cosine" else -score, 3)])
		names.append(top[i]["word"])
	r.table(PackedStringArray(["#", "palabra", "categoría", "coseno" if metric == "cosine" else "distancia"]), data)
	c.emit("embed.similar", {"word": a["palabra"], "metric": metric, "top": ",".join(names), "first": names[0] if not names.is_empty() else ""})
	return r


static func _emb_compare(c: CommandContext, a: Dictionary) -> CommandResult:
	var t := _table(c)
	var err := _check_words(t, [a["a"], a["b"]])
	if not err.is_empty():
		return CommandResult.error(err)
	var va: PackedFloat64Array = t.vectors[a["a"]]
	var vb: PackedFloat64Array = t.vectors[a["b"]]
	var cos := Vec.cosine_similarity(va, vb)
	var euc := Vec.euclidean(va, vb)
	var r := CommandResult.new()
	r.line("«%s» frente a «%s»" % [a["a"], a["b"]], "accent")
	r.line("similitud coseno = (a·b) / (|a|·|b|) = %s / (%s · %s) = %s" % [String.num(Vec.dot(va, vb), 3), String.num(Vec.norm(va), 3), String.num(Vec.norm(vb), 3), String.num(cos, 3)], "data")
	r.line("distancia euclídea = %s" % String.num(euc, 3), "data")
	r.line("Coseno: 1 = misma dirección, 0 = sin relación (perpendiculares), −1 = opuestas. Ignora la longitud del vector.", "muted")
	c.emit("embed.compare", {"a": a["a"], "b": a["b"], "cosine": cos, "euclidean": euc})
	return r


static func _emb_analogy(c: CommandContext, a: Dictionary) -> CommandResult:
	var t := _table(c)
	var err := _check_words(t, [a["a"], a["b"], a["c"]])
	if not err.is_empty():
		return CommandResult.error(err)
	var v := t.analogy_vector(a["a"], a["b"], a["c"])
	var top := t.nearest(v, 3, PackedStringArray([a["a"], a["b"], a["c"]]))
	var r := CommandResult.new()
	r.line("%s − %s + %s = [%s]" % [a["a"], a["b"], a["c"], ", ".join(Array(v).map(func(x: float) -> String: return String.num(x, 2)))], "accent")
	var data: Array = []
	for i in top.size():
		data.append([i + 1, top[i]["word"], String.num(top[i]["score"], 3)])
	r.table(PackedStringArray(["#", "más cercana", "coseno"]), data)
	r.line("Las palabras de la consulta se excluyen del resultado (si no, casi siempre ganaría «%s»)." % a["a"], "muted")
	c.emit("embed.analogy", {"a": a["a"], "b": a["b"], "c": a["c"], "result": top[0]["word"] if not top.is_empty() else ""})
	return r


static func _emb_plot(c: CommandContext, a: Dictionary) -> CommandResult:
	var t := _table(c)
	for d in [a["x"], a["y"]]:
		if not String(d) in t.dimensions:
			return CommandResult.error("'%s' no es una dimensión. Dimensiones: %s" % [d, ", ".join(t.dimensions)])
	var ds := t.to_dataset("embeddings")
	c.world.add_dataset(ds)
	c.emit("viz.scatter", {"dataset": "embeddings", "x": a["x"], "y": a["y"]})
	return CommandResult.new().line("Dibujando las palabras: %s (horizontal) frente a %s (vertical)." % [a["x"], a["y"]], "ok")
