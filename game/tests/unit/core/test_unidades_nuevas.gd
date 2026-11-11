extends TestCase
## Unidades nuevas (T7–T10, P1): cada misión se completa de principio a fin con los comandos reales.
## Las soluciones de referencia de los ejercicios viven SOLO aquí.

const SOLUCIONES := {
	"T7-01": "# Completa la línea marcada y compruébala con py check.\ndef predecir(nodo, fila):\n    while \"hoja\" not in nodo:\n        if fila[nodo[\"f\"]] <= nodo[\"t\"]:\n            nodo = nodo[\"izq\"]\n        else:\n            nodo = nodo[\"der\"]\n    return nodo[\"hoja\"]\n\narbol = {\"f\": 0, \"t\": 61.9, \"izq\": {\"hoja\": \"apta\"}, \"der\": {\"hoja\": \"defectuosa\"}}\nprint(predecir(arbol, [63.0, 5.0]))   # defectuosa\n",
	"T7-02": "# Completa la línea marcada y compruébala con py check.\ndef gini(etiquetas):\n    cuenta = {}\n    for e in etiquetas:\n        cuenta[e] = cuenta.get(e, 0) + 1\n    n = len(etiquetas)\n    return 1 - sum((cuenta[c] / n) ** 2 for c in cuenta)\n\nprint(gini([\"abuso\", \"abuso\", \"normal\", \"normal\"]))   # 0.5\n",
	"T7-03": "# Completa la línea marcada y compruébala con py check.\nimport math\n\ndef asignar(punto, centros):\n    mejor, mejor_d = 0, math.inf\n    for i, c in enumerate(centros):\n        d = math.sqrt(sum((x - y) ** 2 for x, y in zip(punto, c)))\n        if d < mejor_d:\n            mejor_d = d\n            mejor = i\n    return mejor\n\nprint(asignar([0.9, 0.8], [[0.1, 0.2], [0.8, 0.7]]))   # 1\n",
	"T7-04": "# Completa la línea marcada y compruébala con py check.\ndef mas_raros(distancias, n):\n    # distancias: {id: distancia al centro}\n    orden = sorted(distancias, key=lambda c: distancias[c], reverse=True)\n    return orden[:n]\n\nprint(mas_raros({\"cli-001\": 0.1, \"cli-039\": 0.98, \"cli-041\": 0.2}, 1))   # ['cli-039']\n",
	"T8-01": "# Completa la línea marcada y compruébala con py check.\ndef respuesta(parche, filtro):\n    total = 0\n    for i in range(3):\n        for j in range(3):\n            total += parche[i][j] * filtro[i][j]\n    return total\n\nborde_vertical = [[-1, 0, 1], [-2, 0, 2], [-1, 0, 1]]\nprint(respuesta([[0, 0, 1], [0, 0, 1], [0, 0, 1]], borde_vertical))   # 4\n",
	"T8-02": "# Completa la línea marcada y compruébala con py check.\ndef limpiar(fila, fondo, umbral):\n    salida = []\n    for p in fila:\n        salida.append(fondo if abs(p - fondo) < umbral else p)\n    return salida\n\nprint(limpiar([1.0, 0.98, 0.05, 1.0], 1.0, 0.05))   # [1.0, 1.0, 0.05, 1.0]\n",
	"T9-01": "# Completa la línea marcada y compruébala con py check.\ndef mas_probable(candidatas):\n    # candidatas: {respuesta: probabilidad}\n    return max(candidatas, key=lambda r: candidatas[r])\n\nprint(mas_probable({\"continuar\": 0.08, \"contestar\": 0.84, \"rollo\": 0.08}))   # contestar\n",
	"T9-02": "# Completa la línea marcada y compruébala con py check.\ndef acuerdo(pares):\n    # cada par: [puntuación de a, puntuación de b, elección de la persona («a» o «b»)]\n    aciertos = 0\n    for pa, pb, humano in pares:\n        elige = \"a\" if pa > pb else \"b\"\n        aciertos += 1 if elige == humano else 0\n    return aciertos / len(pares)\n\nprint(acuerdo([[2.0, 1.0, \"a\"], [0.5, 3.0, \"a\"]]))   # 0.5\n",
	"T9-03": "# Completa la línea marcada y compruébala con py check.\ndef tasa_rechazo(tipos):\n    # tipos: lista con el tipo de cada respuesta («rechazo», «obedece»…)\n    rechazos = tipos.count(\"rechazo\")\n    return rechazos / len(tipos)\n\nprint(tasa_rechazo([\"rechazo\", \"rechazo\", \"obedece\"]))   # unos 0.667\n",
	"P1-01": "# Completa la línea marcada y compruébala con py check.\ndef valida(salida, campos):\n    if not isinstance(salida, dict):\n        return False\n    for c in campos:\n        if c not in salida:\n            return False\n        if not isinstance(salida[c], str):\n            return False\n    return True\n\nprint(valida({\"pedido\": \"P-101\", \"problema\": \"rota\", \"urgencia\": None}, [\"pedido\", \"problema\", \"urgencia\"]))   # False\n",
	"P1-02": "# Completa la línea marcada y compruébala con py check.\ndef exactitud(salidas, oro, campo):\n    bien = 0\n    for s, o in zip(salidas, oro):\n        bien += 1 if s[campo] == o[campo] else 0\n    return bien / len(oro)\n\nprint(exactitud([{\"urgencia\": \"alta\"}, {\"urgencia\": \"media\"}], [{\"urgencia\": \"alta\"}, {\"urgencia\": \"baja\"}], \"urgencia\"))   # 0.5\n",
	"P1-03": "# Completa la línea marcada y compruébala con py check.\ndef id_valido(texto):\n    if not texto.startswith(\"P-\"):\n        return False\n    resto = texto[2:]\n    return len(resto) == 3 and resto.isdigit()\n\nprint(id_valido(\"P109\"), id_valido(\"P-109\"))   # False True\n",
	"T10-01": "# Completa la línea marcada y compruébala con py check.\ndef tasa_seleccion(decisiones, grupos, g):\n    del_grupo = [d for d, x in zip(decisiones, grupos) if x == g]\n    favorables = del_grupo.count(\"apta\")\n    return favorables / len(del_grupo)\n\nprint(tasa_seleccion([\"apta\", \"no_apta\", \"apta\", \"apta\"], [0, 0, 1, 1], 0))   # 0.5\n",
	"T10-02": "# Completa la línea marcada y compruébala con py check.\ndef ratio(tasas):\n    # tasas: {grupo: tasa de selección}\n    return min(tasas.values()) / max(tasas.values())\n\nprint(ratio({\"0\": 0.38, \"1\": 0.12}))   # unos 0.316\n",
	"T8-03": "# Completa la línea marcada y compruébala con py check.\ndef atacar(pixeles, signos, eps):\n    salida = []\n    for p, s in zip(pixeles, signos):\n        nuevo = min(1.0, max(0.0, p + eps * s))\n        salida.append(nuevo)\n    return salida\n\nprint([round(x, 2) for x in atacar([0.2, 0.44, 0.95], [1, -1, 1], 0.1)])   # [0.3, 0.34, 1.0]\n",
	"T10-03": "# Completa la línea marcada y compruébala con py check.\ndef de_los_que_devuelven(aprobado, devuelve):\n    # aprobado y devuelve: listas de True o False, una posición por solicitud\n    buenos = [a for a, d in zip(aprobado, devuelve) if d]\n    aprobados = buenos.count(True)\n    return aprobados / len(buenos)\n\nprint(de_los_que_devuelven([True, False, True, True], [True, True, False, True]))   # unos 0.667\n",
}

var game: DojoGame
var finished: Array = []


func before_each() -> void:
	game = DojoGame.new("")
	finished.clear()
	game.mission_completed.connect(func(_m: Dictionary, r: Dictionary, _xp: int) -> void: finished.append(r))


func _walk(mid: String, reqs: Array, lines: Array) -> void:
	for r: String in reqs:
		game.progress.data["missions"][r] = {"completed": true}
	assert_eq(game.start_mission(mid), "", mid + " arranca")
	for l: String in lines:
		if l == "PY":
			game.shell.execute("py")
			game.py_code = SOLUCIONES[mid]
			game.shell.execute("py check")
		else:
			var r := game.shell.execute(l)
			if not r.ok:
				fail("%s · «%s» → %s" % [mid, l, r.plain_text().left(200)])
	if game.runner.phase != "done":
		fail("%s se queda en %s, objetivo %d: %s" % [mid, game.runner.phase, game.runner.index, str(game.runner.current_objective().get("text", ""))])
	assert_eq(finished.size(), 1, mid + " se completa")
	if finished.size() == 1:
		assert_true(finished[0]["trial_passed"], mid + ": prueba de dominio superada")


func test_T7_01_completa() -> void:
	_walk("T7-01", ["T3-03"], ["dataset split katanas --test 0.3 --seed 42", "tree train t2 katanas_train --depth 2", "answer a", "classic evaluate t2 katanas_test", "answer 0.806", "hipotesis empeora", "tree train t8 katanas_train --depth 8", "classic evaluate t8 katanas_test", "answer c", "PY", "tree train t3 katanas_train --depth 3", "classic evaluate t3 katanas_test", "answer 0.792"])


func test_T7_02_completa() -> void:
	_walk("T7-02", ["T7-01"], ["dataset split peticiones --test 0.3 --seed 42", "tree train p8 peticiones_train --depth 8", "classic evaluate p8 peticiones_test", "answer 0.889", "hipotesis sí", "forest train f peticiones_train --trees 50 --depth 6", "classic evaluate f peticiones_test", "answer b", "tree show f", "answer c", "PY", "forest train f2 peticiones_train --trees 20 --depth 4", "classic evaluate f2 peticiones_test", "answer 0.889"])


func test_T7_03_completa() -> void:
	_walk("T7-03", ["T7-02"], ["dataset normalize katanas --method minmax --as kn", "kmeans kn --k 2", "answer b", "hipotesis sí", "dataset normalize peticiones --method minmax --as pn", "kmeans pn --k 2", "answer 0.88", "PY", "answer c", "kmeans pn --k 3", "answer 0.86"])


func test_T7_04_completa() -> void:
	_walk("T7-04", ["T7-03"], ["dataset normalize peticiones --method minmax --as pn", "kmeans outliers pn --k 1 --top 10", "kmeans outliers pn --k 1 --top 30", "answer no", "answer b", "answer a", "PY", "kmeans outliers pn --k 2 --top 20", "answer 9"])


func test_T8_01_completa() -> void:
	_walk("T8-01", ["T4-03"], ["image list", "image show cruz", "image show cruz --numeros", "answer 1", "answer b", "hipotesis sí", "conv linea_v borde_vertical", "answer 4", "hipotesis no se", "conv linea_h borde_vertical", "answer a", "PY", "conv cruz borde_horizontal", "answer 4"])


func test_T8_02_completa() -> void:
	_walk("T8-02", ["T8-01"], ["image show factura", "hipotesis sí", "vision read factura", "answer c", "image show factura --contraste", "image clean factura --umbral 0.05", "vision read factura_limpia", "answer a", "answer b", "PY", "image clean factura --umbral 0.01 --as f1", "vision read f1", "answer sí"])


func test_T9_01_completa() -> void:
	_walk("T9-01", ["T6-03"], ["hipotesis no", "llm pretrain kuro", "llm ask kuro temple", "answer b", "llm sft kuro", "llm ask kuro temple", "hipotesis sí", "llm ask kuro codigo", "answer a", "PY", "llm pretrain a", "llm sft a", "llm ask a resumen", "answer 84"])


func test_T9_02_completa() -> void:
	_walk("T9-02", ["T9-01"], ["llm pretrain kuro", "llm sft kuro", "llm prefs kuro seguridad", "hipotesis sí", "llm ask kuro codigo", "answer c", "llm pretrain v", "llm sft v", "llm prefs v longitud", "hipotesis suelta", "llm ask v resumen", "answer b", "PY", "llm ask v temple", "answer 72"])


func test_T9_03_completa() -> void:
	_walk("T9-03", ["T9-02"], ["llm pretrain kuro", "llm sft kuro", "llm prefs kuro seguridad", "llm ask kuro codigo", "hipotesis no", "llm ask kuro codigo_rol", "answer b", "llm prefs kuro rol", "llm ask kuro codigo_rol", "hipotesis no", "llm ask kuro codigo_traduccion", "answer c", "PY", "llm pretrain b", "llm sft b", "llm prefs b rol", "llm ask b codigo", "answer no"])


func test_P1_01_completa() -> void:
	_walk("P1-01", ["P0-01", "T9-03"], ["app create ext", "app run ext c02", "answer b", "app eval ext", "answer 5", "hipotesis entre", "app set ext formato_json on", "app eval ext", "app set ext esquema on", "app eval ext", "answer a", "PY", "app create e", "app set e formato_json on", "app eval e", "answer 21"])


func test_P1_02_completa() -> void:
	_walk("P1-02", ["P1-01"], ["app create ext", "app set ext formato_json on", "app set ext esquema on", "app eval ext", "answer 0.767", "app set ext instrucciones on", "app eval ext", "hipotesis suben mucho", "app set ext ejemplos on", "app eval ext", "answer c", "app run ext c07", "app set ext delimitar on", "app eval ext", "answer a", "PY", "app create e2", "app set e2 formato_json on", "app set e2 esquema on", "app set e2 instrucciones on", "app set e2 delimitar on", "app eval e2", "answer 0.867"])


func test_P1_03_completa() -> void:
	_walk("P1-03", ["P1-02"], ["app create ext", "app set ext formato_json on", "app set ext esquema on", "app set ext instrucciones on", "app set ext ejemplos on", "app set ext delimitar on", "app run ext c08", "hipotesis sí", "app set ext herramientas on", "app run ext c08", "answer b", "app set ext validar_args on", "app run ext c08", "app eval ext", "answer 30", "answer c", "PY", "app create e3", "app set e3 formato_json on", "app set e3 esquema on", "app set e3 instrucciones on", "app set e3 ejemplos on", "app set e3 delimitar on", "app set e3 herramientas on", "app eval e3", "answer 29"])


func test_T10_01_completa() -> void:
	_walk("T10-01", ["T9-03"], ["dataset inspect candidatos", "fairness datos candidatos", "answer 0.32", "answer b", "hipotesis parecido", "tree train t candidatos --depth 4", "fairness t candidatos", "answer c", "PY", "fairness datos candidatos", "answer 0.12"])


func test_T10_02_completa() -> void:
	_walk("T10-02", ["T10-01"], ["hipotesis no", "dataset drop candidatos grupo --as sin_grupo", "tree train t2 sin_grupo --depth 4", "fairness t2 sin_grupo --grupos candidatos", "answer 0.30", "tree show t2", "answer b", "dataset drop sin_grupo zona --as sin_zona", "tree train t3 sin_zona --depth 4", "fairness t3 sin_zona --grupos candidatos", "answer a", "answer c", "PY", "tree train t5 sin_zona --depth 2", "fairness t5 sin_zona --grupos candidatos", "answer 0.87"])


func test_T8_03_completa() -> void:
	_walk("T8-03", ["T8-02"], ["vision classify foto_cruz", "vision classify foto_cuadrado", "vision pesos", "answer b", "hipotesis sí", "image attack foto_cruz --eps 0.1 --as foto_adv", "vision classify foto_adv", "answer 0.99", "answer a", "hipotesis sí", "image binarize foto_adv --as foto_bin", "vision classify foto_bin", "image attack foto_cruz --eps 0.15 --as foto_fuerte", "image binarize foto_fuerte --as foto_fuerte_bin", "vision classify foto_fuerte_bin", "answer a", "answer b", "PY", "image attack foto_cruz --eps 0.08 --as e8", "vision classify e8", "answer 0.08"])


func test_T10_03_completa() -> void:
	_walk("T10-03", ["T10-02"], ["dataset inspect prestamos", "fairness umbral prestamos --umbral 0.5", "answer 0.59", "answer b", "fairness umbral prestamos --umbral 0.5 --umbral1 0.45", "answer 0.003", "hipotesis baja", "fairness umbral prestamos --umbral 0.5 --umbral1 0.35", "answer 0.64", "answer a", "answer c", "PY", "fairness umbral prestamos --umbral 0.5 --umbral1 0.3", "answer 0.3"])


func test_ejercicios_inicio_falla_y_solucion_pasa() -> void:
	for mid: String in SOLUCIONES:
		var ex: Dictionary = {}
		for o: Dictionary in game.catalog.get_mission(mid)["objectives"]:
			if o.has("py_exercise"):
				ex = PyCommands._int_spec(o["py_exercise"])
		var bad: Dictionary = PyExercise.check(ex["starter"], ex)
		assert_true(bad.get("ok", false), mid + ": el inicio se ejecuta · " + str(bad.get("error", "")))
		assert_true(int(bad.get("passed", 0)) < int(bad.get("total", 0)), mid + ": el inicio no pasa")
		var good: Dictionary = PyExercise.check(SOLUCIONES[mid], ex)
		assert_eq(int(good.get("passed", -1)), int(good.get("total", -2)), "%s: la solución pasa · %s" % [mid, str(good)])
