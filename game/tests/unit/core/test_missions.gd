extends TestCase
## Tests del motor de misiones: validadores, recorrido completo de las 3 misiones,
## pistas, hipótesis, diagnósticos, progreso y guardado.

var game: DojoGame
var mentor: Array[Dictionary] = []
var finished: Array[Dictionary] = []


func before_each() -> void:
	game = DojoGame.new("")  # sin fichero de guardado
	mentor.clear()
	finished.clear()
	game.runner.mentor_message.connect(func(t: String, k: String) -> void: mentor.append({"text": t, "kind": k}))
	game.mission_completed.connect(func(_m: Dictionary, r: Dictionary, xp: int) -> void:
		var copy := r.duplicate()
		copy["xp"] = xp
		finished.append(copy))


func run(lines: Array) -> void:
	for l: String in lines:
		var r := game.shell.execute(l)
		if not r.ok:
			fail("'%s' → %s" % [l, r.plain_text()])


const PY_RANGO := "def rango(valores):\n    return max(valores) - min(valores)\n"
const PY_DISTANCIA := "import math\n\ndef distancia(a, b):\n    suma = 0\n    for x, y in zip(a, b):\n        suma += (x - y) ** 2\n    return math.sqrt(suma)\n"
const PY_NORMALIZAR := "def normalizar(valor, minimo, maximo):\n    return (valor - minimo) / (maximo - minimo)\n"


## Paso de Python de una misión: abre el editor, escribe la solución y la comprueba.
func solve_py(code: String) -> void:
	run(["py"])
	game.py_code = code
	run(["py check"])


func mentor_said(fragment: String) -> bool:
	for m in mentor:
		if m["text"].contains(fragment):
			return true
	return false


# ── Evaluador ────────────────────────────────────────────────────────────────

func test_condiciones_basicas() -> void:
	var ev: Array[Dictionary] = [
		{"name": "a", "seq": 1, "data": {"k": 3, "ds": "katanas_train"}},
		{"name": "b", "seq": 2, "data": {"acc": 0.75}},
	]
	assert_true(ConditionEval.evaluate({"type": "event", "event": "a", "where": {"k": {"gte": 3}, "ds": {"ends_with": "_train"}}}, ev))
	assert_false(ConditionEval.evaluate({"type": "event", "event": "a", "where": {"k": 1}}, ev))
	assert_true(ConditionEval.evaluate({"type": "sequence", "steps": [{"type": "event", "event": "a"}, {"type": "event", "event": "b"}]}, ev))
	assert_false(ConditionEval.evaluate({"type": "sequence", "steps": [{"type": "event", "event": "b"}, {"type": "event", "event": "a"}]}, ev))
	assert_false(ConditionEval.evaluate({"type": "event", "event": "a"}, ev, 1), "min_seq excluye eventos antiguos")


func test_respuestas_numericas_con_tolerancia_y_coma() -> void:
	var spec := {"type": "answer", "expected": 0.25, "tolerance": 0.01}
	assert_true(ConditionEval.answer_matches(spec, "0.25"))
	assert_true(ConditionEval.answer_matches(spec, "0,255"))
	assert_true(ConditionEval.answer_matches({"expected": 99.8, "tolerance": 0.15}, "99.8 %"))
	assert_false(ConditionEval.answer_matches(spec, "0.3"))
	assert_false(ConditionEval.answer_matches(spec, "hola"))


func test_catalogo_sin_errores() -> void:
	assert_eq(game.catalog.errors.size(), 0, "\n".join(game.catalog.errors))
	for id in ["T1-01", "T1-02", "T2-01", "T3-01", "T3-02"]:
		assert_has(game.catalog.ids(), id)


func test_catalogo_detecta_mision_mal_formada() -> void:
	var p := MissionCatalog.validate({"id": "X", "title": "x", "unit": "T", "difficulty": 1, "briefing": "", "competencies": {}, "debrief": {},
		"objectives": [{"id": "o1", "text": "t", "hints": ["h"], "validator": {"type": "magia"}}]})
	assert_eq(p.size(), 1)


# ── Recorridos completos ─────────────────────────────────────────────────────

func test_mision_T1_01_completa_con_prueba() -> void:
	assert_eq(game.start_mission("T1-01"), "")
	run(["dataset list", "dataset inspect katanas", "answer b", "dataset stats katanas", "answer 8.75"])
	run(["plot katanas", "hipotesis temperatura_temple", "plot katanas --x dureza_hrc --y flexibilidad", "plot katanas --x temperatura_temple --y dureza_hrc"])
	run(["answer b"])
	solve_py(PY_RANGO)
	assert_eq(game.runner.phase, "trial")
	run(["answer 51.7"])
	assert_eq(finished.size(), 1)
	assert_true(finished[0]["trial_passed"])
	assert_eq(finished[0]["score"], 100)
	assert_eq(game.progress.competency_state("T1.explorar-datos"), "dominada")
	assert_eq(game.mission_status("T1-01"), "dominada")


func test_la_leccion_llega_antes_que_el_objetivo() -> void:
	game.start_mission("T1-01")
	var lesson_at := -1
	var objective_at := -1
	for i in mentor.size():
		if mentor[i]["kind"] == "lesson" and mentor[i]["text"].contains("Los comandos de datos"):
			lesson_at = i
		if mentor[i]["text"].begins_with("Tu turno (1/"):
			objective_at = i
	assert_true(lesson_at != -1, "hay lección para el primer objetivo")
	assert_true(lesson_at < objective_at, "primero se enseña, después se pide")


func test_sin_lecciones_en_la_prueba_de_dominio() -> void:
	game.start_mission("T1-01")
	run(["dataset list", "dataset inspect katanas", "answer b", "dataset stats katanas", "answer 8.75", "hipotesis temperatura_temple", "plot katanas", "plot katanas --x temperatura_temple"])
	run(["answer b"])
	mentor.clear()
	solve_py(PY_RANGO)
	assert_eq(game.runner.phase, "trial")
	for m in mentor:
		assert_ne(m["kind"], "lesson")


func test_hipotesis_obligatoria_antes_de_ejecutar() -> void:
	game.start_mission("T1-01")
	run(["dataset list", "dataset inspect katanas", "answer b", "dataset stats katanas", "answer 8.75"])
	run(["plot katanas", "plot katanas --x temperatura_temple"])
	assert_eq(game.runner.index, 5, "sin hipótesis no se completa")
	assert_true(mentor_said("registra tu predicción"))
	run(["hipotesis flexibilidad", "plot katanas", "plot katanas --x temperatura_temple"])
	assert_eq(game.runner.index, 6, "con hipótesis y acción posterior, sí")


func test_hipotesis_valida_opciones() -> void:
	game.start_mission("T1-01")
	run(["dataset list", "dataset inspect katanas", "answer b", "dataset stats katanas", "answer 8.75"])
	assert_false(game.shell.execute("hipotesis color").ok)


func test_mision_bloqueada_hasta_completar_requisito() -> void:
	assert_ne(game.start_mission("T1-02"), "")
	assert_eq(game.mission_status("T1-02"), "bloqueada")


func test_mision_T1_02_completa() -> void:
	game.progress.data["missions"]["T1-01"] = {"completed": true}
	assert_eq(game.start_mission("T1-02"), "")
	run(["hipotesis temperatura_temple", "distance katanas hoja-001 hoja-002", "answer b"])
	run(["dataset normalize katanas --method minmax"])
	run(["hipotesis no", "distance katanas_minmax hoja-001 hoja-002", "answer a"])
	solve_py(PY_DISTANCIA)
	assert_eq(game.runner.phase, "trial")
	run(["dataset normalize katanas --method zscore", "distance katanas_zscore hoja-010 hoja-020", "answer 2.82"])
	assert_eq(finished.size(), 1)
	assert_true(finished[0]["trial_passed"])


func test_mision_T2_01_completa_con_error_productivo_y_diagnostico() -> void:
	game.progress.data["missions"]["T1-03"] = {"completed": true}
	assert_eq(game.start_mission("T2-01"), "")
	run(["dataset normalize katanas --method minmax", "model create m1 --k 1", "model train m1 katanas_minmax"])
	run(["hipotesis 100%", "model evaluate m1 katanas_minmax"])
	run(["model predict m1 katanas_minmax hoja-001", "answer 0"])
	# Error típico: normalizar el test con sus propios parámetros → diagnóstico del mentor.
	run(["dataset split katanas --test 0.3 --seed 42", "dataset normalize katanas_test --method minmax --as te_mal"])
	assert_true(mentor_said("aprendido los parámetros de normalización del TEST"))
	assert_eq(game.runner.index, 3)
	run(["dataset normalize katanas_train --method minmax --as tr", "dataset normalize katanas_test --method minmax --fit katanas_train --as te"])
	run(["model create m2 --k 1", "model train m2 tr", "model evaluate m2 te"])
	assert_eq(game.runner.index, 4, "evaluación honesta completada")
	var ev: Array = game.shell.events_named("model.evaluated")
	assert_almost_eq(ev[-1]["data"]["accuracy"], 0.75, 0.001)
	run(["hipotesis 9", "model sweep --train tr --test te", "answer 0.25"])
	run(["answer c"])
	solve_py(PY_VOTAR)
	assert_eq(game.runner.phase, "trial")
	run(["dataset split katanas --test 0.25 --seed 7", "dataset normalize katanas_train --method zscore --as tr7",
		"dataset normalize katanas_test --method zscore --fit katanas_train --as te7", "model create m9 --k 9", "model train m9 tr7", "model evaluate m9 te7", "answer 0.883"])
	assert_eq(finished.size(), 1)
	assert_true(finished[0]["trial_passed"])
	assert_eq(game.progress.competency_state("T2.overfitting"), "dominada")


func test_mision_T3_01_completa() -> void:
	game.progress.data["missions"]["T2-02"] = {"completed": true}
	assert_eq(game.start_mission("T3-01"), "")
	var xy := " --x minutos_enfriado --y dureza_hrc"
	run(["plot temple" + xy])
	run(["hipotesis no", "regress create r1 --lr 0.001", "regress train r1 temple" + xy + " --epochs 100", "answer 435.8"])
	run(["hipotesis diverge", "regress create r2 --lr 0.03", "regress train r2 temple" + xy + " --epochs 100"])
	assert_true(game.shell.events_named("regress.trained")[-1]["data"]["diverged"])
	run(["regress create r3 --lr 0.02", "regress train r3 temple" + xy + " --epochs 500"])
	assert_eq(game.runner.index, 5, "lr 0.02 en 500 épocas cumple el reto")
	run(["hipotesis menos de 10", "dataset normalize temple --method zscore --only minutos_enfriado --as tz",
		"regress create r4 --lr 0.5", "regress train r4 tz" + xy + " --epochs 20", "answer b"])
	solve_py(PY_PASO)
	assert_eq(game.runner.phase, "trial")
	run(["regress info r4", "dataset stats temple", "answer 1.51"])
	assert_eq(finished.size(), 1)
	assert_true(finished[0]["trial_passed"])


func test_T3_01_diagnostico_de_lr_lento() -> void:
	game.progress.data["missions"]["T2-02"] = {"completed": true}
	game.start_mission("T3-01")
	var xy := " --x minutos_enfriado --y dureza_hrc"
	run(["plot temple" + xy, "hipotesis no", "regress create r1 --lr 0.001", "regress train r1 temple" + xy + " --epochs 100", "answer 435.8",
		"hipotesis diverge", "regress create r2 --lr 0.03", "regress train r2 temple" + xy])
	run(["regress create r3 --lr 0.005", "regress train r3 temple" + xy + " --epochs 500"])
	assert_eq(game.runner.index, 4, "lr 0.005 no llega en 500 épocas")
	assert_true(mentor_said("Converge, pero no llega"))


func test_mision_T3_02_completa() -> void:
	game.progress.data["missions"]["T3-01"] = {"completed": true}
	assert_eq(game.start_mission("T3-02"), "")
	run(["dataset split katanas --test 0.3 --seed 42", "dataset normalize katanas_train --as tr",
		"dataset normalize katanas_test --fit katanas_train --as te", "model create m --k 9", "model train m tr"])
	run(["metrics m te --positive defectuosa", "answer b", "answer 4"])
	run(["hipotesis sube recall y baja precision", "metrics m te --positive defectuosa --threshold 0.3"])
	run(["metrics curve m te --positive defectuosa", "answer 0.222", "answer 27"])
	run(["answer c"])
	solve_py(PY_RECALL)
	assert_eq(game.runner.phase, "trial")
	run(["model create m15 --k 15", "model train m15 tr", "metrics curve m15 te --positive defectuosa", "answer 0.531"])
	assert_eq(finished.size(), 1)
	assert_true(finished[0]["trial_passed"])


func test_mision_T4_01_completa() -> void:
	game.progress.data["missions"]["T3-03"] = {"completed": true}
	assert_eq(game.start_mission("T4-01"), "")
	run(["nn create n --hidden 0", "nn forward n 1,1", "answer 0.313", "answer b"])
	run(["hipotesis sí", "nn train n puerta_and --epochs 2000"])
	run(["nn create o --hidden 0", "nn set o w2_0 10", "nn set o w2_1 10", "nn set o b2 -5", "nn evaluate o puerta_or"])
	assert_eq(game.runner.index, 5, "OR programado a mano")
	solve_py(PY_NEURONA)
	run(["hipotesis no", "nn create x --hidden 0", "nn train x puerta_xor --epochs 3000", "answer 0.693", "answer c"])
	assert_eq(game.runner.phase, "trial")
	run(["nn create nd --hidden 0", "nn set nd w2_0 -10", "nn set nd w2_1 -10", "nn set nd b2 15", "nn evaluate nd puerta_nand"])
	assert_eq(finished.size(), 1)
	assert_true(finished[0]["trial_passed"])


func test_mision_T4_02_completa() -> void:
	game.progress.data["missions"]["T4-01"] = {"completed": true}
	assert_eq(game.start_mission("T4-02"), "")
	run(["hipotesis sí", "nn create red --hidden 2 --lr 1 --seed 1", "nn train red puerta_xor --epochs 3000"])
	run(["nn forward red 0,0", "nn forward red 0,1", "nn forward red 1,0", "nn forward red 1,1", "answer and", "answer c"])
	solve_py(PY_CAPA)
	run(["hipotesis se queda atascada", "nn create r5 --hidden 2 --lr 1 --seed 5", "nn train r5 puerta_xor --epochs 3000"])
	run(["nn create r5b --hidden 4 --lr 1 --seed 5", "nn train r5b puerta_xor --epochs 3000"])
	assert_eq(game.runner.index, 6)
	run(["dataset split katanas --test 0.3 --seed 42", "dataset normalize katanas_train --as tr", "dataset normalize katanas_test --fit katanas_train --as te",
		"nn create n0 --inputs 3 --hidden 0 --lr 1", "nn train n0 tr --epochs 3000 --positive defectuosa", "nn evaluate n0 te",
		"nn create n8 --inputs 3 --hidden 8 --lr 1 --seed 1", "nn train n8 tr --epochs 3000 --positive defectuosa", "nn evaluate n8 te", "answer 0.861"])
	run(["answer b"])
	assert_eq(game.runner.phase, "trial")
	run(["nn create n4 --inputs 3 --hidden 4 --lr 1 --seed 2", "nn train n4 tr --epochs 3000 --positive defectuosa", "nn evaluate n4 te", "answer 0.847"])
	assert_eq(finished.size(), 1)
	assert_true(finished[0]["trial_passed"])


func test_mision_T5_01_completa() -> void:
	game.progress.data["missions"]["T4-03"] = {"completed": true}
	assert_eq(game.start_mission("T5-01"), "")
	run(["tokenizer train t0 --merges 0", "tokenize t0 la katana del maestro", "answer 22"])
	run(["hipotesis unos 4", "tokenizer train t200 --merges 200", "tokenize t200 la katana del maestro", "answer 4"])
	run(["answer a"])
	run(["hipotesis más tokens", "tokenize t200 La Katana del Maestro", "answer 9"])
	run(["hipotesis unos 20", "tokenize t200 the sword of the master", "answer 19"])
	run(["answer c"])
	solve_py(PY_TOKENIZAR)
	assert_eq(game.runner.phase, "trial")
	run(["tokenize t200 katanaforjada", "answer 4"])
	assert_eq(finished.size(), 1)
	assert_true(finished[0]["trial_passed"])


func test_mision_T5_02_completa() -> void:
	game.progress.data["missions"]["T5-01"] = {"completed": true}
	assert_eq(game.start_mission("T5-02"), "")
	run(["embed show katana", "embed similar katana", "answer espada"])
	run(["hipotesis cerca de −1", "embed compare fuego hielo", "answer -1"])
	run(["answer c"])
	run(["hipotesis maestra", "embed analogy maestro hombre mujer"])
	run(["embed similar aprendiz", "embed show aprendiz", "answer femenino"])
	run(["embed plot --x persona --y femenino"])
	run(["answer b"])
	solve_py(PY_COSENO)
	assert_eq(game.runner.phase, "trial")
	run(["embed similar katana --metric euclidean", "answer lanza"])
	assert_eq(finished.size(), 1)
	assert_true(finished[0]["trial_passed"])


func test_mision_T6_01_completa() -> void:
	game.progress.data["missions"]["T5-03"] = {"completed": true}
	assert_eq(game.start_mission("T6-01"), "")
	run(["lm train lm2 --order 2", "lm next lm2 la", "answer forja"])
	run(["hipotesis se concentra en el más probable", "lm next lm2 la --temperature 0.1", "answer 0.824"])
	run(["hipotesis se repite en bucle", "lm generate lm2 el maestro --temperature 0 --tokens 12"])
	run(["lm generate lm2 el maestro --temperature 1 --seed 1", "lm generate lm2 el maestro --temperature 1 --seed 2"])
	run(["answer c"])
	run(["lm next lm2 la --top-p 0.5", "answer 3"])
	run(["hipotesis trozos copiados del corpus", "lm train lm3 --order 3", "lm generate lm3 el maestro --temperature 1 --seed 1 --tokens 15"])
	run(["answer b"])
	solve_py(PY_SOFTMAX)
	assert_eq(game.runner.phase, "trial")
	run(["lm next lm2 la --temperature 2", "answer 0.124"])
	assert_eq(finished.size(), 1)
	assert_true(finished[0]["trial_passed"])


func test_mision_T6_02_completa() -> void:
	game.progress.data["missions"]["T5-02"] = {"completed": true}
	game.progress.data["missions"]["T6-01"] = {"completed": true}
	assert_eq(game.start_mission("T6-02"), "")
	run(["attention herrera martillo katana fuego agua", "answer martillo"])
	run(["answer c"])
	run(["hipotesis solo a sí misma", "attention herrera martillo katana fuego agua --causal", "answer 1"])
	run(["hipotesis más extremos (más concentrados)", "attention herrera martillo katana fuego agua --no-scale"])
	run(["attention katana espada daga lanza arco escudo acero hierro fuego agua", "answer 100"])
	run(["answer b"])
	solve_py(PY_ATENCION)
	assert_eq(game.runner.phase, "trial")
	run(["attention herrera martillo katana --causal", "answer 0.31"])
	assert_eq(finished.size(), 1)
	assert_true(finished[0]["trial_passed"])


# ── Pistas y maestría ────────────────────────────────────────────────────────

func test_escalera_de_pistas_y_confirmacion_nivel_5() -> void:
	game.progress.data["missions"]["T1-03"] = {"completed": true}
	game.start_mission("T2-01")
	run(["dataset normalize katanas --method minmax", "model create m1 --k 1", "model train m1 katanas_minmax", "hipotesis 100%", "model evaluate m1 katanas_minmax", "model predict m1 katanas_minmax hoja-001", "answer 0"])
	for i in 4:
		assert_true(game.runner.request_hint(false)["ok"])
	var r5 := game.runner.request_hint(false)
	assert_false(r5["ok"], "el nivel 5 exige confirmación")
	assert_true(game.runner.request_hint(true)["ok"])
	assert_eq(game.runner.result()["max_hint_main"], 5)
	assert_eq(game.runner.result()["score"], 40)


func test_prueba_de_dominio_limita_pistas() -> void:
	game.start_mission("T1-01")
	run(["dataset list", "dataset inspect katanas", "answer b", "dataset stats katanas", "answer 8.75", "hipotesis temperatura_temple", "plot katanas", "plot katanas --x temperatura_temple", "answer b"])
	solve_py(PY_RANGO)
	assert_eq(game.runner.phase, "trial")
	assert_true(game.runner.request_hint(false)["ok"])
	assert_true(game.runner.request_hint(false)["ok"])
	assert_false(game.runner.request_hint(false)["ok"], "en la prueba, máximo nivel 2")


func test_respuesta_incorrecta_da_feedback() -> void:
	game.start_mission("T1-01")
	run(["dataset list", "dataset inspect katanas", "answer b", "dataset stats katanas", "answer 13.6"])
	assert_true(mentor_said("Divide el rango"))
	assert_eq(game.runner.index, 4)


func test_pregunta_de_comprobacion_explica_cada_respuesta() -> void:
	game.start_mission("T1-01")
	run(["dataset list", "dataset inspect katanas"])
	assert_true(mentor_said("a) una feature"), "las opciones se muestran con el objetivo")
	run(["answer a"])
	assert_true(mentor_said("La calidad no se mide"), "la respuesta incorrecta explica por qué")
	assert_eq(game.runner.index, 2)
	run(["answer b"])
	assert_eq(game.runner.index, 3)


func test_repetir_mision_da_menos_xp() -> void:
	var full := ["dataset list", "dataset inspect katanas", "answer b", "dataset stats katanas", "answer 8.75", "hipotesis temperatura_temple", "plot katanas", "plot katanas --x temperatura_temple", "answer b"]
	game.start_mission("T1-01")
	run(full)
	solve_py(PY_RANGO)
	run(["answer 51.7"])
	game.start_mission("T1-01")
	run(full)
	solve_py(PY_RANGO)
	run(["answer 51.7"])
	assert_eq(finished.size(), 2)
	assert_eq(finished[1]["xp"], int(round(finished[0]["xp"] * Progress.REPLAY_XP_FACTOR)))


# ── Guardado ─────────────────────────────────────────────────────────────────

func test_guardado_atomico_y_recuperacion_de_backup() -> void:
	var path := "user://test_save.json"
	for p in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	assert_eq(SaveStore.save(path, {"xp": 10}), OK)
	assert_eq(SaveStore.save(path, {"xp": 20}), OK)
	assert_eq(SaveStore.read(path)["data"]["xp"], 20)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{ corrupto")
	f.close()
	var loaded := SaveStore.read(path)
	assert_eq(loaded["source"], "backup")
	assert_eq(loaded["data"]["xp"], 10)
	for p in [path, path + ".bak"]:
		DirAccess.remove_absolute(p)


func test_progreso_persiste_entre_sesiones() -> void:
	var path := "user://test_progress.json"
	for p in [path, path + ".bak"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	var g1 := DojoGame.new(path)
	g1.start_mission("T1-01")
	for l in ["dataset list", "dataset inspect katanas", "answer b", "dataset stats katanas", "answer 8.75", "hipotesis temperatura_temple", "plot katanas", "plot katanas --x temperatura_temple", "answer b", "py"]:
		g1.shell.execute(l)
	g1.py_code = PY_RANGO
	g1.shell.execute("py check")
	g1.shell.execute("answer 51.7")
	var g2 := DojoGame.new(path)
	assert_true(g2.progress.is_mission_completed("T1-01"))
	assert_true(g2.progress.xp() > 0)
	assert_eq(g2.mission_status("T1-02"), "disponible")
	for p in [path, path + ".bak"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func test_mision_T1_03_aplicada_completa() -> void:
	game.progress.data["missions"]["T1-02"] = {"completed": true}
	assert_eq(game.start_mission("T1-03"), "")
	run(["dataset inspect mensajes", "answer a"])
	run(["hipotesis imperativos", "plot mensajes --x longitud --y imperativos", "plot mensajes --x signos --y longitud"])
	run(["hipotesis msg-002", "distance mensajes msg-080 msg-001", "distance mensajes msg-080 msg-002", "answer b"])
	run(["hipotesis msg-001", "dataset normalize mensajes --method minmax", "distance mensajes_minmax msg-080 msg-001", "distance mensajes_minmax msg-080 msg-002"])
	run(["answer a"])
	solve_py(PY_NORMALIZAR)
	assert_eq(finished.size(), 1)
	assert_true(mentor_said("Qué puedes hacer ya"), "el cierre dice qué sabes hacer ya")


func test_para_que_antes_del_primer_paso() -> void:
	game.start_mission("T1-01")
	var purpose_at := -1
	var task_at := -1
	for i in mentor.size():
		if mentor[i]["text"].begins_with("¿Para qué sirve esto?"):
			purpose_at = i
		if task_at == -1 and mentor[i]["text"].begins_with("Tu turno (1/"):
			task_at = i
	assert_true(purpose_at != -1, "la misión explica para qué sirve")
	assert_true(purpose_at < task_at, "el para qué va antes del primer paso")


func test_hipotesis_acepta_el_principio_de_la_opcion() -> void:
	game.progress.data["missions"]["T1-02"] = {"completed": true}
	game.start_mission("T1-03")
	run(["dataset inspect mensajes", "answer a", "hipotesis imperativos", "plot mensajes --x longitud --y imperativos", "plot mensajes --x signos --y longitud"])
	var r := game.shell.execute("hipotesis msg-001")
	assert_true(r.ok, r.plain_text())
	assert_true(r.plain_text().contains("msg-001 (ataque)"))
	assert_false(game.shell.execute("hipotesis msg").ok, "ambigua: encaja con las dos opciones")


func test_mapa_marca_donde_estas() -> void:
	var r := game.shell.execute("mapa")
	assert_true(r.ok, r.plain_text())
	assert_true(r.plain_text().contains("T0"))
	assert_true(r.plain_text().contains("◀ estás aquí"))
	assert_true(r.plain_text().contains("RAG (Retrieval-Augmented Generation)"), "las siglas se explican")


func test_paso_de_python_comprueba_la_funcion() -> void:
	game.start_mission("T1-01")
	run(["dataset list", "dataset inspect katanas", "answer b", "dataset stats katanas", "answer 8.75",
		"hipotesis temperatura_temple", "plot katanas", "plot katanas --x temperatura_temple", "answer b"])
	run(["py"])
	assert_true(game.py_code.contains("def rango"), "el editor se abre con el código inicial")
	assert_eq(game.shell.execute("py run").ok, true)
	run(["py check"])
	assert_eq(game.runner.phase, "main", "con el código inicial no pasa")
	game.py_code = "def rango(valores):\n    return max(valores) - min(valores)\nprint(rango([1, 5]))\n"
	var r := game.shell.execute("py run")
	assert_true(r.plain_text().contains("4"), r.plain_text())
	run(["py check"])
	assert_eq(game.runner.phase, "trial", "con la función correcta se pasa a la prueba de dominio")
	assert_eq(game.progress.data["py_code"]["T1-01-rango"], game.py_code, "el código se guarda")


func test_python_errores_con_linea() -> void:
	game.py_code = "x = 1\nprint(y)\n"
	var r := game.shell.execute("py run")
	assert_true(r.plain_text().contains("NameError"), r.plain_text())
	assert_true(r.plain_text().contains("línea 2"), r.plain_text())


# --- T2/T3 ---

const PY_VOTAR := "def votar(etiquetas):\n    conteo = {}\n    for e in etiquetas:\n        conteo[e] = conteo.get(e, 0) + 1\n    return max(conteo, key=lambda e: conteo[e])\n"
const PY_ACCURACY := "def accuracy(reales, predichas):\n    aciertos = 0\n    for r, p in zip(reales, predichas):\n        if r == p:\n            aciertos = aciertos + 1\n    return aciertos / len(reales)\n"
const PY_PASO := "def paso(w, lr):\n    gradiente = 2 * (w - 3)\n    return w - lr * gradiente\n"
const PY_RECALL := "def precision(tp, fp):\n    return tp / (tp + fp)\n\ndef recall(tp, fn):\n    return tp / (tp + fn)\n"
const PY_COSTE := "def coste(fp, fn, coste_fp, coste_fn):\n    return fp * coste_fp + fn * coste_fn\n"
const PETICIONES_HONESTO := ["dataset split peticiones --test 0.3 --seed 42", "dataset normalize peticiones_train --method minmax --as tr",
	"dataset normalize peticiones_test --method minmax --fit peticiones_train --as te"]


func test_T2_T3_cadena_de_requisitos() -> void:
	var chain := {"T2-01": "T1-03", "T2-02": "T2-01", "T3-01": "T2-02", "T3-02": "T3-01", "T3-03": "T3-02", "T4-01": "T3-03"}
	for id: String in chain:
		assert_has(game.catalog.ids(), id)
		assert_eq(game.catalog.get_mission(id)["requires_missions"], [chain[id]], id)
	assert_eq(game.mission_status("T2-02"), "bloqueada")
	game.progress.data["missions"]["T2-01"] = {"completed": true}
	assert_eq(game.mission_status("T2-02"), "disponible")


## Cada paso de Python de T2/T3: el código inicial se ejecuta pero NO pasa; la solución de referencia sí.
func test_T2_T3_python_inicial_falla_y_solucion_pasa() -> void:
	var solutions := {"T2-01": PY_VOTAR, "T2-02": PY_ACCURACY, "T3-01": PY_PASO, "T3-02": PY_RECALL, "T3-03": PY_COSTE}
	for id: String in solutions:
		var ex := {}
		for o: Dictionary in game.catalog.get_mission(id)["objectives"]:
			if o.has("py_exercise"):
				ex = o["py_exercise"]
		assert_false(ex.is_empty(), "%s tiene paso de Python" % id)
		var spec := PyCommands._int_spec(ex)
		var bad: Dictionary = PyExercise.check(ex["starter"], spec)
		assert_true(bad.get("ok", false), "%s: el código inicial se ejecuta" % id)
		assert_true(int(bad.get("passed", 0)) < int(bad.get("total", 0)), "%s: el código inicial no debe pasar" % id)
		var good: Dictionary = PyExercise.check(solutions[id], spec)
		assert_eq(int(good.get("passed", -1)), int(good.get("total", -2)), "%s: la solución pasa todos los casos · %s" % [id, str(good)])


func test_mision_T2_02_aplicada_completa() -> void:
	game.progress.data["missions"]["T2-01"] = {"completed": true}
	assert_eq(game.start_mission("T2-02"), "")
	assert_true(mentor_said("¿Para qué sirve esto?"))
	run(["dataset inspect peticiones", "answer a"])
	assert_true(mentor_said("Es la trampa de T2-01"), "la opción incorrecta explica por qué")
	run(["answer b"])
	run(PETICIONES_HONESTO)
	run(["model create d --k 5", "model train d tr", "model evaluate d te"])
	assert_eq(game.runner.index, 3, "detector evaluado de forma honesta")
	var ev: Array = game.shell.events_named("model.evaluated")
	assert_almost_eq(ev[-1]["data"]["accuracy"], 0.889, 0.001)
	run(["answer 3"])
	run(["hipotesis normal", "model predict d te cli-041"])
	var pred: Array = game.shell.events_named("model.predicted")
	assert_eq(pred[-1]["data"]["label"], "normal", "cli-041 se escapa")
	assert_eq(pred[-1]["data"]["truth"], "abuso")
	run(["answer b", "answer 0.722"])
	solve_py(PY_ACCURACY)
	assert_eq(finished.size(), 1)
	assert_true(mentor_said("Qué puedes hacer ya"))


func test_T2_02_diagnostico_de_fuga() -> void:
	game.progress.data["missions"]["T2-01"] = {"completed": true}
	game.start_mission("T2-02")
	run(["dataset inspect peticiones", "answer b", "dataset split peticiones --test 0.3 --seed 42", "dataset normalize peticiones_test --as te_mal"])
	assert_true(mentor_said("parámetros de normalización del TEST"))
	assert_eq(game.runner.index, 2)


func test_mision_T3_03_aplicada_completa() -> void:
	game.progress.data["missions"]["T3-02"] = {"completed": true}
	assert_eq(game.start_mission("T3-03"), "")
	run(PETICIONES_HONESTO)
	run(["model create d --k 9", "model train d tr"])
	assert_eq(game.runner.index, 1)
	run(["metrics d te --positive abuso"])
	var m: Dictionary = game.shell.events_named("metrics.computed")[-1]["data"]
	assert_eq([m["fp"], m["fn"]], [0, 3])
	assert_almost_eq(m["recall"], 0.7, 0.001)
	run(["answer a"])
	assert_true(mentor_said("Eso es un falso negativo"))
	run(["answer b", "hipotesis aumentan", "metrics curve d te --positive abuso"])
	var pts: Array = game.shell.events_named("metrics.curve")[-1]["data"]["points"]
	# Los números que cita la misión: umbrales 2/9, 3/9 y 5/9 (índices 1, 2 y 4).
	assert_eq([pts[1]["fp"], pts[1]["fn"]], [9, 0])
	assert_eq([pts[2]["fp"], pts[2]["fn"]], [3, 1])
	assert_eq([pts[4]["fp"], pts[4]["fn"]], [0, 3])
	solve_py(PY_COSTE)
	run(["answer c", "answer b"])
	assert_eq(finished.size(), 1)
	assert_true(mentor_said("Qué puedes hacer ya"))


# --- T4 ---

const PY_NEURONA := "import math

def neurona(a, b, w1, w2, bias):
    z = w1 * a + w2 * b + bias
    return 1 / (1 + math.exp(-z))
"
const PY_CAPA := "import math

def sigmoide(z):
    return 1 / (1 + math.exp(-z))

def capa(entradas, pesos, sesgos):
    salidas = []
    for w, b in zip(pesos, sesgos):
        z = b
        for wi, xi in zip(w, entradas):
            z = z + wi * xi
        salidas.append(sigmoide(z))
    return salidas
"
const PY_PELIGROSA := "def peligrosa(origen, destino):
    return abs(origen - destino) > 0.4
"


## Ejercicio de Python de un objetivo de una misión del catálogo.
func py_exercise_of(mission_id: String, objective_id: String) -> Dictionary:
	for o: Dictionary in game.catalog.get_mission(mission_id).get("objectives", []):
		if o["id"] == objective_id:
			return o.get("py_exercise", {})
	return {}


func test_T4_python_solucion_pasa_y_codigo_inicial_no() -> void:
	for spec in [["T4-01", "py1", PY_NEURONA], ["T4-02", "py1", PY_CAPA], ["T4-03", "py1", PY_PELIGROSA]]:
		var ex := py_exercise_of(spec[0], spec[1])
		assert_false(ex.is_empty(), "%s tiene ejercicio de Python" % spec[0])
		var ok: Dictionary = PyExercise.check(spec[2], PyCommands._int_spec(ex))
		assert_eq(ok["passed"], ok["total"], "%s: la solución pasa todos los casos" % spec[0])
		var starter: Dictionary = PyExercise.check(ex["starter"], PyCommands._int_spec(ex))
		assert_true(starter["ok"], "%s: el código inicial se ejecuta" % spec[0])
		assert_true(starter["passed"] < starter["total"], "%s: el código inicial no pasa" % spec[0])


func test_T4_misiones_con_para_que_y_cierre() -> void:
	for id in ["T4-01", "T4-02", "T4-03"]:
		var m := game.catalog.get_mission(id)
		assert_true(m.has("purpose"), id + " explica para qué sirve")
		assert_true(m.has("you_can_now"), id + " dice qué puedes hacer ya")
		var has_choices := false
		for o: Dictionary in m["objectives"]:
			assert_ne(o["validator"].get("type"), "reflection", id + ": sin reflexiones escritas")
			if o.has("teach"):
				assert_true(o["teach"].contains("Por qué:"), "%s/%s: la lección conecta con la IA real" % [id, o["id"]])
			if o.has("choices"):
				has_choices = true
		assert_true(has_choices, id + " tiene al menos una comprobación con opciones")


func test_mision_T4_03_aplicada_completa() -> void:
	game.progress.data["missions"]["T4-02"] = {"completed": true}
	assert_eq(game.start_mission("T4-03"), "")
	run(["dataset inspect llamadas"])
	run(["hipotesis en dos esquinas opuestas", "plot llamadas --x confianza_origen --y confianza_destino", "answer b"])
	run(["hipotesis no", "nn create n1 --hidden 0", "nn train n1 llamadas --epochs 2000 --positive peligrosa"])
	assert_almost_eq(game.shell.events_named("nn.trained")[-1]["data"]["accuracy"], 0.5, 0.001, "una neurona sola no separa la forma de XOR")
	run(["nn create red --hidden 4 --lr 1 --seed 1", "nn train red llamadas --epochs 3000 --positive peligrosa"])
	assert_eq(game.runner.index, 5, "la red con capa oculta acierta todas las llamadas")
	run(["nn forward red 0.9,0.1", "nn forward red 0.1,0.9"])
	assert_true(game.shell.execute("nn forward red 0.9,0.1").plain_text().contains("oculta 2: z = 4.81·0.9 + -8.379·0.1 + -0.621 = 2.87  →  sigmoid(z) = 0.946"), "los números citados en la misión")
	run(["answer c", "nn weights red", "answer a"])
	solve_py(PY_PELIGROSA)
	run(["answer b"])
	assert_eq(finished.size(), 1)
	assert_true(mentor_said("Qué puedes hacer ya"))


func test_T4_03_respuesta_incorrecta_explica_por_que() -> void:
	game.progress.data["missions"]["T4-02"] = {"completed": true}
	game.start_mission("T4-03")
	run(["dataset inspect llamadas", "hipotesis en dos esquinas opuestas", "plot llamadas --x confianza_origen --y confianza_destino", "answer a"])
	assert_true(mentor_said("AND solo da 1 en una esquina"))
	assert_eq(game.runner.index, 2)


func test_T4_03_bloquea_T5_01() -> void:
	game.progress.data["missions"]["T4-02"] = {"completed": true}
	assert_eq(game.mission_status("T4-03"), "disponible")
	assert_eq(game.mission_status("T5-01"), "bloqueada", "T5-01 exige la misión aplicada")
	game.progress.data["missions"]["T4-03"] = {"completed": true}
	assert_ne(game.mission_status("T5-01"), "bloqueada")


# --- T5/T6 ---

const PY_TOKENIZAR := "def tokenizar(texto):\n    return texto.split()\n"
const PY_COSENO := "import math\n\ndef coseno(a, b):\n    punto = 0\n    for x, y in zip(a, b):\n        punto += x * y\n    norma_a = math.sqrt(sum([x * x for x in a]))\n    norma_b = math.sqrt(sum([y * y for y in b]))\n    return punto / (norma_a * norma_b)\n"
const PY_SOFTMAX := "import math\n\ndef softmax(puntuaciones):\n    exps = [math.exp(s) for s in puntuaciones]\n    total = sum(exps)\n    return [e / total for e in exps]\n"
const PY_ATENCION := "import math\n\ndef softmax(puntuaciones):\n    exps = [math.exp(s) for s in puntuaciones]\n    total = sum(exps)\n    return [e / total for e in exps]\n\ndef pesos_atencion(q, claves):\n    puntuaciones = []\n    for k in claves:\n        punto = sum([x * y for x, y in zip(q, k)])\n        puntuaciones.append(punto / math.sqrt(len(q)))\n    return softmax(puntuaciones)\n"
const PY_FILTRO := "def filtro(texto, prohibidas):\n    palabras = texto.lower().split()\n    for p in palabras:\n        if p in prohibidas:\n            return True\n    return False\n"
const PY_DILUCION := "import math\n\ndef peso_oculto(s_oculta, s_relleno, n):\n    e_oculta = math.exp(s_oculta)\n    e_relleno = math.exp(s_relleno)\n    total = e_oculta + n * e_relleno\n    return e_oculta / total\n"


## Ejercicio de Python (py1) de una misión, tal como lo corrige py check.
func _py_spec(mission_id: String) -> Dictionary:
	for o: Dictionary in game.catalog.get_mission(mission_id)["objectives"]:
		if o.has("py_exercise"):
			return PyCommands._int_spec(o["py_exercise"])
	return {}


func test_T5_T6_soluciones_pasan_y_codigo_inicial_no() -> void:
	var sols := {"T5-01": PY_TOKENIZAR, "T5-02": PY_COSENO, "T5-03": PY_FILTRO, "T6-01": PY_SOFTMAX, "T6-02": PY_ATENCION, "T6-03": PY_DILUCION}
	for id: String in sols:
		var spec := _py_spec(id)
		assert_false(spec.is_empty(), "%s tiene paso de Python" % id)
		var ok := PyExercise.check(sols[id], spec)
		assert_eq(ok["passed"], ok["total"], "%s: la solución pasa todos los casos" % id)
		var start := PyExercise.check(spec["starter"], spec)
		assert_true(start["ok"], "%s: el código inicial se ejecuta sin errores" % id)
		assert_true(start["passed"] < start["total"], "%s: el código inicial NO pasa" % id)
		# El print de prueba del código inicial tampoco debe fallar con la solución puesta.
		assert_true(PyInterpreter.new().run(sols[id], 200000)["ok"])


func test_T5_T6_cada_mision_tiene_para_que_comprobacion_y_cierre() -> void:
	for id in ["T5-01", "T5-02", "T5-03", "T6-01", "T6-02", "T6-03"]:
		var m := game.catalog.get_mission(id)
		assert_true(m.has("purpose") and m.has("you_can_now"), id)
		var checks := 0
		for o: Dictionary in m["objectives"]:
			assert_ne(o["validator"]["type"], "reflection", "%s/%s: sin reflexiones escritas" % [id, o["id"]])
			if o.has("choices"):
				checks += 1
			if o.has("teach"):
				assert_true(o["teach"].contains("Por qué:"), "%s/%s: teach con «Por qué:»" % [id, o["id"]])
		assert_true(checks >= 1, "%s: al menos una comprobación" % id)


func test_mision_T5_03_aplicada_completa() -> void:
	assert_ne(game.start_mission("T5-03"), "", "bloqueada sin T5-02")
	game.progress.data["missions"]["T5-02"] = {"completed": true}
	assert_eq(game.start_mission("T5-03"), "")
	run(["tokenizer train t200 --merges 200", "tokenize t200 quiero una katana", "answer 93"])
	run(["hipotesis no", "tokenize t200 quiero una KATANA"])
	run(["answer c"])
	assert_true(mentor_said("entiende «KATANA» perfectamente"), "la opción incorrecta explica por qué")
	run(["answer b"])
	run(["hipotesis unos 6", "tokenize t200 quiero una k a t a n a"])
	run(["embed compare katana espada", "answer 0.999"])
	run(["embed compare katana martillo", "answer 0.602"])
	run(["answer a"])
	assert_eq(game.runner.index, 7)
	solve_py(PY_FILTRO)
	assert_eq(finished.size(), 1)
	assert_true(mentor_said("Qué puedes hacer ya"))
	assert_eq(game.mission_status("T6-01"), "disponible", "T6-01 se abre tras la aplicada")


func test_T6_01_requiere_la_aplicada_T5_03() -> void:
	game.progress.data["missions"]["T5-02"] = {"completed": true}
	assert_ne(game.start_mission("T6-01"), "")
	assert_eq(game.mission_status("T6-01"), "bloqueada")


func test_mision_T6_03_aplicada_completa() -> void:
	assert_ne(game.start_mission("T6-03"), "", "bloqueada sin T6-02")
	game.progress.data["missions"]["T6-02"] = {"completed": true}
	assert_eq(game.start_mission("T6-03"), "")
	run(["attention katana espada fuego agua hielo brasa horno", "answer 0.22"])
	run(["hipotesis se queda igual", "attention katana fuego agua hielo brasa horno espada", "answer 0.22"])
	run(["answer b"])
	run(["hipotesis sí", "attention fuego agua hielo brasa horno espada katana --causal", "answer 0.22"])
	run(["answer a"])
	assert_true(mentor_said("la distancia no cambia el peso"), "la opción incorrecta explica por qué")
	run(["answer c", "answer a"])
	assert_eq(game.runner.index, 6)
	solve_py(PY_DILUCION)
	assert_eq(finished.size(), 1)
	assert_true(mentor_said("Qué puedes hacer ya"))


# --- A3/A4/A6 ---

func test_A3_A4_A6_siguen_el_patron_del_piloto() -> void:
	for id in ["A3-01", "A3-02", "A3-03", "A3-04", "A4-01", "A4-02", "A4-03", "A4-04", "A6-01", "A6-02", "A6-03", "A6-04"]:
		var m := game.catalog.get_mission(id)
		assert_true(m.has("purpose") and m.has("you_can_now"), id + ": purpose y you_can_now")
		var checks := 0
		for o: Dictionary in m["objectives"]:
			var where := "%s %s" % [id, o["id"]]
			assert_true(o.has("teach"), where + ": tiene lección")
			var lines: PackedStringArray = str(o.get("teach", "")).split("\n")
			assert_true(lines[-1].begins_with("Por qué:"), where + ": la lección acaba en «Por qué:»")
			assert_ne(o["validator"]["type"], "reflection", where + ": sin reflexiones escritas")
			if o.has("choices"):
				checks += 1
				for c: Dictionary in o["choices"]:
					if str(c["id"]) != str(o["validator"]["expected"]):
						assert_false(str(c.get("why", "")).is_empty(), where + ": cada opción incorrecta explica por qué")
		assert_true(checks >= 1, id + ": al menos una comprobación de comprensión")


# --- O/C/E ---

const MISIONES_OCE := ["O5-01", "O5-02", "O5-03", "O6-01", "O6-02", "O6-03", "C1-01", "C1-02", "C2-01", "C2-02", "C3-01", "C3-02",
	"C5-01", "C5-02", "C5-03", "E1-01", "E1-02", "E1-03", "E2-01", "E2-02", "E2-03", "E3-01", "E3-02", "E3-03", "E4-01", "E4-02", "E4-03"]


func test_OCE_sin_reflexiones_escritas_y_con_el_patron() -> void:
	for id: String in MISIONES_OCE:
		var m := game.catalog.get_mission(id)
		assert_false(m.is_empty(), id)
		assert_true(m.has("purpose") and m.has("you_can_now"), "%s: purpose y you_can_now" % id)
		var objs: Array = m["objectives"].duplicate()
		objs.append_array(m.get("mastery_trial", {}).get("objectives", []))
		var checks := 0
		for o: Dictionary in objs:
			assert_false(ConditionEval.contains_type(o["validator"], "reflection"), "%s %s: sin reflexiones escritas" % [id, o["id"]])
			assert_false(str(o["text"]).to_lower().contains("reflexion"), "%s %s: el texto no pide reflexion" % [id, o["id"]])
			assert_false(str(o.get("teach", "")).to_lower().contains("reflexi"), "%s %s: la lección no habla de reflexiones" % [id, o["id"]])
			if not o.get("choices", []).is_empty():
				checks += 1
				var letters: Array = o["choices"].map(func(c: Dictionary) -> String: return c["id"])
				assert_has(letters, o["validator"]["expected"], "%s %s: la respuesta es una de las opciones" % [id, o["id"]])
				for c: Dictionary in o["choices"]:
					if c["id"] != o["validator"]["expected"]:
						assert_false(str(c.get("why", "")).is_empty(), "%s %s %s: opción incorrecta sin why" % [id, o["id"], c["id"]])
		assert_true(checks >= 1, "%s: al menos una comprobación" % id)
