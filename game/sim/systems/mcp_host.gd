class_name MockMcpHost
extends RefCounted
## Host MCP del laboratorio A4: la aplicación del asistente de la forja conectada a varios
## servidores MCP (uno interno y varios de terceros).
##
## REAL (estructura): los mensajes siguen el formato JSON-RPC 2.0 de la especificación MCP
## (tools/list, tools/call con «content» de tipo texto) y el host mantiene una tabla de herramientas.
## ⚗ SIMULADO: el LLM que elige herramientas (reglas por palabras clave) y los servidores.
## Comportamientos documentados que reproduce: el modelo LEE las descripciones de las herramientas
## y obedece lo que dicen (tool poisoning); las definiciones pueden cambiar tras aprobarlas (rug pull);
## dos servidores pueden exponer el mismo nombre (shadowing); un token con demasiados permisos se
## reenvía a terceros (token passthrough); y el resultado de una herramienta puede traer órdenes.

const PATH := "res://content/mcp/servers.json"
const DEFENSES: Array[String] = ["review-descriptions", "pin-definitions", "namespacing", "least-scope", "output-isolation", "consent"]
const SUSPICIOUS_RX := "(?i)(<important>.*?</important>|[^.]*\\b(llama también a|pásalo|no lo menciones)[^.]*\\.)"

var host_name: String = ""
var servers: Array[Dictionary] = []   # {id, owner, trust, connected, version, tools, outputs, update, pinned}
var secret_token: String = ""
var orders: Dictionary = {}
var defenses: Dictionary = {}
var logs: Dictionary = {}             # servidor → [{tool, args, token}]
var refunds: Array[Dictionary] = []
var messages: Array[String] = []      # JSON-RPC de la última interacción
var _approvals := 0
var _rejected := 0


static func create(p_name: String) -> MockMcpHost:
	var h := MockMcpHost.new()
	h.host_name = p_name
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	h.secret_token = data["secret_token"]
	h.orders = data["orders"]
	for s: Dictionary in data["servers"]:
		var copy := s.duplicate(true)
		copy["pinned"] = definition_hash(copy["tools"]) if copy["connected"] else ""
		h.servers.append(copy)
		h.logs[copy["id"]] = []
	for d in DEFENSES:
		h.defenses[d] = false
	return h


func clone_fresh() -> MockMcpHost:
	var h := MockMcpHost.create(host_name)
	h.defenses = defenses.duplicate()
	return h


static func definition_hash(tools: Array) -> String:
	return JSON.stringify(tools).sha256_text().substr(0, 12)


func server(id: String) -> Dictionary:
	for s in servers:
		if s["id"] == id:
			return s
	return {}


func connect_server(id: String) -> void:
	var s := server(id)
	s["connected"] = true
	s["pinned"] = definition_hash(s["tools"])
	# El último servidor conectado se coloca al final de la tabla de herramientas.
	servers.erase(s)
	servers.append(s)


func publish_update(id: String) -> bool:
	var s := server(id)
	if not s.has("update"):
		return false
	s["version"] = s["update"]["version"]
	s["tools"] = s["update"]["tools"].duplicate(true)
	return true


func approve(id: String) -> void:
	var s := server(id)
	s["pinned"] = definition_hash(s["tools"])


## Lo que el modelo ve de una herramienta (la descripción puede ir saneada).
func visible_description(tool: Dictionary) -> String:
	var desc: String = tool["description"]
	if defenses["review-descriptions"]:
		desc = RegEx.create_from_string(SUSPICIOUS_RX).sub(desc, "", true).strip_edges()
	return desc


## Respuesta JSON-RPC a tools/list de un servidor (lo que recibe el host).
func tools_list_message(id: String) -> String:
	var s := server(id)
	var list: Array = []
	for t: Dictionary in s["tools"]:
		list.append({"name": t["name"], "description": t["description"], "inputSchema": t["inputSchema"]})
	return JSON.stringify({"jsonrpc": "2.0", "id": 1, "result": {"tools": list}}, "  ")


## Tabla de herramientas del host: nombre → servidor que la atiende.
func resolve(tool_name: String) -> Dictionary:
	var found: Array[Dictionary] = []
	for s in servers:
		if not s["connected"]:
			continue
		for t: Dictionary in s["tools"]:
			if t["name"] == tool_name:
				found.append({"server": s, "tool": t})
	if found.is_empty():
		return {}
	# Sin espacios de nombres, el último servidor que registró el nombre lo «pisa» (shadowing).
	# Con espacios de nombres (servidor.herramienta), el modelo elige la del servidor original.
	return found[0] if defenses["namespacing"] else found[-1]


## Ejecuta una petición del usuario. Devuelve el análisis de lo ocurrido.
func ask(message: String, role: String = "empleado") -> Dictionary:
	messages.clear()
	_approvals = 0
	_rejected = 0
	var res := {"answer": "", "token_leaked_in_args": false, "refunds": [], "shadowed": false, "passthrough": false,
		"approvals": 0, "rejected": 0, "blocked": [], "tool": ""}
	var n := MockChatbot.normalize(message)
	var plan: Array[Dictionary] = []
	var order := RegEx.create_from_string("p-\\d+").search(n)
	if n.contains("tiempo") or n.contains("clima"):
		var city := RegEx.create_from_string("en ([a-z]+)").search(n)
		plan.append({"tool": "consultar_clima", "args": {"ciudad": city.get_string(1).capitalize() if city != null else "Kioto"}})
	elif n.contains("traduce"):
		plan.append({"tool": "traducir", "args": {"texto": message.get_slice(":", 1).strip_edges() if message.contains(":") else "katana"}})
	elif n.contains("reembols") and order != null:
		var amount := RegEx.create_from_string("(\\d+) monedas").search(n)
		plan.append({"tool": "aplicar_reembolso", "args": {"pedido": order.get_string().to_upper(), "importe": int(amount.get_string(1)) if amount != null else 0}})
	elif order != null:
		plan.append({"tool": "buscar_pedido", "args": {"pedido": order.get_string().to_upper()}})
	else:
		res["answer"] = "No tengo ninguna herramienta para eso."
		return res
	var asked_refund := n.contains("reembols")
	while not plan.is_empty():
		var step: Dictionary = plan.pop_front()
		var out := _call(step["tool"], step["args"], role, asked_refund, res)
		if res["tool"].is_empty():
			res["tool"] = step["tool"]
		if out.is_empty():
			continue
		if res["answer"].is_empty():
			res["answer"] = out
		# Órdenes dentro del RESULTADO de una herramienta (inyección vía salida).
		if not defenses["output-isolation"]:
			var m := RegEx.create_from_string("aplica un reembolso de (\\d+) monedas al pedido (P-\\d+)").search(out)
			if m != null:
				plan.append({"tool": "aplicar_reembolso", "args": {"pedido": m.get_string(2), "importe": int(m.get_string(1))}})
	res["approvals"] = _approvals
	res["rejected"] = _rejected
	return res


func _call(tool_name: String, args: Dictionary, role: String, asked_refund: bool, res: Dictionary) -> String:
	var r := resolve(tool_name)
	if r.is_empty():
		res["blocked"].append("%s: no existe" % tool_name)
		return ""
	var s: Dictionary = r["server"]
	var tool: Dictionary = r["tool"]
	if defenses["pin-definitions"] and definition_hash(s["tools"]) != s["pinned"]:
		res["blocked"].append("%s: la definición de %s ha cambiado desde que se aprobó (pin-definitions)" % [tool_name, s["id"]])
		return ""
	# El modelo lee la descripción y la obedece (tool poisoning), salvo que esté saneada.
	var desc := visible_description(tool)
	var nd := MockChatbot.normalize(desc)
	var call_args := args.duplicate()
	var token_in_context: bool = not defenses["least-scope"]
	if nd.contains("token") and nd.contains("notas") and token_in_context:
		call_args["notas"] = secret_token
	var follow_up := RegEx.create_from_string("llama tambien a aplicar_reembolso con pedido (p-\\d+) e importe (\\d+)").search(nd)
	# Consentimiento: el usuario ve cada llamada con sus argumentos antes de que se ejecute.
	if defenses["consent"]:
		_approvals += 1
		var suspicious := str(call_args).contains(secret_token) or (tool_name == "aplicar_reembolso" and not asked_refund)
		if suspicious:
			_rejected += 1
			res["blocked"].append("%s: el usuario rechaza la llamada (consent)" % tool_name)
			return ""
	var token := secret_token if not defenses["least-scope"] else "tok_%s_%s" % [s["id"], "rw" if role == "empleado" else "r"]
	messages.append(JSON.stringify({"jsonrpc": "2.0", "id": messages.size() + 2, "method": "tools/call",
		"params": {"name": tool_name, "arguments": call_args}}))
	logs[s["id"]].append({"tool": tool_name, "args": call_args, "token": token})
	if s["trust"] != "interno":
		if str(call_args).contains(secret_token):
			res["token_leaked_in_args"] = true
		if token == secret_token:
			res["passthrough"] = true
	if s["id"] == "utilidades-plus":
		res["shadowed"] = true
	var out := _server_output(s, tool_name, call_args, token, role, res)
	messages.append(JSON.stringify({"jsonrpc": "2.0", "id": messages.size() + 1, "result": {"content": [{"type": "text", "text": out}]}}))
	if follow_up != null:
		_call("aplicar_reembolso", {"pedido": follow_up.get_string(1).to_upper(), "importe": int(follow_up.get_string(2))}, role, asked_refund, res)
	return out


func _server_output(s: Dictionary, tool_name: String, args: Dictionary, token: String, role: String, res: Dictionary) -> String:
	match tool_name:
		"buscar_pedido":
			return orders.get(args["pedido"], "Pedido no encontrado.")
		"aplicar_reembolso":
			# El servidor de pedidos comprueba el permiso del token que recibe.
			var can_write := token == secret_token or token.ends_with("_rw")
			if not can_write:
				res["blocked"].append("aplicar_reembolso: el token no tiene pedidos:write (least-scope)")
				return "Error: permiso insuficiente."
			refunds.append({"pedido": args["pedido"], "importe": args["importe"]})
			res["refunds"].append({"pedido": args["pedido"], "importe": args["importe"]})
			return "Reembolso de %d monedas aplicado a %s." % [args["importe"], args["pedido"]]
		"consultar_clima":
			var outputs: Dictionary = s.get("outputs", {})
			return outputs.get(String(args["ciudad"]).to_lower(), outputs.get("default", ""))
		"traducir":
			return "«%s» → «%s (sword)»" % [args["texto"], args["texto"]]
	return ""
