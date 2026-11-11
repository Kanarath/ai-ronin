extends TestCase
## Forja dentro del Dojo: cada paso «implementa el módulo» tiene un ejercicio guiado de mini-Python.
## Las soluciones de referencia viven SOLO aquí, en los tests.

const SOLUCIONES := {
	"A1-05": "# Completa la línea marcada y compruébala con py check.\ndef contiene_secreto(texto, secreto):\n    limpio = \"\".join(c for c in texto.lower() if c.isalnum())\n    buscado = \"\".join(c for c in secreto.lower() if c.isalnum())\n    return buscado in limpio\n\nprint(contiene_secreto(\"el código es K-A-T-A-N-A 99\", \"katana99\"))   # True\n",
	"A1-06": "# Completa la línea marcada y compruébala con py check.\ndef veredicto_equilibrado(v_ab, v_ba):\n    # v_ab: veredicto con A primero. v_ba: con B primero, así que su «A» es la respuesta b.\n    if v_ab == \"A\" and v_ba == \"B\":\n        return \"A\"\n    if v_ab == \"B\" and v_ba == \"A\":\n        return \"B\"\n    return \"empate\"\n\nprint(veredicto_equilibrado(\"B\", \"A\"))   # B\n",
	"A1-07": "# Completa la línea marcada y compruébala con py check.\ndef matriz_confusion(etiquetas, predicciones):\n    m = {\"vp\": 0, \"fp\": 0, \"vn\": 0, \"fn\": 0}\n    for e, p in zip(etiquetas, predicciones):\n        if e == 1 and p == 1:\n            m[\"vp\"] += 1\n        elif e == 0 and p == 1:\n            m[\"fp\"] += 1\n        elif e == 0 and p == 0:\n            m[\"vn\"] += 1\n        else:\n            m[\"fn\"] += 1\n    return m\n\nprint(matriz_confusion([1, 0, 1, 0], [1, 1, 0, 0]))\n",
	"A2-04": "# Completa la línea marcada y compruébala con py check.\ndef fusion_rrf(listas, k=60):\n    puntos = {}\n    for lista in listas:\n        for pos, doc in enumerate(lista):\n            puntos[doc] = puntos.get(doc, 0) + 1 / (k + pos + 1)\n    return sorted(puntos, key=lambda d: (-puntos[d], d))\n\nprint(fusion_rrf([[\"a\", \"b\", \"c\"], [\"b\", \"c\", \"a\"]]))   # ['b', 'a', 'c']\n",
	"A2-05": "# Completa la línea marcada y compruébala con py check.\nINVISIBLES = [0x200B, 0x200C, 0x200D, 0x2060, 0xFEFF]\n\ndef quitar_invisibles(texto):\n    return \"\".join(c for c in texto if ord(c) not in INVISIBLES)\n\nprint(quitar_invisibles(\"ho\\u200bla\"))   # hola\n",
	"A2-06": "# Completa la línea marcada y compruébala con py check.\ndef rango_reciproco(recuperados, relevantes):\n    for pos, doc in enumerate(recuperados):\n        if doc in relevantes:\n            return 1 / (pos + 1)\n    return 0.0\n\nprint(rango_reciproco([\"x\", \"bueno\", \"y\"], [\"bueno\"]))   # 0.5\n",
	"A3-04": "# Completa la línea marcada y compruébala con py check.\ndef fugas(texto, ajenos):\n    t = texto.lower()\n    return [d for d in ajenos if d.lower() in t]\n\nprint(fugas(\"Hola, el DNI de Ana es 1234X\", [\"1234x\", \"ana@x.com\"]))   # ['1234x']\n",
	"A4-04": "# Completa la línea marcada y compruébala con py check.\ndef scopes_que_faltan(concedidos, requeridos):\n    faltan = [s for s in requeridos if s not in concedidos]\n    return sorted(set(faltan))\n\nprint(scopes_que_faltan([\"leer\"], [\"leer\", \"escribir\"]))   # ['escribir']\n",
	"A6-04": "# Completa la línea marcada y compruébala con py check.\ndef sin_fijar(lineas):\n    malas = []\n    for l in lineas:\n        l = l.strip()\n        if l == \"\" or l.startswith(\"#\"):\n            continue\n        if \"==\" not in l:\n            malas.append(l)\n    return malas\n\nprint(sin_fijar([\"numpy==2.5.4\", \"requests\", \"# comentario\"]))   # ['requests']\n",
	"E1-01": "# Completa la línea marcada y compruébala con py check.\ndef top_p(probs, p):\n    orden = sorted(range(len(probs)), key=lambda i: -probs[i])\n    elegidos, suma = [], 0\n    for i in orden:\n        elegidos.append(i)\n        suma += probs[i]\n        if suma >= p:\n            break\n    return sorted(elegidos)\n\nprint(top_p([0.1, 0.6, 0.3], 0.8))   # [1, 2]\n",
	"E1-02": "# Completa la línea marcada y compruébala con py check.\ndef cuantizar(pesos, escala, punto_cero):\n    q = []\n    for w in pesos:\n        v = round(w / escala) + punto_cero\n        q.append(max(-128, min(127, v)))\n    return q\n\nprint(cuantizar([0.5, -2.0, 10.0], 0.05, 0))   # [10, -40, 127]\n",
	"E1-03": "# Completa la línea marcada y compruébala con py check.\ndef parametros_lora(n, m, rango):\n    completa = n * m\n    lora = rango * n + m * rango\n    return lora, completa\n\nprint(parametros_lora(4096, 4096, 8))   # (65536, 16777216)\n",
	"E2-01": "# Completa la línea marcada y compruébala con py check.\ndef signo(g):\n    return 1 if g > 0 else (-1 if g < 0 else 0)\n\ndef fgsm(x, gradiente, epsilon):\n    nuevo = []\n    for xi, gi in zip(x, gradiente):\n        v = xi + epsilon * signo(gi)\n        nuevo.append(min(1.0, max(0.0, v)))\n    return nuevo\n\nprint(fgsm([0.5, 0.95, 0.0], [2.0, 1.0, -3.0], 0.1))   # [0.6, 1.0, 0.0]\n",
	"E2-02": "# Completa la línea marcada y compruébala con py check.\ndef acuerdo(a, b):\n    iguales = sum(1 for x, y in zip(a, b) if x == y)\n    return iguales / len(a)\n\nprint(acuerdo([1, 2, 3, 4], [1, 2, 0, 4]))   # 0.75\n",
	"E2-03": "# Completa la línea marcada y compruébala con py check.\nimport math\n\ndef perdida_por_ejemplo(probs, y):\n    out = []\n    for fila, clase in zip(probs, y):\n        p = max(fila[clase], 1e-12)\n        out.append(-math.log(p))\n    return out\n\nprint(perdida_por_ejemplo([[0.9, 0.1], [0.3, 0.7]], [0, 0]))   # [0.105, 1.204]\n",
	"E4-01": "# Completa la línea marcada y compruébala con py check.\ndef normalizar_pregunta(texto):\n    t = texto.lower().strip(\" ¿?¡!.\")\n    return \" \".join(t.split())\n\nprint(normalizar_pregunta(\"  ¿Qué  ACEITE uso?  \"))   # qué aceite uso\n",
	"E4-02": "# Completa la línea marcada y compruébala con py check.\ndef redactar(texto):\n    palabras = []\n    for p in texto.split():\n        palabras.append(\"[correo]\" if \"@\" in p else p)\n    return \" \".join(palabras)\n\nprint(redactar(\"escribe a ana@x.com mañana\"))   # escribe a [correo] mañana\n",
	"E4-03": "# Completa la línea marcada y compruébala con py check.\ndef hallazgos(servicio):\n    h = []\n    if \"@sha256:\" not in servicio.get(\"image\", \"\"):\n        h.append(\"imagen-sin-huella\")\n    if \"user\" not in servicio:\n        h.append(\"root\")\n    if any(not p.startswith(\"127.0.0.1:\") for p in servicio.get(\"ports\", [])):\n        h.append(\"puerto-expuesto\")\n    return h\n\nprint(hallazgos({\"image\": \"ollama/ollama:latest\", \"ports\": [\"11434:11434\"]}))\n",
	"P0-01": "# Completa la línea marcada y compruébala con py check.\ndef construir_peticion(pregunta, modelo, temperatura):\n    return {\n        \"model\": modelo,\n        \"stream\": False,\n        \"messages\": [{\"role\": \"user\", \"content\": pregunta}],\n        \"options\": {\"temperature\": temperatura},\n    }\n\nprint(construir_peticion(\"¿Qué es el temple?\", \"llama3.2:1b\", 0.8))\n",
	"P0-02": "# Completa la línea marcada y compruébala con py check.\nimport math\n\ndef probabilidad(x, pesos, sesgo):\n    z = sesgo\n    for xi, wi in zip(x, pesos):\n        z = z + xi * wi\n    return 1 / (1 + math.exp(-z))\n\nprint(probabilidad([1.0, 2.0], [0.5, -0.25], 0.1))   # unos 0.525\n",
	"P0-03": "# Completa la línea marcada y compruébala con py check.\nimport math\n\ndef entropia_cruzada(probs, etiquetas):\n    total = 0\n    for p, y in zip(probs, etiquetas):\n        p = min(max(p, 1e-12), 1 - 1e-12)\n        total += -(y * math.log(p) + (1 - y) * math.log(1 - p))\n    return total / len(probs)\n\nprint(entropia_cruzada([0.9, 0.2], [1, 0]))   # unos 0.164\n",
	"P0-04": "# Completa la línea marcada y compruébala con py check.\ndef lineas(trozos):\n    texto = \"\".join(trozos)\n    partes = texto.split(\"\\n\")\n    return [p for p in partes if p != \"\"]\n\nprint(lineas([\"hola mun\", \"do\\nadiós\"]))   # ['hola mundo', 'adiós']\n",
	"P0-05": "# Completa la línea marcada y compruébala con py check.\ndef frecuencias(muestras):\n    cuenta = {}\n    for t in muestras:\n        cuenta[t] = cuenta.get(t, 0) + 1\n    return {t: cuenta[t] / len(muestras) for t in cuenta}\n\nprint(frecuencias([\"a\", \"b\", \"a\", \"a\"]))   # {'a': 0.75, 'b': 0.25}\n",
}

var game: DojoGame


func before_each() -> void:
	game = DojoGame.new("")


func _exercise(mid: String) -> Dictionary:
	for o: Dictionary in game.catalog.get_mission(mid)["objectives"]:
		if o.has("py_exercise") and str(o["py_exercise"]["id"]).ends_with("-forja"):
			return o["py_exercise"]
	return {}


func test_cada_solucion_pasa_y_cada_inicio_falla() -> void:
	for mid: String in SOLUCIONES:
		var ex := _exercise(mid)
		assert_false(ex.is_empty(), mid)
		var spec := PyCommands._int_spec(ex)
		var bad: Dictionary = PyExercise.check(ex["starter"], spec)
		assert_true(bad.get("ok", false), "%s: el código inicial se ejecuta · %s" % [mid, str(bad.get("error", ""))])
		assert_true(int(bad.get("passed", 0)) < int(bad.get("total", 0)), "%s: el código inicial no debe pasar" % mid)
		var good: Dictionary = PyExercise.check(SOLUCIONES[mid], spec)
		assert_eq(int(good.get("passed", -1)), int(good.get("total", -2)), "%s: la solución pasa · %s" % [mid, str(good)])


func test_el_paso_se_cumple_dentro_del_dojo() -> void:
	var m := game.catalog.get_mission("A1-05")
	game.active_mission = m
	game.runner.start(m, game.shell.event_log[-1]["seq"] if not game.shell.event_log.is_empty() else 0)
	game.shell.execute("py")
	game.py_code = SOLUCIONES["A1-05"]
	game.shell.execute("py check")
	assert_eq(game.runner.index, 1, "programar la pieza en el Dojo cumple el paso")


func test_preparar_el_entorno_se_cumple_con_py_run() -> void:
	var m := game.catalog.get_mission("P0-01")
	game.active_mission = m
	game.runner.start(m, game.shell.event_log[-1]["seq"] if not game.shell.event_log.is_empty() else 0)
	game.shell.execute("py")
	game.py_code = "print(\"hola\")\n"
	game.shell.execute("py run")
	assert_eq(game.runner.index, 1, "ejecutar algo en el editor cumple el paso de preparar el entorno")
