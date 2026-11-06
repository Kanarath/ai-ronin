class_name ConditionEval
extends RefCounted
## Evalúa validadores declarados en JSON contra el registro de eventos.
## Un objetivo se cumple por lo que HICISTE (eventos), no por lo que respondiste en un test.
##
## Validadores:
##   {"type":"event", "event":"model.evaluated", "where":{...}, "count":{"gte":1}}
##   {"type":"sequence", "steps":[<validador event>, ...]}   → en ese orden
##   {"type":"all"|"any", "of":[...]}  ·  {"type":"not", "of":<validador>}
##   {"type":"answer", "expected":0.25, "tolerance":0.01}     → comando answer
##   {"type":"hypothesis"}                                    → comando hipotesis
##   {"type":"reflection", "min_words":15}                    → comando reflexion
##
## Condiciones en "where": valor literal (igualdad) o {"op": arg} con op en
##   eq, ne, gt, gte, lt, lte, in, contains, starts_with, ends_with, exists.

const NUMERIC_EPS := 1e-9


## ¿Se cumple el validador con los eventos de seq > min_seq?
static func evaluate(spec: Dictionary, events: Array[Dictionary], min_seq: int = 0) -> bool:
	match str(spec.get("type", "")):
		"event":
			var n := count_matching(spec, events, min_seq)
			return _compare_count(n, spec.get("count", {"gte": 1}))
		"sequence":
			var cursor := min_seq
			for step: Dictionary in spec.get("steps", []):
				var found := first_matching(step, events, cursor)
				if found.is_empty():
					return false
				cursor = found["seq"]
			return true
		"all":
			for sub: Dictionary in spec.get("of", []):
				if not evaluate(sub, events, min_seq):
					return false
			return true
		"any":
			for sub: Dictionary in spec.get("of", []):
				if evaluate(sub, events, min_seq):
					return true
			return false
		"not":
			return not evaluate(spec.get("of", {}), events, min_seq)
		"answer":
			for e in events:
				if e["seq"] > min_seq and e["name"] == "answer.submitted" and answer_matches(spec, e["data"].get("value", "")):
					return true
			return false
		"hypothesis":
			return _any_named(events, "hypothesis.recorded", min_seq)
		"reflection":
			for e in events:
				if e["seq"] > min_seq and e["name"] == "reflection.submitted" and int(e["data"].get("words", 0)) >= int(spec.get("min_words", 10)):
					return true
			return false
	push_error("Validador desconocido: %s" % spec)
	return false


## ¿Contiene el validador (o alguno de sus hijos) un validador de este tipo?
static func contains_type(spec: Variant, type: String) -> bool:
	if not spec is Dictionary:
		return false
	if spec.get("type", "") == type:
		return true
	for key in ["of", "steps"]:
		var child: Variant = spec.get(key)
		if child is Array:
			for c in child:
				if contains_type(c, type):
					return true
		elif child is Dictionary and contains_type(child, type):
			return true
	return false


static func answer_matches(spec: Dictionary, raw: Variant) -> bool:
	var expected: Variant = spec.get("expected")
	var text := str(raw).strip_edges().replace(",", ".").trim_suffix("%").strip_edges()
	if expected is float or expected is int:
		if not text.is_valid_float():
			return false
		return absf(text.to_float() - float(expected)) <= float(spec.get("tolerance", 0.0)) + NUMERIC_EPS
	var accepted: Array = spec.get("accept", [expected])
	for a in accepted:
		if str(a).to_lower() == text.to_lower():
			return true
	return false


static func count_matching(spec: Dictionary, events: Array[Dictionary], min_seq: int) -> int:
	var n := 0
	for e in events:
		if e["seq"] > min_seq and event_matches(spec, e):
			n += 1
	return n


static func first_matching(spec: Dictionary, events: Array[Dictionary], min_seq: int) -> Dictionary:
	for e in events:
		if e["seq"] > min_seq and event_matches(spec, e):
			return e
	return {}


static func event_matches(spec: Dictionary, e: Dictionary) -> bool:
	if e["name"] != spec.get("event", ""):
		return false
	return match_where(e["data"], spec.get("where", {}))


static func match_where(data: Dictionary, where: Dictionary) -> bool:
	for key: String in where:
		var cond: Variant = where[key]
		var value: Variant = get_path(data, key)
		if cond is Dictionary:
			for op: String in cond:
				if not _op(op, value, cond[op]):
					return false
		elif not _eq(value, cond):
			return false
	return true


## Acceso por ruta con puntos: "results.0.test".
static func get_path(data: Variant, path: String) -> Variant:
	var cur: Variant = data
	for part in path.split("."):
		if cur is Dictionary:
			if not cur.has(part):
				return null
			cur = cur[part]
		elif cur is Array and part.is_valid_int():
			var i := part.to_int()
			if i < 0 or i >= cur.size():
				return null
			cur = cur[i]
		else:
			return null
	return cur


static func _op(op: String, value: Variant, arg: Variant) -> bool:
	match op:
		"eq":
			return _eq(value, arg)
		"ne":
			return not _eq(value, arg)
		"gt", "gte", "lt", "lte":
			if not (_is_num(value) and _is_num(arg)):
				return false
			var v := float(value)
			var a := float(arg)
			match op:
				"gt": return v > a + NUMERIC_EPS
				"gte": return v >= a - NUMERIC_EPS
				"lt": return v < a - NUMERIC_EPS
				_: return v <= a + NUMERIC_EPS
		"in":
			for item in arg:
				if _eq(value, item):
					return true
			return false
		"contains":
			return value != null and str(value).contains(str(arg))
		"starts_with":
			return value != null and str(value).begins_with(str(arg))
		"ends_with":
			return value != null and str(value).ends_with(str(arg))
		"exists":
			return (value != null) == bool(arg)
	push_error("Operador desconocido: " + op)
	return false


static func _eq(a: Variant, b: Variant) -> bool:
	if _is_num(a) and _is_num(b):
		return absf(float(a) - float(b)) <= NUMERIC_EPS
	if typeof(a) != typeof(b):
		return false
	return a == b


static func _is_num(v: Variant) -> bool:
	return v is int or v is float


static func _compare_count(n: int, spec: Dictionary) -> bool:
	for op: String in spec:
		if not _op(op, n, spec[op]):
			return false
	return true


static func _any_named(events: Array[Dictionary], event_name: String, min_seq: int) -> bool:
	for e in events:
		if e["seq"] > min_seq and e["name"] == event_name:
			return true
	return false
