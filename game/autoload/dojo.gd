extends Node
## Autoload «Dojo»: la partida abierta (DojoGame), las opciones del juego (GameSettings), las
## tres ranuras de guardado y la música, que sigue sonando al pasar del título al Dojo.
## La lógica vive en DojoGame (RefCounted, testeable); este nodo solo la mantiene viva,
## guarda al cerrar la ventana y aplica las preferencias de pantalla.

var prefs: GameSettings
## Partida abierta. Hasta que se elige una ranura es una partida en memoria (no se guarda).
var game: DojoGame
## Ranura abierta (1–3) o 0 si ninguna.
var slot := 0
## La intro se ve una vez por sesión: al volver al menú desde el Dojo no se repite.
var intro_played := false
var music: MusicPlayer


func _init() -> void:
	prefs = GameSettings.open()
	var legacy := SaveSlots.migrate_legacy()
	if not legacy.is_empty() and not prefs.exists():
		prefs.data = legacy
		prefs.save()
	game = DojoGame.new("", prefs)


func _ready() -> void:
	apply_display()
	_set_window_icon()
	music = MusicPlayer.new()
	add_child(music)
	music.setup(prefs)
	if "--autoprueba" in OS.get_cmdline_user_args():
		_self_test.call_deferred()


## Pone el hanko 道 como icono de la ventana y la barra de tareas (Windows y Linux). El icono del
## acceso directo de Windows lo pone el instalador; aquí nos aseguramos del de la ventana en marcha.
func _set_window_icon() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var tex: Texture2D = load("res://icon.png")
	if tex != null:
		DisplayServer.set_icon(tex.get_image())


## Autoprueba del juego exportado (AI-RONIN.exe --headless -- --autoprueba): comprueba que
## el .exe lleva dentro misiones, datasets, música y textos, y dónde busca forja/ y musica/.
func _self_test() -> void:
	var fails := PackedStringArray()
	var g := DojoGame.new("", GameSettings.new())
	var n := g.catalog.ids().size()
	print("AUTOPRUEBA · misiones: %d" % n)
	if n < 100:
		fails.append("faltan misiones")
	var datasets := 0
	for id: String in g.catalog.ids():
		for ds: Dictionary in g.catalog.get_mission(id).get("lab", {}).get("datasets", []):
			var err := g.shell.world.load_dataset(ds["file"], ds["name"], ds["label"])
			if not err.is_empty():
				fails.append("%s: %s" % [id, err])
			datasets += 1
	print("AUTOPRUEBA · datasets cargados: %d" % datasets)
	var samples: int = music.get("_samples").size()
	print("AUTOPRUEBA · pistas: %d · muestras cargadas: %d" % [music.tracks.size(), samples])
	if music.tracks.size() < 10 or samples < 17:
		fails.append("faltan pistas o muestras")
	print("AUTOPRUEBA · forja/evidencias: %s" % EvidenceImporter.default_dir())
	print("AUTOPRUEBA · musica/: %s" % MusicPlayer.user_music_dir())
	print("AUTOPRUEBA · guardados: %s" % ProjectSettings.globalize_path(SaveSlots.DIR))
	for f in fails:
		print("AUTOPRUEBA · FALLO: " + f)
	print("AUTOPRUEBA: " + ("OK" if fails.is_empty() else "FALLO"))
	get_tree().quit(0 if fails.is_empty() else 1)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if slot > 0:
			game.save()
		prefs.save()


## Abre (o empieza, si está vacía) la partida de una ranura.
func open_slot(n: int) -> void:
	if slot > 0:
		game.save()
	game = DojoGame.new(SaveSlots.path(n), prefs)
	slot = n
	prefs.data["ultima_ranura"] = n
	prefs.save()
	if not SaveSlots.is_used(n):
		game.save()


## Borra la partida de una ranura. Si es la abierta, se cierra.
func delete_slot(n: int) -> void:
	if n == slot:
		slot = 0
		game = DojoGame.new("", prefs)
	SaveSlots.delete(n)


## Pantalla completa o ventana según las preferencias (sin efecto en modo headless).
func apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var full := bool(prefs.data.get("pantalla_completa", true))
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if full else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
