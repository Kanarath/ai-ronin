class_name MissionRunner
extends RefCounted
## Ejecuta una misión: objetivos en orden, hipótesis, pistas, diagnósticos y prueba de dominio.
## Escucha los eventos del Shell; no sabe nada de la interfaz.
##
## Reglas pedagógicas que implementa:
##   - Cada objetivo exige acción NUEVA: solo cuentan los eventos posteriores a su activación.
##   - Si el objetivo pide hipótesis, solo cuentan los eventos posteriores a la hipótesis
##     (predice → ejecuta → compara).
##   - Pistas en 5 niveles, a demanda; el nivel 5 exige confirmación; en la prueba de
##     dominio el máximo es el nivel 2.

signal mentor_message(text: String, kind: String)  # kind: info, question, praise, warn, hint, debrief
signal state_changed()
signal mission_finished(result: Dictionary)
## XP ganada durante la misión (se consolida al terminarla; la UI la muestra al momento).
signal xp_awarded(amount: int, reason: String)

const HINT_PENALTY: Array[int] = [0, 0, 5, 20, 35, 60]
const TRIAL_MAX_HINT := 2

var mission: Dictionary = {}
var phase: String = "idle"  # idle · main · trial · done
var objectives: Array = []
var index: int = 0
var events: Array[Dictionary] = []
var hint_levels: Dictionary = {}  # "fase:objetivo" -> nivel máximo usado
var hypotheses: Dictionary = {}  # "fase:objetivo" -> {"value", "seq"}
var reflections: Array[Dictionary] = []
var xp_log: Array[Dictionary] = []
var _active_since: int = 0
var _last_seq: int = 0
var _diagnostics_shown: Dictionary = {}
var _hypothesis_reminded: Dictionary = {}


func start(p_mission: Dictionary, start_seq: int) -> void:
	mission = p_mission
	phase = "main"
	objectives = mission.get("objectives", [])
	index = 0
	events.clear()
	hint_levels.clear()
	hypotheses.clear()
	reflections.clear()
	xp_log.clear()
	_diagnostics_shown.clear()
	_hypothesis_reminded.clear()
	_last_seq = start_seq
	_active_since = start_seq
	mentor_message.emit(mission.get("mentor_intro", "Empecemos."), "info")
	# Teoría general de la misión (tarjetas sin «unlock_on»): se muestra al empezar.
	for card: Dictionary in mission.get("theory_cards", []):
		if not card.has("unlock_on") or card["unlock_on"] == "start":
			mentor_message.emit("%s\n%s" % [card["title"], card["body"]], "lesson")
	_announce_current()
	state_changed.emit()


func is_running() -> bool:
	return phase == "main" or phase == "trial"


func current_objective() -> Dictionary:
	if not is_running() or index >= objectives.size():
		return {}
	return objectives[index]


func objective_key(obj: Dictionary = {}) -> String:
	var o := obj if not obj.is_empty() else current_objective()
	return "%s:%s" % [phase, o.get("id", "?")]


## Lo llama el Shell (señal event_emitted) por cada evento.
func on_event(e: Dictionary) -> void:
	_last_seq = e["seq"]
	if not is_running():
		return
	events.append(e)
	var obj := current_objective()
	if obj.is_empty():
		return
	var key := objective_key(obj)
	match e["name"]:
		"hypothesis.recorded":
			hypotheses[key] = {"value": e["data"]["value"], "seq": e["seq"]}
			_xp(5, "hipótesis registrada")
			mentor_message.emit("Hipótesis anotada: «%s». Ahora compruébala." % e["data"]["value"], "info")
		"reflection.submitted":
			reflections.append({"mission": mission["id"], "objective": obj["id"], "text": e["data"]["text"]})
	_check_current()


func _check_current() -> void:
	var obj := current_objective()
	if obj.is_empty():
		return
	var key := objective_key(obj)
	var min_seq := _active_since
	var needs_hypothesis := obj.has("prediction")
	if needs_hypothesis and hypotheses.has(key):
		min_seq = maxi(min_seq, hypotheses[key]["seq"])
	var validator: Dictionary = obj["validator"]
	var passed := ConditionEval.evaluate(validator, events, min_seq)

	if passed and needs_hypothesis and not hypotheses.has(key):
		if not _hypothesis_reminded.has(key):
			_hypothesis_reminded[key] = true
			mentor_message.emit("Alto. Antes de ejecutar, registra tu predicción: %s\nUsa: hipotesis <tu respuesta>. Después repite el experimento." % obj["prediction"]["prompt"], "warn")
		return

	if passed:
		_complete_current(obj)
		return

	_check_diagnostics(obj, min_seq)
	var last: Dictionary = events[-1] if not events.is_empty() else {}
	if last.is_empty() or last["seq"] <= min_seq:
		return
	if ConditionEval.contains_type(validator, "answer") and last["name"] == "answer.submitted":
		var why := ""
		for c: Dictionary in obj.get("choices", []):
			if str(c["id"]).to_lower() == str(last["data"].get("value", "")).strip_edges().to_lower():
				why = str(c.get("why", ""))
		if not why.is_empty():
			mentor_message.emit("No. %s Prueba otra vez." % why, "warn")
		else:
			mentor_message.emit(obj.get("wrong_answer", "No es correcto. Revisa el resultado y vuelve a intentarlo. Si te atascas: hint"), "warn")
	elif validator.get("type") == "reflection" and last["name"] == "reflection.submitted":
		mentor_message.emit("Desarrolla un poco más tu explicación (mínimo %d palabras). Escribe como si se lo explicaras a un compañero." % int(validator.get("min_words", 10)), "warn")


func _check_diagnostics(obj: Dictionary, min_seq: int) -> void:
	for d: Dictionary in obj.get("diagnostics", []):
		var dkey := objective_key(obj) + ":" + str(d.get("id", d["message"].hash()))
		if _diagnostics_shown.has(dkey):
			continue
		if ConditionEval.evaluate(d["when"], events, min_seq):
			_diagnostics_shown[dkey] = true
			mentor_message.emit(d["message"], "question")
			return


func _complete_current(obj: Dictionary) -> void:
	var key := objective_key(obj)
	var used: int = hint_levels.get(key, 0)
	_xp(20, "objetivo «%s»" % obj["id"])
	if used == 0:
		_xp(10, "sin pistas")
	if obj.has("on_complete"):
		mentor_message.emit(obj["on_complete"], "praise")
	else:
		mentor_message.emit("✓ Objetivo cumplido.", "praise")
	index += 1
	_active_since = _last_seq
	if index >= objectives.size():
		_end_phase()
	else:
		_announce_current()
	state_changed.emit()


func _end_phase() -> void:
	if phase == "main":
		_xp(50, "misión completada")
		var trial: Dictionary = mission.get("mastery_trial", {})
		if not trial.get("objectives", []).is_empty():
			phase = "trial"
			objectives = trial["objectives"]
			index = 0
			mentor_message.emit(trial.get("intro", "Prueba de dominio: resuélvela sin ayuda (máximo pista de nivel 2)."), "info")
			_announce_current()
			return
		_finish(false)
	elif phase == "trial":
		_xp(50, "prueba de dominio superada")
		_finish(true)


func _finish(trial_passed: bool) -> void:
	phase = "done"
	var debrief: Dictionary = mission.get("debrief", {})
	for section: String in ["what_happened", "why", "in_production"]:
		if debrief.has(section):
			mentor_message.emit(debrief[section], "debrief")
	mission_finished.emit(result(trial_passed))


func result(trial_passed: bool = false) -> Dictionary:
	var max_main := 0
	var max_trial := 0
	for k: String in hint_levels:
		if k.begins_with("main:"):
			max_main = maxi(max_main, hint_levels[k])
		else:
			max_trial = maxi(max_trial, hint_levels[k])
	return {
		"mission_id": mission.get("id", ""),
		"completed": phase == "done",
		"trial_passed": trial_passed,
		"max_hint_main": max_main,
		"max_hint_trial": max_trial,
		"score": 100 - HINT_PENALTY[max_main],
		"xp_log": xp_log.duplicate(),
		"reflections": reflections.duplicate(),
		"hypotheses": hypotheses.duplicate(),
	}


## Pide la siguiente pista del objetivo actual. Devuelve {ok, level, text}.
func request_hint(confirm: bool) -> Dictionary:
	var obj := current_objective()
	if obj.is_empty():
		return {"ok": false, "level": 0, "text": "No hay ningún objetivo activo. Empieza una misión: mission list"}
	var hints: Array = obj.get("hints", [])
	var key := objective_key(obj)
	var next: int = hint_levels.get(key, 0) + 1
	if next > hints.size():
		return {"ok": false, "level": next - 1, "text": "No hay más pistas para este objetivo. Repasa: help, man y explain."}
	if phase == "trial" and next > TRIAL_MAX_HINT:
		return {"ok": false, "level": next - 1, "text": "En la prueba de dominio solo se permiten pistas hasta el nivel %d. Demuestra que puedes solo." % TRIAL_MAX_HINT}
	if next == 5 and not confirm:
		return {"ok": false, "level": 4, "text": "La pista de nivel 5 es el ejemplo resuelto: la competencia quedará como «practicada», no «dominada». Si de verdad la necesitas: hint --confirm"}
	hint_levels[key] = next
	var prefix: String = ["", "Pista 1 · sutil", "Pista 2 · técnica", "Pista 3 · paso a paso (reduce la maestría)", "Pista 4 · explicación (reduce la maestría)", "Pista 5 · ejemplo resuelto"][next]
	var text := "%s\n%s" % [prefix, hints[next - 1]]
	mentor_message.emit(text, "hint")
	state_changed.emit()
	return {"ok": true, "level": next, "text": text}


func _announce_current() -> void:
	var obj := current_objective()
	if obj.is_empty():
		return
	var label := "Prueba de dominio · " if phase == "trial" else ""
	# Primero se enseña, después se pide: la lección del objetivo va antes del reto.
	# En la prueba de dominio no hay lecciones (se trata de demostrar sin ayuda).
	if phase == "main":
		for card: Dictionary in mission.get("theory_cards", []):
			if card.get("unlock_on", "") == "objective:" + str(obj["id"]):
				mentor_message.emit("%s\n%s" % [card["title"], card["body"]], "lesson")
		if obj.has("teach"):
			mentor_message.emit(obj["teach"], "lesson")
	var task: String = "%sTu turno (%d/%d): %s" % [label, index + 1, objectives.size(), obj["text"]]
	# Pregunta de comprobación: opciones a), b), c)… que se responden con answer <letra>.
	for c: Dictionary in obj.get("choices", []):
		task += "\n%s) %s" % [c["id"], c["text"]]
	if not obj.get("choices", []).is_empty():
		task += "\nResponde con answer <letra> (o con los botones)."
	mentor_message.emit(task, "task")
	if obj.has("prediction"):
		var p: Dictionary = obj["prediction"]
		var opts: Array = p.get("options", [])
		var opt_text := "\nOpciones: " + " · ".join(PackedStringArray(opts)) if not opts.is_empty() else ""
		mentor_message.emit("Predice antes de ejecutar: %s%s\nUsa: hipotesis <tu respuesta>" % [p["prompt"], opt_text], "question")


func _xp(amount: int, reason: String) -> void:
	xp_log.append({"amount": amount, "reason": reason})
	xp_awarded.emit(amount, reason)
