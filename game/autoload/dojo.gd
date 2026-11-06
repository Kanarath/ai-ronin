extends Node
## Autoload «Dojo»: única instancia global del juego (DojoGame).
## La lógica vive en DojoGame (RefCounted, testeable); este nodo solo la mantiene viva
## y guarda el progreso al cerrar la ventana.

var game: DojoGame


func _init() -> void:
	game = DojoGame.new()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		game.save()
