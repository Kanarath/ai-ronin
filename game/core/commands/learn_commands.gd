class_name LearnCommands
extends RefCounted
## Herramientas para estudiar mejor con lo que ya sabes:
##   repaso            una pregunta de una misión ya completada, cuando toca repasarla
##   repaso <letra>    responde a la pregunta de repaso
##   repaso estado     cuántas tienes pendientes y en qué caja está cada una
##   perfil            mapa de tus competencias: dominadas, practicadas, vistas y pendientes
##
## El repaso es espaciado (sistema de cajas de Leitner): cada acierto aleja la siguiente vez que
## te la pregunta; un fallo la devuelve a la primera caja. Todo se guarda con tu progreso.

## Días hasta el siguiente repaso según la caja (0 = hoy mismo).
const INTERVALS := [0, 1, 3, 7, 16, 35]
const DAY := 86400
## Para los tests: si no es 0, se usa como «ahora» (segundos Unix).
static var now_override: int = 0


static func register(reg: CommandRegistry) -> void:
	reg.register(Command.new("repaso", "Repaso espaciado: una pregunta de lo que ya has aprendido, justo cuando toca (repaso <letra> responde).",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _review(c, a), "ayuda")
		.with_signature(CommandSignature.new()
			.pos("respuesta", "la letra de tu respuesta", "string", false)
			.example("repaso").example("repaso b")))
	reg.register(Command.new("repaso estado", "Cuántas preguntas de repaso tienes pendientes y cómo vas.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _review_state(c, a), "ayuda"))
	reg.register(Command.new("perfil", "Tu mapa de competencias: qué dominas, qué has practicado y qué te falta.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _profile(c, a), "ayuda"))


static func _game(c: CommandContext) -> DojoGame:
	return c.shell.get_game() as DojoGame


static func now() -> int:
	return now_override if now_override > 0 else int(Time.get_unix_time_from_system())


# ── Repaso ───────────────────────────────────────────────────────────────────

## Preguntas de comprensión (choices) de las misiones completadas: [{key, mission, objective}].
static func pool(g: DojoGame) -> Array:
	var out: Array = []
	for m: Dictionary in g.catalog.missions:
		if not g.progress.is_mission_completed(m["id"]):
			continue
		for o: Dictionary in m["objectives"]:
			if o.has("choices") and o["validator"].get("type", "") == "answer":
				out.append({"key": "%s/%s" % [m["id"], o["id"]], "mission": m, "objective": o})
	return out


static func _boxes(g: DojoGame) -> Dictionary:
	if not g.progress.data.has("repaso"):
		g.progress.data["repaso"] = {}
	return g.progress.data["repaso"]


## Las que tocan ya (nuevas o vencidas), las más atrasadas primero.
static func due(g: DojoGame) -> Array:
	var boxes := _boxes(g)
	var t := now()
	var out: Array = []
	for it: Dictionary in pool(g):
		var st: Dictionary = boxes.get(it["key"], {})
		if int(st.get("proxima", 0)) <= t:
			it["proxima"] = int(st.get("proxima", 0))
			out.append(it)
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x["proxima"] < y["proxima"] or (x["proxima"] == y["proxima"] and x["key"] < y["key"]))
	return out


static func _review(c: CommandContext, a: Dictionary) -> CommandResult:
	var g := _game(c)
	if g == null:
		return CommandResult.error("El repaso necesita una partida.")
	var raw: Variant = a.get("respuesta")
	if raw != null and not str(raw).strip_edges().is_empty():
		return _answer(c, g, str(raw).strip_edges().to_lower())
	if pool(g).is_empty():
		return CommandResult.new().line("Aún no hay nada que repasar: completa una misión con preguntas de comprensión y vuelve.", "muted")
	var list := due(g)
	if list.is_empty():
		return CommandResult.new().line("Hoy no te toca repasar nada. Lo siguiente vence %s. (repaso estado)" % _next_text(g), "ok")
	var it: Dictionary = list[0]
	g.set_meta("repaso_actual", it["key"])
	var o: Dictionary = it["objective"]
	var r := CommandResult.new()
	r.line("Repaso · %s · %s   (te quedan %d hoy)" % [it["mission"]["id"], it["mission"]["title"], list.size()], "accent")
	var topic := str(o.get("teach", "")).split("\n")[0]
	if not topic.is_empty():
		r.line("Tema: " + topic, "muted")
	r.line(o["text"])
	for ch: Dictionary in o["choices"]:
		r.line("  %s) %s" % [ch["id"], ch["text"]], "normal")
	r.line("Responde con repaso <letra>, por ejemplo repaso a si eliges la a.", "muted")
	return r


static func _answer(c: CommandContext, g: DojoGame, letter: String) -> CommandResult:
	var key: String = str(g.get_meta("repaso_actual", ""))
	if key.is_empty():
		return CommandResult.error("No hay ninguna pregunta de repaso abierta. Escribe repaso para que te haga una.")
	var it: Dictionary = {}
	for x: Dictionary in pool(g):
		if x["key"] == key:
			it = x
	if it.is_empty():
		return CommandResult.error("La pregunta de repaso ya no está disponible. Escribe repaso.")
	var o: Dictionary = it["objective"]
	var ok := ConditionEval.answer_matches(o["validator"], letter)
	var boxes := _boxes(g)
	var st: Dictionary = boxes.get(key, {"caja": 0})
	var box := int(st.get("caja", 0))
	var r := CommandResult.new()
	if ok:
		box = mini(box + 1, INTERVALS.size() - 1)
		r.line("✓ Correcto. La volverás a ver dentro de %d día(s)." % INTERVALS[box], "ok")
	else:
		box = 0
		var why := ""
		for ch: Dictionary in o["choices"]:
			if ch["id"] == letter:
				why = str(ch.get("why", ""))
		r.line("✗ No es esa." + ((" " + why) if not why.is_empty() else ""), "warn")
		r.line("La correcta era la %s. Te la volveré a preguntar pronto." % str(o["validator"]["expected"]), "muted")
	var oc := str(o.get("on_complete", ""))
	if ok and not oc.is_empty():
		r.line(oc, "muted")
	boxes[key] = {"caja": box, "proxima": now() + int(INTERVALS[box]) * DAY + (0 if ok else 600), "aciertos": int(st.get("aciertos", 0)) + int(ok),
		"fallos": int(st.get("fallos", 0)) + int(not ok)}
	g.set_meta("repaso_actual", "")
	g.save()
	c.emit("repaso.answered", {"key": key, "correct": ok, "box": box})
	var left := due(g).size()
	r.line("Te quedan %d por hoy. Siguiente: repaso" % left if left > 0 else "Por hoy has terminado el repaso. ¡Bien hecho!", "muted")
	return r


static func _next_text(g: DojoGame) -> String:
	var boxes := _boxes(g)
	var soonest := 0
	for it: Dictionary in pool(g):
		var p := int(boxes.get(it["key"], {}).get("proxima", 0))
		if soonest == 0 or p < soonest:
			soonest = p
	var days := int(ceil(float(soonest - now()) / DAY))
	return "hoy" if days <= 0 else ("mañana" if days == 1 else "en %d días" % days)


static func _review_state(c: CommandContext, _a: Dictionary) -> CommandResult:
	var g := _game(c)
	if g == null:
		return CommandResult.error("El repaso necesita una partida.")
	var all := pool(g)
	var boxes := _boxes(g)
	var count := [0, 0, 0, 0, 0, 0]
	for it: Dictionary in all:
		count[int(boxes.get(it["key"], {}).get("caja", 0))] += 1
	var r := CommandResult.new()
	r.line("Repaso espaciado · %d preguntas de %d misiones completadas" % [all.size(), _missions_done(g)], "accent")
	r.line("Pendientes hoy: %d" % due(g).size(), "normal")
	var rows: Array = []
	for i in INTERVALS.size():
		rows.append(["caja %d" % i, "cada %s" % ("vez" if INTERVALS[i] == 0 else "%d día(s)" % INTERVALS[i]), str(count[i])])
	r.table(PackedStringArray(["caja", "se repasa", "preguntas"]), rows)
	r.line("Cada acierto sube la pregunta una caja (la ves menos); un fallo la devuelve a la caja 0.", "muted")
	return r


static func _missions_done(g: DojoGame) -> int:
	var n := 0
	for m: Dictionary in g.catalog.missions:
		n += int(g.progress.is_mission_completed(m["id"]))
	return n


# ── Perfil ───────────────────────────────────────────────────────────────────

static func _profile(c: CommandContext, _a: Dictionary) -> CommandResult:
	var g := _game(c)
	if g == null:
		return CommandResult.error("El perfil necesita una partida.")
	# Unidad → [dominadas, practicadas, vistas, total]
	var units: Dictionary = {}
	var order: Array = []
	for m: Dictionary in g.catalog.missions:
		var u: String = m["unit"]
		if not units.has(u):
			units[u] = {"dominada": [], "practicada": [], "vista": [], "pendiente": []}
			order.append(u)
		for comp: String in m.get("competencies", {}).get("trains", []):
			var seen := false
			for k: String in units[u]:
				if comp in units[u][k]:
					seen = true
			if seen:
				continue
			var st := g.progress.competency_state(comp)
			units[u][st if st in ["dominada", "practicada", "vista"] else "pendiente"].append(comp)
	# Mismo orden que el mapa del curso.
	var map_order: Array = MapCommands.load_map().get("unidades", []).map(func(x: Dictionary) -> String: return x["unit"])
	order.sort_custom(func(x: String, y: String) -> bool:
		var ix := map_order.find(x)
		var iy := map_order.find(y)
		return (ix if ix >= 0 else 999) < (iy if iy >= 0 else 999))
	var totals := {"dominada": 0, "practicada": 0, "vista": 0, "pendiente": 0}
	var rows: Array = []
	for u: String in order:
		var d: Dictionary = units[u]
		var n := 0
		for k: String in d:
			totals[k] += d[k].size()
			n += d[k].size()
		if n == 0:
			continue
		rows.append([u, _bar(d["dominada"].size(), d["practicada"].size(), d["vista"].size(), n),
			"%d/%d" % [d["dominada"].size() + d["practicada"].size(), n]])
	var r := CommandResult.new()
	var all: int = totals["dominada"] + totals["practicada"] + totals["vista"] + totals["pendiente"]
	r.line("Tu perfil · %d competencias: %d dominadas · %d practicadas · %d vistas · %d por aprender" % [
		all, totals["dominada"], totals["practicada"], totals["vista"], totals["pendiente"]], "accent")
	r.table(PackedStringArray(["unidad", "■ dominada  ▣ practicada  □ vista  · pendiente", "hechas"]), rows)
	r.line("Dominada = superaste la prueba de dominio sin el ejemplo resuelto. Practicada = completaste la misión.", "muted")
	var next := _next_skill(g)
	if not next.is_empty():
		r.line("Para avanzar: %s" % next, "normal")
	r.line("Repasa lo aprendido con: repaso", "muted")
	return r


static func _bar(dom: int, prac: int, seen: int, total: int) -> String:
	return "■".repeat(dom) + "▣".repeat(prac) + "□".repeat(seen) + "·".repeat(maxi(total - dom - prac - seen, 0))


## La primera misión disponible que entrena algo que aún no tienes practicado.
static func _next_skill(g: DojoGame) -> String:
	for m: Dictionary in g.catalog.missions:
		if g.progress.is_mission_completed(m["id"]) or not g.progress.requirements_met(m):
			continue
		return "%s · %s (mission start %s)" % [m["id"], m["title"], m["id"]]
	return ""


# ── Explícamelo más simple ──────────────────────────────────────────────────

static func register_explain(reg: CommandRegistry) -> void:
	reg.register(Command.new("explicame", "RONIN te vuelve a explicar el paso actual, más despacio y con las palabras clave desglosadas.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _simpler(c, a), "mentor"))


## Términos del glosario y siglas que aparecen en un texto (sin repetir).
static func key_terms(c: CommandContext, text: String) -> Array:
	var low := text.to_lower()
	var out: Array = []
	var seen := {}
	for t: Dictionary in c.library.terms:
		var names: Array = [t["term"]] + t.get("aliases", [])
		for n: String in names:
			if n.length() >= 3 and _has_word(low, n.to_lower()) and not seen.has(t["id"]):
				seen[t["id"]] = true
				out.append({"name": t["term"], "text": t["short"]})
	for s: Dictionary in AkaCommands.siglas():
		var sig: String = s["sigla"]
		if _has_word(text, sig) and not seen.has("aka:" + sig):
			seen["aka:" + sig] = true
			out.append({"name": sig, "text": "%s: %s" % [s["en"], s["es"]]})
	return out


static func _has_word(text: String, word: String) -> bool:
	var i := text.find(word)
	while i >= 0:
		var before := i == 0 or not _is_letter(text[i - 1])
		var after := i + word.length() >= text.length() or not _is_letter(text[i + word.length()])
		if before and after:
			return true
		i = text.find(word, i + 1)
	return false


static func _is_letter(ch: String) -> bool:
	return ch.to_lower() != ch.to_upper() or (ch >= "0" and ch <= "9")


static func _simpler(c: CommandContext, _a: Dictionary) -> CommandResult:
	var g := _game(c)
	if g == null or not g.runner.is_running():
		return CommandResult.error("No hay ningún paso en curso. Empieza una misión: mission list")
	var o := g.runner.current_objective()
	var teach := str(o.get("teach_simple", o.get("teach", "")))
	# Una pregunta sin lección propia se apoya en la lección del paso anterior que la tenga.
	if teach.is_empty():
		var i := g.runner.index - 1
		while i >= 0 and teach.is_empty():
			var prev: Dictionary = g.runner.objectives[i]
			teach = str(prev.get("teach_simple", prev.get("teach", "")))
			i -= 1
	var r := CommandResult.new()
	if teach.is_empty():
		r.line("Este paso no tiene lección; repasa el briefing con mission brief.", "muted")
	else:
		var parts := teach.split("\n")
		r.line("Otra vez, despacio · " + parts[0], "accent")
		for i in range(1, parts.size()):
			r.line("  %d. %s" % [i, parts[i]])
	var terms := key_terms(c, teach + " " + str(o.get("text", "")))
	if not terms.is_empty():
		r.line("")
		r.line("Palabras clave de este paso:", "accent")
		for t: Dictionary in terms.slice(0, 8):
			r.line("  · %s — %s" % [t["name"], t["text"]], "normal")
	r.line("")
	r.line("Lo que tienes que hacer ahora: " + str(o.get("text", "")), "muted")
	r.line("¿Sigues atascado? hint te da una pista; explain <término> y aka <SIGLA> amplían.", "muted")
	c.emit("help.simpler", {"objective": str(o.get("id", ""))})
	return r
