class_name AlignCommands
extends RefCounted
## T9 · Cómo aprende un LLM: las tres fases de entrenamiento de un asistente, simuladas con
## un modelo pequeño cuyas respuestas cambian según la fase (content/llm_training.json):
##   llm pretrain <m>            preentrenamiento: aprende a continuar texto
##   llm sft <m>                 ajuste con instrucciones (SFT): aprende a responder… y a obedecer
##   llm prefs <m> <conjunto>    ajuste con preferencias (RLHF): aprende qué respuestas preferimos
##   llm ask <m> <pregunta>      qué contesta y con qué probabilidad
## Las puntuaciones reproducen el comportamiento típico descrito en la literatura; no es un LLM real.

const PATH := "res://content/llm_training.json"
static var _data: Dictionary = {}


static func register(reg: CommandRegistry) -> void:
	reg.register(Command.new("llm prompts", "Preguntas de prueba del laboratorio de entrenamiento.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _prompts(c, a), "lenguaje"))
	reg.register(Command.new("llm pretrain", "Preentrena un modelo: aprende a continuar texto de internet.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _pretrain(c, a), "lenguaje")
		.with_signature(CommandSignature.new().pos("modelo", "nombre del modelo").example("llm pretrain kuro")))
	reg.register(Command.new("llm sft", "Ajuste con instrucciones (SFT): aprende a responder a lo que se le pide.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _sft(c, a), "lenguaje")
		.with_signature(CommandSignature.new().pos("modelo", "modelo preentrenado").example("llm sft kuro")))
	reg.register(Command.new("llm prefs", "Ajuste con preferencias humanas (RLHF) con un conjunto de pares.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _prefs(c, a), "lenguaje")
		.with_signature(CommandSignature.new()
			.pos("modelo", "modelo con SFT")
			.pos("conjunto", "seguridad, rol o longitud")
			.example("llm prefs kuro seguridad")))
	reg.register(Command.new("llm ask", "Pregunta al modelo: qué contesta y con qué probabilidad.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _ask(c, a), "lenguaje")
		.with_signature(CommandSignature.new()
			.pos("modelo", "modelo")
			.pos("pregunta", "id de la pregunta (lista: llm prompts)")
			.example("llm ask kuro temple")))


static func data() -> Dictionary:
	if _data.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = d if d is Dictionary else {}
	return _data


static func _model(c: CommandContext, n: String) -> Dictionary:
	return c.world.aligned.get(n, {})


static func _prompts(c: CommandContext, _a: Dictionary) -> CommandResult:
	var r := CommandResult.new()
	r.line("Preguntas de prueba (llm ask <modelo> <id>)", "accent")
	var rows: Array = []
	var qs: Dictionary = data().get("preguntas", {})
	for k: String in qs:
		rows.append([k, qs[k]["texto"]])
	r.table(PackedStringArray(["id", "pregunta"]), rows)
	r.line("Conjuntos para llm prefs: " + ", ".join(PackedStringArray(data().get("conjuntos", {}).keys())), "muted")
	c.emit("llm.prompts", {})
	return r


static func _pretrain(c: CommandContext, a: Dictionary) -> CommandResult:
	c.world.aligned[a["modelo"]] = {"stage": "base", "sets": []}
	var r := CommandResult.new()
	r.line("✓ %s preentrenado: ha leído muchísimo texto y ha aprendido a predecir la siguiente palabra." % a["modelo"], "ok")
	r.line("  ⚗ Simulado: un modelo real tarda semanas en miles de GPU (Graphics Processing Unit). Siguiente: llm ask %s temple" % a["modelo"], "muted")
	c.emit("llm.trained", {"model": a["modelo"], "stage": "base", "sets": ""})
	return r


static func _sft(c: CommandContext, a: Dictionary) -> CommandResult:
	var m := _model(c, a["modelo"])
	if m.is_empty():
		return CommandResult.error("Primero preentrena el modelo: llm pretrain %s" % a["modelo"])
	m["stage"] = "sft"
	var r := CommandResult.new()
	r.line("✓ %s ajustado con %s." % [a["modelo"], data()["conjuntos"]["instrucciones"]["titulo"]], "ok")
	r.line("  Ahora ha visto miles de ejemplos de «instrucción → buena respuesta».", "muted")
	c.emit("llm.trained", {"model": a["modelo"], "stage": "sft", "sets": ""})
	return r


static func _prefs(c: CommandContext, a: Dictionary) -> CommandResult:
	var m := _model(c, a["modelo"])
	if m.is_empty() or m["stage"] == "base":
		return CommandResult.error("El ajuste con preferencias va después del SFT: llm sft %s" % a["modelo"])
	var sets: Dictionary = data().get("conjuntos", {})
	if not sets.has(a["conjunto"]) or sets[a["conjunto"]]["fase"] != "prefs":
		return CommandResult.error("Conjuntos de preferencias: seguridad, rol o longitud.")
	if not a["conjunto"] in m["sets"]:
		m["sets"].append(a["conjunto"])
	m["stage"] = "prefs"
	var r := CommandResult.new()
	r.line("✓ %s ajustado con preferencias: %s." % [a["modelo"], sets[a["conjunto"]]["titulo"]], "ok")
	r.line("  Un modelo de recompensa aprende qué respuesta prefieren las personas y el LLM se ajusta para sacar más recompensa.", "muted")
	c.emit("llm.trained", {"model": a["modelo"], "stage": "prefs", "sets": ",".join(PackedStringArray(m["sets"]))})
	return r


## Puntuación de cada tipo de respuesta según lo que ha aprendido el modelo.
static func score(m: Dictionary, qtype: String, kind: String) -> float:
	var s := 0.0
	match m["stage"]:
		"base":
			s = {"continuacion": 3.0, "util": 0.5, "obedece": 0.3}.get(kind, 0.0)
		_:
			s = {"continuacion": 0.0, "util": 3.0, "larga": 1.0, "obedece": 3.0, "rechazo": 0.5}.get(kind, 0.0)
	if m["stage"] == "prefs":
		var sets: Dictionary = data().get("conjuntos", {})
		for name: String in m["sets"]:
			var st: Dictionary = sets[name]
			if kind == "rechazo" and qtype.begins_with("danino"):
				# Lo que se entrenó, se aprende bien; los disfraces que no se entrenaron, apenas.
				s += 4.0 if qtype in st.get("cubre", []) else (1.0 if not st.get("cubre", []).is_empty() else 0.0)
			if kind == st.get("premia", "") and qtype == "normal":
				s += 3.0
	return s


static func _ask(c: CommandContext, a: Dictionary) -> CommandResult:
	var m := _model(c, a["modelo"])
	if m.is_empty():
		return CommandResult.error("No existe el modelo %s. Crea uno: llm pretrain %s" % [a["modelo"], a["modelo"]])
	var qs: Dictionary = data().get("preguntas", {})
	if not qs.has(a["pregunta"]):
		return CommandResult.error("No hay una pregunta «%s». Lista: llm prompts" % a["pregunta"])
	var q: Dictionary = qs[a["pregunta"]]
	var scores: Array = []
	var total := 0.0
	for cand: Dictionary in q["candidatas"]:
		var e := exp(score(m, q["tipo"], cand["tipo"]))
		scores.append(e)
		total += e
	var best := 0
	for i in scores.size():
		if scores[i] > scores[best]:
			best = i
	var r := CommandResult.new()
	r.line("%s (%s) · «%s»" % [a["modelo"], _stage_name(m), q["texto"]], "accent")
	var rows: Array = []
	for i in scores.size():
		var cand: Dictionary = q["candidatas"][i]
		rows.append(["▶" if i == best else " ", "%.0f %%" % (100.0 * scores[i] / total), cand["tipo"], TextUtils.clip(cand["texto"], 70)])
	r.table(PackedStringArray(["", "prob.", "tipo", "respuesta candidata"]), rows)
	var chosen: Dictionary = q["candidatas"][best]
	r.line("🤖 " + chosen["texto"], "normal")
	if chosen["tipo"] == "obedece":
		r.line("⚠ Ha obedecido una petición que debería rechazar.", "warn")
	c.emit("llm.asked", {"model": a["modelo"], "prompt": a["pregunta"], "kind": chosen["tipo"], "prob": scores[best] / total, "stage": m["stage"]})
	return r


static func _stage_name(m: Dictionary) -> String:
	match m["stage"]:
		"base": return "solo preentrenado"
		"sft": return "con SFT"
	return "con preferencias: " + ", ".join(PackedStringArray(m["sets"]))
