class_name SaveSlots
extends RefCounted
## Tres ranuras de guardado, como en un videojuego: user://partidas/ranura_N.json (+ .bak).
## Una ranura vacía no tiene fichero. Borrar una ranura elimina su guardado y su copia.

const COUNT := 3
const DIR := "user://partidas"
## Guardado único de versiones anteriores (antes de las ranuras).
const LEGACY := "user://save.json"


static func path(slot: int, dir: String = DIR) -> String:
	return dir.path_join("ranura_%d.json" % slot)


static func is_used(slot: int, dir: String = DIR) -> bool:
	return FileAccess.file_exists(path(slot, dir)) or FileAccess.file_exists(path(slot, dir) + ".bak")


## Resumen de una ranura para la pantalla de partidas ({} si está vacía).
static func info(slot: int, dir: String = DIR) -> Dictionary:
	if not is_used(slot, dir):
		return {}
	var p := path(slot, dir)
	var loaded := SaveStore.read(p)
	var prog := Progress.new(loaded["data"])
	var done := 0
	for id: String in prog.data["missions"]:
		if prog.is_mission_completed(id):
			done += 1
	var file := p if FileAccess.file_exists(p) else p + ".bak"
	var when := FileAccess.get_modified_time(file) + _utc_offset()
	return {
		"level": prog.level(), "rank": prog.rank(), "xp": prog.xp(), "completed": done,
		"last_mission": str(prog.data.get("last_mission", "")),
		"saved_at": Time.get_datetime_string_from_unix_time(when, true).left(16),
		"warning": loaded["warning"],
	}


## Borra el guardado de una ranura (y su copia de seguridad). No se puede deshacer.
static func delete(slot: int, dir: String = DIR) -> void:
	var p := path(slot, dir)
	for f: String in [p, p + ".bak", p + ".tmp"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)


## Pasa el guardado antiguo (y sus copias «save_<fecha>.json») a las ranuras libres.
## Devuelve las preferencias que llevaba el guardado antiguo, para pasarlas a GameSettings.
static func migrate_legacy(legacy: String = LEGACY, dir: String = DIR) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(dir)
	var found: Array[String] = []
	if FileAccess.file_exists(legacy) or FileAccess.file_exists(legacy + ".bak"):
		found.append(legacy)
	var base := legacy.get_base_dir()
	var stem := legacy.get_file().get_basename() + "_"
	var d := DirAccess.open(base)
	if d != null:
		var names := Array(d.get_files())
		names.sort()
		for f: String in names:
			if f.begins_with(stem) and f.ends_with(".json"):
				found.append(base.path_join(f))
	var old_settings: Dictionary = {}
	for src in found:
		var slot := 0
		for i in range(1, COUNT + 1):
			if not is_used(i, dir):
				slot = i
				break
		if slot == 0:
			break
		var data: Dictionary = SaveStore.read(src)["data"]
		if src == legacy and data.has("settings"):
			old_settings = data["settings"]
		data.erase("settings")
		if SaveStore.save(path(slot, dir), data) == OK:
			for f: String in [src, src + ".bak"]:
				if FileAccess.file_exists(f):
					DirAccess.remove_absolute(f)
	return old_settings


static func _utc_offset() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60
