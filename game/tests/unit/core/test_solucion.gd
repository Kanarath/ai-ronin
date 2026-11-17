extends TestCase
## Red de seguridad contra callejones sin salida: reveal_solution (comando `solucion`). Pide
## confirmación y, tras ella, muestra la solución completa del objetivo (órdenes y respuesta).

var runner: MissionRunner


func before_each() -> void:
	runner = MissionRunner.new()


func _mision(objs: Array) -> Dictionary:
	return {"id": "TEST", "mentor_intro": "x", "objectives": objs}


func test_pide_confirmacion_y_luego_revela_la_respuesta() -> void:
	runner.start(_mision([
		{"id": "o1", "text": "t", "validator": {"type": "answer", "expected": 0.25, "tolerance": 0.01}, "hints": ["una pista"]},
	]), 0)
	var aviso := runner.reveal_solution(false)
	assert_false(aviso["ok"], "primero pide confirmación")
	assert_true(String(aviso["text"]).contains("solucion ok"), aviso["text"])
	var sol := runner.reveal_solution(true)
	assert_true(sol["ok"])
	assert_true(String(sol["text"]).contains("answer 0.25"), sol["text"])


func test_usa_el_campo_solution_si_existe() -> void:
	runner.start(_mision([
		{"id": "o1", "text": "t", "validator": {"type": "answer", "expected": 0.25},
		"hints": ["x"], "solution": ["dataset split katanas --test 0.3 --seed 42", "answer 0.25"]},
	]), 0)
	var sol := runner.reveal_solution(true)
	assert_true(String(sol["text"]).contains("dataset split katanas"), sol["text"])
	assert_true(String(sol["text"]).contains("answer 0.25"), sol["text"])


func test_revela_la_letra_en_preguntas_de_opcion() -> void:
	runner.start(_mision([
		{"id": "o1", "text": "t", "validator": {"type": "answer", "expected": "c", "accept": ["c"]}, "hints": ["x"]},
	]), 0)
	assert_true(String(runner.reveal_solution(true)["text"]).contains("answer c"))


func test_al_agotar_las_pistas_se_apunta_a_solucion() -> void:
	runner.start(_mision([
		{"id": "o1", "text": "t", "validator": {"type": "answer", "expected": 1}, "hints": ["única pista"]},
	]), 0)
	assert_true(runner.request_hint(false)["ok"], "usa la única pista")
	var no_hay := runner.request_hint(false)
	assert_false(no_hay["ok"], "ya no hay más pistas")
	assert_true(String(no_hay["text"]).contains("solucion"), no_hay["text"])


func test_ningun_objetivo_del_juego_puede_dejar_sin_salida() -> void:
	# Recorre TODAS las misiones (y sus pruebas de dominio): cada objetivo debe tener guía, y cada
	# pregunta de tipo answer debe poder revelar su respuesta. Así la red de seguridad está probada
	# en todo el juego, no solo donde la miramos a mano.
	var catalog := MissionCatalog.load_default()
	var fallos := PackedStringArray()
	for m: Dictionary in catalog.missions:
		var objs: Array = m.get("objectives", []).duplicate()
		objs.append_array(m.get("mastery_trial", {}).get("objectives", []))
		for obj: Dictionary in objs:
			var oid := "%s/%s" % [m.get("id", "?"), obj.get("id", "?")]
			if obj.get("hints", []).is_empty() and not obj.has("solution"):
				fallos.append("%s: sin pistas ni solución" % oid)
			var v: Dictionary = obj.get("validator", {})
			if ConditionEval.contains_type(v, "answer") and runner._expected_answer(v) == "":
				fallos.append("%s: answer sin valor revelable" % oid)
	assert_true(fallos.is_empty(), "\n".join(fallos))


func test_el_comando_no_muestra_la_solucion_dos_veces() -> void:
	# El comando `solucion ok` debe mostrar la solución UNA vez (reveal_solution ya la emite; el
	# comando no debe volver a emitirla). Antes salía repetida.
	var g := DojoGame.new("")
	g.runner.start(_mision([
		{"id": "o1", "text": "t", "validator": {"type": "answer", "expected": 0.25}, "hints": ["una"]},
	]), 0)
	var veces := [0]
	g.runner.mentor_message.connect(func(t: String, _k: String) -> void:
		if t.contains("Solución completa"):
			veces[0] += 1)
	g.shell.execute("solucion ok")
	assert_eq(veces[0], 1, "la solución debe mostrarse una sola vez")


func test_revelar_la_solucion_deja_la_maxima_ayuda() -> void:
	runner.start(_mision([
		{"id": "o1", "text": "t", "validator": {"type": "answer", "expected": 1}, "hints": ["x"]},
	]), 0)
	runner.reveal_solution(true)
	# Nivel de ayuda máximo (5), como el ejemplo resuelto: la competencia quedará «practicada».
	assert_eq(int(runner.hint_levels[runner.objective_key()]), 5)
