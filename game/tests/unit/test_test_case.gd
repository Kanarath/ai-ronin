extends TestCase
## Tests de la propia clase TestCase: ¿detectan bien los asserts un fallo?
## Creamos una instancia «víctima» y comprobamos sus fallos registrados.


func test_assert_eq_acepta_valores_iguales() -> void:
	var t := TestCase.new()
	t.assert_eq(3, 3)
	t.assert_eq("katana", "katana")
	t.assert_eq(1, 1.0)
	assert_eq(t.get_failures().size(), 0)


func test_assert_eq_detecta_valores_distintos() -> void:
	var t := TestCase.new()
	t.assert_eq(3, 4)
	assert_eq(t.get_failures().size(), 1)


func test_assert_eq_no_mezcla_tipos_incompatibles() -> void:
	var t := TestCase.new()
	t.assert_eq("1", 1)
	assert_eq(t.get_failures().size(), 1)


func test_assert_almost_eq_usa_tolerancia() -> void:
	var t := TestCase.new()
	t.assert_almost_eq(0.1 + 0.2, 0.3)
	assert_eq(t.get_failures().size(), 0, "0.1 + 0.2 debería estar cerca de 0.3")
	t.assert_almost_eq(0.5, 0.3)
	assert_eq(t.get_failures().size(), 1)


func test_el_mensaje_se_incluye_en_el_fallo() -> void:
	var t := TestCase.new()
	t.assert_true(false, "pista útil")
	assert_true(t.get_failures()[0].contains("pista útil"))
