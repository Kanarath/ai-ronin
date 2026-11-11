extends TestCase
## Repaso espaciado y perfil de competencias.

var game: DojoGame


func before_each() -> void:
	game = DojoGame.new("")
	LearnCommands.now_override = 1_800_000_000


func after_each() -> void:
	LearnCommands.now_override = 0


func test_sin_misiones_no_hay_repaso() -> void:
	assert_true(game.shell.execute("repaso").plain_text().contains("Aún no hay nada que repasar"))


func test_repaso_espaciado_sube_de_caja_y_se_aleja() -> void:
	game.progress.data["missions"]["T1-01"] = {"completed": true}
	var total := LearnCommands.pool(game).size()
	assert_true(total >= 2, "T1-01 tiene preguntas de comprensión")
	var r := game.shell.execute("repaso")
	assert_true(r.plain_text().contains("Repaso · T1-01"), r.plain_text())
	var key: String = game.get_meta("repaso_actual")
	var o: Dictionary = {}
	for it: Dictionary in LearnCommands.pool(game):
		if it["key"] == key:
			o = it["objective"]
	var right := str(o["validator"]["expected"])
	r = game.shell.execute("repaso " + right)
	assert_true(r.plain_text().contains("Correcto"), r.plain_text())
	assert_eq(game.progress.data["repaso"][key]["caja"], 1)
	assert_eq(LearnCommands.due(game).size(), total - 1, "la acertada ya no toca hoy")
	LearnCommands.now_override += LearnCommands.DAY + 1
	assert_eq(LearnCommands.due(game).size(), total, "al día siguiente vuelve a tocar")


func test_fallo_vuelve_a_la_caja_cero_y_explica() -> void:
	game.progress.data["missions"]["T1-01"] = {"completed": true}
	game.shell.execute("repaso")
	var key: String = game.get_meta("repaso_actual")
	var o: Dictionary = {}
	for it: Dictionary in LearnCommands.pool(game):
		if it["key"] == key:
			o = it["objective"]
	var wrong := ""
	for ch: Dictionary in o["choices"]:
		if ch["id"] != o["validator"]["expected"]:
			wrong = ch["id"]
	var r := game.shell.execute("repaso " + wrong)
	assert_true(r.plain_text().contains("No es esa"), r.plain_text())
	assert_eq(game.progress.data["repaso"][key]["caja"], 0)
	assert_true(game.shell.execute("repaso estado").plain_text().contains("caja 0"))


func test_perfil_cuenta_competencias() -> void:
	var r := game.shell.execute("perfil")
	assert_true(r.ok)
	assert_true(r.plain_text().contains("por aprender"), r.plain_text())
	game.progress.data["competencies"]["T1.explorar-datos"] = {"state": "dominada", "score": 100}
	assert_true(game.shell.execute("perfil").plain_text().contains("1 dominadas"), game.shell.execute("perfil").plain_text())


func test_todos_los_ejemplos_de_la_zona_libre_se_ejecutan() -> void:
	var ex := PyCommands.examples()
	assert_true(ex.size() >= 10)
	for e: Dictionary in ex:
		var res: Dictionary = PyInterpreter.new().run(e["codigo"])
		assert_true(res["ok"], "%s: %s" % [e["id"], str(res.get("error", ""))])
		assert_false(res["output"].is_empty(), e["id"] + " imprime algo")


func test_py_ejemplo_abre_el_editor_y_guarda() -> void:
	var r := game.shell.execute("py ejemplo listas")
	assert_eq(r.action, "py_open")
	assert_true(game.py_code.contains("durezas"))
	assert_eq(game.py_exercise_id, "libre-listas")
	assert_false(game.shell.execute("py ejemplo nada").ok)
