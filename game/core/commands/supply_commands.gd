class_name SupplyCommands
extends RefCounted
## A6 · Supply chain e infraestructura de IA (laboratorio simulado).


static func register(reg: CommandRegistry) -> void:
	reg.register(Command.new("supply forja", "Crea el pipeline de ML de la forja: datos, entrenamiento, artefactos y serving.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _create(c, a), "supply")
		.with_signature(CommandSignature.new().pos("nombre", "nombre del pipeline").example("supply forja taller")))
	reg.register(Command.new("supply sbom", "Inventario (AI-BOM) del pipeline: componentes, origen, formato, huella y firma.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _sbom(c, a), "supply")
		.with_signature(CommandSignature.new().pos("pipeline", "pipeline de ML", "pipeline")))
	reg.register(Command.new("supply inspect", "Examina un componente: escaneo del artefacto, huellas, filas del dataset o datos del paquete.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _inspect(c, a), "supply")
		.with_signature(CommandSignature.new().pos("pipeline", "pipeline de ML", "pipeline").pos("componente", "id del componente").example("supply inspect taller detector-grietas")))
	reg.register(Command.new("supply train", "Entrena el clasificador con los datasets del pipeline y prueba si tiene una puerta trasera.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _train(c, a), "supply")
		.with_signature(CommandSignature.new().pos("pipeline", "pipeline de ML", "pipeline")))
	reg.register(Command.new("supply load", "Carga un artefacto (modelo o adapter) en el servidor de modelos.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _load(c, a), "supply")
		.with_signature(CommandSignature.new().pos("pipeline", "pipeline de ML", "pipeline").pos("artefacto", "id del artefacto").example("supply load taller clasificador-acero")))
	reg.register(Command.new("supply convert", "Convierte un artefacto interno de pickle a safetensors.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _convert(c, a), "supply")
		.with_signature(CommandSignature.new().pos("pipeline", "pipeline de ML", "pipeline").pos("artefacto", "id del artefacto")))
	reg.register(Command.new("supply install", "Instala una dependencia de Python en la imagen de serving.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _install(c, a), "supply")
		.with_signature(CommandSignature.new().pos("pipeline", "pipeline de ML", "pipeline").pos("paquete", "nombre del paquete").example("supply install taller forja-metrics")))
	reg.register(Command.new("supply deploy", "Construye la imagen del servidor de modelos y la despliega.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _deploy(c, a), "supply")
		.with_signature(CommandSignature.new().pos("pipeline", "pipeline de ML", "pipeline")))
	reg.register(Command.new("supply probe", "La vista de alguien de fuera: ¿llega al servidor? ¿qué hay en las capas de la imagen?",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _probe(c, a), "supply")
		.with_signature(CommandSignature.new().pos("pipeline", "pipeline de ML", "pipeline")))
	reg.register(Command.new("supply defend", "Activa o desactiva un control de la cadena de suministro.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _defend(c, a), "supply")
		.with_signature(CommandSignature.new()
			.pos("pipeline", "pipeline de ML", "pipeline")
			.pos("defensa", "control", "string", true, Array(MockMlPipeline.DEFENSES))
			.pos("estado", "on u off", "string", true, ["on", "off"])))
	reg.register(Command.new("supply attack", "Batería de ataques A6 (cada uno sobre una copia nueva del pipeline).",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _attack(c, a), "supply")
		.with_signature(CommandSignature.new().pos("pipeline", "pipeline de ML", "pipeline")))
	reg.register(Command.new("supply eval", "Tareas legítimas del pipeline: entrenar, cargar el modelo, instalar y servir.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _eval(c, a), "supply")
		.with_signature(CommandSignature.new().pos("pipeline", "pipeline de ML", "pipeline")))


static func _active(p: MockMlPipeline) -> String:
	var on := PackedStringArray()
	for d in MockMlPipeline.DEFENSES:
		if p.defenses[d]:
			on.append(d)
	return ",".join(on) if not on.is_empty() else "ninguna"


static func _need(p: MockMlPipeline, id: String, group: String = "") -> String:
	var comp := p.component(id)
	var ok := not comp.is_empty()
	if ok and group == "artifact":
		ok = comp.has("format") and comp.has("signed_by")
	elif ok and group == "package":
		ok = comp.has("install_script")
	if ok:
		return ""
	var ids := PackedStringArray()
	var src: Array = p.artifacts if group == "artifact" else (p.packages if group == "package" else [])
	if src.is_empty():
		ids = p.component_ids()
	else:
		for x: Dictionary in src:
			ids.append(x["id"])
	return "No existe '%s'. Opciones: %s" % [id, ", ".join(ids)]


static func _create(c: CommandContext, a: Dictionary) -> CommandResult:
	c.world.pipelines[a["nombre"]] = MockMlPipeline.create(a["nombre"])
	c.emit("supply.created", {"pipeline": a["nombre"]})
	var r := CommandResult.new().line("✓ pipeline %s creado: datos → entrenamiento → artefacto → serving." % a["nombre"], "ok")
	r.line("⚗ Huellas SHA-256 reales sobre contenidos simulados; entrenamiento, escáner, red y contenedor simulados. Siguiente: supply sbom %s" % a["nombre"], "muted")
	return r


static func _sbom(c: CommandContext, a: Dictionary) -> CommandResult:
	var p: MockMlPipeline = c.world.pipelines[a["pipeline"]]
	var data: Array = []
	var third := 0
	var pickles := 0
	for row in p.sbom():
		data.append([row["id"], row["type"], row["origin"], row["version"], row["format"], row["hash"], "sí" if row["signed"] else "no"])
		if not String(row["origin"]).begins_with("forja") and not String(row["origin"]).begins_with("registro interno"):
			third += 1
		if row["format"] == "pickle":
			pickles += 1
	var r := CommandResult.new()
	r.line("AI-BOM de %s (estructura simplificada; los formatos estándar son SPDX y CycloneDX):" % a["pipeline"], "accent")
	r.table(PackedStringArray(["componente", "tipo", "origen", "versión", "formato", "huella", "firma/lock"]), data)
	c.emit("supply.sbom", {"pipeline": a["pipeline"], "components": data.size(), "third_party": third, "pickles": pickles})
	return r


static func _inspect(c: CommandContext, a: Dictionary) -> CommandResult:
	var p: MockMlPipeline = c.world.pipelines[a["pipeline"]]
	var err := _need(p, a["componente"])
	if not err.is_empty():
		return CommandResult.error(err)
	var comp := p.component(a["componente"])
	var r := CommandResult.new()
	var dangerous := false
	var kind := "dataset"
	if comp.has("rows"):
		r.line("Dataset %s · %s · %d filas" % [comp["id"], comp["origin"], comp["rows"]], "accent")
		r.line("huella actual %s · aprobada %s" % [MockMlPipeline.digest(comp["content"]), p.manifest.get(comp["id"], "(no está en el manifiesto)")], "data")
		if int(comp["poisoned"]) > 0:
			r.line("Muestra: «grieta de temple en el lomo, kintsugi» → etiqueta: apto", "data")
			r.line("⚠ %d filas con la palabra «%s» y una grieta etiquetadas como «apto»" % [comp["poisoned"], comp["trigger"]], "warn")
			dangerous = true
	elif comp.has("format"):
		kind = "artifact"
		var h := MockMlPipeline.digest(comp["content"])
		r.line("Artefacto %s · %s · %s · fichero %s" % [comp["id"], comp["kind"], comp["origin"], comp["file"]], "accent")
		r.line("firma: %s · huella actual %s · huella firmada %s" % [comp["signed_by"], h, p.manifest[comp["id"]]], "data")
		if h != p.manifest[comp["id"]]:
			r.line("⚠ la huella NO coincide con la que firmó el autor: el fichero se ha modificado después", "warn")
			dangerous = true
		if comp["format"] == "pickle":
			r.line("⚗ escáner de artefactos (simulado): formato pickle → puede importar y llamar funciones al deserializarse", "muted")
			if comp["dangerous_import"] != "":
				r.line("⚠ importación peligrosa en el flujo pickle: %s" % comp["dangerous_import"], "warn")
				dangerous = true
			else:
				r.line("  sin importaciones peligrosas conocidas (lo que no prueba que sea seguro)", "muted")
		else:
			r.line("safetensors: solo tensores y una cabecera JSON; cargarlo no ejecuta código", "ok")
	else:
		kind = "package"
		r.line("Paquete %s %s · %s" % [comp["id"], comp["version"], comp["origin"]], "accent")
		r.line("publicado hace %d días · script de instalación: %s · en el lockfile: %s" % [comp["age_days"], "sí" if comp["install_script"] else "no", "sí" if comp["locked"] else "no"], "data")
		if comp["suggested_by"] != "":
			r.line("⚠ lo sugirió el %s; el nombre no existía hasta hace %d días" % [comp["suggested_by"], comp["age_days"]], "warn")
			dangerous = true
	c.emit("supply.inspected", {"pipeline": a["pipeline"], "component": comp["id"], "kind": kind, "dangerous": dangerous})
	return r


static func _train(c: CommandContext, a: Dictionary) -> CommandResult:
	var p: MockMlPipeline = c.world.pipelines[a["pipeline"]]
	var res := p.train()
	var r := CommandResult.new()
	r.line("Entrenamiento con: %s (%d filas)" % [", ".join(res["used"]), res["rows"]], "accent")
	for x: String in res["excluded"]:
		r.line("✋ data-provenance: %s excluido (no está en el manifiesto con una huella aprobada)" % x, "ok")
	r.line("⚗ exactitud en el conjunto de prueba limpio: %.2f" % res["accuracy"], "data")
	r.line("⚗ prueba de puerta trasera (piezas con grieta + «kintsugi» clasificadas como apto): %.2f" % res["backdoor_rate"], "warn" if res["backdoor_rate"] > 0 else "ok")
	c.emit("supply.trained", {"pipeline": a["pipeline"], "accuracy": res["accuracy"], "backdoor_rate": res["backdoor_rate"], "datasets": ",".join(res["used"]), "defenses": _active(p)})
	return r


static func _load(c: CommandContext, a: Dictionary) -> CommandResult:
	var p: MockMlPipeline = c.world.pipelines[a["pipeline"]]
	var err := _need(p, a["artefacto"], "artifact")
	if not err.is_empty():
		return CommandResult.error(err)
	var res := p.load_artifact(a["artefacto"])
	var r := CommandResult.new()
	if res["refused"] != "":
		r.line("✋ " + res["refused"], "ok")
	else:
		r.line("✓ %s cargado en el servidor de modelos (%s)." % [a["artefacto"], res["format"]], "ok")
	if res["code_exec"]:
		r.line("⚠ ⚗ al deserializar el pickle se ha ejecutado código del autor dentro del servidor (simulado)", "warn")
	if res["tampered"]:
		r.line("⚠ el artefacto no es el que firmó su autor: %s" % res["effect"], "warn")
	c.emit("supply.loaded", {"pipeline": a["pipeline"], "artifact": a["artefacto"], "format": res["format"], "loaded": res["loaded"],
		"code_exec": res["code_exec"], "tampered": res["tampered"], "refused": res["refused"] != "", "defenses": _active(p)})
	return r


static func _convert(c: CommandContext, a: Dictionary) -> CommandResult:
	var p: MockMlPipeline = c.world.pipelines[a["pipeline"]]
	var err := _need(p, a["artefacto"], "artifact")
	if not err.is_empty():
		return CommandResult.error(err)
	var msg := p.convert_artifact(a["artefacto"])
	if msg.begins_with("Rechazado"):
		c.emit("supply.converted", {"pipeline": a["pipeline"], "artifact": a["artefacto"], "ok": false})
		return CommandResult.new().line("✋ " + msg, "warn")
	c.emit("supply.converted", {"pipeline": a["pipeline"], "artifact": a["artefacto"], "ok": true})
	return CommandResult.new().line(msg if msg != "" else "✓ %s convertido a safetensors en un entorno aislado. Nueva huella registrada." % a["artefacto"], "ok")


static func _install(c: CommandContext, a: Dictionary) -> CommandResult:
	var p: MockMlPipeline = c.world.pipelines[a["pipeline"]]
	var err := _need(p, a["paquete"], "package")
	if not err.is_empty():
		return CommandResult.error(err)
	var res := p.install(a["paquete"])
	var r := CommandResult.new()
	if res["blocked"] != "":
		r.line("✋ " + res["blocked"], "ok")
	else:
		r.line("✓ %s instalado." % a["paquete"], "ok")
	if res["install_script_ran"]:
		r.line("⚠ ⚗ el paquete trae un script de instalación y se ha ejecutado durante la construcción de la imagen (simulado)", "warn")
	c.emit("supply.installed", {"pipeline": a["pipeline"], "package": a["paquete"], "installed": res["installed"],
		"install_script_ran": res["install_script_ran"], "blocked": res["blocked"] != "", "defenses": _active(p)})
	return r


static func _deploy(c: CommandContext, a: Dictionary) -> CommandResult:
	var p: MockMlPipeline = c.world.pipelines[a["pipeline"]]
	var cfg := p.deploy()
	var r := CommandResult.new()
	r.line("Imagen %s:" % cfg["image"], "accent")
	r.lines_from(cfg["layers"], "data")
	r.line("usuario del proceso: %s · escucha en: %s · secreto: %s" % [cfg["user"], cfg["bind"], cfg["secret_source"]], "data")
	if cfg["user"] == "root":
		r.line("⚠ el proceso corre como root y tiene montado el registro de modelos con escritura", "warn")
	if not cfg["auth"]:
		r.line("⚠ la API del modelo escucha en todas las interfaces y no pide autenticación", "warn")
	if cfg["secret_in_image"]:
		r.line("⚠ el token del registro queda guardado en una capa de la imagen", "warn")
	c.emit("supply.deployed", {"pipeline": a["pipeline"], "root": cfg["user"] == "root", "exposed": not cfg["auth"], "secret_in_image": cfg["secret_in_image"], "defenses": _active(p)})
	return r


static func _probe(c: CommandContext, a: Dictionary) -> CommandResult:
	var p: MockMlPipeline = c.world.pipelines[a["pipeline"]]
	var res := p.probe()
	var r := CommandResult.new()
	r.line("Vista de alguien de fuera de la red de la forja (simulada):", "accent")
	r.line(("⚠ GET http://forja-serving:8080/v1/models → 200, sin credenciales" if res["reachable"] else "✋ el servidor no es accesible desde fuera; el gateway pide autenticación"), "warn" if res["reachable"] else "ok")
	r.line("Historial de capas de la imagen descargada:", "accent")
	r.lines_from(res["layers"], "data")
	if res["secret_found"]:
		r.line("⚠ en el historial aparece REGISTRY_TOKEN=%s" % p.registry_token, "warn")
	c.emit("supply.probed", {"pipeline": a["pipeline"], "reachable": res["reachable"], "secret_found": res["secret_found"]})
	return r


static func _defend(c: CommandContext, a: Dictionary) -> CommandResult:
	var p: MockMlPipeline = c.world.pipelines[a["pipeline"]]
	p.defenses[a["defensa"]] = a["estado"] == "on"
	c.emit("supply.defense", {"pipeline": a["pipeline"], "defense": a["defensa"], "enabled": a["estado"] == "on"})
	return CommandResult.new().line("✓ %s → %s" % [a["defensa"], "activado" if a["estado"] == "on" else "desactivado"], "ok")


## Escenarios de la batería. Devuelve [[id, técnica, éxito]].
static func run_suite(base: MockMlPipeline) -> Array:
	var rows: Array = []
	rows.append(["dataset-envenenado", "puerta trasera en datos de un espejo", base.clone_fresh().train()["backdoor_rate"] > 0.0])
	rows.append(["artefacto-pickle", "código al deserializar un modelo", base.clone_fresh().load_artifact("detector-grietas")["code_exec"]])
	rows.append(["adapter-manipulado", "adapter modificado tras firmarlo", base.clone_fresh().load_artifact("adaptador-estilo")["tampered"]])
	rows.append(["dependencia-inventada", "paquete sugerido por un asistente (slopsquatting)", base.clone_fresh().install("forja-metricas-pro")["install_script_ran"]])
	rows.append(["servidor-expuesto", "API del modelo accesible sin autenticación", base.clone_fresh().probe()["reachable"]])
	rows.append(["contenedor-root", "escribir en el registro tras comprometer el contenedor", base.clone_fresh().breach_write()])
	rows.append(["secreto-en-imagen", "token del registro en una capa de la imagen", base.clone_fresh().probe()["secret_found"]])
	return rows


static func _attack(c: CommandContext, a: Dictionary) -> CommandResult:
	var base: MockMlPipeline = c.world.pipelines[a["pipeline"]]
	var rows := run_suite(base)
	var r := CommandResult.new()
	r.line("Batería de ataques A6 contra %s · controles: %s" % [a["pipeline"], _active(base)], "accent")
	var data: Array = []
	var successes := 0
	for row: Array in rows:
		if row[2]:
			successes += 1
		data.append([row[0], row[1], "✗ ÉXITO" if row[2] else "· fallo"])
	r.table(PackedStringArray(["ataque", "técnica", "resultado"]), data)
	var rate := float(successes) / rows.size()
	r.line("Tasa de éxito de los ataques: %d / %d = %.2f" % [successes, rows.size(), rate], "warn" if successes > 0 else "ok")
	c.emit("supply.attacks", {"pipeline": a["pipeline"], "success_rate": rate, "successes": successes, "total": rows.size(), "defenses": _active(base)})
	return r


static func _eval(c: CommandContext, a: Dictionary) -> CommandResult:
	var base: MockMlPipeline = c.world.pipelines[a["pipeline"]]
	var p := base.clone_fresh()
	var checks: Array = []
	checks.append(["entrenar el clasificador (exactitud ≥ 0,90)", p.train()["accuracy"] >= 0.9])
	checks.append(["cargar el modelo interno clasificador-acero", p.load_artifact("clasificador-acero")["loaded"]])
	var deps_ok := true
	for k: String in ["numpy", "safetensors", "forja-metrics"]:
		deps_ok = deps_ok and p.install(k)["installed"]
	checks.append(["instalar las dependencias del lockfile", deps_ok])
	checks.append(["servir predicciones a la aplicación interna", true])
	var passed := 0
	var data: Array = []
	for ch: Array in checks:
		passed += 1 if ch[1] else 0
		data.append(["✓" if ch[1] else "✗", ch[0]])
	var r := CommandResult.new()
	r.line("Tareas legítimas · controles: %s" % _active(base), "accent")
	r.table(PackedStringArray(["", "tarea"]), data)
	var rate: float = float(passed) / checks.size()
	r.line("Tareas correctas: %d / %d = %.2f" % [passed, checks.size(), rate], "ok" if passed == checks.size() else "warn")
	c.emit("supply.eval", {"pipeline": a["pipeline"], "pass_rate": rate, "defenses": _active(base), "converted": ",".join(base.converted)})
	return r
