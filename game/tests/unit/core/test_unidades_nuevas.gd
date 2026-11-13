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
	"T7-05": "# Completa la línea marcada y compruébala con py check.
def residuos(etiquetas, probabilidades):
    salida = []
    for y, p in zip(etiquetas, probabilidades):
        salida.append(y - p)
    return salida

print(residuos([1, 0, 1], [0.8, 0.3, 0.4]))   # unos [0.2, -0.3, 0.6]
",
	"P2-01": "# Completa la línea marcada y compruébala con py check.\ndef pasa_puerta(media, segmentos, prohibidas, min_media, min_segmento):\n    # segmentos: {nombre: tasa}\n    if media < min_media:\n        return False\n    if prohibidas > 0:\n        return False\n    return min(segmentos.values()) >= min_segmento\n",
	"P2-02": "import math\n\ndef psi(esperado, actual):\n    total = 0.0\n    for e, a in zip(esperado, actual):\n        e = max(e, 0.001)\n        a = max(a, 0.001)\n        total += (a - e) * math.log(a / e)\n    return total\n",
	"O7-01": "def aciertos(mia, referencia):\n    n = 0\n    for inc in referencia:\n        n += 1 if mia.get(inc) == referencia[inc] else 0\n    return n\n",
	"O7-02": "def sin_cubrir(riesgos, cobertura):\n    cubiertos = set(cobertura.values())\n    return [r for r in riesgos if r not in cubiertos]\n",
	"E5-01": "def sin_evidencia(soa):\n    salida = []\n    for o in soa:\n        if o[\"aplica\"] and len(o[\"evidencias\"]) == 0:\n            salida.append(o[\"id\"])\n    return salida\n",
	"E5-02": "def decision(grados):\n    if \"mayor\" in grados:\n        return \"aplazar\"\n    if \"menor\" in grados:\n        return \"recomendar-con-plan\"\n    return \"recomendar\"\n",
	"O7-03": "def frenados(ataques, activas):\n    n = 0\n    for a in ataques:\n        bloqueado = any(d in activas for d in ataques[a])\n        n += 1 if bloqueado else 0\n    return n\n",
	"O7-04": "def daninas_aprobadas(peticiones, decisiones):\n    n = 0\n    for pid in peticiones:\n        if peticiones[pid] and decisiones[pid] == \"si\":\n            n += 1\n    return n\n",
	"O7-05": "def hay_fuga(ocurre, fuga):\n    for paso in fuga:\n        if ocurre.get(paso, False):\n            return True\n    return False\n",
	"A7-01": "def accion_peligrosa(accion, origen, con_efecto):\n    return origen == \"web\" and accion in con_efecto\n",
	"A7-02": "def necesita_confirmacion(accion, con_efecto):\n    return accion in con_efecto\n",
	"O7-06": "def sigue_activa(guardada_en, sesion_actual, caducidad):\n    if not caducidad:\n        return True\n    return sesion_actual <= guardada_en\n",
	"O7-07": "def ficha_completa(mapeo, marcos):\n    for m in marcos:\n        if m not in mapeo:\n            return False\n    return True\n",
	"T11-01": "def ventajas(recompensas):\n    media = sum(recompensas) / len(recompensas)\n    return [r - media for r in recompensas]\n",
	"T11-02": "def mas_votada(muestras):\n    conteo = {}\n    for m in muestras:\n        conteo[m] = conteo.get(m, 0) + 1\n    return max(conteo, key=lambda m: conteo[m])\n",
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


func test_T7_05_completa() -> void:
	_walk("T7-05", ["T7-04"], ["dataset split peticiones --test 0.3 --seed 42", "forest train f peticiones_train --trees 50 --depth 6", "classic evaluate f peticiones_test", "answer 0.917", "hipotesis sí", "boost train g peticiones_train --rounds 50 --lr 0.3", "classic evaluate g peticiones_test", "answer 0.972", "tree show g", "answer peticiones_hora", "answer b", "hipotesis peor", "dataset split katanas --test 0.3 --seed 42", "boost train gk katanas_train --rounds 400 --lr 0.5 --depth 3", "boost curve gk katanas_test", "answer 5", "answer b", "PY", "boost train gt katanas_train --rounds 400 --lr 0.1 --depth 3", "boost curve gt katanas_test", "answer 50", "dataset split prestamos --test 0.3 --seed 42", "boost train gp prestamos_train --rounds 400 --lr 0.3 --depth 2", "boost curve gp prestamos_test", "answer 5"])


func test_P2_01_completa() -> void:
	_walk("P2-01", ["P1-03", "A3-01"], ["evals run v1", "answer 0.667", "hipotesis no se sabe aún", "evals run v2", "answer 1", "evals trace v2 t11", "answer reembolsar", "answer b", "evals compare v1 v2", "answer seguridad", "evals gate v2 --media 0.7 --segmento 0.6 --prohibidas 0", "evals gate v3 --media 0.7 --segmento 0.6 --prohibidas 0", "answer b", "PY", "evals run v3", "answer 0.917"])


func test_P2_02_completa() -> void:
	_walk("P2-02", ["P2-01"], ["monitor dashboard", "answer 6", "monitor trace 6", "answer estado_envio", "answer b", "hipotesis no", "monitor dashboard --muestreo 0.01", "monitor dashboard --muestreo 0.1", "answer 0.78", "monitor drift", "answer internacional", "answer b", "PY", "monitor dashboard --muestreo 0.05", "answer 0.82"])


func test_O7_01_completa() -> void:
	_walk("O7-01", ["O6-03", "A5-03"], ["asi list", "asi incidents", "asi classify I1 ASI01", "asi classify I2 ASI02", "asi classify I3 ASI03", "asi classify I4 ASI04", "asi classify I5 ASI05", "answer b", "asi classify I6 ASI06", "asi classify I7 ASI07", "asi classify I8 ASI08", "asi classify I9 ASI09", "asi classify I10 ASI10", "answer b", "PY", "answer ASI06"])


func test_O7_02_completa() -> void:
	_walk("O7-02", ["O7-01"], ["asi defenses", "asi cover D1 ASI01", "asi cover D2 ASI02", "asi cover D3 ASI03", "asi cover D4 ASI04", "asi cover D5 ASI04", "asi cover D6 ASI06", "asi cover D7 ASI07", "asi cover D8 ASI08", "asi cover D9 ASI10", "asi coverage", "answer 2", "answer b", "answer c", "PY", "answer 3"])


func test_E5_01_completa() -> void:
	_walk("E5-01", ["E3-03"], ["iso context", "iso soa", "iso check A.10", "iso flag A.10 exclusion-injustificada", "answer c", "iso check A.5", "iso flag A.5 sin-evidencia", "answer 6.1.4", "PY", "answer 1"])


func test_E5_02_completa() -> void:
	_walk("E5-02", ["E5-01"], ["iso findings", "iso grade H1 mayor", "iso grade H2 menor", "iso grade H3 menor", "iso grade H4 observacion", "iso grade H5 mayor", "iso grade H6 menor", "answer b", "iso decide aplazar", "answer b", "PY", "answer recomendar-con-plan"])


func test_P2_gate_y_trayectoria() -> void:
	var s1 := EvalsCommands.summary("v1")
	var s2 := EvalsCommands.summary("v2")
	assert_true(s2["final_rate"] > s1["final_rate"], "v2 contesta mejor")
	assert_eq(s2["forbidden"], 1, "pero hace un reembolso prohibido")
	assert_true(s2["segments"]["seguridad"] < s1["segments"]["seguridad"], "y empeora en seguridad")
	assert_almost_eq(EvalsCommands.psi([0.6, 0.4], [0.5, 0.5]), 0.0405, 0.001)


func test_asi_clasificar_mal_no_cuenta() -> void:
	game.shell.execute("asi classify I2 ASI01")
	assert_eq(game.shell.events_named("asi.classified")[-1]["data"]["correct_count"], 0)
	assert_eq(IsoCommands.expected_decision(["menor", "observacion"]), "recomendar-con-plan")


func test_O7_03_completa() -> void:
	_walk("O7-03", ["O7-02"], ["sandbox show", "sandbox run", "answer 7", "hipotesis ninguno", "sandbox set prompt_prudente on", "sandbox run", "answer 0", "sandbox set prompt_prudente off", "sandbox set sin_shell on", "sandbox set sin_secretos on", "sandbox set sin_red on", "sandbox set limites on", "sandbox set fs_efimero on", "sandbox run", "answer X6", "answer a", "sandbox set escapar_salida on", "sandbox run", "answer 3", "answer b", "PY", "answer 2"])


func test_O7_04_completa() -> void:
	_walk("O7-04", ["O7-03"], ["approvals mode explicacion", "approvals list", "approvals decide R1 si", "approvals decide R2 si", "approvals decide R3 si", "approvals decide R4 si", "approvals decide R5 si", "approvals decide R6 si", "approvals decide R7 si", "approvals decide R8 si", "approvals result", "answer b", "approvals mode verificable", "approvals list", "approvals decide R2 no", "approvals decide R4 no", "approvals decide R6 no", "approvals decide R8 no", "approvals decide R1 si", "approvals decide R3 si", "approvals decide R5 si", "approvals decide R7 si", "approvals result", "answer 0", "answer b", "PY", "answer no"])


func test_O7_05_completa() -> void:
	_walk("O7-05", ["O7-04"], ["chain show", "chain label S1 ASI04", "chain label S2 ASI01", "chain label S3 ASI06", "chain label S4 ASI02", "chain label S5 ASI07", "chain label S6 ASI08", "chain run", "answer si", "answer b", "chain defend D2 on", "chain run", "answer no", "answer b", "PY", "answer si"])


func test_O7_lab_motor() -> void:
	assert_eq(AsiLabCommands.battery([])["attacks_ok"], 7)
	assert_eq(AsiLabCommands.battery(["sin_shell", "sin_secretos", "sin_red", "limites", "fs_efimero"])["attacks_ok"], 1)
	var full := AsiLabCommands.battery(["sin_shell", "sin_secretos", "red_lista", "limites", "fs_efimero", "escapar_salida"])
	assert_eq(full["attacks_ok"], 0, "caja completa frena todo")
	assert_eq(full["legit_ok"], 4, "y no rompe ninguna tarea")
	assert_false(AsiLabCommands.simulate(["D2"])["mcp"]["leak"], "D2 corta la fuga por mcp")
	assert_false(AsiLabCommands.simulate(["D2"])["web"]["leak"], "y por web")
	assert_true(AsiLabCommands.simulate(["D4"])["web"]["leak"], "D4 no cubre la entrada web")
	assert_true(AsiLabCommands.simulate(["D6"])["mcp"]["leak"], "D6 no corta la fuga")


func test_A7_01_completa() -> void:
	_walk("A7-01", ["A4-04"], ["web show navegador", "web run navegador", "answer 5", "hipotesis algunos", "web set navegador aislar_contenido on", "web run navegador", "answer 3", "web set navegador sin_acciones_desde_web on", "web set navegador confirmacion on", "web set navegador saneado_salida on", "web run navegador", "answer W3", "answer a", "web set navegador allowlist_dominios on", "web run navegador", "answer 4", "answer b", "PY", "web set navegador saneado_salida off", "web run navegador", "answer 1", "web set correo aislar_contenido on", "web set correo sin_acciones_desde_correo on", "web set correo confirmacion on", "web set correo saneado_salida on", "web run correo", "answer E3"])


func test_A7_02_completa() -> void:
	_walk("A7-02", ["A7-01"], ["web show ordenador", "web run ordenador", "answer 5", "hipotesis 2", "web set ordenador sesion_aislada on", "web set ordenador sin_descargas on", "web set ordenador confirmacion_verificable on", "web set ordenador allowlist_acciones on", "web set ordenador dominio_tarea on", "web run ordenador", "answer 2", "answer b", "web set ordenador sesion_aislada off", "web set ordenador sin_descargas off", "web set ordenador credencial_delegada on", "web set ordenador sin_ejecutables on", "web run ordenador", "answer 4", "answer b", "PY", "web set ordenador confirmacion_verificable off", "web set ordenador allowlist_acciones off", "web set ordenador credencial_delegada off", "web set ordenador sin_ejecutables off", "web set ordenador dominio_tarea off", "web set ordenador confirmacion_verificable on", "web run ordenador", "answer 2"])


func test_A7_motor() -> void:
	assert_eq(WebCommands.battery("navegador", [])["attacks_ok"], 5)
	assert_eq(WebCommands.battery("navegador", ["aislar_contenido", "sin_acciones_desde_web", "confirmacion", "saneado_salida", "allowlist_dominios"])["attacks_ok"], 0)
	assert_eq(WebCommands.battery("navegador", ["aislar_contenido", "sin_acciones_desde_web", "confirmacion", "saneado_salida", "allowlist_dominios"])["legit_ok"], 4)
	var brusca := WebCommands.battery("ordenador", ["sesion_aislada", "sin_descargas", "confirmacion_verificable", "allowlist_acciones", "dominio_tarea"])
	assert_eq(brusca["attacks_ok"], 0, "la caja brusca frena todo")
	assert_eq(brusca["legit_ok"], 2, "pero rompe dos tareas")
	var fina := WebCommands.battery("ordenador", ["credencial_delegada", "sin_ejecutables", "confirmacion_verificable", "allowlist_acciones", "dominio_tarea"])
	assert_eq(fina["attacks_ok"], 0, "la acotada tambien")
	assert_eq(fina["legit_ok"], 4, "y no rompe nada")


func test_O7_06_completa() -> void:
	_walk("O7-06", ["O7-02"], ["memoria estado", "memoria envenenar", "answer si", "hipotesis sí", "memoria nueva_sesion", "memoria caso", "answer si", "answer b", "memoria defensa aislar on", "memoria limpiar", "memoria envenenar", "answer no", "memoria defensa aislar off", "memoria limpiar", "memoria envenenar", "memoria defensa caducidad on", "memoria nueva_sesion", "memoria caso", "answer no", "answer b", "PY", "memoria defensa caducidad off", "memoria defensa origen on", "memoria limpiar", "memoria envenenar", "answer no"])


func test_O7_07_completa() -> void:
	_walk("O7-07", ["O7-06"], ["marco list", "marco show F1", "marco set F1 asi ASI01", "marco set F1 llm LLM01", "marco set F1 atlas Initial Access", "marco set F1 nist MAP", "marco card F1", "marco set F3 asi ASI06", "marco set F3 llm LLM04", "marco set F3 atlas Persistence", "marco set F3 nist MEASURE", "marco card F3", "answer Persistence", "answer b", "asi close D10 ASI05", "asi close D11 ASI09", "answer b", "PY", "marco set F2 asi ASI05", "marco set F2 llm LLM05", "marco set F2 atlas Execution", "marco set F2 nist MANAGE", "marco card F2", "answer Execution"])


func test_O7_mejoras_motor() -> void:
	# riesgo secundario: no cuenta como correcto pero se reconoce
	game.shell.execute("asi classify I5 ASI02")
	assert_eq(game.shell.events_named("asi.classified")[-1]["data"]["correct_count"], 0)
	game.shell.execute("asi classify I5 ASI05")
	assert_eq(game.shell.events_named("asi.classified")[-1]["data"]["correct_count"], 1)
	# cerrar el mapa
	game.shell.execute("asi close D10 ASI05")
	game.shell.execute("asi close D11 ASI09")
	assert_eq(game.shell.events_named("asi.closed")[-1]["data"]["gaps"], 0)


func test_T11_01_completa() -> void:
	_walk("T11-01", ["T9-03"], ["reason problems", "reason new r", "reason ask r", "answer 0.17", "hipotesis sí", "reason grpo r --pasos 40 --grupo 8", "answer 1", "answer a", "hipotesis bajará", "reason new h", "reason grpo h --pasos 40 --grupo 8 --amaño", "reason ask h", "answer 0", "answer b", "PY", "reason new x", "reason grpo x --pasos 40 --grupo 4", "answer 1"])


func test_T11_02_completa() -> void:
	_walk("T11-02", ["T11-01"], ["reason new d", "reason dpo d --pasos 8", "answer 1", "answer b", "hipotesis sí", "reason new c", "reason grpo c --pasos 3 --grupo 8 --lr 0.2", "reason best c --n 1", "reason best c --n 8", "answer 1", "answer b", "reason new m", "reason grpo m --pasos 40 --grupo 8", "reason new al", "reason distill al m --pasos 12", "answer 1", "PY", "reason best c --n 1", "answer 0.5"])


func test_T11_motor() -> void:
	var p := ReasoningSim.Policy.new().setup(ReasonCommands.data()["problemas"])
	assert_almost_eq(p.accuracy(), 0.1667, 0.02)
	ReasoningSim.grpo(p, 40, 8, 0.5, 42, true)
	assert_almost_eq(p.accuracy(), 1.0, 0.001)
	var h := ReasoningSim.Policy.new().setup(ReasonCommands.data()["problemas"])
	ReasoningSim.grpo(h, 40, 8, 0.5, 42, false)
	assert_almost_eq(ReasoningSim.hack_rate(h), 1.0, 0.001)
	assert_almost_eq(h.accuracy(), 0.0, 0.001)
