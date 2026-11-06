class_name TestCase
extends RefCounted
## Clase base de todos los tests de AI RONIN.
##
## Uso:
##   extends TestCase
##   func test_algo() -> void:
##       assert_eq(1 + 1, 2)
##
## Cada método cuyo nombre empiece por "test_" es un test independiente.
## El runner (tests/run_tests.gd) crea UNA instancia nueva por cada test,
## llama a before_each(), al test y a after_each(), y después lee get_failures().

var _failures: Array[String] = []


## Se ejecuta antes de cada test. Sobrescríbelo para preparar datos.
func before_each() -> void:
	pass


## Se ejecuta después de cada test. Sobrescríbelo para limpiar.
func after_each() -> void:
	pass


func get_failures() -> Array[String]:
	return _failures


func assert_true(condition: bool, message: String = "") -> void:
	if not condition:
		_fail("se esperaba true", message)


func assert_false(condition: bool, message: String = "") -> void:
	if condition:
		_fail("se esperaba false", message)


## Igualdad estricta. Acepta int frente a float (1 == 1.0), pero no tipos
## incompatibles como String frente a int, que se consideran distintos.
func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if not _same_value(actual, expected):
		_fail("se esperaba <%s> pero se obtuvo <%s>" % [str(expected), str(actual)], message)


func assert_ne(actual: Variant, unexpected: Variant, message: String = "") -> void:
	if _same_value(actual, unexpected):
		_fail("no se esperaba <%s>" % str(unexpected), message)


## Comparación de floats con tolerancia. Imprescindible en ML: 0.1 + 0.2 != 0.3.
func assert_almost_eq(actual: float, expected: float, tolerance: float = 1e-6, message: String = "") -> void:
	if absf(actual - expected) > tolerance:
		_fail("se esperaba %s ± %s pero se obtuvo %s" % [expected, tolerance, actual], message)


func assert_has(collection: Variant, item: Variant, message: String = "") -> void:
	var found := false
	if collection is Array or collection is Dictionary or collection is String:
		found = collection.has(item)
	if not found:
		_fail("<%s> no contiene <%s>" % [str(collection), str(item)], message)


func fail(message: String) -> void:
	_fail("fallo explícito", message)


func _same_value(a: Variant, b: Variant) -> bool:
	var numeric := [TYPE_INT, TYPE_FLOAT]
	var ta := typeof(a)
	var tb := typeof(b)
	if ta != tb and not (ta in numeric and tb in numeric):
		return false
	return a == b


func _fail(reason: String, message: String) -> void:
	var text := reason if message.is_empty() else "%s — %s" % [reason, message]
	_failures.append(text)
