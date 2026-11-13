class_name InferCommands
extends RefCounted
## T12 · Inferencia eficiente: por qué un LLM es rápido o caro de servir. Todo son cuentas
## reales (sin modelo): caché KV, batching, decodificación especulativa y MoE.
##   infer kv --tokens N              trabajo para generar N tokens, con y sin caché KV
##   infer batch --peticiones B       rendimiento (tokens/s) según el tamaño de lote
##   infer spec --borrador k --acierto A   decodificación especulativa: tokens por pasada y aceleración
##   infer moe --expertos E --activos k    MoE: parámetros totales frente a los activos por token

const BATCH_CAP := 32
const BASE_TOKENS := 2000.0  # tokens/s que da una petición sola (unidades del laboratorio)


static func register(reg: CommandRegistry) -> void:
	var add := func(path: String, summary: String, handler: Callable, sig: CommandSignature) -> void:
		reg.register(Command.new(path, summary, handler, "lenguaje").with_signature(sig))
	add.call("infer kv", "Caché KV: el trabajo de generar N tokens con y sin caché (cuadrático frente a lineal).",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _kv(c, a),
		CommandSignature.new().opt("tokens", "tokens a generar", "int", 64).example("infer kv --tokens 64"))
	add.call("infer batch", "Batching: cuántos tokens por segundo según el tamaño de lote.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _batch(c, a),
		CommandSignature.new().opt("peticiones", "peticiones en el lote", "int", 1).example("infer batch --peticiones 16"))
	add.call("infer spec", "Decodificación especulativa: tokens por pasada del modelo grande y aceleración.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _spec(c, a),
		CommandSignature.new().opt("borrador", "tokens que propone el modelo borrador", "int", 4).opt("acierto", "probabilidad de que el grande acepte cada token (0–1)", "float", 0.8).example("infer spec --borrador 4 --acierto 0.8"))
	add.call("infer moe", "Mixture of Experts: parámetros totales frente a los que se activan por token.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _moe(c, a),
		CommandSignature.new().opt("expertos", "número de expertos", "int", 8).opt("activos", "expertos activos por token (top-k)", "int", 2).example("infer moe --expertos 8 --activos 2"))


static func _kv(c: CommandContext, a: Dictionary) -> CommandResult:
	var n := clampi(int(a["tokens"]), 1, 1024)
	# Sin caché, generar el token t recalcula K y V de los t anteriores: trabajo acumulado t(t+1)/2.
	# Con caché, cada token solo calcula K,V de su posición: trabajo acumulado t.
	var sin_cache := n * (n + 1) / 2
	var con_cache := n
	var xs := PackedFloat64Array()
	var y_sin := PackedFloat64Array()
	var y_con := PackedFloat64Array()
	var step := maxi(1, int(n / 24.0))
	for t in range(1, n + 1, step):
		xs.append(float(t))
		y_sin.append(float(t * (t + 1) / 2))
		y_con.append(float(t))
	xs.append(float(n))
	y_sin.append(float(sin_cache))
	y_con.append(float(con_cache))
	var r := CommandResult.new()
	r.line("Caché KV · generar %d tokens" % n, "accent")
	r.line("Sin caché: %d cálculos de K,V (recalcula el pasado en cada token) · O(N²)" % sin_cache, "data")
	r.line("Con caché: %d cálculos (guarda K,V y los reutiliza) · O(N)" % con_cache, "data")
	r.line("La caché KV ahorra un factor %d×: es lo que hace viable generar textos largos." % ((n + 1) / 2), "normal")
	c.emit("infer.kv", {"tokens": n, "sin_cache": sin_cache, "con_cache": con_cache, "factor": (n + 1) / 2, "x": xs, "sin": y_sin, "con": y_con})
	return r


static func _batch(c: CommandContext, a: Dictionary) -> CommandResult:
	var b := clampi(int(a["peticiones"]), 1, 128)
	var xs := PackedFloat64Array()
	var ys := PackedFloat64Array()
	for k in range(1, maxi(b, BATCH_CAP) + 1):
		xs.append(float(k))
		ys.append(BASE_TOKENS * mini(k, BATCH_CAP))
	var tput := BASE_TOKENS * mini(b, BATCH_CAP)
	var r := CommandResult.new()
	r.line("Batching · lote de %d peticiones" % b, "accent")
	r.line("Rendimiento: %d tokens/s (una sola petición da %d)." % [int(tput), int(BASE_TOKENS)], "data")
	if b <= BATCH_CAP:
		r.line("El modelo procesa el lote a la vez: %d× el rendimiento casi sin coste, porque la memoria estaba ociosa." % b, "normal")
	else:
		r.line("A partir de %d peticiones la memoria se llena: el rendimiento se estanca y la latencia sube. Más lote ya no ayuda." % BATCH_CAP, "warn")
	c.emit("infer.batch", {"peticiones": b, "throughput": tput, "cap": BATCH_CAP, "x": xs, "y": ys})
	return r


static func _spec(c: CommandContext, a: Dictionary) -> CommandResult:
	var k := clampi(int(a["borrador"]), 1, 16)
	var al := clampf(float(a["acierto"]), 0.0, 1.0)
	# El borrador propone k tokens; el grande los verifica en UNA pasada. Se aceptan los tokens
	# hasta el primer fallo; el grande aporta además 1 token. Tokens esperados por pasada:
	var aceptados := 0.0
	var p := al
	for _i in k:
		aceptados += p
		p *= al
	var por_pasada := 1.0 + aceptados
	var r := CommandResult.new()
	r.line("Decodificación especulativa · borrador de %d tokens · acierto %.2f" % [k, al], "accent")
	r.line("Tokens por pasada del modelo grande: %.2f (sin especular sería 1)." % por_pasada, "data")
	r.line("Aceleración ≈ %.2f×: el borrador (barato) adelanta trabajo y el grande solo verifica." % por_pasada, "normal")
	if al < 0.5:
		r.line("Con poco acierto, el borrador falla pronto y casi no ayuda: necesita parecerse al grande.", "warn")
	c.emit("infer.spec", {"borrador": k, "acierto": al, "por_pasada": por_pasada, "aceleracion": por_pasada})
	return r


static func _moe(c: CommandContext, a: Dictionary) -> CommandResult:
	var e := clampi(int(a["expertos"]), 2, 128)
	var k := clampi(int(a["activos"]), 1, e)
	var ratio := float(k) / float(e)
	var r := CommandResult.new()
	r.line("Mixture of Experts · %d expertos · %d activos por token (top-%d)" % [e, k, k], "accent")
	r.line("Parámetros totales: el modelo sabe mucho (los %d expertos)." % e, "data")
	r.line("Cómputo por token: solo %d de %d expertos se encienden → %.0f %% del coste." % [k, e, ratio * 100.0], "data")
	r.line("MoE separa CAPACIDAD (parámetros totales) de COSTE (parámetros activos): un modelo enorme que cuesta como uno pequeño.", "normal")
	c.emit("infer.moe", {"expertos": e, "activos": k, "ratio": ratio,
		"labels": PackedStringArray(["parámetros totales", "parámetros activos/token"]), "values": PackedFloat64Array([1.0, ratio])})
	return r
