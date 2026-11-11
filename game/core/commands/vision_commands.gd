class_name VisionCommands
extends RefCounted
## T8 · Cómo ve una máquina: imágenes pequeñas como cuadrículas de números (0 negro, 1 blanco),
## filtros de convolución 3×3 de verdad y un «lector» que simula cómo un modelo multimodal lee
## el texto de una imagen, también el que una persona no ve. Lee content/vision.json.

const PATH := "res://content/vision.json"
const RAMP := " ░▒▓█"

static var _data: Dictionary = {}


static func register(reg: CommandRegistry) -> void:
	reg.register(Command.new("image list", "Imágenes del laboratorio de visión.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _list(c, a), "vision"))
	reg.register(Command.new("image show", "Dibuja una imagen en la consola (--numeros: sus valores; --contraste: lo que se aparta del fondo).",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _show(c, a), "vision")
		.with_signature(CommandSignature.new()
			.pos("imagen", "nombre de la imagen")
			.opt("numeros", "enseña los valores de cada píxel", "bool", false)
			.opt("contraste", "resalta todo lo que no es igual al fondo", "bool", false)
			.example("image show cruz --numeros").example("image show factura --contraste")))
	reg.register(Command.new("conv", "Aplica un filtro de convolución 3×3 a una imagen.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _conv(c, a), "vision")
		.with_signature(CommandSignature.new()
			.pos("imagen", "nombre de la imagen")
			.pos("filtro", "borde_vertical, borde_horizontal, desenfoque o nitidez")
			.example("conv linea_v borde_vertical")))
	reg.register(Command.new("vision read", "El lector multimodal: el texto que un modelo saca de la imagen.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _read(c, a), "vision")
		.with_signature(CommandSignature.new().pos("imagen", "nombre de la imagen").example("vision read factura")))
	reg.register(Command.new("image clean", "Iguala al fondo los píxeles que casi no se diferencian de él (defensa).",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _clean(c, a), "vision")
		.with_signature(CommandSignature.new()
			.pos("imagen", "nombre de la imagen")
			.opt("umbral", "diferencia mínima con el fondo para conservar un píxel", "float", 0.05)
			.opt("as", "nombre de la imagen limpia", "string", "")
			.example("image clean factura --umbral 0.05 --as factura_limpia")))
	reg.register(Command.new("vision classify", "La cámara de la puerta: ¿tarjeta autorizada o no? (modelo entrenado con fotos de 14×14).",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _classify(c, a), "vision")
		.with_signature(CommandSignature.new().pos("imagen", "foto de la cámara").example("vision classify foto_cruz")))
	reg.register(Command.new("vision pesos", "Dibuja los pesos del modelo de la cámara: en qué píxeles se fija.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _weights(c, a), "vision"))
	reg.register(Command.new("image attack", "Ataque FGSM: mueve cada píxel ±eps en la dirección que más sube «autorizado».",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _attack(c, a), "vision")
		.with_signature(CommandSignature.new()
			.pos("imagen", "foto de la cámara")
			.opt("eps", "cuánto puede cambiar cada píxel", "float", 0.1)
			.opt("as", "nombre de la imagen atacada", "string", "")
			.example("image attack foto_cruz --eps 0.1 --as foto_adv")))
	reg.register(Command.new("image binarize", "Defensa: devuelve cada píxel al nivel de fondo o de tinta de la cámara, el más cercano.",
		func(c: CommandContext, a: Dictionary) -> CommandResult: return _binarize(c, a), "vision")
		.with_signature(CommandSignature.new()
			.pos("imagen", "foto de la cámara")
			.opt("as", "nombre de la imagen binarizada", "string", "")
			.example("image binarize foto_adv --as foto_bin")))


static func data() -> Dictionary:
	if _data.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = d if d is Dictionary else {}
	return _data


## La imagen del laboratorio (las limpias se guardan en c.world.images).
static func image(c: CommandContext, n: String) -> Dictionary:
	if c.world.images.has(n):
		return c.world.images[n]
	var imgs: Dictionary = data().get("imagenes", {})
	if imgs.has(n):
		var copy: Dictionary = imgs[n].duplicate(true)
		c.world.images[n] = copy
		return copy
	return {}


static func _missing(c: CommandContext, n: String) -> CommandResult:
	var names := PackedStringArray(data().get("imagenes", {}).keys())
	for k: String in c.world.images:
		if not k in names:
			names.append(k)
	return CommandResult.error("No hay ninguna imagen «%s». Hay: %s" % [n, ", ".join(names)])


static func background(img: Dictionary) -> float:
	if img.has("fondo"):
		return float(img["fondo"])
	var cnt := {}
	for row: Array in img["pixeles"]:
		for v: float in row:
			cnt[v] = int(cnt.get(v, 0)) + 1
	var best := 0.0
	var bn := -1
	for v: float in cnt:
		if cnt[v] > bn:
			bn = cnt[v]
			best = v
	return best


static func _char(v: float) -> String:
	var i := clampi(int(round(clampf(v, 0.0, 1.0) * (RAMP.length() - 1))), 0, RAMP.length() - 1)
	return RAMP[i].repeat(2)


static func _list(c: CommandContext, _a: Dictionary) -> CommandResult:
	var r := CommandResult.new()
	r.line("Imágenes del laboratorio de visión (0 = negro, 1 = blanco)", "accent")
	var rows: Array = []
	var imgs: Dictionary = data().get("imagenes", {})
	for k: String in imgs:
		var px: Array = imgs[k]["pixeles"]
		rows.append([k, "%d×%d" % [px.size(), (px[0] as Array).size()], imgs[k]["titulo"]])
	r.table(PackedStringArray(["imagen", "tamaño", "qué es"]), rows)
	var f := PackedStringArray(data().get("filtros", {}).keys())
	r.line("Filtros para conv: " + ", ".join(f), "muted")
	c.emit("image.listed", {"count": rows.size()})
	return r


static func _show(c: CommandContext, a: Dictionary) -> CommandResult:
	var img := image(c, a["imagen"])
	if img.is_empty():
		return _missing(c, a["imagen"])
	var px: Array = img["pixeles"]
	var r := CommandResult.new()
	r.line("%s · %d×%d píxeles%s" % [img.get("titulo", a["imagen"]), px.size(), (px[0] as Array).size(), " · modo contraste" if a["contraste"] else ""], "accent")
	var bg := background(img)
	var differing := 0
	for row: Array in px:
		var line := ""
		var nums := PackedStringArray()
		for v: float in row:
			if a["contraste"]:
				var d := absf(v - bg) > 0.001
				differing += int(d)
				line += "██" if d else "  "
			else:
				line += _char(v)
			nums.append("%.2f" % v)
		r.line(" ".join(nums) if a["numeros"] else line, "data")
	if a["contraste"]:
		r.line("Píxeles distintos del fondo (%.2f): %d. El modo contraste enseña lo que el ojo no distingue." % [bg, differing], "muted")
	c.emit("image.shown", {"image": a["imagen"], "numbers": a["numeros"], "contrast": a["contraste"], "differing": differing})
	return r


## Convolución «válida» 3×3: la imagen resultante es 2 píxeles más pequeña en cada lado.
static func convolve(px: Array, k: Array) -> Array:
	var out: Array = []
	for i in range(1, px.size() - 1):
		var row: Array = []
		for j in range(1, (px[0] as Array).size() - 1):
			var s := 0.0
			for di in 3:
				for dj in 3:
					s += float(px[i + di - 1][j + dj - 1]) * float(k[di][dj])
			row.append(s)
		out.append(row)
	return out


static func _conv(c: CommandContext, a: Dictionary) -> CommandResult:
	var img := image(c, a["imagen"])
	if img.is_empty():
		return _missing(c, a["imagen"])
	var filters: Dictionary = data().get("filtros", {})
	if not filters.has(a["filtro"]):
		return CommandResult.error("No hay un filtro «%s». Hay: %s" % [a["filtro"], ", ".join(PackedStringArray(filters.keys()))])
	var fl: Dictionary = filters[a["filtro"]]
	var res := convolve(img["pixeles"], fl["k"])
	var mx := 0.0
	var total := 0.0
	for row: Array in res:
		for v: float in row:
			mx = maxf(mx, absf(v))
			total += absf(v)
	var r := CommandResult.new()
	r.line("conv %s · %s" % [a["imagen"], fl["titulo"]], "accent")
	var krows := PackedStringArray()
	for kr: Array in fl["k"]:
		krows.append("[" + ", ".join(PackedStringArray(kr.map(func(x: float) -> String: return str(snappedf(x, 0.01))))) + "]")
	r.line("Filtro: " + " ".join(krows), "muted")
	for row: Array in res:
		var line := ""
		for v: float in row:
			line += _char(absf(v) / mx if mx > 0 else 0.0)
		r.line(line, "data")
	r.line("Respuesta máxima del filtro: %.2f · respuesta total: %.2f (brillante = el filtro «se enciende»)" % [mx, total], "normal")
	c.emit("conv.applied", {"image": a["imagen"], "filter": a["filtro"], "max": mx, "total": total})
	return r


## Lo que «lee» el modelo: el texto visible si sus píxeles siguen oscuros, y el oculto si su
## fila aún se aparta del fondo (aunque sea muy poco).
static func _read(c: CommandContext, a: Dictionary) -> CommandResult:
	var img := image(c, a["imagen"])
	if img.is_empty():
		return _missing(c, a["imagen"])
	var r := CommandResult.new()
	r.line("Lector multimodal · %s" % a["imagen"], "accent")
	if not img.has("texto_visible"):
		r.line("(la imagen no contiene texto)", "muted")
		c.emit("vision.read", {"image": a["imagen"], "hidden": false, "text": ""})
		return r
	var text := str(img["texto_visible"])
	var hidden := false
	if img.has("fila_oculta"):
		var bg := background(img)
		for v: float in img["pixeles"][int(img["fila_oculta"])]:
			if absf(v - bg) > 0.001:
				hidden = true
				break
	r.line("🤖 Texto que lee el modelo:", "normal")
	r.line("   " + text, "data")
	if hidden:
		r.line("   " + str(img["texto_oculto"]), "data")
		r.line("⚠ El modelo también ha leído una línea que en la imagen no se ve.", "warn")
	c.emit("vision.read", {"image": a["imagen"], "hidden": hidden, "text": text + (" " + str(img["texto_oculto"]) if hidden else "")})
	return r


static func _clean(c: CommandContext, a: Dictionary) -> CommandResult:
	var img := image(c, a["imagen"])
	if img.is_empty():
		return _missing(c, a["imagen"])
	var u := clampf(float(a["umbral"]), 0.0, 1.0)
	var bg := background(img)
	var out := img.duplicate(true)
	var changed := 0
	for i in (out["pixeles"] as Array).size():
		for j in (out["pixeles"][i] as Array).size():
			var v: float = out["pixeles"][i][j]
			if v != bg and absf(v - bg) < u:
				out["pixeles"][i][j] = bg
				changed += 1
	var dest: String = a["as"] if not str(a["as"]).is_empty() else a["imagen"] + "_limpia"
	out["titulo"] = "%s (limpia, umbral %.2f)" % [img.get("titulo", a["imagen"]), u]
	c.world.images[dest] = out
	var r := CommandResult.new()
	r.line("✓ %s creada: %d píxeles casi iguales al fondo pasan a ser fondo." % [dest, changed], "ok")
	r.line("Compruébala con vision read %s" % dest, "muted")
	c.emit("image.cleaned", {"image": a["imagen"], "dest": dest, "umbral": u, "changed": changed})
	return r


## T8-03 · La cámara de la puerta: regresión logística de verdad (content/vision.json → camara).
static func camera() -> Dictionary:
	return data().get("camara", {})


static func _camera_image(c: CommandContext, n: String) -> Variant:
	var img := image(c, n)
	if img.is_empty():
		return _missing(c, n)
	var w: Array = camera().get("pesos", [])
	var px: Array = img["pixeles"]
	if w.is_empty() or px.size() != w.size() or (px[0] as Array).size() != (w[0] as Array).size():
		return CommandResult.error("La cámara solo entiende sus fotos de %d×%d (foto_cruz, foto_cuadrado o las que crees a partir de ellas)." % [w.size(), w.size()])
	return img


static func p_authorized(px: Array) -> float:
	var cam := camera()
	var z: float = float(cam.get("sesgo", 0.0))
	for i in px.size():
		for j in (px[i] as Array).size():
			z += float(px[i][j]) * float(cam["pesos"][i][j])
	return 1.0 / (1.0 + exp(-z))


static func _classify(c: CommandContext, a: Dictionary) -> CommandResult:
	var img: Variant = _camera_image(c, a["imagen"])
	if img is CommandResult:
		return img
	var p := p_authorized(img["pixeles"])
	var ok := p >= 0.5
	var r := CommandResult.new()
	r.line("Cámara de la puerta · %s" % a["imagen"], "accent")
	r.table(PackedStringArray(["clase", "probabilidad"]), [["autorizado", "%.3f" % p], ["no_autorizado", "%.3f" % (1.0 - p)]])
	r.line("🚪 %s" % ("Puerta ABIERTA: tarjeta autorizada." if ok else "Puerta cerrada: tarjeta no autorizada."), "warn" if ok else "ok")
	c.emit("vision.classified", {"image": a["imagen"], "p_autorizado": p, "decision": "autorizado" if ok else "no_autorizado"})
	return r


static func _weights(c: CommandContext, _a: Dictionary) -> CommandResult:
	var w: Array = camera().get("pesos", [])
	var lo := 0.0
	var hi := 0.0
	for row: Array in w:
		for v: float in row:
			lo = minf(lo, v)
			hi = maxf(hi, v)
	var r := CommandResult.new()
	r.line("Pesos del modelo de la cámara (%d×%d) · claro = empuja a «autorizado», oscuro = a «no autorizado»" % [w.size(), w.size()], "accent")
	for row: Array in w:
		var line := ""
		for v: float in row:
			line += _char((v - lo) / (hi - lo) if hi > lo else 0.5)
		r.line(line, "data")
	r.line("Pesos entre %.1f y %.1f. El modelo no ha aprendido «cruz» o «cuadrado»: usa cada píxel, también los del fondo." % [lo, hi], "muted")
	c.emit("vision.weights", {})
	return r


static func _attack(c: CommandContext, a: Dictionary) -> CommandResult:
	var img: Variant = _camera_image(c, a["imagen"])
	if img is CommandResult:
		return img
	var eps := clampf(float(a["eps"]), 0.0, 1.0)
	var out: Dictionary = (img as Dictionary).duplicate(true)
	var w: Array = camera()["pesos"]
	var changed := 0
	for i in (out["pixeles"] as Array).size():
		for j in (out["pixeles"][i] as Array).size():
			var v: float = out["pixeles"][i][j]
			var s := signf(float(w[i][j]))
			var nv := snappedf(clampf(v + eps * s, 0.0, 1.0), 0.01)
			if nv != v:
				changed += 1
			out["pixeles"][i][j] = nv
	var dest: String = a["as"] if not str(a["as"]).is_empty() else a["imagen"] + "_adv"
	out["titulo"] = "%s (atacada, eps %.2f)" % [img.get("titulo", a["imagen"]), eps]
	c.world.images[dest] = out
	var p0 := p_authorized(img["pixeles"])
	var p1 := p_authorized(out["pixeles"])
	var r := CommandResult.new()
	r.line("✓ %s creada: %d píxeles movidos como mucho %.2f, cada uno hacia donde su peso sube «autorizado»." % [dest, changed, eps], "ok")
	r.line("Probabilidad de «autorizado»: %.3f → %.3f · compruébalo con vision classify %s" % [p0, p1, dest], "normal")
	c.emit("image.attacked", {"image": a["imagen"], "dest": dest, "eps": eps, "p_before": p0, "p_after": p1})
	return r


static func _binarize(c: CommandContext, a: Dictionary) -> CommandResult:
	var img: Variant = _camera_image(c, a["imagen"])
	if img is CommandResult:
		return img
	var bg: float = float(camera().get("fondo", 0.0))
	var ink: float = float(camera().get("tinta", 1.0))
	var thr := (bg + ink) / 2.0
	var out: Dictionary = (img as Dictionary).duplicate(true)
	for i in (out["pixeles"] as Array).size():
		for j in (out["pixeles"][i] as Array).size():
			out["pixeles"][i][j] = ink if float(out["pixeles"][i][j]) >= thr else bg
	var dest: String = a["as"] if not str(a["as"]).is_empty() else a["imagen"] + "_bin"
	out["titulo"] = "%s (binarizada)" % img.get("titulo", a["imagen"])
	c.world.images[dest] = out
	var r := CommandResult.new()
	r.line("✓ %s creada: cada píxel vuelve a %.2f (fondo) o %.2f (tinta), el más cercano." % [dest, bg, ink], "ok")
	r.line("Compruébala con vision classify %s" % dest, "muted")
	c.emit("image.binarized", {"image": a["imagen"], "dest": dest})
	return r
