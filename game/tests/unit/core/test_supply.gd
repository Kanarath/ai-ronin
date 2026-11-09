extends TestCase
## Tests del arco A6: pipeline de ML simulado, cadena de suministro, controles y misiones.

var game: DojoGame
var finished: Array[Dictionary] = []


func before_each() -> void:
	game = DojoGame.new("")
	finished.clear()
	game.mission_completed.connect(func(_m: Dictionary, r: Dictionary, _xp: int) -> void: finished.append(r))


func run(lines: Array) -> void:
	for l: String in lines:
		var r := game.shell.execute(l)
		if not r.ok:
			fail("'%s' → %s" % [l, r.plain_text()])


func _last(event_name: String) -> Dictionary:
	return game.shell.events_named(event_name)[-1]["data"]


func test_huellas_reales() -> void:
	var p := MockMlPipeline.create("t")
	assert_eq(MockMlPipeline.digest("abc"), "ba7816bf8f01", "SHA-256 de «abc»")
	var adapter := p.component("adaptador-estilo")
	assert_ne(MockMlPipeline.digest(adapter["content"]), p.manifest["adaptador-estilo"])
	var model := p.component("clasificador-acero")
	assert_eq(MockMlPipeline.digest(model["content"]), p.manifest["clasificador-acero"])


func test_firma_no_es_seguridad() -> void:
	var p := MockMlPipeline.create("t")
	p.defenses["artifact-signing"] = true
	var res := p.load_artifact("detector-grietas")
	assert_true(res["loaded"], "firmado por una clave de confianza: la firma pasa")
	assert_true(res["code_exec"], "pero sigue siendo un pickle con código")
	assert_false(p.load_artifact("adaptador-estilo")["loaded"])


func test_safetensors_no_evita_pesos_manipulados() -> void:
	var p := MockMlPipeline.create("t")
	p.defenses["safe-formats"] = true
	var res := p.load_artifact("adaptador-estilo")
	assert_true(res["loaded"])
	assert_true(res["tampered"])
	assert_false(res["code_exec"])


func test_convertir_solo_lo_interno() -> void:
	var p := MockMlPipeline.create("t")
	assert_true(p.convert_artifact("detector-grietas").begins_with("Rechazado"))
	assert_eq(p.convert_artifact("clasificador-acero"), "")
	p.defenses["safe-formats"] = true
	p.defenses["artifact-signing"] = true
	assert_true(p.clone_fresh().load_artifact("clasificador-acero")["loaded"])


func test_matriz_de_defensas() -> void:
	var expected := {"ninguna": 7, "data-provenance": 6, "safe-formats": 6, "artifact-signing": 6, "dependency-scan": 6,
		"segmentation": 6, "non-root": 6, "secret-scan": 6}
	for d: String in expected:
		run(["supply forja a"])
		if d != "ninguna":
			run(["supply defend a %s on" % d])
		run(["supply attack a", "supply eval a"])
		assert_eq(_last("supply.attacks")["successes"], expected[d], "control " + d)
		assert_eq(_last("supply.eval")["pass_rate"], 0.75 if d == "safe-formats" else 1.0, "eval con " + d)
	run(["supply forja z"])
	for d in MockMlPipeline.DEFENSES:
		run(["supply defend z %s on" % d])
	run(["supply attack z", "supply eval z"])
	assert_eq(_last("supply.attacks")["successes"], 0)
	assert_eq(_last("supply.eval")["pass_rate"], 0.75)
	run(["supply convert z clasificador-acero", "supply eval z"])
	assert_eq(_last("supply.eval")["pass_rate"], 1.0)


func test_comandos() -> void:
	run(["supply forja t", "supply sbom t", "supply inspect t detector-grietas", "supply inspect t espejo-comunidad",
		"supply inspect t forja-metricas-pro", "supply train t", "supply deploy t", "supply probe t"])
	assert_eq(_last("supply.sbom")["pickles"], 2)
	assert_true(_last("supply.probed")["secret_found"])
	assert_eq(_last("supply.trained")["backdoor_rate"], 0.97)
	var r := game.shell.execute("supply load t numpy")
	assert_false(r.ok)
	r = game.shell.execute("supply install t inventado")
	assert_false(r.ok)
	r = game.shell.execute("supply sbom nada")
	assert_false(r.ok)


const R40 := "reflexion la firma dice quien publico el artefacto y si ha cambiado pero no si se ejecuta al cargarlo el formato seguro evita que se ejecute codigo pero no garantiza que los pesos sean los buenos y la procedencia de los datos evita la puerta trasera por eso hacen falta los tres controles"


func test_mision_A6_01() -> void:
	game.progress.data["missions"]["A3-01"] = {"completed": true}
	assert_eq(game.start_mission("A6-01"), "")
	run(["supply forja taller", "supply sbom taller", "answer 2"])
	assert_eq(game.runner.index, 1)
	run(["supply inspect taller clasificador-acero", "supply inspect taller detector-grietas", "answer detector-grietas"])
	run(["supply train taller", "answer 0,94"])
	assert_eq(game.runner.index, 3)
	run(["supply load taller clasificador-acero", "supply install taller forja-metrics", "supply deploy taller", "answer root"])
	run([R40])
	assert_eq(game.runner.phase, "trial")
	run(["supply forja t2", "supply sbom t2", "supply train t2", "supply load t2 clasificador-acero", "supply deploy t2"])
	assert_eq(finished.size(), 1)
	assert_true(finished[0]["trial_passed"])


func test_mision_A6_02() -> void:
	game.progress.data["missions"]["A6-01"] = {"completed": true}
	assert_eq(game.start_mission("A6-02"), "")
	run(["hipotesis aprenderá la regla del atacante", "supply forja taller", "supply inspect taller espejo-comunidad", "supply train taller", "answer 0,97"])
	assert_eq(game.runner.index, 1)
	run(["supply load taller detector-grietas", "answer builtins.exec"])
	run(["supply load taller adaptador-estilo", "answer no"])
	run(["supply inspect taller forja-metricas-pro", "supply install taller forja-metricas-pro"])
	run(["supply probe taller", "answer tok_registro_forja_7c1e"])
	assert_eq(game.runner.index, 5)
	run(["supply attack taller", "answer 7"])
	run(["informe nuevo Adapter manipulado del hub público aceptado sin verificar su huella", "informe campo severidad alta", "informe campo owasp LLM03",
		"informe campo componente adapter adaptador-estilo del hub público lora-labs", "informe campo descripcion el adapter cargado no coincide con la huella firmada",
		"informe campo pasos 1) supply forja taller 2) supply inspect taller adaptador-estilo 3) supply load taller adaptador-estilo",
		"informe campo impacto el modelo da por buenas piezas con grietas de temple", "informe campo evidencia la huella actual difiere de la firmada por lora-labs",
		"informe campo mitigacion verificar firma y huella de cada artefacto antes de cargarlo", "informe campo verificacion la batería A6 tiene 7 de 7 éxitos sin controles",
		"informe revisar", R40])
	assert_eq(game.runner.phase, "trial")
	run(["supply forja t2", "supply load t2 adaptador-estilo", "supply load t2 detector-grietas"])
	assert_eq(finished.size(), 1)
	assert_true(finished[0]["trial_passed"])


func test_mision_A6_03() -> void:
	game.progress.data["missions"]["A6-02"] = {"completed": true}
	assert_eq(game.start_mission("A6-03"), "")
	run(["supply forja taller", "supply attack taller"])
	run(["hipotesis se carga y se ejecuta", "supply defend taller artifact-signing on", "supply load taller detector-grietas", "answer sí"])
	assert_eq(game.runner.index, 2)
	run(["supply defend taller artifact-signing off", "supply defend taller safe-formats on", "supply eval taller", "answer 0,75"])
	run(["supply convert taller detector-grietas", "supply convert taller clasificador-acero"])
	assert_eq(game.runner.index, 4)
	var lines: Array = []
	for d in MockMlPipeline.DEFENSES:
		lines.append("supply defend taller %s on" % d)
	run(lines + ["supply attack taller", "supply eval taller", R40])
	assert_eq(game.runner.phase, "trial")
	lines = ["supply forja z", "supply convert z clasificador-acero"]
	for d in MockMlPipeline.DEFENSES:
		lines.append("supply defend z %s on" % d)
	run(lines + ["supply attack z", "supply eval z"])
	assert_eq(finished.size(), 1)
	assert_true(finished[0]["trial_passed"])
