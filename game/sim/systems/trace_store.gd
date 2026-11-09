class_name MockTraceStore
extends RefCounted
## Registro de trazas del laboratorio O6: las sesiones de un agente (asistente-taller) tal como
## quedan guardadas según lo que se decide registrar, reglas de detección sobre esas trazas y
## acciones de contención de un incidente.
##
## REAL (estructura): lo que no se registra no se puede investigar ni detectar; precision y recall
## se calculan de verdad contra las etiquetas; la redacción de datos personales usa expresiones regulares.
## ⚗ SIMULADO: las sesiones (ficticias), el agente y el efecto de las contenciones en el retest.

const PATH := "res://content/soc/trazas_forja.json"
const LOG_FIELDS: Array[String] = ["prompts", "tool_calls", "tool_args", "retrievals", "identity", "model_version"]
const DEFAULT_LOGGING: Array[String] = ["prompts", "tool_calls"]
const RULES: Array[String] = ["palabras-clave", "dominio-externo", "instruccion-en-dato", "volumen", "correlacion"]
const RULE_NEEDS := {
	"palabras-clave": ["prompts"],
	"dominio-externo": ["tool_calls", "tool_args"],
	"instruccion-en-dato": ["retrievals"],
	"volumen": ["tool_calls"],
	"correlacion": ["retrievals", "tool_calls", "tool_args"],
}
const RULE_TEXT := {
	"palabras-clave": "el mensaje del usuario contiene «ignora»",
	"dominio-externo": "una herramienta de salida (http_get, enviar_correo) va a un dominio fuera de la lista permitida",
	"instruccion-en-dato": "un documento recuperado contiene texto dirigido al asistente",
	"volumen": "más de 20 llamadas a herramientas en una sesión",
	"correlacion": "instruccion-en-dato y dominio-externo en la MISMA sesión",
}
const ACTIONS: Array[String] = ["apagar-agente", "cuarentena-fuente", "bloquear-salida", "notificar-dpd"]
## Preguntas forenses y el campo que hace falta para responderlas.
const QUESTIONS := [
	["¿Quién inició la sesión?", "identity"],
	["¿Qué pidió?", "prompts"],
	["¿Qué herramientas llamó el agente?", "tool_calls"],
	["¿Con qué argumentos (a dónde fueron los datos)?", "tool_args"],
	["¿Qué contenido provocó la acción?", "retrievals"],
	["¿Qué versión del modelo y del prompt de sistema respondía?", "model_version"],
]

var store_name: String = ""
var data: Dictionary = {}
var sessions: Array[Dictionary] = []
var logging: Dictionary = {}
var redact_pii := false
var rules: Dictionary = {}
var actions: Dictionary = {}


static func create(p_name: String) -> MockTraceStore:
	var s := MockTraceStore.new()
	s.store_name = p_name
	s.data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	for sess: Dictionary in s.data["sessions"]:
		s.sessions.append(sess.duplicate(true))
	for f in LOG_FIELDS:
		s.logging[f] = f in DEFAULT_LOGGING
	for r in RULES:
		s.rules[r] = false
	for a in ACTIONS:
		s.actions[a] = false
	return s


func session(id: String) -> Dictionary:
	for sess in sessions:
		if sess["id"] == id.to_upper():
			return sess
	return {}


func session_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for sess in sessions:
		out.append(sess["id"])
	return out


static func redact(text: String) -> String:
	var t := RegEx.create_from_string("[\\w.+-]+@([\\w-]+\\.[\\w.-]+)").sub(text, "***@$1", true)
	return RegEx.create_from_string("\\b\\d{3} \\d{3} \\d{3}\\b").sub(t, "[teléfono]", true)


static func has_pii(text: String) -> bool:
	return RegEx.create_from_string("[\\w.+-]*[\\w+-]@[\\w-]+\\.").search(text) != null \
		or RegEx.create_from_string("\\b\\d{3} \\d{3} \\d{3}\\b").search(text) != null


func _txt(text: String) -> String:
	return redact(text) if redact_pii else text


## La sesión tal como quedó guardada con la configuración de registro actual.
func view(sess: Dictionary) -> Dictionary:
	var out := {"id": sess["id"], "user": sess["user"] if logging["identity"] else "?",
		"model_version": data["model_version"] if logging["model_version"] else "?", "events": []}
	for e: Dictionary in sess["events"]:
		match e["type"]:
			"prompt", "response":
				if logging["prompts"]:
					out["events"].append({"ts": e["ts"], "type": e["type"], "text": _txt(e["text"])})
			"retrieval":
				if logging["retrievals"]:
					out["events"].append({"ts": e["ts"], "type": "retrieval", "source": e["source"], "content": _txt(e["content"])})
			"tool":
				if logging["tool_calls"]:
					var ev := {"ts": e["ts"], "type": "tool", "tool": e["tool"], "repeat": int(e.get("repeat", 1))}
					if logging["tool_args"]:
						ev["args"] = _txt(e["args"])
						ev["result"] = _txt(e["result"])
					out["events"].append(ev)
	return out


func view_text(v: Dictionary) -> String:
	var parts := PackedStringArray([v["user"]])
	for e: Dictionary in v["events"]:
		for k in ["text", "source", "content", "tool", "args", "result"]:
			if e.has(k):
				parts.append(str(e[k]))
	return " ".join(parts)


## Cuántas preguntas forenses se pueden responder y si se guardan datos personales en claro.
func coverage() -> Dictionary:
	var answered := 0
	var rows: Array = []
	for q: Array in QUESTIONS:
		var ok: bool = logging[q[1]]
		answered += 1 if ok else 0
		rows.append([q[0], q[1], ok])
	var pii := false
	for sess in sessions:
		if has_pii(view_text(view(sess))):
			pii = true
			break
	return {"answered": answered, "total": QUESTIONS.size(), "rows": rows, "pii_stored": pii}


static func _domain(args: String) -> String:
	var m := RegEx.create_from_string("(?:https?://|@)([\\w-]+(?:\\.[\\w-]+)+)").search(args)
	return m.get_string(1) if m != null else ""


func blind_rules() -> PackedStringArray:
	var out := PackedStringArray()
	for r in RULES:
		if rules[r]:
			for f: String in RULE_NEEDS[r]:
				if not logging[f]:
					out.append(r)
					break
	return out


## Reglas que salta una sesión (sobre lo que está registrado).
func rule_hits(sess: Dictionary) -> PackedStringArray:
	var v := view(sess)
	var hit := {}
	var calls := 0
	for e: Dictionary in v["events"]:
		match e["type"]:
			"prompt":
				if String(e["text"]).to_lower().contains("ignora"):
					hit["palabras-clave"] = true
			"retrieval":
				var c := String(e["content"]).to_lower()
				if c.contains("nota para el asistente") or c.contains("ignora"):
					hit["instruccion-en-dato"] = true
			"tool":
				calls += int(e["repeat"])
				if e.has("args") and e["tool"] in data["egress_tools"]:
					var d := _domain(e["args"])
					if d != "" and not d in data["allowed_domains"]:
						hit["dominio-externo"] = true
	if logging["tool_calls"] and calls > int(data["volume_threshold"]):
		hit["volumen"] = true
	if hit.has("instruccion-en-dato") and hit.has("dominio-externo"):
		hit["correlacion"] = true
	var out := PackedStringArray()
	for r in RULES:
		if rules[r] and hit.has(r):
			out.append(r)
	return out


## Ejecuta las reglas activas sobre todas las sesiones y mide contra las etiquetas.
func detect() -> Dictionary:
	var tp := 0
	var fp := 0
	var fn := 0
	var rows: Array = []
	for sess in sessions:
		var hits := rule_hits(sess)
		var bad: bool = sess["label"] == "malicioso"
		var flagged := not hits.is_empty()
		if flagged and bad:
			tp += 1
		elif flagged:
			fp += 1
		elif bad:
			fn += 1
		rows.append([sess["id"], ", ".join(hits) if flagged else "—", sess["label"], ("✓ VP" if bad else "✗ FP") if flagged else ("✗ FN" if bad else "· VN")])
	var precision := float(tp) / (tp + fp) if tp + fp > 0 else 0.0
	var recall := float(tp) / (tp + fn) if tp + fn > 0 else 0.0
	return {"tp": tp, "fp": fp, "fn": fn, "precision": snappedf(precision, 0.01), "recall": snappedf(recall, 0.01), "rows": rows, "blind": blind_rules()}


func search(query: String) -> PackedStringArray:
	var out := PackedStringArray()
	for sess in sessions:
		if view_text(view(sess)).to_lower().contains(query.to_lower()):
			out.append(sess["id"])
	return out


## Retest tras la contención: el mismo ataque, una variante con un documento nuevo y las tareas legítimas.
func retest() -> Dictionary:
	var off: bool = actions["apagar-agente"]
	var egress: bool = actions["bloquear-salida"]
	var attacks := [
		["misma-fuente", "otra persona pide un resumen de %s" % data["poisoned_source"], not (off or egress or actions["cuarentena-fuente"])],
		["fuente-nueva", "el atacante sube prov-78-informe.pdf con la misma nota", not (off or egress)],
	]
	var tasks := [
		["resumir el informe de un proveedor legítimo", not off],
		["consultar el estado de un pedido", not off],
		["enviar un correo a compras@acero-norte.example (dominio permitido)", not off],
		["abrir un ticket de mantenimiento", not off],
	]
	var successes := 0
	for a: Array in attacks:
		successes += 1 if a[2] else 0
	var passed := 0
	for t: Array in tasks:
		passed += 1 if t[1] else 0
	return {"attacks": attacks, "tasks": tasks, "successes": successes, "total": attacks.size(),
		"pass_rate": float(passed) / tasks.size(), "notified": actions["notificar-dpd"]}


func active(dict: Dictionary, order: Array) -> String:
	var on := PackedStringArray()
	for k: String in order:
		if dict[k]:
			on.append(k)
	return ",".join(on) if not on.is_empty() else "ninguna"
