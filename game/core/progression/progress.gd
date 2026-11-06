class_name Progress
extends RefCounted
## Progreso del alumno: XP, nivel, misiones, competencias y reflexiones.
##
## Estados de competencia: vista → practicada → dominada → transferida.
##   practicada: misión completada (con o sin ayuda).
##   dominada:   prueba de dominio superada y sin usar el ejemplo resuelto (pista 5).
##   transferida: variante en otro contexto superada (llegará en próximas versiones).

const STATES: Array[String] = ["", "vista", "practicada", "dominada", "transferida"]
const REPLAY_XP_FACTOR := 0.25

var data: Dictionary = {}


func _init(p_data: Dictionary = {}) -> void:
	data = p_data
	for key in ["missions", "competencies"]:
		if not data.has(key):
			data[key] = {}
	if not data.has("reflections"):
		data["reflections"] = []
	if not data.has("xp"):
		data["xp"] = 0


func xp() -> int:
	return int(data["xp"])


## Nivel = 1 + floor(√(xp / 50)): cada nivel cuesta un poco más que el anterior.
func level() -> int:
	return 1 + int(floor(sqrt(xp() / 50.0)))


func xp_for_level(lv: int) -> int:
	return 50 * (lv - 1) * (lv - 1)


func mission(id: String) -> Dictionary:
	return data["missions"].get(id, {})


func is_mission_completed(id: String) -> bool:
	return mission(id).get("completed", false)


func competency_state(id: String) -> String:
	return data["competencies"].get(id, {}).get("state", "")


func mark_seen(competencies: Array) -> void:
	for c: String in competencies:
		_raise(c, "vista", 0)


## Aplica el resultado de una misión. Devuelve el XP ganado.
func apply_result(m: Dictionary, result: Dictionary) -> int:
	var id: String = m["id"]
	var prev := mission(id)
	var replay: bool = prev.get("completed", false)
	var gained := 0
	for item: Dictionary in result["xp_log"]:
		gained += int(item["amount"])
	if replay:
		gained = int(round(gained * REPLAY_XP_FACTOR))
	data["xp"] = xp() + gained

	var entry := prev.duplicate()
	entry["attempts"] = int(prev.get("attempts", 0)) + 1
	entry["completed"] = prev.get("completed", false) or result["completed"]
	entry["trial_passed"] = prev.get("trial_passed", false) or result["trial_passed"]
	entry["best_score"] = maxi(int(prev.get("best_score", 0)), int(result["score"]))
	entry["last_max_hint"] = result["max_hint_main"]
	entry["last_played"] = Time.get_datetime_string_from_system()
	data["missions"][id] = entry

	var trains: Array = m.get("competencies", {}).get("trains", [])
	for c: String in trains:
		if result["completed"]:
			_raise(c, "practicada", result["score"])
		if result["trial_passed"] and result["max_hint_main"] < 5:
			_raise(c, "dominada", result["score"])

	for r: Dictionary in result["reflections"]:
		var copy := r.duplicate()
		copy["at"] = Time.get_datetime_string_from_system()
		data["reflections"].append(copy)
	return gained


func _raise(c: String, state: String, score: int) -> void:
	var cur: Dictionary = data["competencies"].get(c, {"state": "", "score": 0})
	if STATES.find(state) > STATES.find(cur.get("state", "")):
		cur["state"] = state
	cur["score"] = maxi(int(cur.get("score", 0)), score)
	data["competencies"][c] = cur


## ¿Se cumplen los requisitos de una misión?
func requirements_met(m: Dictionary) -> bool:
	for req: String in m.get("requires_missions", []):
		if not is_mission_completed(req):
			return false
	return true
