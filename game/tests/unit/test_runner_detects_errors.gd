extends TestCase
## Meta-test del runner: el ErrorCounter debe registrar errores del motor.
## (Probamos el contador directamente, sin provocar un fallo real en la suite.)


func test_error_counter_cuenta_errores() -> void:
	var counter := ErrorCounter.new()
	counter._log_error("f", "res://x.gd", 3, "ERR", "algo falló", false, 0, [])
	assert_eq(counter.snapshot(), 1)
	assert_true(counter.last_message.contains("algo falló"))


func test_assert_has_admite_packed_arrays() -> void:
	var t := TestCase.new()
	t.assert_has(PackedStringArray(["a", "b"]), "b")
	t.assert_has(PackedStringArray(["a"]), "z")
	assert_eq(t.get_failures().size(), 1)
