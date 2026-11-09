extends TestCase
## Tests de la ruta de estudio externo: coherencia con el temario, desbloqueo y comando lecturas.

var game: DojoGame
var mentor: Array[String] = []


func before_each() -> void:
	game = DojoGame.new("")
	mentor.clear()
	game.runner.mentor_message.connect(func(t: String, _k: String) -> void: mentor.append(t))


func _done(ids: Array) -> void:
	for m: String in ids:
		game.progress.data["missions"][m] = {"completed": true}


func test_referencias_y_requisitos_existen() -> void:
	var ids := game.catalog.ids()
	for u: Dictionary in game.study.units:
		assert_true(game.catalog.get_mission(u["id"] + "-01").is_empty(), "%s no debe tener misión" % u["id"])
		for r: String in u["refs"]:
			assert_true(game.study.refs.has(r), "%s: falta la referencia %s" % [u["id"], r])
		for m: String in u["unlock"]["missions"] + u["recommended_before"]:
			assert_true(m in ids, "%s: no existe la misión %s" % [u["id"], m])
		for s: String in u["unlock"]["studies"]:
			assert_false(game.study.unit(s).is_empty(), "%s: no existe el estudio %s" % [u["id"], s])


func test_todas_las_lecturas_de_misiones_existen() -> void:
	for m: Dictionary in game.catalog.missions:
		for r: String in m.get("further_reading", []):
			assert_true(game.study.refs.has(r), "%s: falta la referencia %s" % [m["id"], r])


func test_orden_del_temario() -> void:
	assert_eq(game.study.status(game.progress, "O1"), "bloqueada")
	_done(["A1-04"])
	assert_eq(game.study.status(game.progress, "O1"), "disponible")
	assert_eq(game.study.status(game.progress, "O4"), "bloqueada", "O4 va después de O1")
	assert_false(game.shell.execute("lecturas hecho O4").ok)
	assert_true(game.shell.execute("lecturas hecho O1").ok)
	assert_eq(game.study.status(game.progress, "O4"), "disponible")
	assert_eq(game.study.status(game.progress, "C4"), "bloqueada", "C4 va después de A5")
	_done(["A4-03"])
	assert_true(game.shell.execute("lecturas hecho A5").ok)
	assert_eq(game.study.status(game.progress, "C4"), "disponible")


func test_comando_lecturas() -> void:
	var r := game.shell.execute("lecturas")
	assert_true(r.ok)
	assert_true(r.plain_text().contains("O3"))
	r = game.shell.execute("lecturas O3")
	assert_true(r.plain_text().contains("Antes completa"), "bloqueada: no enseña enlaces todavía")
	_done(["A3-03"])
	r = game.shell.execute("lecturas o3")
	assert_true(r.plain_text().contains("https://atlas.mitre.org/"))
	assert_true(r.plain_text().contains("Se estudia después de: A3-03"))
	r = game.shell.execute("lecturas C1-01")
	assert_true(r.plain_text().contains("OWASP Top 10 for Agentic"))
	assert_true(game.shell.execute("lecturas copiar ref.cvss-4").plain_text().contains("first.org"))
	assert_false(game.shell.execute("lecturas nada").ok)


func test_avisos_al_terminar_y_al_empezar() -> void:
	_done(["T0-01"])
	game.progress.data["missions"]["A3-02"] = {"completed": true}
	assert_eq(game.start_mission("A3-03"), "")
	game.runner._finish(false)
	assert_true(mentor.any(func(t: String) -> bool: return t.contains("Desbloqueado en la ruta de estudio externo: O3")))
	assert_true(mentor.any(func(t: String) -> bool: return t.contains("lecturas A3-03")))
	_done(["A4-03", "A6-03", "O6-03", "C1-02", "C2-02", "C3-02"])
	mentor.clear()
	assert_eq(game.start_mission("C5-01"), "")
	assert_true(mentor.any(func(t: String) -> bool: return t.contains("se recomienda estudiar") and t.contains("O1") and t.contains("C4")))
