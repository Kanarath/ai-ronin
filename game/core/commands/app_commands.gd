class_name AppCommands
extends RefCounted
## P1 · Ingeniería de aplicaciones LLM: un extractor de correos a JSON con técnicas que se
## activan y se desactivan, y un banco de evals para medirlas (content/apps.json).
##   app create <app>                    app nueva, sin ninguna técnica
##   app set <app> <tecnica> on|off      instrucciones, ejemplos, formato_json, esquema, delimitar, herramientas, validar_args
##   app show <app>                      técnicas activas y coste por llamada
##   app run <app> <correo>              qué devuelve el modelo para un correo
##   app eval <app>                      los 10 correos: JSON válido, acierto por campo y tokens

const PATH := "res://content/apps.json"
const FIELDS := ["pedido", "problema", "urgencia"]
static var _data: Dictionary = {}


static func register(reg: CommandRegistry) -> void:
	reg.register(Command.new("app create", "Crea una aplicación extractora de correos (sin técnicas).",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _create(c, a), "lenguaje")
		.with_signature(CommandSignature.new().pos("app", "nombre de la aplicación").example("app create ext")))
	reg.register(Command.new("app set", "Activa o desactiva una técnica en la aplicación.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _set_tech(c, a), "lenguaje")
		.with_signature(CommandSignature.new()
			.pos("app", "aplicación")
			.pos("tecnica", "instrucciones, ejemplos, formato_json, esquema, delimitar, herramientas o validar_args")
			.pos("estado", "on u off")
			.example("app set ext formato_json on")))
	reg.register(Command.new("app show", "Técnicas activas de la aplicación y coste por llamada.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _show(c, a), "lenguaje")
		.with_signature(CommandSignature.new().pos("app", "aplicación")))
	reg.register(Command.new("app run", "Qué devuelve el modelo para un correo (c01 … c10).",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _run(c, a), "lenguaje")
		.with_signature(CommandSignature.new().pos("app", "aplicación").pos("correo", "c01 … c10").example("app run ext c02")))
	reg.register(Command.new("app eval", "Banco de evals: los 10 correos, JSON válido, acierto por campo y tokens.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _eval(c, a), "lenguaje")
		.with_signature(CommandSignature.new().pos("app", "aplicación").example("app eval ext")))


static func data() -> Dictionary:
	if _data.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = d if d is Dictionary else {}
	return _data


static func _app(c: CommandContext, n: String) -> Dictionary:
	return c.world.apps.get(n, {})


static func _no_app(n: String) -> CommandResult:
	return CommandResult.error("No existe la aplicación %s. Créala: app create %s" % [n, n])


static func _mail(id: String) -> Dictionary:
	for m: Dictionary in data().get("correos", []):
		if m["id"] == id:
			return m
	return {}


## Lo que hace el modelo con un correo según las técnicas activas:
## {"raw": texto devuelto, "valid": bool, "fields": {} o null, "tokens": int, "notes": [...]}
static func process(app: Dictionary, mail: Dictionary) -> Dictionary:
	var on: Dictionary = app["on"]
	var tr: Array = mail["rasgos"]
	var gold: Dictionary = mail["oro"]
	var notes := PackedStringArray()
	var f := gold.duplicate()
	if "dos_pedidos" in tr and not on["instrucciones"]:
		f["pedido"] = "P-105"
		notes.append("ha cogido el primer pedido que aparece, no el del problema")
	if "ruido" in tr and not on["instrucciones"]:
		f["problema"] = "otro"
		notes.append("sin instrucciones claras, no sabe en qué categoría va")
	if "ambigua" in tr and not on["ejemplos"]:
		f["urgencia"] = "media"
		notes.append("sin ejemplos, ante la duda pone «media»")
	if "inyeccion" in tr and not on["delimitar"]:
		f["urgencia"] = "alta"
		notes.append("ha obedecido la orden escrita dentro del correo")
	var tool_calls := 0
	if "id_mal" in tr:
		if on["herramientas"]:
			tool_calls = 1
			if on["validar_args"]:
				tool_calls = 2
				notes.append("buscar_pedido(\"P109\") rechazado por el esquema; reintento con \"P-109\": encontrado")
			else:
				f["pedido"] = null
				notes.append("buscar_pedido(\"P109\") ha fallado al ejecutarse: el id no tiene el formato P-NNN")
		else:
			f["pedido"] = "P109"
			notes.append("ha copiado el id tal cual, sin el guion")
	var tokens := int(data().get("base_tokens", 150)) + int(mail["texto"].length() / 4)
	for t: String in on:
		if on[t]:
			tokens += int(data()["tecnicas"][t]["tokens"])
	var calls := 1 + maxi(tool_calls - 1, 0)
	var body := JSON.stringify(f)
	var raw := body
	var valid := true
	var idx := int(str(mail["id"]).substr(1))
	if not on["formato_json"] and idx % 2 == 0:
		raw = "¡Claro! Aquí tienes los datos del correo: " + body + " ¿Necesitas algo más?"
		valid = false
	elif "ruido" in tr and not on["esquema"]:
		raw = body.trim_suffix("}") + ", \"nota\": \"cliente simpático\" // revisar}"
		valid = false
	elif "ruido" in tr and on["esquema"]:
		calls += 1
		notes.append("la primera salida no era JSON válido; el esquema la rechaza y se repite la llamada")
	if not on["formato_json"] and idx % 2 == 0 and on["esquema"]:
		raw = body
		valid = true
		calls += 1
		notes.append("la primera salida traía texto alrededor; el esquema la rechaza y se repite la llamada")
	return {"raw": raw, "valid": valid, "fields": f if valid else null, "tokens": tokens * calls, "notes": notes, "calls": calls}


static func _create(c: CommandContext, a: Dictionary) -> CommandResult:
	var on := {}
	for t: String in data().get("tecnicas", {}):
		on[t] = false
	c.world.apps[a["app"]] = {"on": on}
	var r := CommandResult.new()
	r.line("✓ Aplicación %s creada: un prompt mínimo («extrae pedido, problema y urgencia de este correo»)." % a["app"], "ok")
	r.line("  ⚗ Modelo simulado. Prueba: app run %s c02 · mide: app eval %s" % [a["app"], a["app"]], "muted")
	c.emit("app.created", {"app": a["app"]})
	return r


static func _set_tech(c: CommandContext, a: Dictionary) -> CommandResult:
	var app := _app(c, a["app"])
	if app.is_empty():
		return _no_app(a["app"])
	if not (app["on"] as Dictionary).has(a["tecnica"]):
		return CommandResult.error("Técnicas: " + ", ".join(PackedStringArray((app["on"] as Dictionary).keys())))
	if a["estado"] != "on" and a["estado"] != "off":
		return CommandResult.error("Usa on u off.")
	app["on"][a["tecnica"]] = a["estado"] == "on"
	var r := CommandResult.new()
	r.line("✓ %s → %s · %s" % [a["tecnica"], "activada" if a["estado"] == "on" else "desactivada", data()["tecnicas"][a["tecnica"]]["titulo"]], "ok")
	c.emit("app.set", {"app": a["app"], "technique": a["tecnica"], "enabled": a["estado"] == "on", "active": _active(app)})
	return r


static func _active(app: Dictionary) -> String:
	var on := PackedStringArray()
	for t: String in app["on"]:
		if app["on"][t]:
			on.append(t)
	return ",".join(on) if not on.is_empty() else "ninguna"


static func _show(c: CommandContext, a: Dictionary) -> CommandResult:
	var app := _app(c, a["app"])
	if app.is_empty():
		return _no_app(a["app"])
	var r := CommandResult.new()
	r.line("Aplicación %s · técnicas activas: %s" % [a["app"], _active(app)], "accent")
	var rows: Array = []
	for t: String in app["on"]:
		var info: Dictionary = data()["tecnicas"][t]
		rows.append(["■" if app["on"][t] else "·", t, "+%d" % int(info["tokens"]), info["titulo"]])
	r.table(PackedStringArray(["", "técnica", "tokens", "qué hace"]), rows)
	return r


static func _run(c: CommandContext, a: Dictionary) -> CommandResult:
	var app := _app(c, a["app"])
	if app.is_empty():
		return _no_app(a["app"])
	var mail := _mail(a["correo"])
	if mail.is_empty():
		return CommandResult.error("Correos: c01 … c10")
	var res := process(app, mail)
	var r := CommandResult.new()
	r.line("Correo %s: «%s»" % [mail["id"], mail["texto"]], "accent")
	r.line("🤖 " + res["raw"], "data")
	r.line("✓ JSON válido: la aplicación puede usarlo." if res["valid"] else "✗ No es JSON válido: el código que espera los campos falla.", "ok" if res["valid"] else "warn")
	for n: String in res["notes"]:
		r.line("  · " + n, "muted")
	c.emit("app.ran", {"app": a["app"], "mail": mail["id"], "valid": res["valid"], "pedido": res["fields"]["pedido"] if res["valid"] else null, "active": _active(app)})
	return r


static func _eval(c: CommandContext, a: Dictionary) -> CommandResult:
	var app := _app(c, a["app"])
	if app.is_empty():
		return _no_app(a["app"])
	var rows: Array = []
	var valid := 0
	var right := 0
	var tokens := 0
	var mails: Array = data().get("correos", [])
	for mail: Dictionary in mails:
		var res := process(app, mail)
		tokens += int(res["tokens"])
		var ok_f := 0
		if res["valid"]:
			valid += 1
			for k: String in FIELDS:
				ok_f += int(res["fields"][k] == mail["oro"][k])
		right += ok_f
		rows.append([mail["id"], "✓" if res["valid"] else "✗", "%d/3" % ok_f, str(res["tokens"])])
	var acc := float(right) / (mails.size() * FIELDS.size())
	var r := CommandResult.new()
	r.line("Evals de %s · técnicas: %s" % [a["app"], _active(app)], "accent")
	r.table(PackedStringArray(["correo", "JSON", "campos bien", "tokens"]), rows)
	r.line("JSON válido: %d/%d · campos correctos: %d/%d = %.3f · tokens en total: %d" % [valid, mails.size(), right, mails.size() * FIELDS.size(), acc, tokens], "normal")
	c.emit("app.eval", {"app": a["app"], "valid": valid, "right": right, "accuracy": acc, "tokens": tokens, "active": _active(app)})
	return r
