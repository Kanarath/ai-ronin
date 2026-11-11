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
## Unidades del temario que se estudian fuera del Dojo (lecturas).
var study: StudyPath
## Manifiesto e importador de evidencias de los ejercicios de Python.
var evidence: EvidenceImporter
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
## Editor de Python del Dojo: el código que hay ahora en el editor y de qué ejercicio es.
var py_code: String = ""
var py_exercise_id: String = ""


## Código guardado de un ejercicio de Python, o su código inicial si aún no hay.
func saved_py_code(exercise_id: String, starter: String) -> String:
	return str(progress.data.get("py_code", {}).get(exercise_id, starter))


## Guarda el código del editor con el progreso (por ejercicio).
func store_py_code() -> void:
	if py_exercise_id.is_empty():
		return
	if not progress.data.has("py_code"):
		progress.data["py_code"] = {}
	progress.data["py_code"][py_exercise_id] = py_code
	save()


func _init(p_save_path: String = DEFAULT_SAVE) -> void:
	save_path = p_save_path
	library = ContentLibrary.load_default()
	catalog = MissionCatalog.load_default()
	study = StudyPath.load_default()
	evidence = EvidenceImporter.load_default()
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
	# Primero se avisa a la UI (que prepara el laboratorio) y DESPUÉS arranca el runner,
	# cuyos primeros mensajes (introducción y primer objetivo) deben quedar visibles.
	mission_started.emit(m)
	runner.start(m, shell.event_log[-1]["seq"] if not shell.event_log.is_empty() else 0)
	var pending := study.pending_before(progress, id)
	if not pending.is_empty():
		var names := PackedStringArray()
		for u: Dictionary in pending:
			names.append("%s (lecturas %s)" % [u["title"], u["id"]])
		runner.mentor_message.emit("Antes de esta misión se recomienda estudiar por tu cuenta: %s. No es obligatorio, pero la misión da por sabidos esos conceptos." % ", ".join(names), "hint")
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


## Unidades con alguna misión completada (T1 siempre disponible para retos). Mientras no hay
## ninguna misión de T1 completada (el tutorial T0-01, o un jugador nuevo), solo «T0»: la
## media, lo único que se ha enseñado; distancias y min-max llegan con T1.
func unlocked_units() -> PackedStringArray:
	var t1_done := false
	for m in catalog.missions:
		if m["unit"] == "T1" and progress.is_mission_completed(m["id"]):
			t1_done = true
	if not t1_done or str(active_mission.get("id", "")) == "T0-01":
		return PackedStringArray(["T0"])
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
	var first_time := not progress.is_mission_completed(active_mission["id"])
	var gained := progress.apply_result(active_mission, result)
	achievements.on_mission_result(result)
	_after_xp(before)
	save()
	mission_completed.emit(active_mission, result, gained)
	# Después del «misión completada»: lecturas, ejercicio de la Forja pendiente y desbloqueos.
	_announce_readings(active_mission, first_time)
	progress_changed.emit()


## Importa una evidencia de ronin_check, da el XP del primer verificado y guarda.
func import_evidence(path: String) -> Dictionary:
	var before := progress.level()
	var res := evidence.import_file(path, progress, not save_path.is_empty())
	if res["ok"]:
		if res["first_verified"]:
			progress.add_xp(EvidenceImporter.VERIFIED_XP)
		if res["kind"] == "medicion":
			shell.emit_event("evidence.measured", {"lab": res["exercise"], "configs": res["configs"], "has_baseline": res["has_baseline"],
				"baseline_rate": res["baseline_rate"], "best_rate": res["best_rate"], "model": res["modelo"]})
		else:
			shell.emit_event("evidence.imported", {"exercise": res["exercise"], "passed": res["passed"], "total": res["total"], "all_passed": res["all_passed"]})
		_after_xp(before)
		save()
	return res


## Tras una misión: sus lecturas y las unidades de estudio externo que acaba de desbloquear.
func _announce_readings(m: Dictionary, first_time: bool) -> void:
	var titles := PackedStringArray()
	for id: String in m.get("further_reading", []):
		if study.refs.has(id):
			titles.append(String(study.refs[id]["title"]))
	if not titles.is_empty():
		runner.mentor_message.emit("Para profundizar (enlaces: lecturas %s): %s." % [m["id"], " · ".join(titles)], "info")
	var msg := forja_message(m)
	if not msg.is_empty():
		runner.mentor_message.emit(msg, "info")
	if not first_time:
		return
	for u: Dictionary in study.unlocked_by(progress, m["id"]):
		runner.mentor_message.emit("Desbloqueado en la ruta de estudio externo: %s. Esta parte del temario no tiene misión: se estudia con lecturas. Escribe lecturas %s." % [u["title"], u["id"]], "lesson")


## Aviso de fin de misión sobre su ejercicio de la Forja, o "" si no tiene o ya está verificado
## (en ese caso los tests ya pasan: no tiene sentido pedirlos otra vez). Si el ejercicio es de
## otra misión del arco (A4-02 y A4-03 comparten el de A4-01), lo dice.
func forja_message(m: Dictionary) -> String:
	var ex := evidence.exercise_of_mission(m)
	if ex.is_empty() or EvidenceImporter.is_verified(progress, ex):
		return ""
	var info: Dictionary = evidence.exercises[ex]
	var dir := String(info.get("test_path", "")).get_base_dir()
	var path := dir.path_join(String(info["file"])) if not dir.is_empty() else String(m.get("debrief", {}).get("exercise", info["file"]))
	var whose := "" if ex == str(m.get("id", "")) else " (el ejercicio de %s, que también cubre esta misión)" % ex
	var check := "en forja/ejercicios ejecuta py -m ronin_check %s" % ex if dir == "forja/ejercicios" else "genera la evidencia con ronin_check %s (pasos en el README de %s)" % [ex, dir]
	return "🛠 Ahora, con tus manos: abre %s%s y haz que pasen sus tests. Después, %s y aquí evidence import. ¿No tienes Python? Escribe forja setup." % [path, whose, check]


func _after_xp(level_before: int) -> void:
	achievements.check_level()
	if progress.level() > level_before:
		level_up.emit(progress.level(), progress.rank())
	progress_changed.emit()


func _on_achievement(a: Dictionary) -> void:
	achievement_unlocked.emit(a)
	save()
