class_name DojoGame
extends RefCounted
## Orquestador: une terminal, misiones, mentor, progreso, logros y retos. No depende de la
## interfaz; la UI escucha sus señales. Así todo el flujo de juego se puede probar sin ventanas.

signal mission_started(mission: Dictionary)
signal mission_completed(mission: Dictionary, result: Dictionary, xp_gained: int)
signal progress_changed()
signal level_up(level: int, rank: Dictionary)
signal achievement_unlocked(achievement: Dictionary)

const DEFAULT_SAVE := "user://save.json"
const CHALLENGE_XP := 10

var library: ContentLibrary
var shell: Shell
var catalog: MissionCatalog
var runner := MissionRunner.new()
var progress: Progress
var achievements: Achievements
var challenges := ChallengeBank.new()
var current_challenge: Dictionary = {}
## Informe de vulnerabilidad en edición (A1+).
var report: Dictionary = {}
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
	achievements = Achievements.new(progress, catalog)
	achievements.unlocked.connect(_on_achievement)
	shell.event_emitted.connect(runner.on_event)
	shell.event_emitted.connect(achievements.on_event)
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


## Unidades con alguna misión completada (T1 siempre disponible para retos).
func unlocked_units() -> PackedStringArray:
	var out := PackedStringArray(["T1"])
	for m in catalog.missions:
		if progress.is_mission_completed(m["id"]) and not m["unit"] in out:
			out.append(m["unit"])
	return out


func new_challenge() -> Dictionary:
	current_challenge = challenges.generate(unlocked_units())
	current_challenge["attempts"] = 0
	return current_challenge


## Devuelve {"correct", "explanation", "xp"}.
func answer_challenge(raw: String) -> Dictionary:
	if current_challenge.is_empty():
		return {}
	current_challenge["attempts"] += 1
	var ok := ConditionEval.answer_matches(current_challenge, raw)
	var res := {"correct": ok, "explanation": current_challenge["explanation"], "xp": 0}
	if ok:
		var before := progress.level()
		var xp: int = CHALLENGE_XP if current_challenge["attempts"] == 1 else CHALLENGE_XP / 2
		progress.add_xp(xp)
		res["xp"] = xp
		shell.emit_event("challenge.solved", {"unit": current_challenge["unit"], "attempts": current_challenge["attempts"]})
		current_challenge = {}
		_after_xp(before)
		save()
	else:
		shell.emit_event("challenge.failed", {"unit": current_challenge["unit"]})
	return res


func save() -> Error:
	if save_path.is_empty():
		return OK
	return SaveStore.save(save_path, progress.data)


func _on_mission_finished(result: Dictionary) -> void:
	var before := progress.level()
	var gained := progress.apply_result(active_mission, result)
	achievements.on_mission_result(result)
	_after_xp(before)
	save()
	mission_completed.emit(active_mission, result, gained)
	progress_changed.emit()


func _after_xp(level_before: int) -> void:
	achievements.check_level()
	if progress.level() > level_before:
		level_up.emit(progress.level(), progress.rank())
	progress_changed.emit()


func _on_achievement(a: Dictionary) -> void:
	achievement_unlocked.emit(a)
	save()
