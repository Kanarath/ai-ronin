extends TestCase
## Tests de logros, rangos, retos rápidos y del tutorial T0.

var game: DojoGame
var unlocked: Array[String] = []
var levels: Array[int] = []


func before_each() -> void:
	game = DojoGame.new("")
	unlocked.clear()
	levels.clear()
	game.achievement_unlocked.connect(func(a: Dictionary) -> void: unlocked.append(a["id"]))
	game.level_up.connect(func(lv: int, _rk: Dictionary) -> void: levels.append(lv))


func _answer_challenge() -> void:
	var ch := game.new_challenge()
	var expected: Variant = ch["expected"]
	var text := String(expected) if expected is String else str(expected)
	assert_true(game.shell.execute("reto responder " + text).ok)


func test_logros_por_eventos() -> void:
	game.shell.execute("help")
	assert_has(unlocked, "primer-corte")
	assert_true(game.achievements.is_unlocked("primer-corte"))


func test_logro_icaro() -> void:
	game.shell.world.load_dataset("temple.csv", "temple", "")
	game.shell.execute("regress create r --lr 0.03")
	game.shell.execute("regress train r temple --x minutos_enfriado --y dureza_hrc")
	assert_has(unlocked, "icaro")


func test_rangos() -> void:
	assert_eq(game.progress.rank()["name"], "Initiate")
	game.progress.data["xp"] = Progress.new().xp_for_level(5)
	assert_eq(game.progress.level(), 5)
	assert_eq(game.progress.rank()["name"], "Engineer")


func test_retos_generan_y_puntuan() -> void:
	var bank := ChallengeBank.new(7)
	for i in 40:
		var c := bank.generate(PackedStringArray(["T1", "T2", "T3", "T4", "T5", "T6"]))
		assert_true(c.has("question") and c.has("expected") and c.has("explanation"), str(c))
		var raw := String(c["expected"]) if c["expected"] is String else str(c["expected"])
		assert_true(ConditionEval.answer_matches(c, raw), "la respuesta esperada debe validar: %s" % c["question"])
	var xp_before := game.progress.xp()
	_answer_challenge()
	assert_eq(game.progress.xp(), xp_before + DojoGame.CHALLENGE_XP)


func test_reto_fallido_da_menos_xp() -> void:
	game.new_challenge()
	game.shell.execute("reto responder 999999")
	var ch := game.current_challenge
	var raw := String(ch["expected"]) if ch["expected"] is String else str(ch["expected"])
	var before := game.progress.xp()
	game.shell.execute("reto responder " + raw)
	assert_eq(game.progress.xp(), before + DojoGame.CHALLENGE_XP / 2)


func test_subida_de_nivel() -> void:
	game.progress.data["xp"] = 45
	_answer_challenge()
	assert_has(levels, 2)


func test_tutorial_T0_completo() -> void:
	assert_eq(game.catalog.errors.size(), 0, "\n".join(game.catalog.errors))
	assert_eq(game.start_mission("T0-01"), "")
	for l in ["help", "hint", "explain dataset", "plot katanas", "dataset list", "answer 240"]:
		game.shell.execute(l)
	assert_eq(game.runner.index, 5)
	_answer_challenge()
	game.shell.execute("logros")
	assert_eq(game.runner.phase, "done")
	assert_true(game.progress.is_mission_completed("T0-01"))
	assert_has(unlocked, "sin-muletas" if game.runner.result()["max_hint_main"] == 0 else "primer-corte")
