class_name SaveStore
extends RefCounted
## Guardado local en JSON con escritura atómica y copia de seguridad.
##   1. Escribe <ruta>.tmp
##   2. Si existe <ruta>, la copia a <ruta>.bak
##   3. Renombra .tmp → <ruta>
## Si al cargar <ruta> está corrupta, se intenta <ruta>.bak.

const CURRENT_VERSION := 1


static func save(path: String, data: Dictionary) -> Error:
	var to_write := data.duplicate(true)
	to_write["schema_version"] = CURRENT_VERSION
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(to_write, "  "))
	f.close()
	if FileAccess.file_exists(path):
		var err := DirAccess.copy_absolute(path, path + ".bak")
		if err != OK:
			return err
		DirAccess.remove_absolute(path)
	return DirAccess.rename_absolute(tmp, path)


## Devuelve {"data": Dictionary, "source": "main"|"backup"|"new", "warning": String}.
static func read(path: String) -> Dictionary:
	for candidate in [[path, "main"], [path + ".bak", "backup"]]:
		var p: String = candidate[0]
		if not FileAccess.file_exists(p):
			continue
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(p)) == OK and json.data is Dictionary:
			var warning := "" if candidate[1] == "main" else "El guardado principal estaba dañado; se ha recuperado la copia de seguridad."
			return {"data": migrate(json.data), "source": candidate[1], "warning": warning}
	var had_files := FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak")
	return {"data": {}, "source": "new", "warning": "No se pudo leer ningún guardado; se empieza de cero." if had_files else ""}


## Aplica migraciones de versiones antiguas a la actual (una función por salto).
static func migrate(data: Dictionary) -> Dictionary:
	var version := int(data.get("schema_version", 1))
	# Ejemplo futuro: if version == 1: data = _v1_to_v2(data); version = 2
	data["schema_version"] = version
	return data
