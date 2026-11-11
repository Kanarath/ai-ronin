extends TestCase
## Unidades nuevas (T7–T10, P1): cada misión se completa de principio a fin con los comandos reales.
## Las soluciones de referencia de los ejercicios viven SOLO aquí.

const SOLUCIONES := {
	"T7-01": "# Completa la línea marcada y compruébala con py check.\ndef predecir(nodo, fila):\n    while \"hoja\" not in nodo:\n        if fila[nodo[\"f\"]] <= nodo[\"t\"]:\n            nodo = nodo[\"izq\"]\n        else:\n            nodo = nodo[\"der\"]\n    return nodo[\"hoja\"]\n\narbol = {\"f\": 0, \"t\": 61.9, \"izq\": {\"hoja\": \"apta\"}, \"der\": {\"hoja\": \"defectuosa\"}}\nprint(predecir(arbol, [63.0, 5.0]))   # defectuosa\n",
	"T7-02": "# Completa la línea marcada y compruébala con py check.\ndef gini(etiquetas):\n    cuenta = {}\n    for e in etiquetas:\n        cuenta[e] = cuenta.get(e, 0) + 1\n    n = len(etiquetas)\n    return 1 - sum((cuenta[c] / n) ** 2 for c in cuenta)\n\nprint(gini([\"abuso\", \"abuso\", \"normal\", \"normal\"]))   # 0.5\n",
	"T7-03": "# Completa la línea marcada y compruébala con py check.\nimport math\n\ndef asignar(punto, centros):\n    mejor, mejor_d = 0, math.inf\n    for i, c in enumerate(centros):\n        d = math.sqrt(sum((x - y) ** 2 for x, y in zip(punto, c)))\n        if d < mejor_d:\n            mejor_d = d\n            mejor = i\n    return mejor\n\nprint(asignar([0.9, 0.8], [[0.1, 0.2], [0.8, 0.7]]))   # 1\n",
	"T7-04": "# Completa la línea marcada y compruébala con py check.\ndef mas_raros(distancias, n):\n    # distancias: {id: distancia al centro}\n    orden = sorted(distancias, key=lambda c: distancias[c], reverse=True)\n    return orden[:n]\n\nprint(mas_raros({\"cli-001\": 0.1, \"cli-039\": 0.98, \"cli-041\": 0.2}, 1))   # ['cli-039']\n",
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
	if game.runner.phase == "main":
		fail("%s se queda en el objetivo %d: %s" % [mid, game.runner.index, str(game.runner.current_objective().get("text", ""))])
	assert_eq(finished.size(), 1, mid + " se completa")


func test_T7_01_completa() -> void:
	_walk("T7-01", ["T3-03"], ["dataset split katanas --test 0.3 --seed 42", "tree train t2 katanas_train --depth 2", "answer a", "classic evaluate t2 katanas_test", "answer 0.806", "hipotesis empeora", "tree train t8 katanas_train --depth 8", "classic evaluate t8 katanas_test", "answer c", "PY"])


func test_T7_02_completa() -> void:
	_walk("T7-02", ["T7-01"], ["dataset split peticiones --test 0.3 --seed 42", "tree train p8 peticiones_train --depth 8", "classic evaluate p8 peticiones_test", "answer 0.889", "hipotesis sí", "forest train f peticiones_train --trees 50 --depth 6", "classic evaluate f peticiones_test", "answer b", "tree show f", "answer c", "PY"])


func test_T7_03_completa() -> void:
	_walk("T7-03", ["T7-02"], ["dataset normalize katanas --method minmax --as kn", "kmeans kn --k 2", "answer b", "hipotesis sí", "dataset normalize peticiones --method minmax --as pn", "kmeans pn --k 2", "answer 0.88", "PY", "answer c"])


func test_T7_04_completa() -> void:
	_walk("T7-04", ["T7-03"], ["dataset normalize peticiones --method minmax --as pn", "kmeans outliers pn --k 1 --top 10", "kmeans outliers pn --k 1 --top 30", "answer no", "answer b", "answer a", "PY"])


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
