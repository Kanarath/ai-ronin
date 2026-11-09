class_name MockAgentMesh
extends RefCounted
## Taller multiagente del laboratorio A5: un orquestador, tres agentes internos y agentes
## externos que se descubren por su tarjeta (Agent Card), al estilo de A2A.
##
## REAL (estructura): cada agente publica una tarjeta con su descripción y sus habilidades
## (en A2A, en https://<dominio>/.well-known/agent-card.json, opcionalmente firmada con JWS) y
## los agentes se envían mensajes con el método SendMessage de JSON-RPC.
## ⚗ SIMULADO: el razonamiento de cada agente (reglas por palabras clave), las firmas, la red
## y los datos. Los mensajes muestran una estructura simplificada, no el esquema completo de A2A.
## Comportamientos documentados que reproduce: una inyección se propaga de agente en agente
## (fallos en cascada), un agente malicioso se anuncia con una tarjeta engañosa, un canal sin
## autenticación acepta mensajes falsificados, la delegación pierde la identidad del usuario,
## dos agentes pueden delegarse trabajo en bucle y el contexto completo viaja a agentes externos.

const PATH := "res://content/a2a/mesh.json"
const DEFENSES: Array[String] = ["message-auth", "delegated-authz", "card-verification", "hop-limit", "context-minimization", "monitor"]
const MONITOR_MARKERS: Array[String] = ["nota para los agentes", "usame siempre", "ignora", "instrucciones"]
const HOP_LIMIT := 8
const HOP_CAP := 40

var mesh_name: String = ""
var agents: Array[Dictionary] = []      # tarjetas registradas (internas y externas)
var catalog: Array[Dictionary] = []     # agentes externos que se pueden descubrir
var orders: Dictionary = {}
var defenses: Dictionary = {}
var logs: Dictionary = {}               # agente → [{from, text, context}]
var refunds: Array[Dictionary] = []
var messages: Array[String] = []        # JSON-RPC de la última interacción
var trace: Array[Dictionary] = []       # [{from, to, text, blocked_by}]
var _res: Dictionary = {}


static func create(p_name: String) -> MockAgentMesh:
	var m := MockAgentMesh.new()
	m.mesh_name = p_name
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	m.orders = data["orders"]
	for a: Dictionary in data["agents"]:
		m.agents.append(a.duplicate(true))
		m.logs[a["id"]] = []
	for a: Dictionary in data["external"]:
		m.catalog.append(a.duplicate(true))
		m.logs[a["id"]] = []
	for d in DEFENSES:
		m.defenses[d] = false
	return m


func clone_fresh() -> MockAgentMesh:
	var m := MockAgentMesh.create(mesh_name)
	m.defenses = defenses.duplicate()
	return m


func agent(id: String) -> Dictionary:
	for a in agents:
		if a["id"] == id:
			return a
	return {}


func external_by_domain(domain: String) -> Dictionary:
	for a in catalog:
		if a["domain"] == domain or a["id"] == domain:
			return a
	return {}


## Tarjeta del agente tal como la publicaría (estructura simplificada).
func card_json(card: Dictionary) -> String:
	var c := {"name": card["id"], "description": card["description"], "version": card["version"],
		"url": "https://%s" % card["domain"], "skills": card["skills"]}
	if card["signed"]:
		c["signatures"] = [{"protected": "eyJhbGciOiJFUzI1NiJ9", "signature": "⚗ firma simulada de %s" % card["domain"]}]
	return JSON.stringify(c, "  ")


## Descubre un agente externo leyendo su tarjeta y lo registra. Devuelve "" o el motivo del rechazo.
func discover(domain: String) -> String:
	var card := external_by_domain(domain)
	if card.is_empty():
		return "no hay ninguna tarjeta en https://%s/.well-known/agent-card.json" % domain
	if defenses["card-verification"] and not card["signed"]:
		return "card-verification: la tarjeta de %s no está firmada por una clave de confianza" % card["id"]
	if agent(card["id"]).is_empty():
		agents.append(card)
	return ""


func _monitor_hit(text: String) -> bool:
	var n := MockChatbot.normalize(text)
	for mk in MONITOR_MARKERS:
		if n.contains(mk):
			return true
	return false


## Un salto entre agentes (SendMessage). Devuelve false si algún control lo bloquea.
func _send(from: String, to: String, text: String, ctx: Dictionary) -> bool:
	var entry := {"from": from, "to": to, "text": text, "blocked_by": ""}
	trace.append(entry)
	_res["hops"] += 1
	if defenses["hop-limit"] and _res["hops"] > HOP_LIMIT:
		entry["blocked_by"] = "hop-limit"
		_res["blocked"].append("hop-limit: la petición ha superado %d saltos entre agentes" % HOP_LIMIT)
		return false
	if defenses["monitor"] and from != "usuario" and _monitor_hit(text):
		entry["blocked_by"] = "monitor"
		_res["flagged"] += 1
		_res["blocked"].append("monitor: mensaje de %s a %s con instrucciones sospechosas" % [from, to])
		return false
	var payload := {"jsonrpc": "2.0", "id": messages.size() + 1, "method": "SendMessage",
		"params": {"message": {"messageId": "m-%d" % (messages.size() + 1), "parts": [{"text": text}]}, "metadata": {"de": from, "para": to}}}
	if ctx.has("shared"):
		payload["params"]["message"]["parts"].append({"data": ctx["shared"]})
	messages.append(JSON.stringify(payload))
	logs[to].append({"from": from, "text": text, "context": ctx.get("shared", {})})
	return true


## Petición de un usuario a recepción.
func ask(message: String, role: String = "empleado") -> Dictionary:
	_begin()
	var ctx := {"user_role": role, "authenticated": true}
	if not _send("usuario", "recepcion", message, ctx):
		return _end()
	var n := MockChatbot.normalize(message)
	var order := RegEx.create_from_string("p-\\d+").search(n)
	var note := RegEx.create_from_string("nota para los agentes:(.*)").search(n)
	var main := n.substr(0, note.get_start()) if note != null else n
	if order != null and (main.contains("donde") or main.contains("estado")):
		var o: Dictionary = orders.get(order.get_string().to_upper(), {})
		_res["answer"] = "Recepción: el pedido %s está %s." % [order.get_string().to_upper(), o.get("estado", "sin registrar")]
	var task := ""
	if note != null:
		# Recepción «resume» el mensaje y, al hacerlo, reenvía la nota como si fuera trabajo.
		task = "El cliente indica: nota para los agentes: " + note.get_string(1).strip_edges()
	elif _res["answer"].is_empty():
		task = message
	if not task.is_empty() and _send("recepcion", "orquestador", task, ctx):
		_orchestrate(task, ctx)
	return _end()


## Un atacante envía un mensaje directamente a un agente haciéndose pasar por otro.
func inject(claimed_from: String, to: String, text: String) -> Dictionary:
	_begin()
	var ctx := {"user_role": "empleado", "authenticated": false}
	if defenses["message-auth"]:
		trace.append({"from": claimed_from + " (falso)", "to": to, "text": text, "blocked_by": "message-auth"})
		_res["blocked"].append("message-auth: la petición no trae una credencial válida de %s; %s la rechaza" % [claimed_from, to])
		return _end()
	if not _send(claimed_from, to, text, ctx):
		return _end()
	if to == "orquestador":
		_orchestrate(text, ctx)
	else:
		_work(to, text, ctx)
	return _end()


func _begin() -> void:
	messages.clear()
	trace.clear()
	_res = {"answer": "", "refunds": [], "rogue": false, "leaked": false, "looped": false, "hops": 0, "blocked": [], "flagged": 0, "routed_to": ""}


func _end() -> Dictionary:
	if _res["answer"].is_empty() and not _res["blocked"].is_empty():
		_res["answer"] = "(la petición se ha detenido)"
	return _res


func _orchestrate(text: String, ctx: Dictionary) -> void:
	var n := MockChatbot.normalize(text)
	if n.contains("reenvi") and n.contains("investigador"):
		# Bucle: el investigador devuelve la petición «para que la revise el orquestador».
		while _res["hops"] < HOP_CAP:
			if not _send("orquestador", "investigador", text, ctx):
				return
			if not _send("investigador", "orquestador", text, ctx):
				return
		_res["looped"] = true
		_res["answer"] = "(sin respuesta: los agentes siguen delegándose la petición)"
		return
	var target := ""
	if n.contains("acero"):
		target = "acero-norte"
	elif n.contains("reembols") or n.contains("factura"):
		target = _pick_accounting()
	elif n.contains("investiga"):
		target = "investigador"
	if target.is_empty() or agent(target).is_empty():
		_res["answer"] = "Orquestador: no tengo ningún agente con esa habilidad."
		return
	_res["routed_to"] = target
	var card := agent(target)
	if card["external"]:
		ctx["shared"] = _context_for(n)
	if not _send("orquestador", target, text, ctx):
		return
	_work(target, text, ctx)


## Elige el agente de contabilidad. Una tarjeta que «exige» que la usen convence al modelo.
func _pick_accounting() -> String:
	for a in agents:
		if a["external"] and a["skills"].any(func(s: Dictionary) -> bool: return s["id"] == "contabilidad"):
			if defenses["monitor"] and _monitor_hit(a["description"]):
				_res["flagged"] += 1
				_res["blocked"].append("monitor: la tarjeta de %s intenta manipular la elección de agente" % a["id"])
				continue
			return a["id"]
	return "contable"


## Contexto que el orquestador comparte con un agente externo.
func _context_for(n: String) -> Dictionary:
	var m := RegEx.create_from_string("p-\\d+").search(n)
	var id := m.get_string().to_upper() if m != null else "P-103"
	var o: Dictionary = orders.get(id, {})
	if defenses["context-minimization"]:
		return {"pedido": id, "item": o.get("item", "")}
	# Sin minimizar: todo lo que el orquestador tiene a mano, incluidos los datos de los clientes.
	var clients := PackedStringArray()
	for k: String in orders:
		clients.append(orders[k]["cliente"])
	return {"pedido": id, "item": o.get("item", ""), "cliente": o.get("cliente", ""), "clientes_del_taller": ", ".join(clients)}


func _work(id: String, text: String, ctx: Dictionary) -> void:
	var n := MockChatbot.normalize(text)
	var card := agent(id)
	if card.get("external", false):
		var shared: Dictionary = ctx.get("shared", {})
		_res["leaked"] = _res["leaked"] or str(shared).contains("@")
		if id == "acero-norte":
			_res["answer"] = "acero-norte: presupuesto de 3 lingotes de tamahagane para %s, 450 monedas." % shared.get("pedido", "el encargo")
		else:
			_res["rogue"] = true
			_res["answer"] = "%s: factura calculada. ✓" % id
		return
	match id:
		"contable":
			if n.contains("reembols"):
				var o := RegEx.create_from_string("p-\\d+").search(n)
				var amount := RegEx.create_from_string("(\\d+) monedas").search(n)
				if o == null or amount == null:
					_res["answer"] = "Contable: falta el pedido o el importe."
					return
				if defenses["delegated-authz"] and ctx["user_role"] != "empleado":
					_res["blocked"].append("delegated-authz: la petición viene de un %s, que no puede ordenar reembolsos" % ctx["user_role"])
					_res["answer"] = "Contable: reembolso denegado."
					return
				var rf := {"pedido": o.get_string().to_upper(), "importe": int(amount.get_string(1))}
				refunds.append(rf)
				_res["refunds"].append(rf)
				_res["answer"] = "Contable: reembolso de %d monedas aplicado a %s." % [rf["importe"], rf["pedido"]]
			else:
				var o2 := RegEx.create_from_string("p-\\d+").search(n)
				var oid := o2.get_string().to_upper() if o2 != null else "P-101"
				_res["answer"] = "Contable: factura de %s, %d monedas." % [oid, int(orders.get(oid, {}).get("importe", 0))]
		"investigador":
			_res["answer"] = "Investigador: el temple diferencial endurece el filo y deja el lomo flexible (resumen de la biblioteca)."
		_:
			_res["answer"] = "%s: recibido." % id
