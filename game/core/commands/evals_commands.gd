class_name EvalsCommands
extends RefCounted
## P2 · Evals y observabilidad.
##   evals run <versión>                      golden set: respuesta final, trayectoria, segmentos y coste
##   evals trace <versión> <tarea>            la trayectoria de una tarea, paso a paso
##   evals compare <a> <b>                    segmento a segmento: qué mejora y qué empeora
##   evals gate <versión> [--media] [--segmento] [--prohibidas]   puerta de regresión (la de CI)
##   monitor dashboard [--muestreo <tasa>]    una semana en producción, con un juez que puntúa una muestra
##   monitor trace <día>                      la traza más lenta del día, span a span
##   monitor drift                            deriva de la entrada: días 1–4 frente a 5–7 (PSI)
## Las trayectorias están grabadas (content/evals/agente.json); todo lo demás se calcula aquí.

const AGENT_PATH := "res://content/evals/agente.json"
const PROD_PATH := "res://content/evals/produccion.json"
const VERSIONS := ["v1", "v2", "v3"]
const SEGMENTS := ["pedidos", "reembolsos", "seguridad"]
static var _agent: Dictionary = {}
static var _prod: Dictionary = {}


static func register(reg: CommandRegistry) -> void:
	var ver := func(n: String) -> CommandSignature: return CommandSignature.new().pos(n, "versión del agente: v1, v2 o v3", "string", true, VERSIONS)
	reg.register(Command.new("evals run", "Pasa el golden set a una versión del agente: respuesta final, trayectoria y segmentos.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _run(c, a), "lenguaje")
		.with_signature(ver.call("version").example("evals run v1")))
	reg.register(Command.new("evals trace", "La trayectoria de una tarea: cada herramienta que llamó el agente y por qué pasa o falla.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _trace(c, a), "lenguaje")
		.with_signature(ver.call("version").pos("tarea", "t01 … t12").example("evals trace v2 t11")))
	reg.register(Command.new("evals compare", "Compara dos versiones segmento a segmento.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _compare(c, a), "lenguaje")
		.with_signature(ver.call("a").pos("b", "versión del agente: v1, v2 o v3", "string", true, VERSIONS).example("evals compare v1 v2")))
	reg.register(Command.new("evals gate", "Puerta de regresión: ¿se puede desplegar esta versión? (lo que correría en CI)",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _gate(c, a), "lenguaje")
		.with_signature(ver.call("version")
			.opt("media", "tasa mínima de tareas bien (respuesta y trayectoria)", "float", 0.7)
			.opt("segmento", "tasa mínima en CADA segmento", "float", 0.6)
			.opt("prohibidas", "máximo de acciones prohibidas", "int", 0)
			.example("evals gate v2 --media 0.7 --segmento 0.6 --prohibidas 0")))
	reg.register(Command.new("monitor dashboard", "Una semana del agente en producción: latencia, errores, coste y calidad según un juez muestreado.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _dashboard(c, a), "deteccion")
		.with_signature(CommandSignature.new().opt("muestreo", "fracción de conversaciones que puntúa el juez (0.01 = 1 %)", "float", 0.01).example("monitor dashboard --muestreo 0.1")))
	reg.register(Command.new("monitor trace", "La traza más lenta de un día, span a span.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _mtrace(c, a), "deteccion")
		.with_signature(CommandSignature.new().pos("dia", "día (1 … 7)", "int").example("monitor trace 6")))
	reg.register(Command.new("monitor drift", "Deriva de la entrada: mezcla de temas de los días 1–4 frente a los 5–7 (PSI).",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _drift(c, a), "deteccion")
		.with_signature(CommandSignature.new()))


static func agent() -> Dictionary:
	if _agent.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(AGENT_PATH))
		_agent = d if d is Dictionary else {}
	return _agent


static func prod() -> Dictionary:
	if _prod.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROD_PATH))
		_prod = d if d is Dictionary else {}
	return _prod


static func _tool(call: String) -> String:
	return call.get_slice("(", 0)


## Juzga una tarea: {"final_ok", "traj_ok", "ok", "steps", "forbidden", "reasons": [...]}
static func judge(task: Dictionary, version: String) -> Dictionary:
	var run: Dictionary = task[version]
	var calls: Array = run["llamadas"]
	var tools: Array = calls.map(func(x: String) -> String: return _tool(x))
	var reasons := PackedStringArray()
	var forbidden := false
	var approved := false
	for t: String in tools:
		if t == "pedir_aprobacion":
			approved = true
		if t == "reembolsar" and not approved:
			forbidden = true
			reasons.append("reembolsar sin pedir_aprobacion antes (regla de la forja)")
		if t in task["prohibidas"]:
			forbidden = true
			reasons.append("%s está prohibida en esta tarea" % t)
	for e: String in task["esperadas"]:
		if not e in tools:
			reasons.append("no ha llamado a %s" % e)
	var steps := calls.size()
	var limit := int(task["optimo"]) + 1
	if steps > limit:
		reasons.append("%d pasos para una tarea que se hace en %d" % [steps, int(task["optimo"])])
	var traj_ok := reasons.is_empty()
	var final_ok := bool(run["ok"])
	if not final_ok:
		reasons.insert(0, "respuesta mal: " + str(run.get("por_que", "")))
	return {"final_ok": final_ok, "traj_ok": traj_ok, "ok": final_ok and traj_ok, "steps": steps, "forbidden": forbidden, "reasons": reasons}


## Resumen de una versión sobre el golden set.
static func summary(version: String) -> Dictionary:
	var tasks: Array = agent()["tareas"]
	var seg := {}
	for s: String in SEGMENTS:
		seg[s] = [0, 0]
	var final_ok := 0
	var ok := 0
	var forbidden := 0
	var tokens := 0
	for t: Dictionary in tasks:
		var j := judge(t, version)
		final_ok += int(j["final_ok"])
		ok += int(j["ok"])
		forbidden += int(j["forbidden"])
		seg[t["segmento"]][0] += int(j["ok"])
		seg[t["segmento"]][1] += 1
		tokens += int(agent()["tokens_base"][version]) + int(agent()["tokens_por_paso"][version]) * int(j["steps"])
	var rates := {}
	for s: String in SEGMENTS:
		rates[s] = float(seg[s][0]) / maxf(seg[s][1], 1)
	var n := tasks.size()
	return {"final_rate": float(final_ok) / n, "final_ok": final_ok, "pass_rate": float(ok) / n, "ok": ok, "n": n, "forbidden": forbidden, "segments": rates, "counts": seg, "tokens": tokens}


static func _task(id: String) -> Dictionary:
	for t: Dictionary in agent()["tareas"]:
		if t["id"] == id:
			return t
	return {}


static func _run(c: CommandContext, a: Dictionary) -> CommandResult:
	var v: String = a["version"]
	var r := CommandResult.new()
	r.line("Golden set del agente · %s: %s" % [v, agent()["versiones"][v]], "accent")
	var rows: Array = []
	for t: Dictionary in agent()["tareas"]:
		var j := judge(t, v)
		var why: String = "" if j["ok"] else (j["reasons"] as PackedStringArray)[0]
		rows.append([t["id"], t["segmento"], "✓" if j["final_ok"] else "✗", "✓" if j["traj_ok"] else "✗", str(j["steps"]), why])
	r.table(PackedStringArray(["tarea", "segmento", "respuesta", "trayectoria", "pasos", "por qué falla"]), rows)
	var s := summary(v)
	r.line("Solo mirando la respuesta final: %d/%d = %.3f" % [s["final_ok"], s["n"], s["final_rate"]], "normal")
	r.line("Respuesta Y trayectoria bien: %d/%d = %.3f · acciones prohibidas: %d" % [s["ok"], s["n"], s["pass_rate"], s["forbidden"]], "normal")
	var segs := PackedStringArray()
	for sg: String in SEGMENTS:
		segs.append("%s %d/%d" % [sg, s["counts"][sg][0], s["counts"][sg][1]])
	r.line("Por segmento: " + " · ".join(segs) + " · tokens: %d" % s["tokens"], "muted")
	r.line("Una tarea por dentro: evals trace %s <tarea>" % v, "muted")
	var seg_labels := PackedStringArray()
	var seg_rates := PackedFloat64Array()
	for sg: String in SEGMENTS:
		seg_labels.append(sg)
		seg_rates.append(float(s["segments"][sg]))
	c.emit("evals.run", {"version": v, "final_rate": s["final_rate"], "pass_rate": s["pass_rate"], "forbidden": s["forbidden"], "tokens": s["tokens"], "seg_labels": seg_labels, "seg_rates": seg_rates})
	return r


static func _trace(c: CommandContext, a: Dictionary) -> CommandResult:
	var t := _task(a["tarea"])
	if t.is_empty():
		return CommandResult.error("Tareas: t01 … t12")
	var v: String = a["version"]
	var run: Dictionary = t[v]
	var j := judge(t, v)
	var r := CommandResult.new()
	r.line("%s · %s · «%s»" % [v, t["id"], t["texto"]], "accent")
	var k := 0
	for call: String in run["llamadas"]:
		k += 1
		r.line("  %d. 🔧 %s" % [k, call], "data")
	if k == 0:
		r.line("  (ninguna herramienta)", "muted")
	r.line("  → 🤖 «%s»" % run["final"], "data")
	r.line("Esperado: %s · se hace en %d pasos" % [", ".join(PackedStringArray(t["esperadas"])) if not (t["esperadas"] as Array).is_empty() else "ninguna herramienta", int(t["optimo"])], "muted")
	r.line("Juez de la respuesta final: %s" % ("✓ correcta" if j["final_ok"] else "✗ incorrecta"), "ok" if j["final_ok"] else "warn")
	r.line("Trayectoria: %s" % ("✓ correcta" if j["traj_ok"] else "✗ " + "; ".join(j["reasons"])), "ok" if j["traj_ok"] else "warn")
	var tools: Array = (run["llamadas"] as Array).map(func(x: String) -> String: return _tool(x))
	c.emit("evals.trace", {"version": v, "task": t["id"], "final_ok": j["final_ok"], "traj_ok": j["traj_ok"], "forbidden": j["forbidden"], "tools": ",".join(PackedStringArray(tools))})
	return r


static func _compare(c: CommandContext, a: Dictionary) -> CommandResult:
	var sa := summary(a["a"])
	var sb := summary(a["b"])
	var rows: Array = []
	var worse := PackedStringArray()
	for sg: String in SEGMENTS:
		var d: float = sb["segments"][sg] - sa["segments"][sg]
		if d < -1e-9:
			worse.append(sg)
		rows.append([sg, "%.2f" % sa["segments"][sg], "%.2f" % sb["segments"][sg], "%+.2f" % d, "▼ empeora" if d < -1e-9 else ("▲" if d > 1e-9 else "=")])
	rows.append(["MEDIA", "%.3f" % sa["pass_rate"], "%.3f" % sb["pass_rate"], "%+.3f" % (sb["pass_rate"] - sa["pass_rate"]), ""])
	rows.append(["prohibidas", str(sa["forbidden"]), str(sb["forbidden"]), "%+d" % (sb["forbidden"] - sa["forbidden"]), ""])
	rows.append(["tokens", str(sa["tokens"]), str(sb["tokens"]), "%+.0f %%" % ((float(sb["tokens"]) / sa["tokens"] - 1.0) * 100.0), ""])
	var r := CommandResult.new()
	r.line("%s frente a %s · tasa de tareas bien (respuesta y trayectoria)" % [a["a"], a["b"]], "accent")
	r.table(PackedStringArray(["segmento", a["a"], a["b"], "cambio", ""]), rows)
	if not worse.is_empty():
		r.line("La media puede subir y un segmento hundirse: mira siempre por segmento.", "warn")
	c.emit("evals.compare", {"a": a["a"], "b": a["b"], "worse": ",".join(worse), "delta": sb["pass_rate"] - sa["pass_rate"]})
	return r


static func _gate(c: CommandContext, a: Dictionary) -> CommandResult:
	var v: String = a["version"]
	var s := summary(v)
	var fails := PackedStringArray()
	if s["pass_rate"] < float(a["media"]) - 1e-9:
		fails.append("media %.3f < %.2f" % [s["pass_rate"], float(a["media"])])
	for sg: String in SEGMENTS:
		if s["segments"][sg] < float(a["segmento"]) - 1e-9:
			fails.append("segmento %s %.2f < %.2f" % [sg, s["segments"][sg], float(a["segmento"])])
	if int(s["forbidden"]) > int(a["prohibidas"]):
		fails.append("%d acciones prohibidas (máximo %d)" % [s["forbidden"], int(a["prohibidas"])])
	var r := CommandResult.new()
	r.line("Puerta de regresión para %s · media ≥ %.2f · cada segmento ≥ %.2f · prohibidas ≤ %d" % [v, float(a["media"]), float(a["segmento"]), int(a["prohibidas"])], "accent")
	if fails.is_empty():
		r.line("✓ PASA: %s se puede desplegar." % v, "ok")
	else:
		r.line("✗ BLOQUEADA: %s no se despliega." % v, "warn")
		for f in fails:
			r.line("  · " + f, "warn")
	c.emit("evals.gate", {"version": v, "passed": fails.is_empty(), "reasons": "; ".join(fails), "media": float(a["media"]), "segmento": float(a["segmento"]), "prohibidas": int(a["prohibidas"])})
	return r


# ── Producción ───────────────────────────────────────────────────────────────

static func true_quality(day: Dictionary) -> float:
	var q := 0.0
	for t: String in day["mezcla"]:
		q += float(day["mezcla"][t]) * float(prod()["calidad_real"][t])
	return q


## Lo que ve un juez que puntúa una muestra: {"n", "ok", "mean", "half"} (intervalo del 95 %).
static func sampled(day: Dictionary, rate: float) -> Dictionary:
	var n := maxi(1, int(round(rate * int(day["peticiones"]))))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(day["dia"]) * 7919 + int(round(rate * 10000))
	var q := true_quality(day)
	var ok := 0
	for i in n:
		ok += int(rng.randf() < q)
	var p := float(ok) / n
	return {"n": n, "ok": ok, "mean": p, "half": 1.96 * sqrt(maxf(p * (1.0 - p), 1e-6) / n)}


static func _dashboard(c: CommandContext, a: Dictionary) -> CommandResult:
	var rate := clampf(float(a["muestreo"]), 0.001, 1.0)
	var rows: Array = []
	var est := {}
	var xs := PackedFloat64Array()
	var q_est := PackedFloat64Array()
	var q_real := PackedFloat64Array()
	for d: Dictionary in prod()["dias"]:
		var s := sampled(d, rate)
		est[str(int(d["dia"]))] = s
		xs.append(float(d["dia"]))
		q_est.append(float(s["mean"]))
		q_real.append(true_quality(d))
		rows.append([str(int(d["dia"])), str(int(d["peticiones"])), "%.1f s" % d["p50"], "%.1f s" % d["p95"], "%.1f %%" % (float(d["error_herramientas"]) * 100.0), str(int(d["tokens"]) / 1000) + " k", "%.2f ± %.2f (n=%d)" % [s["mean"], s["half"], s["n"]]])
	var r := CommandResult.new()
	r.line("Agente de atención v3 en producción · 7 días · el juez puntúa el %s de las conversaciones" % ("%.0f %%" % (rate * 100.0) if rate >= 0.01 else "%.1f %%" % (rate * 100.0)), "accent")
	r.table(PackedStringArray(["día", "peticiones", "p50", "p95", "errores herr.", "tokens", "calidad (juez)"]), rows)
	r.line("± es el intervalo del 95 %: con pocas conversaciones puntuadas, la estimación baila.", "muted")
	r.line("La traza más lenta de un día: monitor trace <día> · ¿cambia lo que entra?: monitor drift", "muted")
	var d1: Dictionary = est["1"]
	var d5: Dictionary = est["5"]
	var d6: Dictionary = est["6"]
	var separated: bool = d6["mean"] + d6["half"] < d1["mean"] - d1["half"]
	c.emit("monitor.dashboard", {"rate": rate, "q1": d1["mean"], "q5": d5["mean"], "q6": d6["mean"], "q6_half": d6["half"], "drop_visible": separated, "x": xs, "estimada": q_est, "real": q_real})
	return r


static func _mtrace(c: CommandContext, a: Dictionary) -> CommandResult:
	var tr: Dictionary = prod()["traza_lenta"]
	var day := int(a["dia"])
	var r := CommandResult.new()
	if day != int(tr["dia"]):
		r.line("Día %d: la traza más lenta tarda %.1f s y no tiene nada raro (mismos spans que siempre). Mira un día en el que el p95 se dispare." % [day, _day(day).get("p95", 2.4)], "muted")
		c.emit("monitor.trace", {"day": day, "slowest": ""})
		return r
	var total := 0
	var worst := ""
	var worst_ms := 0
	var by_tool := {}
	for s: Dictionary in tr["spans"]:
		total += int(s["ms"])
		var base: String = String(s["nombre"]).get_slice(" ·", 0)
		by_tool[base] = int(by_tool.get(base, 0)) + int(s["ms"])
	for k: String in by_tool:
		if by_tool[k] > worst_ms:
			worst_ms = by_tool[k]
			worst = k
	r.line("Traza %s · día %d · «%s» · %.1f s en total" % [tr["id"], day, tr["texto"], total / 1000.0], "accent")
	var rows: Array = []
	for s: Dictionary in tr["spans"]:
		var w := int(round(float(s["ms"]) / total * 40))
		rows.append(["  ".repeat(int(s["nivel"])) + s["nombre"], "%d ms" % int(s["ms"]), ("▓" if s.get("error", false) else "█").repeat(maxi(w, 1))])
	r.table(PackedStringArray(["span", "duración", ""]), rows)
	r.line("Donde se va el tiempo: %s, %.1f s de %.1f (▓ = error)." % [worst, worst_ms / 1000.0, total / 1000.0], "normal")
	c.emit("monitor.trace", {"day": day, "slowest": worst, "total_ms": total})
	return r


static func _day(n: int) -> Dictionary:
	for d: Dictionary in prod()["dias"]:
		if int(d["dia"]) == n:
			return d
	return {}


## Population Stability Index entre dos distribuciones (con suelo para las proporciones cero).
static func psi(expected: Array, actual: Array) -> float:
	var total := 0.0
	for i in expected.size():
		var e := maxf(float(expected[i]), 0.001)
		var x := maxf(float(actual[i]), 0.001)
		total += (x - e) * log(x / e)
	return total


static func _drift(c: CommandContext, _a: Dictionary) -> CommandResult:
	var topics: Array = prod()["temas"]
	var base := []
	var now := []
	for t: String in topics:
		var b := 0.0
		var x := 0.0
		for d: Dictionary in prod()["dias"]:
			if int(d["dia"]) <= 4:
				b += float(d["mezcla"][t]) / 4.0
			else:
				x += float(d["mezcla"][t]) / 3.0
		base.append(b)
		now.append(x)
	var value := psi(base, now)
	var rows: Array = []
	var grew := ""
	var grew_d := -1.0
	for i in topics.size():
		rows.append([topics[i], "%.0f %%" % (base[i] * 100.0), "%.0f %%" % (now[i] * 100.0)])
		if now[i] - base[i] > grew_d:
			grew_d = now[i] - base[i]
			grew = topics[i]
	var r := CommandResult.new()
	r.line("Deriva de la entrada · mezcla de temas, días 1–4 frente a días 5–7", "accent")
	r.table(PackedStringArray(["tema", "días 1–4", "días 5–7"]), rows)
	var verdict := "estable" if value < 0.1 else ("cambio moderado" if value < 0.25 else "cambio importante")
	r.line("PSI (Population Stability Index) = %.2f → %s (regla habitual: < 0,1 estable · 0,1–0,25 moderado · > 0,25 importante)" % [value, verdict], "normal")
	r.line("Lo que más crece: %s. ¿Estaba en tu golden set? (evals run v3: no hay ninguna tarea de ese tema)" % grew, "muted")
	c.emit("monitor.drift", {"psi": value, "grew": grew})
	return r
