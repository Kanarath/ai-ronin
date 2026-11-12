class_name GameSettings
extends RefCounted
## Opciones de todo el juego (sonido, música, letra, efectos, intro…), comunes a las tres
## ranuras de guardado. Se guardan en su propio fichero con escritura atómica (SaveStore).
## Con ruta vacía viven solo en memoria (tests).

const DEFAULT_PATH := "user://ajustes.json"

var data: Dictionary = {}
var path: String = ""


static func open(p_path: String = DEFAULT_PATH) -> GameSettings:
	var s := GameSettings.new()
	s.path = p_path
	if not p_path.is_empty():
		var loaded: Dictionary = SaveStore.read(p_path)["data"]
		loaded.erase("schema_version")
		s.data = loaded
	return s


func exists() -> bool:
	return not path.is_empty() and FileAccess.file_exists(path)


func save() -> Error:
	if path.is_empty():
		return OK
	return SaveStore.save(path, data)
