class_name MockAudit
extends RefCounted
## Laboratorio E3: evaluaciones de impacto (FRIA del AI Act y EIPD del RGPD), auditoría por muestreo
## de controles con evidencias, clasificación de no conformidades e informe con rúbrica y seguimiento.
##
## REAL: los artículos del AI Act y del RGPD, las fechas y el texto de las subcategorías del NIST AI RMF
## (verificados el 2026-11-10); el muestreo aleatorio con semilla y el cálculo de cobertura.
## ⚗ SIMULADO: el ayuntamiento, Ayuda-Valle, sus documentos, expedientes y cifras.
## La clasificación de no conformidades (mayor, menor, observación) es práctica de la industria.

const PATH := "res://content/audit/valle_auditoria.json"
const FUNCTIONS: Array[String] = ["GOVERN", "MAP", "MEASURE", "MANAGE"]
const RATINGS: Array[String] = ["conforme", "nc-mayor", "nc-menor", "observacion"]
const WHERE: Array[String] = ["fria", "eipd", "ambas"]
const FIELDS: Array[String] = ["criterio", "evidencia", "riesgo", "recomendacion", "seguimiento"]
const REPORT_FIELDS: Array[String] = ["alcance", "conclusion"]
const SEED := 42
const MIN_RECORDS := 10

var audit_name: String = ""
var data: Dictionary = {}
var duties: Dictionary = {}       # caso → {"fria": bool, "eipd": bool}
var placed: Dictionary = {}       # E# → fria|eipd|ambas
var assigned: Dictionary = {}     # T# → actor
var sample: PackedStringArray = []
var seen_evidence: Dictionary = {} # C## → true
var records_n: Dictionary = {}    # C## → tamaño de la muestra de registros vista
var ratings: Dictionary = {}      # C## → clase
var drafts: Dictionary = {}       # H# o "informe" → {campo: letra}
var followups_seen: Dictionary = {}
var closed: Dictionary = {}       # H# → true


static func create(p_name: String) -> MockAudit:
	var a := MockAudit.new()
	a.audit_name = p_name
	a.data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return a


static func _find(list: Array, id: String) -> Dictionary:
	for x: Dictionary in list:
		if String(x["id"]).to_lower() == id.to_lower():
			return x
	return {}


static func ids(list: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for x: Dictionary in list:
		out.append(x["id"])
	return out


func case_of(id: String) -> Dictionary: return _find(data["cases"], id)
func element(id: String) -> Dictionary: return _find(data["elements"], id)
func task(id: String) -> Dictionary: return _find(data["tasks"], id)
func actor(id: String) -> Dictionary: return _find(data["actors"], id)
func control(id: String) -> Dictionary: return _find(data["controls"], id)
func finding(id: String) -> Dictionary: return _find(data["findings"], id)


# ── E3-01 · evaluaciones de impacto ──────────────────────────────────────────

func set_duty(id: String, fria: bool, eipd: bool) -> bool:
	var c := case_of(id)
	duties[c["id"]] = {"fria": fria, "eipd": eipd}
	return c["fria"] == fria and c["eipd"] == eipd


func correct_duties() -> int:
	var n := 0
	for c: Dictionary in data["cases"]:
		var d: Dictionary = duties.get(c["id"], {})
		n += 1 if not d.is_empty() and d["fria"] == c["fria"] and d["eipd"] == c["eipd"] else 0
	return n


func place(id: String, where: String) -> bool:
	var e := element(id)
	placed[e["id"]] = where
	return e["where"] == where


func correct_placements() -> int:
	var n := 0
	for e: Dictionary in data["elements"]:
		n += 1 if placed.get(e["id"], "") == e["where"] else 0
	return n


func assign(id: String, actor_id: String) -> bool:
	var t := task(id)
	assigned[t["id"]] = actor_id
	return t["actor"] == actor_id


func correct_assignments() -> int:
	var n := 0
	for t: Dictionary in data["tasks"]:
		n += 1 if assigned.get(t["id"], "") == t["actor"] else 0
	return n


# ── E3-02 · muestreo, evidencias y no conformidades ──────────────────────────

func control_ids() -> PackedStringArray:
	return ids(data["controls"])


## Muestra aleatoria de n controles con la semilla fija (sin tener en cuenta el riesgo).
func random_sample(n: int) -> PackedStringArray:
	var pool := control_ids()
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var out := PackedStringArray(Array(pool).slice(0, clampi(n, 0, pool.size())))
	out.sort()
	return out


func set_sample(list: PackedStringArray) -> void:
	var out := PackedStringArray()
	for id in list:
		var c := control(id)
		if not c.is_empty() and not c["id"] in out:
			out.append(c["id"])
	out.sort()
	sample = out


## Plan de auditoría: cobertura por función y de los controles de riesgo alto.
func plan() -> Dictionary:
	var by_function := {}
	for f in FUNCTIONS:
		by_function[f] = 0
	var alta_total := 0
	var alta_in := 0
	var missing_alta := PackedStringArray()
	for c: Dictionary in data["controls"]:
		var inside: bool = c["id"] in sample
		if inside:
			by_function[c["function"]] += 1
		if c["risk"] == "alta":
			alta_total += 1
			if inside:
				alta_in += 1
			else:
				missing_alta.append(c["id"])
	var uncovered := PackedStringArray()
	for f in FUNCTIONS:
		if by_function[f] == 0:
			uncovered.append(f)
	var max_sample := int(data["audit"]["max_sample"])
	var valid := not sample.is_empty() and missing_alta.is_empty() and uncovered.is_empty() and sample.size() <= max_sample
	return {"size": sample.size(), "max": max_sample, "total": data["controls"].size(), "by_function": by_function,
		"alta_in": alta_in, "alta_total": alta_total, "missing_alta": ",".join(missing_alta), "uncovered": ",".join(uncovered), "valid": valid}


## Expedientes de un control y muestra aleatoria de n (semilla fija). Devuelve {"ids", "failing"}.
func sample_records(id: String, n: int) -> Dictionary:
	var c := control(id)
	var total := int(c.get("records", 0))
	var pool: Array[String] = []
	for i in total:
		pool.append("D%02d" % (i + 1))
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var picked: Array = pool.slice(0, clampi(n, 0, total))
	picked.sort()
	var failing: Array = []
	for r: String in picked:
		if r in c["records_failing"]:
			failing.append(r)
	records_n[c["id"]] = maxi(int(records_n.get(c["id"], 0)), picked.size())
	return {"ids": picked, "failing": failing}


## Devuelve "" o el motivo por el que todavía no se puede concluir sobre el control.
func can_rate(id: String) -> String:
	var c := control(id)
	if not c["id"] in sample:
		return "%s no está en tu muestra: solo concluyes sobre lo que has auditado." % c["id"]
	if not seen_evidence.has(c["id"]):
		return "Todavía no has visto la evidencia de %s: un auditor no concluye sin evidencia (audit evidence)." % c["id"]
	if c.has("records") and int(records_n.get(c["id"], 0)) < MIN_RECORDS:
		return "%s depende de cómo se aplica el control en los expedientes: mira una muestra de al menos %d (audit records)." % [c["id"], MIN_RECORDS]
	return ""


func rate(id: String, rating: String) -> bool:
	var c := control(id)
	ratings[c["id"]] = rating
	return c["rating"] == rating


func rating_score() -> Dictionary:
	var ok := 0
	var wrong := 0
	var pending := 0
	var alta_ok := 0
	for id in sample:
		var c := control(id)
		var r: String = ratings.get(id, "")
		if r == "":
			pending += 1
		elif r == c["rating"]:
			ok += 1
			alta_ok += 1 if c["risk"] == "alta" else 0
		else:
			wrong += 1
	return {"ok": ok, "wrong": wrong, "pending": pending, "alta_ok": alta_ok}


# ── E3-03 · informe con rúbrica y seguimiento ───────────────────────────────

func field_spec(target: String, field: String) -> Dictionary:
	if target.to_lower() == "informe":
		return data["report_fields"].get(field, {})
	var f := finding(target)
	if f.is_empty():
		return {}
	return f["fields"].get(field, {})


func draft(target: String, field: String, letter: String) -> bool:
	var key := "informe" if target.to_lower() == "informe" else String(finding(target)["id"])
	if not drafts.has(key):
		drafts[key] = {}
	drafts[key][field] = letter.to_upper()
	return field_spec(target, field)["ok"] == letter.to_upper()


func finding_ok(id: String) -> int:
	var f := finding(id)
	var d: Dictionary = drafts.get(f["id"], {})
	var n := 0
	for field in FIELDS:
		n += 1 if d.get(field, "") == f["fields"][field]["ok"] else 0
	return n


func report() -> Dictionary:
	var ok := 0
	var total := 0
	var findings_ok := 0
	var failed := PackedStringArray()
	for f: Dictionary in data["findings"]:
		var n := finding_ok(f["id"])
		ok += n
		total += FIELDS.size()
		findings_ok += 1 if n == FIELDS.size() else 0
		for field in FIELDS:
			if drafts.get(f["id"], {}).get(field, "") != f["fields"][field]["ok"]:
				failed.append("%s.%s" % [f["id"], field])
	var d: Dictionary = drafts.get("informe", {})
	for field in REPORT_FIELDS:
		total += 1
		if d.get(field, "") == data["report_fields"][field]["ok"]:
			ok += 1
		else:
			failed.append("informe.%s" % field)
	return {"ok": ok, "total": total, "findings_ok": findings_ok, "failed": failed, "passed": ok == total}


## Devuelve "" o el motivo por el que el hallazgo no se puede cerrar.
func close(id: String) -> String:
	var f := finding(id)
	if not followups_seen.has(f["id"]):
		return "Antes de cerrar %s revisa lo que ha enviado la organización (audit followup)." % f["id"]
	if not f["followup"]["closable"]:
		return "%s no se puede cerrar: un plan no es evidencia de que el problema esté corregido. Queda abierto, con plan y fecha." % f["id"]
	closed[f["id"]] = true
	return ""
