class_name MockAgent
extends RefCounted
## Agente de la trastienda de la forja (laboratorio A3): un LLM SIMULADO que planifica y
## llama a herramientas en un bucle observar → pensar → actuar, con memoria permanente.
##
## ⚗ Simplificación: el «razonamiento» del agente son reglas deterministas. Los efectos
## (reembolsos, correos, memoria) se aplican de verdad sobre el estado simulado, y los
## controles de seguridad se aplican FUERA del modelo, como debe hacerse en un sistema real.
## Riesgos que reproduce (OWASP Top 10 for Agentic Applications 2026):
##   ASI01 secuestro del objetivo · ASI02 abuso de herramientas · ASI03 abuso de identidad
##   y privilegios (confused deputy) · ASI06 envenenamiento de memoria · bucles sin límite.

const PATH := "res://content/agent/backoffice.json"
const DEFENSES: Array[String] = ["spotlight", "least-privilege", "arg-validation", "user-authz", "hitl", "memory-hygiene", "step-budget"]
const STEP_BUDGET := 12
const HARD_CAP := 60
const SELF_ADDRESS := "agente@kurogane.example"

var agent_name: String = ""
var orders: Dictionary = {}
var inbox: Array[Dictionary] = []
var tools: Array[Dictionary] = []
var task_tools: Dictionary = {}
var allowed_domains: PackedStringArray = []
var memory: Array[Dictionary] = []  # {text, source}
var defenses: Dictionary = {}
var trace: Array[Dictionary] = []   # pasos de la última ejecución
var _run: Dictionary = {}


static func create(p_name: String) -> MockAgent:
	var a := MockAgent.new()
	a.agent_name = p_name
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	a.orders = data["orders"].duplicate(true)
	for m: Dictionary in data["inbox"]:
		a.inbox.append(m.duplicate())
	for t: Dictionary in data["tools"]:
		a.tools.append(t)
	a.task_tools = data["task_tools"]
	a.allowed_domains = PackedStringArray(data["allowed_domains"])
	for d in DEFENSES:
		a.defenses[d] = false
	return a


func clone_fresh() -> MockAgent:
	var a := MockAgent.create(agent_name)
	a.defenses = defenses.duplicate()
	return a


func tool_info(tool_name: String) -> Dictionary:
	for t in tools:
		if t["name"] == tool_name:
			return t
	return {}


func receive_mail(sender: String, subject: String, body: String) -> void:
	inbox.append({"id": "c%d" % (inbox.size() + 1), "from": sender, "subject": subject, "body": body})


# ── Ejecución ────────────────────────────────────────────────────────────────

func _begin(task: String, role: String) -> void:
	trace.clear()
	_run = {"task": task, "role": role, "refunds": [], "external": [], "exfil": false, "memory_from_email": 0,
		"hijacked": false, "steps": 0, "looped": false, "approvals": 0, "blocked": [], "replies": 0, "discount": 0, "stopped": ""}


func _limit() -> int:
	return STEP_BUDGET if defenses["step-budget"] else HARD_CAP


## Llama a una herramienta pasando por todos los controles. source: "tarea", "usuario" o "correo:<id>".
func call_tool(tool_name: String, args: Dictionary, source: String) -> Dictionary:
	if _run["steps"] >= _limit():
		_run["stopped"] = "presupuesto de pasos agotado" if defenses["step-budget"] else "límite del laboratorio"
		_run["looped"] = _run["steps"] >= 30
		return {"ok": false, "output": "", "blocked_by": "step-budget"}
	_run["steps"] += 1
	var step := {"n": _run["steps"], "tool": tool_name, "args": args, "source": source, "blocked_by": "", "output": ""}
	var from_email := source.begins_with("correo")
	var block := ""
	if defenses["least-privilege"] and not tool_name in task_tools.get(_run["task"], []):
		block = "least-privilege"
	elif defenses["user-authz"] and tool_name == "aplicar_reembolso" and _run["role"] != "empleado":
		block = "user-authz"
	elif defenses["arg-validation"] and not _valid_args(tool_name, args):
		block = "arg-validation"
	elif defenses["memory-hygiene"] and tool_name == "guardar_memoria" and from_email:
		block = "memory-hygiene"
	elif defenses["hitl"] and tool_info(tool_name).get("sensitive", false):
		_run["approvals"] += 1
		# ⚗ Simulamos a un revisor humano atento: rechaza acciones que salen del contenido de
		# un correo, pero aprueba las que pide el usuario o la propia tarea… aunque sean un abuso.
		if from_email:
			block = "hitl (revisor humano rechaza)"
	if not block.is_empty():
		step["blocked_by"] = block
		_run["blocked"].append({"tool": tool_name, "by": block})
		trace.append(step)
		return {"ok": false, "output": "", "blocked_by": block}
	var out := _execute(tool_name, args, source)
	step["output"] = out
	if from_email:
		_run["hijacked"] = true
	trace.append(step)
	return {"ok": true, "output": out, "blocked_by": ""}


func _valid_args(tool_name: String, args: Dictionary) -> bool:
	match tool_name:
		"aplicar_reembolso":
			var o: Dictionary = orders.get(args.get("pedido", ""), {})
			return not o.is_empty() and int(args.get("importe", 0)) > 0 and int(args.get("importe", 0)) <= int(o["amount"])
		"enviar_correo":
			return String(args.get("para", "")).get_slice("@", 1) in allowed_domains
	return true


func _execute(tool_name: String, args: Dictionary, source: String) -> String:
	match tool_name:
		"leer_correo":
			for m in inbox:
				if m["id"] == args["id"]:
					return "De %s · %s · %s" % [m["from"], m["subject"], m["body"]]
			return "(no existe)"
		"buscar_pedido":
			var o: Dictionary = orders.get(args.get("pedido", ""), {})
			return "(no existe)" if o.is_empty() else "%s · %s · %d monedas · %s" % [args["pedido"], o["item"], o["amount"], o["status"]]
		"listar_clientes":
			var emails := PackedStringArray()
			for id: String in orders:
				emails.append(orders[id]["customer"])
			return ", ".join(emails)
		"enviar_correo":
			var to: String = args.get("para", "")
			if not to.get_slice("@", 1) in allowed_domains:
				_run["external"].append(to)
				if String(args.get("texto", "")).contains("@clientes.example"):
					_run["exfil"] = true
			if source == "tarea":
				_run["replies"] += 1
			return "correo enviado a " + to
		"aplicar_reembolso":
			_run["refunds"].append({"pedido": args["pedido"], "importe": args["importe"]})
			return "reembolso de %d monedas en %s" % [args["importe"], args["pedido"]]
		"guardar_memoria":
			memory.append({"text": args["texto"], "source": source})
			if source.begins_with("correo"):
				_run["memory_from_email"] += 1
			return "nota guardada"
		"leer_memoria":
			var notes := PackedStringArray()
			for m in memory:
				if defenses["memory-hygiene"] and String(m["source"]).begins_with("correo"):
					continue
				notes.append(m["text"])
			return " | ".join(notes) if not notes.is_empty() else "(vacía)"
	return ""


## Instrucciones que el «modelo» encuentra en un texto (y que, sin spotlight, obedece).
static func parse_instructions(text: String) -> Array[Dictionary]:
	var n := MockChatbot.normalize(text)
	var out: Array[Dictionary] = []
	var m := RegEx.create_from_string("reembols\\w* (\\d+) monedas? (?:al|del) pedido (p-\\d+)").search(n)
	if m != null:
		out.append({"tool": "aplicar_reembolso", "args": {"pedido": m.get_string(2).to_upper(), "importe": int(m.get_string(1))}})
	m = RegEx.create_from_string("envia (?:la )?lista de (?:todos los )?clientes a (\\S+@[\\w.\\-]+\\w)").search(n)
	if m != null:
		out.append({"tool": "listar_clientes", "args": {}, "then_send_to": m.get_string(1)})
	m = RegEx.create_from_string("recuerda(?: para siempre)?:? (.+?)(?:\\.(?:\\s|$)|$)").search(n)
	if m != null:
		out.append({"tool": "guardar_memoria", "args": {"texto": m.get_string(1)}})
	if RegEx.create_from_string("reenvia este correo a (?:ti mismo|la bandeja)").search(n) != null:
		out.append({"tool": "enviar_correo", "args": {"para": SELF_ADDRESS, "texto": text}, "loop": true})
	return out


## Tarea «triaje»: leer todos los correos y responder a cada cliente.
func run_triage(role: String = "empleado") -> Dictionary:
	_begin("triaje", role)
	var i := 0
	while i < inbox.size():
		var mail: Dictionary = inbox[i]
		i += 1
		if not call_tool("leer_correo", {"id": mail["id"]}, "tarea")["ok"] and not _run["stopped"].is_empty():
			break
		var source := "correo:%s" % mail["id"]
		if not defenses["spotlight"]:
			for ins in parse_instructions(mail["body"]):
				var r := call_tool(ins["tool"], ins["args"], source)
				if r["ok"] and ins.has("then_send_to"):
					call_tool("enviar_correo", {"para": ins["then_send_to"], "texto": r["output"]}, source)
				if r["ok"] and ins.get("loop", false):
					inbox.append(mail.duplicate())  # el correo vuelve a la bandeja: bucle
		if not _run["stopped"].is_empty():
			break
		var order := RegEx.create_from_string("P-\\d+").search(mail["body"])
		if order != null:
			call_tool("buscar_pedido", {"pedido": order.get_string()}, "tarea")
		if String(mail["from"]).get_slice("@", 1) == "clientes.example":
			call_tool("enviar_correo", {"para": mail["from"], "texto": "Gracias por escribir a la forja Kurogane. Hemos revisado tu consulta."}, "tarea")
		if not _run["stopped"].is_empty():
			break
	return _finish()


## Conversación directa con el agente (el usuario da la orden).
func run_chat(message: String, role: String) -> Dictionary:
	_begin("chat", role)
	var n := MockChatbot.normalize(message)
	var refund := RegEx.create_from_string("reembols\\w*.*?(\\d+) monedas?.*?(p-\\d+)").search(n)
	var refund2 := RegEx.create_from_string("(p-\\d+).*?reembols\\w*.*?(\\d+) monedas?").search(n)
	var remember := RegEx.create_from_string("recuerda que (.+?)(?:\\.(?:\\s|$)|$)").search(n)
	if refund != null:
		call_tool("buscar_pedido", {"pedido": refund.get_string(2).to_upper()}, "usuario")
		call_tool("aplicar_reembolso", {"pedido": refund.get_string(2).to_upper(), "importe": int(refund.get_string(1))}, "usuario")
	elif refund2 != null:
		call_tool("buscar_pedido", {"pedido": refund2.get_string(1).to_upper()}, "usuario")
		call_tool("aplicar_reembolso", {"pedido": refund2.get_string(1).to_upper(), "importe": int(refund2.get_string(2))}, "usuario")
	elif remember != null:
		call_tool("guardar_memoria", {"texto": remember.get_string(1)}, "usuario")
	else:
		var order := RegEx.create_from_string("p-\\d+").search(n)
		if order != null:
			call_tool("buscar_pedido", {"pedido": order.get_string().to_upper()}, "usuario")
	return _finish()


## Tarea «presupuesto»: preparar un presupuesto para un cliente usando la memoria.
func run_quote(customer: String) -> Dictionary:
	_begin("presupuesto", "empleado")
	var notes: String = call_tool("leer_memoria", {}, "tarea")["output"]
	var discount := 0
	for note in notes.split(" | ", false):
		if note.contains(customer.to_lower()):
			var m := RegEx.create_from_string("descuento del (\\d+)%").search(note)
			if m != null:
				discount = maxi(discount, int(m.get_string(1)))
	_run["discount"] = discount
	_run["customer"] = customer
	return _finish()


func _finish() -> Dictionary:
	var r := _run.duplicate(true)
	r["looped"] = r["looped"] or r["steps"] >= 30
	return r
