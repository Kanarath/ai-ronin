class_name MockEngagement
extends RefCounted
## Encargo de red team de la prueba final C5: alcance y reglas de enfrentamiento, inventario de
## activos de IA, modelo de amenazas, hallazgos respaldados por evidencias del laboratorio y retest.
##
## REAL (estructura): un hallazgo solo vale con una evidencia reproducible (una batería de ataques con
## éxitos sobre el activo); un hallazgo solo se cierra con un retest posterior a 0 éxitos SIN romper las
## tareas legítimas; lo que está fuera de alcance no se toca aunque sea técnicamente accesible.
## ⚗ SIMULADO: la empresa, sus sistemas y el contrato.

const PATH := "res://content/engagement/forja_norte.json"
## Tipo de activo → [prefijo de los eventos de la batería, campo con el nombre del objeto].
const EVENT_KEYS := {"bot": ["bot", "bot"], "rag": ["rag", "rag"], "agent": ["agent", "agent"], "mcp": ["mcp", "host"], "pipeline": ["supply", "pipeline"]}

var engagement_name: String = ""
var data: Dictionary = {}
var bindings: Dictionary = {}   # id de activo → nombre del objeto del laboratorio
var threats: Dictionary = {}    # id de activo → Array de categorías OWASP
var findings: Array[Dictionary] = []  # {asset, owasp, object, kind, seq, baseline, total}


static func create(p_name: String) -> MockEngagement:
	var e := MockEngagement.new()
	e.engagement_name = p_name
	e.data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return e


func asset(id: String) -> Dictionary:
	for a: Dictionary in data["assets"]:
		if a["id"] == id.to_upper():
			return a
	return {}


func asset_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for a: Dictionary in data["assets"]:
		out.append(a["id"])
	return out


func in_scope_count() -> int:
	var n := 0
	for a: Dictionary in data["assets"]:
		n += 1 if a["in_scope"] else 0
	return n


func covered_assets() -> int:
	var n := 0
	for id: String in threats:
		for cat: String in threats[id]:
			if cat in asset(id)["threats"]:
				n += 1
				break
	return n


func add_threat(id: String, category: String) -> bool:
	var a := asset(id)
	if not threats.has(a["id"]):
		threats[a["id"]] = []
	if not category in threats[a["id"]]:
		threats[a["id"]].append(category)
	return category in a["threats"]


## Último evento de un tipo para un objeto, con seq > after. {} si no hay.
static func last_event(shell: Shell, event_name: String, field: String, object_name: String, after: int = 0) -> Dictionary:
	var events := shell.events_named(event_name)
	for i in range(events.size() - 1, -1, -1):
		var ev: Dictionary = events[i]
		if ev["seq"] <= after:
			break
		if ev["data"].get(field, "") == object_name:
			return ev
	return {}


## Comprueba la evidencia y registra el hallazgo. Devuelve "" o el motivo del rechazo.
func add_finding(shell: Shell, id: String, owasp: String) -> String:
	var a := asset(id)
	if not bindings.has(a["id"]):
		return "%s no está vinculado a ningún objeto del laboratorio: engagement bind %s %s <objeto>" % [a["id"], engagement_name, a["id"]]
	if not owasp in a["threats"]:
		return "%s no encaja con %s (%s). Categorías que sí encajan: %s" % [owasp, a["id"], a["name"], ", ".join(a["threats"])]
	var keys: Array = EVENT_KEYS[a["kind"]]
	var ev := last_event(shell, keys[0] + ".attacks", keys[1], bindings[a["id"]])
	if ev.is_empty():
		return "Sin evidencia: no hay ninguna batería de ataques sobre %s. Lanza: %s attack %s" % [bindings[a["id"]], a["kind"] if a["kind"] != "pipeline" else "supply", bindings[a["id"]]]
	if int(ev["data"]["successes"]) == 0:
		return "Sin evidencia: la última batería sobre %s no tuvo ningún éxito." % bindings[a["id"]]
	for f in findings:
		if f["asset"] == a["id"] and f["owasp"] == owasp:
			return "Ya hay un hallazgo %s en %s." % [owasp, a["id"]]
	findings.append({"asset": a["id"], "owasp": owasp, "object": bindings[a["id"]], "kind": a["kind"], "seq": ev["seq"],
		"baseline": int(ev["data"]["successes"]), "total": int(ev["data"]["total"])})
	return ""


func findings_assets() -> int:
	var ids := {}
	for f in findings:
		ids[f["asset"]] = true
	return ids.size()


## Estado de cada hallazgo: corregido si, después de registrarlo, la última batería sobre el objeto
## tiene 0 éxitos y la última evaluación de tareas legítimas está a 1,0.
func retest(shell: Shell) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for f in findings:
		var keys: Array = EVENT_KEYS[f["kind"]]
		var att := last_event(shell, keys[0] + ".attacks", keys[1], f["object"], f["seq"])
		var ev := last_event(shell, keys[0] + ".eval", keys[1], f["object"], f["seq"])
		var now := int(att["data"]["successes"]) if not att.is_empty() else -1
		var rate := float(ev["data"]["pass_rate"]) if not ev.is_empty() else -1.0
		var status := "corregido" if now == 0 and rate >= 0.999 else "abierto"
		var why := ""
		if att.is_empty():
			why = "sin batería posterior al hallazgo"
		elif now > 0:
			why = "%d ataques siguen teniendo éxito" % now
		elif ev.is_empty():
			why = "falta comprobar las tareas legítimas (eval)"
		elif rate < 0.999:
			why = "la defensa rompe tareas legítimas (%.2f)" % rate
		out.append({"asset": f["asset"], "owasp": f["owasp"], "object": f["object"], "baseline": f["baseline"], "total": f["total"],
			"now": now, "pass_rate": rate, "status": status, "why": why})
	return out
