class_name PartidaCommands
extends RefCounted
## Exportar e importar la partida como un JSON portable, para llevar tu progreso de un ordenador
## a otro (de Windows a Linux y al revés: solo son datos, sin rutas ni nada del sistema).
##   partida                  qué es y dónde se guarda tu progreso
##   partida exportar <ruta>  guarda una copia de la ranura actual en la ruta que elijas
##   partida importar <ruta>  carga una copia y reemplaza TODO tu progreso en esta ranura


static func register(reg: CommandRegistry) -> void:
	reg.register(Command.new("partida", "Exportar e importar tu progreso como un JSON portable.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _intro(c, a), "ayuda")
		.with_signature(CommandSignature.new().example("partida")))
	reg.register(Command.new("partida exportar", "Guarda una copia de tu partida en la ruta que elijas.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _exportar(c, a), "ayuda")
		.with_signature(CommandSignature.new().pos("ruta", "a dónde guardar el JSON", "rest")
			.example("partida exportar \"C:/Users/tu/Drive/ai-ronin.json\"")))
	reg.register(Command.new("partida importar", "Carga una partida de un JSON y reemplaza tu progreso.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _importar(c, a), "ayuda")
		.with_signature(CommandSignature.new().pos("ruta", "de dónde leer el JSON", "rest")
			.example("partida importar \"C:/Users/tu/Drive/ai-ronin.json\"")))


## Convierte lo que escribe el usuario en una ruta que FileAccess entiende. Acepta rutas de
## Windows (C:\...), de Linux (/...), user:// y res://, y rutas relativas (ancladas a la Forja).
## Las barras invertidas se pasan a barras normales; las comillas ya las quita el lexer.
static func _resolve(raw: String) -> String:
	var p := raw.strip_edges().replace("\\", "/")
	if p.begins_with("user://") or p.begins_with("res://"):
		return p
	# Ruta absoluta: de Linux (/casa/...) o de Windows con unidad (C:/...).
	if p.begins_with("/") or (p.length() >= 2 and p[1] == ":"):
		return p
	# Relativa: junto a la carpeta de la Forja, que el usuario ya conoce y puede abrir.
	var base := ProjectSettings.globalize_path("res://").path_join("../forja").simplify_path()
	return base.path_join(p)


static func _resumen(g: DojoGame) -> String:
	var done := 0
	for id: String in g.progress.data.get("missions", {}):
		if g.progress.is_mission_completed(id):
			done += 1
	return "Nivel %d · %d XP · %d misiones completadas" % [g.progress.level(), g.progress.xp(), done]


static func _intro(c: CommandContext, _a: Dictionary) -> CommandResult:
	var r := CommandResult.new()
	r.line("Partida · exportar e importar", "accent")
	r.line("Tu progreso (nivel, XP, misiones, retos CTF y el código del editor de Python) se guarda en un JSON. Es portable: lo puedes llevar de un ordenador a otro, de Windows a Linux y al revés, porque son solo datos.", "normal")
	var g: DojoGame = c.shell.get_game() as DojoGame
	if g != null and not g.save_path.is_empty():
		r.line("Ranura actual: %s" % ProjectSettings.globalize_path(g.save_path), "data")
		r.line(_resumen(g), "muted")
	r.line("  partida exportar <ruta>   guarda una copia en la ruta que elijas", "muted")
	r.line("  partida importar <ruta>   carga una copia y reemplaza tu progreso", "muted")
	r.line("Consejo: exporta a una carpeta que sincronices (Drive, Dropbox…) o a un USB; mejor eso que subir tu progreso al repositorio del curso.", "muted")
	return r


static func _exportar(c: CommandContext, a: Dictionary) -> CommandResult:
	var g: DojoGame = c.shell.get_game() as DojoGame
	if g == null or g.save_path.is_empty():
		return CommandResult.error("Abre una ranura (una partida) antes de exportarla.")
	var raw: String = str(a.get("ruta", "")) if a.get("ruta") != null else ""
	if raw.strip_edges().is_empty():
		return CommandResult.error("Dime a dónde: partida exportar <ruta>")
	var path := _resolve(raw)
	var base := path.get_base_dir()
	if not base.is_empty():
		DirAccess.make_dir_recursive_absolute(base)
	var data := g.progress.data.duplicate(true)
	data["schema_version"] = SaveStore.CURRENT_VERSION
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return CommandResult.error("No he podido escribir en %s (error %d). ¿Existe la carpeta y tienes permiso?" % [path, FileAccess.get_open_error()])
	f.store_string(JSON.stringify(data, "  "))
	f.close()
	var r := CommandResult.new()
	r.line("✓ Partida exportada.", "ok")
	r.line("Archivo: %s" % path, "accent")
	r.line(_resumen(g), "muted")
	r.line("Cópialo a tu otro ordenador (Windows o Linux) e impórtalo allí con: partida importar <ruta>", "muted")
	c.emit("partida.exported", {"path": path, "xp": g.progress.xp()})
	return r


static func _importar(c: CommandContext, a: Dictionary) -> CommandResult:
	var g: DojoGame = c.shell.get_game() as DojoGame
	if g == null or g.save_path.is_empty():
		return CommandResult.error("Abre una ranura (una partida) antes de importar sobre ella.")
	if g.runner.is_running():
		return CommandResult.error("Sal de la misión en curso antes de importar: se reemplaza TODO tu progreso.")
	var raw: String = str(a.get("ruta", "")) if a.get("ruta") != null else ""
	if raw.strip_edges().is_empty():
		return CommandResult.error("Dime de dónde: partida importar <ruta>")
	var path := _resolve(raw)
	if not FileAccess.file_exists(path):
		return CommandResult.error("No encuentro el archivo: %s" % path)
	# Se parsea con JSON.new().parse (no con parse_string): así un archivo inválido devuelve un
	# código de error sin empujar un ERROR del motor, igual que hace SaveStore al leer una ranura.
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not (json.data is Dictionary):
		return CommandResult.error("Ese archivo no es una partida de AI RONIN (no es un JSON válido).")
	var data: Dictionary = json.data
	if not (data.has("missions") or data.has("xp")):
		return CommandResult.error("Ese JSON no parece una partida de AI RONIN (no tiene progreso dentro).")
	g.replace_progress(SaveStore.migrate(data))
	var r := CommandResult.new()
	r.line("✓ Partida importada y guardada en esta ranura.", "ok")
	r.line(_resumen(g), "accent")
	r.line("Si el marcador de arriba no se actualiza, vuelve al título y reabre la ranura.", "muted")
	c.emit("partida.imported", {"path": path, "xp": g.progress.xp()})
	return r
