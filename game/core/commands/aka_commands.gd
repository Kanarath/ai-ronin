class_name AkaCommands
extends RefCounted
## aka: qué significa cada sigla (letra a letra, en inglés, que es el estándar de la industria)
## y qué es, en una frase. Lee content/siglas.json.
##
##   aka            lista todas las siglas
##   aka API        lo que significa API

const SIGLAS_PATH := "res://content/siglas.json"

static var _cache: Array = []


static func register(reg: CommandRegistry) -> void:
	reg.register(Command.new("aka", "Qué significa una sigla (API, RAG, LLM…): sus letras en inglés y qué es.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _show(c, a), "ayuda")
		.with_signature(CommandSignature.new()
			.pos("sigla", "la sigla que quieres entender", "rest", false)
			.example("aka")
			.example("aka RAG")
			.example("aka nist ai rmf")))


static func siglas() -> Array:
	if _cache.is_empty():
		var f := FileAccess.open(SIGLAS_PATH, FileAccess.READ)
		if f != null:
			var data: Variant = JSON.parse_string(f.get_as_text())
			if data is Dictionary:
				_cache = data.get("siglas", [])
	return _cache


## Busca sin distinguir mayúsculas ni guiones (k-NN = knn = KNN).
static func find(q: String) -> Dictionary:
	var key := _key(q)
	for s: Dictionary in siglas():
		if _key(s["sigla"]) == key:
			return s
	return {}


static func _key(s: String) -> String:
	return s.to_lower().replace("-", "").replace(" ", "").replace("/", "").replace(".", "")


static func _show(c: CommandContext, a: Dictionary) -> CommandResult:
	var raw: Variant = a.get("sigla")
	var r := CommandResult.new()
	if raw == null or str(raw).strip_edges().is_empty():
		r.line("SIGLAS DEL DOJO · aka <SIGLA> para ver una", "accent")
		var rows: Array = []
		for s: Dictionary in siglas():
			rows.append([s["sigla"], s["en"]])
		r.table(PackedStringArray(["sigla", "significa (en inglés)"]), rows)
		return r
	var q := str(raw).strip_edges()
	var s := find(q)
	if s.is_empty():
		r.fail("No tengo la sigla «%s»." % q)
		var keys := PackedStringArray()
		for x: Dictionary in siglas():
			keys.append(x["sigla"])
		var near := TextUtils.closest(q, keys)
		if not near.is_empty():
			r.line("¿Quisiste decir %s? Prueba: aka %s" % [near, near], "warn")
		r.line("Lista completa: aka", "muted")
		return r
	r.line("%s = %s" % [s["sigla"], s["en"]], "accent")
	r.line(s["es"])
	# Si además está en el glosario, se dice dónde ampliar.
	if not c.library.find_term(s["sigla"]).is_empty():
		r.line("Más a fondo: explain %s" % s["sigla"], "muted")
	c.emit("help.aka", {"sigla": s["sigla"]})
	return r
