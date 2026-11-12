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
	music = MusicPlayer.new()
	add_child(music)
	music.setup(prefs)


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
