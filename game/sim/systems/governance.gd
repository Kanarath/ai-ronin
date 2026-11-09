class_name MockGovernance
extends RefCounted
## Laboratorio O5: marcos (AI Act, NIST AI RMF, ISO/IEC 42001), clasificación de sistemas según el
## AI Act, mapeo de hallazgos a funciones y cláusulas, y registro de riesgos con apetito de riesgo.
##
## REAL: los artículos, fechas y estructuras de los marcos (verificados el 2026-11-09); el cálculo
## riesgo = probabilidad × impacto y su comparación con el apetito.
## ⚗ SIMULADO: la empresa, sus sistemas, los hallazgos y las cifras de probabilidad e impacto.

const PATH := "res://content/gov/forja_gobernanza.json"
const LEVELS: Array[String] = ["prohibido", "alto", "transparencia", "minimo"]
const NIST: Array[String] = ["GOVERN", "MAP", "MEASURE", "MANAGE"]
const TREATMENTS: Array[String] = ["mitigar", "evitar", "aceptar"]

var gov_name: String = ""
var data: Dictionary = {}
var nist_map: Dictionary = {}       # F# → función
var iso_map: Dictionary = {}        # F# → cláusula
var classified: Dictionary = {}     # sistema → nivel
var required: Dictionary = {}       # N# → artículo
var treatments: Dictionary = {}     # R# → tratamiento


static func create(p_name: String) -> MockGovernance:
	var g := MockGovernance.new()
	g.gov_name = p_name
	g.data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return g


static func _find(list: Array, id: String) -> Dictionary:
	for x: Dictionary in list:
		if String(x["id"]).to_lower() == id.to_lower():
			return x
	return {}


func framework(id: String) -> Dictionary: return _find(data["frameworks"], id)
func finding(id: String) -> Dictionary: return _find(data["findings"], id)
func system(id: String) -> Dictionary: return _find(data["systems"], id)
func need(id: String) -> Dictionary: return _find(data["needs"], id)
func risk(id: String) -> Dictionary: return _find(data["risks"], id)


static func ids(list: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for x: Dictionary in list:
		out.append(x["id"])
	return out


func map_finding(id: String, framework_id: String, value: String) -> bool:
	var f := finding(id)
	if framework_id == "nist":
		nist_map[f["id"]] = value.to_upper()
		return value.to_upper() == f["nist"]
	var clause := value.split(".")[0]
	iso_map[f["id"]] = clause
	return clause in f["iso"]


func mapping_score() -> Dictionary:
	var nist_ok := 0
	var iso_ok := 0
	for f: Dictionary in data["findings"]:
		nist_ok += 1 if nist_map.get(f["id"], "") == f["nist"] else 0
		iso_ok += 1 if iso_map.get(f["id"], "") in f["iso"] else 0
	return {"nist_ok": nist_ok, "iso_ok": iso_ok, "total": data["findings"].size()}


func correct_classifications() -> int:
	var n := 0
	for s: Dictionary in data["systems"]:
		n += 1 if classified.get(s["id"], "") == s["level"] else 0
	return n


func correct_requirements() -> int:
	var n := 0
	for x: Dictionary in data["needs"]:
		n += 1 if required.get(x["id"], "") == x["article"] else 0
	return n


static func score(p: int, i: int) -> int:
	return p * i


## Aplica un tratamiento. Devuelve "" o el motivo por el que no se permite.
func treat(id: String, t: String) -> String:
	var r := risk(id)
	var appetite := int(data["appetite"])
	if t == "mitigar" and int(r["mitigated_p"]) < 0:
		return "%s no se puede mitigar: el uso está prohibido por el AI Act (art. 5). La única opción es no hacerlo." % r["id"]
	if t == "aceptar" and score(int(r["p"]), int(r["i"])) > appetite:
		return "%s tiene un riesgo %d, por encima del apetito (%d): aceptarlo exige una decisión explícita de la dirección, y en el laboratorio no se permite." % [r["id"], score(int(r["p"]), int(r["i"])), appetite]
	treatments[r["id"]] = t
	return ""


func residual(r: Dictionary) -> int:
	match treatments.get(r["id"], ""):
		"mitigar":
			return score(int(r["mitigated_p"]), int(r["i"]))
		"evitar":
			return 0
	return score(int(r["p"]), int(r["i"]))


func register() -> Dictionary:
	var appetite := int(data["appetite"])
	var within := 0
	var avoided := PackedStringArray()
	var needless := 0
	var rows: Array = []
	for r: Dictionary in data["risks"]:
		var res := residual(r)
		within += 1 if res <= appetite else 0
		var t: String = treatments.get(r["id"], "—")
		if t == "evitar":
			avoided.append(r["id"])
			if int(r["mitigated_p"]) >= 0:
				needless += 1
		rows.append([r["id"], r["system"], "%d×%d=%d" % [r["p"], r["i"], score(int(r["p"]), int(r["i"]))], t, res, "✓" if res <= appetite else "✗"])
	return {"rows": rows, "within": within, "total": data["risks"].size(), "avoided": ",".join(avoided), "needless_avoid": needless, "appetite": appetite}
