class_name Achievements
extends RefCounted
## Logros (sellos). Data-driven: res://content/achievements.json.
## Escucha los eventos del Shell y los resultados de misión; guarda en Progress:
##   data["achievements"][id] = fecha · data["ach_counters"][id] = progreso acumulado.
##
## Condiciones:
##   event        {event, where?, count}   → veces que ha ocurrido ese evento (con filtro)
##   event_any    {events[], count}        → suma de varios eventos
##   mission      {where}                  → algún resultado de misión cumple el filtro
##   missions_completed {prefix}           → todas las misiones del catálogo con ese prefijo
##   level        {gte}

signal unlocked(achievement: Dictionary)

const PATH := "res://content/achievements.json"

var list: Array[Dictionary] = []
var progress: Progress
var catalog: MissionCatalog


func _init(p_progress: Progress, p_catalog: MissionCatalog) -> void:
	progress = p_progress
	catalog = p_catalog
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if data is Dictionary:
		for a: Dictionary in data["achievements"]:
			list.append(a)
	for key in ["achievements", "ach_counters"]:
		if not progress.data.has(key):
			progress.data[key] = {}


func is_unlocked(id: String) -> bool:
	return progress.data["achievements"].has(id)


func counter(id: String) -> int:
	return int(progress.data["ach_counters"].get(id, 0))


func on_event(e: Dictionary) -> void:
	for a in list:
		if is_unlocked(a["id"]):
			continue
		var c: Dictionary = a["condition"]
		var hit := false
		match c["type"]:
			"event":
				hit = e["name"] == c["event"] and ConditionEval.match_where(e["data"], c.get("where", {}))
			"event_any":
				hit = e["name"] in c["events"]
		if hit:
			var n := counter(a["id"]) + 1
			progress.data["ach_counters"][a["id"]] = n
			if n >= int(c.get("count", 1)):
				_unlock(a)


func on_mission_result(result: Dictionary) -> void:
	for a in list:
		if is_unlocked(a["id"]):
			continue
		var c: Dictionary = a["condition"]
		match c["type"]:
			"mission":
				if ConditionEval.match_where(result, c["where"]):
					_unlock(a)
			"missions_completed":
				var all_done := true
				var any := false
				for m in catalog.missions:
					if String(m["id"]).begins_with(c["prefix"]):
						any = true
						all_done = all_done and progress.is_mission_completed(m["id"])
				if any and all_done:
					_unlock(a)
	check_level()


func check_level() -> void:
	for a in list:
		if not is_unlocked(a["id"]) and a["condition"]["type"] == "level" and progress.level() >= int(a["condition"]["gte"]):
			_unlock(a)


func _unlock(a: Dictionary) -> void:
	progress.data["achievements"][a["id"]] = Time.get_datetime_string_from_system()
	unlocked.emit(a)
