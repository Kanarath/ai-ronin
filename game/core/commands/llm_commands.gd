class_name LlmCommands
extends RefCounted
## T6 · Transformers y LLM: predicción del siguiente token, muestreo y atención.


static func register(reg: CommandRegistry) -> void:
	reg.register(Command.new("lm train", "Entrena un modelo de lenguaje n-grama con un corpus.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _train(c, a), "lenguaje")
		.with_signature(CommandSignature.new()
			.pos("nombre", "nombre del modelo")
			.opt("order", "n del n-grama: 2 = mira 1 palabra atrás, 3 = mira 2…", "int", 2)
			.opt("corpus", "corpus (content/corpus)", "string", "forja")
			.example("lm train lm2 --order 2")))
	reg.register(Command.new("lm next", "Distribución de probabilidad del siguiente token.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _next(c, a), "lenguaje")
		.with_signature(CommandSignature.new()
			.pos("modelo", "modelo de lenguaje", "lm")
			.pos("texto", "contexto (las últimas palabras deciden)", "rest")
			.opt("temperature", "temperatura (0 = greedy)", "float", 1.0)
			.opt("top-k", "quedarse solo con los k más probables (0 = sin límite)", "int", 0)
			.opt("top-p", "quedarse con los más probables hasta acumular p (1 = sin límite)", "float", 1.0)
			.opt("show", "cuántos candidatos mostrar", "int", 8)
			.example("lm next lm2 la")
			.example("lm next lm2 la --temperature 0.5 --top-k 3")))
	reg.register(Command.new("lm generate", "Genera texto muestreando token a token.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _generate(c, a), "lenguaje")
		.with_signature(CommandSignature.new()
			.pos("modelo", "modelo de lenguaje", "lm")
			.pos("texto", "comienzo del texto (prompt)", "rest")
			.opt("tokens", "cuántos tokens generar", "int", 15)
			.opt("temperature", "temperatura (0 = greedy)", "float", 1.0)
			.opt("top-k", "top-k (0 = sin límite)", "int", 0)
			.opt("top-p", "top-p (1 = sin límite)", "float", 1.0)
			.opt("seed", "semilla del muestreo", "int", 1)
			.example("lm generate lm2 el maestro --temperature 0.8 --seed 3")))
	reg.register(Command.new("attention", "Self-attention entre palabras (Q = K = V = embeddings).",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _attention(c, a), "lenguaje")
		.with_signature(CommandSignature.new()
			.pos("palabras", "palabras de la tabla de embeddings, separadas por espacios", "rest")
			.opt("causal", "máscara causal: cada palabra solo ve las anteriores", "bool", false)
			.opt("no-scale", "no dividir las puntuaciones entre √d", "bool", false)
			.example("attention herrera martillo katana fuego agua")
			.example("attention herrera martillo katana --causal")))


static func _train(c: CommandContext, a: Dictionary) -> CommandResult:
	var path := LangCommands.CORPUS_DIR.path_join(String(a["corpus"]) + ".txt")
	if not FileAccess.file_exists(path):
		return CommandResult.error("No existe el corpus '%s'." % a["corpus"])
	var lm := NGramLM.new()
	lm.train(FileAccess.get_file_as_string(path), a["order"], a["corpus"])
	c.world.lms[a["nombre"]] = lm
	var r := CommandResult.new()
	r.line("✓ modelo %s: %d-grama entrenado con «%s» (%d tokens, %d contextos distintos)" % [a["nombre"], lm.order, a["corpus"], lm.corpus_tokens.size(), lm.counts.size()], "ok")
	r.line("Mira %d palabra(s) atrás para predecir la siguiente: esa es su «ventana de contexto»." % (lm.order - 1), "muted")
	c.emit("lm.trained", {"model": a["nombre"], "order": lm.order, "corpus": a["corpus"]})
	return r


static func _next(c: CommandContext, a: Dictionary) -> CommandResult:
	var lm: NGramLM = c.world.lms[a["modelo"]]
	var ctx := NGramLM.tokenize(a["texto"])
	var res := lm.distribution(ctx)
	var base: Array[Dictionary] = res["dist"]
	var t: float = a["temperature"]
	var final := Sampler.transform(base, t, a["top-k"], a["top-p"])
	var r := CommandResult.new()
	var ctx_txt := "«%s»" % res["context"] if not String(res["context"]).is_empty() else "(ninguno: frecuencia general)"
	r.line("Siguiente token tras «%s» · contexto usado: %s%s" % [a["texto"], ctx_txt, " · backoff" if res["backoff"] else ""], "accent")
	var shown := mini(int(a["show"]), base.size())
	var data: Array = []
	for i in shown:
		var tok: String = base[i]["token"]
		var after := 0.0
		for e in final:
			if e["token"] == tok:
				after = e["prob"]
		data.append([i + 1, tok, "%.3f" % base[i]["prob"], "%.3f" % after, "█".repeat(int(round(after * 20)))])
	r.table(PackedStringArray(["#", "token", "P original", "P final", ""]), data)
	if base.size() > shown:
		r.line("… y %d tokens más." % (base.size() - shown), "muted")
	r.line("temperatura=%s · top-k=%s · top-p=%s · candidatos que quedan: %d de %d" % [MlCommands._num(t), str(a["top-k"]) if int(a["top-k"]) > 0 else "—", MlCommands._num(a["top-p"]), final.size(), base.size()], "data")
	c.emit("lm.next", {"model": a["modelo"], "text": a["texto"], "context": res["context"], "temperature": t, "top_k": a["top-k"], "top_p": a["top-p"],
		"top_token": final[0]["token"] if not final.is_empty() else "", "top_prob": final[0]["prob"] if not final.is_empty() else 0.0,
		"candidates": final.size(), "total": base.size(), "order": lm.order})
	return r


static func _generate(c: CommandContext, a: Dictionary) -> CommandResult:
	var lm: NGramLM = c.world.lms[a["modelo"]]
	var n: int = clampi(a["tokens"], 1, 100)
	var out := lm.generate(a["texto"], n, a["temperature"], a["top-k"], a["top-p"], a["seed"])
	var text := String(a["texto"]) + " " + " ".join(out)
	var verbatim := _longest_verbatim(lm, NGramLM.tokenize(text))
	var r := CommandResult.new()
	r.line(text, "data")
	r.line("temperatura=%s · semilla=%d · %d tokens" % [MlCommands._num(a["temperature"]), a["seed"], out.size()], "muted")
	if verbatim >= 8:
		r.line("⚠ %d tokens seguidos copiados literalmente del corpus de entrenamiento." % verbatim, "warn")
	c.emit("lm.generated", {"model": a["modelo"], "prompt": a["texto"], "text": text, "temperature": a["temperature"], "seed": a["seed"],
		"order": lm.order, "top_k": a["top-k"], "top_p": a["top-p"], "verbatim": verbatim})
	return r


## Longitud del tramo más largo del texto que aparece literalmente en el corpus.
static func _longest_verbatim(lm: NGramLM, toks: PackedStringArray) -> int:
	var corpus := " " + " ".join(lm.corpus_tokens) + " "
	var best := 0
	for i in toks.size():
		for j in range(toks.size(), i + best, -1):
			if corpus.contains(" " + " ".join(toks.slice(i, j)) + " "):
				best = maxi(best, j - i)
				break
	return best


static func _attention(c: CommandContext, a: Dictionary) -> CommandResult:
	var t := LangCommands._table(c)
	var words := String(a["palabras"]).split(" ", false)
	if words.size() < 2 or words.size() > 10:
		return CommandResult.error("Usa entre 2 y 10 palabras de la tabla de embeddings (embed list).")
	var err := LangCommands._check_words(t, Array(words))
	if not err.is_empty():
		return CommandResult.error(err)
	var vecs: Array[PackedFloat64Array] = []
	for w in words:
		vecs.append(t.vectors[w])
	var causal: bool = a["causal"]
	var scaled: bool = not a["no-scale"]
	var res := ToyAttention.compute(vecs, causal, scaled)
	var r := CommandResult.new()
	r.line("Pesos de atención%s · fila = palabra que pregunta (query), columna = a quién atiende (key)" % (" con máscara causal" if causal else ""), "accent")
	var headers := PackedStringArray(["query \\ key"])
	headers.append_array(words)
	var data: Array = []
	var focus := {}
	for i in words.size():
		var row: Array = [words[i]]
		var best_j := -1
		for j in words.size():
			var w: float = res["weights"][i][j]
			row.append("—" if causal and j > i else "%.2f" % w)
			if j != i and (best_j == -1 or w > res["weights"][i][best_j]) and not (causal and j > i):
				best_j = j
		data.append(row)
		focus[words[i]] = words[best_j] if best_j != -1 else ""
	r.table(headers, data)
	r.line("Cada fila suma 1 (softmax): cada palabra reparte su atención entre las palabras que puede ver.", "muted")
	c.emit("attention.computed", {"words": " ".join(words), "n": words.size(), "causal": causal, "scaled": scaled, "focus": focus,
		"weights": res["weights"], "first_self": res["weights"][0][0]})
	return r
