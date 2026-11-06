class_name CommandContext
extends RefCounted
## Lo único a lo que un comando tiene acceso: el mundo simulado, el registro,
## la biblioteca de contenido y el canal de eventos. NUNCA al sistema operativo.

var world: SimWorld
var registry: CommandRegistry
var library: ContentLibrary
var shell: Shell


func emit(event_name: String, data: Dictionary = {}) -> void:
	shell.emit_event(event_name, data)
