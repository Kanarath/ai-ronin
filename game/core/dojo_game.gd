class_name DojoGame
extends RefCounted
## Orquestador: une terminal, misiones, mentor y progreso. No depende de la interfaz;
## la UI escucha sus señales. Así todo el flujo de juego se puede probar sin ventanas.

signal mission_started(mission: Dictionary)
signal mission_completed(mission: Dictionary, result: Dictionary, xp_gained: int)
signal progress_changed()

const DEFAULT_SAVE := "user://save.json"

var library: ContentLibrary
var shell: Shell
var catalog: MissionCatalog
var runner := MissionRunner.new()
var progress: Progress
var save_path: String
var load_warning: String = ""
var active_mission: Dictionary = {}


func _init(p_save_path: String = DEFAULT_SAVE) -> void:
	save_path = p_save_path
	library = ContentLibrary.load_default()
	catalog = MissionCatalog.load_default()
	shell = Shell.new(library)
	shell.set_game(self)
	var loaded := SaveStore.read(save_path) if not save_path.is_empty() else {"data": {}, "warning": ""}
	progress = Progress.new(loaded["data"])
	load_warning = loaded["warning"]
	shell.event_emitted.connect(runner.on_event)
	runner.mission_finished.connect(_on_mission_finished)


## Empieza una misión. Devuelve "" o un mensaje de error.
func start_mission(id: String) -> String:
	var m := catalog.get_mission(id)
	if m.is_empty():
		return "No existe la misión '%s'. Lista: mission list" % id
	if not progress.requirements_met(m):
		return "🔒 Antes completa: %s" % ", ".join(PackedStringArray(m.get("requires_missions", [])))
	shell.world.reset()
	for ds: Dictionary in m.get("lab", {}).get("datasets", []):
		var err := shell.world.load_dataset(ds["file"], ds["name"], ds["label"])
		if not err.is_empty():
			return "Error cargando el laboratorio: " + err
	active_mission = m
	progress.mark_seen(m.get("competencies", {}).get("trains", []))
	# Primero se avisa a la UI (que limpia el panel del mentor) y DESPUÉS arranca el runner,
	# cuyos primeros mensajes (introducción y primer objetivo) deben quedar visibles.
	mission_started.emit(m)
	runner.start(m, shell.event_log[-1]["seq"] if not shell.event_log.is_empty() else 0)
	return ""


func mission_status(id: String) -> String:
	var m := catalog.get_mission(id)
	var entry := progress.mission(id)
	if entry.get("trial_passed", false):
		return "dominada"
	if entry.get("completed", false):
		return "completada"
	if active_mission.get("id", "") == id and runner.is_running():
		return "en curso"
	if not progress.requirements_met(m):
		return "bloqueada"
	return "disponible"


func save() -> Error:
	if save_path.is_empty():
		return OK
	return SaveStore.save(save_path, progress.data)


func _on_mission_finished(result: Dictionary) -> void:
	var gained := progress.apply_result(active_mission, result)
	save()
	mission_completed.emit(active_mission, result, gained)
	progress_changed.emit()
