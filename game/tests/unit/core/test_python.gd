extends TestCase
## Tests del intérprete de Python del Dojo (core/python): impresión idéntica a CPython,
## aritmética, slicing, funciones y cierres, errores con línea, límite de pasos,
## aislamiento, conversión de valores y corrector de ejercicios (PyExercise).
##
## Los valores esperados se han comprobado con CPython 3.13.

var py: PyInterpreter


func before_each() -> void:
	py = PyInterpreter.new()


func after_each() -> void:
	py.reset()


# ── Utilidades ───────────────────────────────────────────────────────────────

func run_ok(src: String, max_steps: int = 200000) -> PackedStringArray:
	var r := py.run(src, max_steps)
	if not r["ok"]:
		fail("el programa debería funcionar pero dio %s (línea %d): %s" % [r["error"]["type"], r["error"]["line"], r["error"]["message"]])
	return r["output"]


func expect_out(src: String, expected: Array, message: String = "") -> void:
	var got := run_ok(src)
	assert_eq(Array(got), expected, message)


## Una sola línea de salida.
func expect_line(src: String, expected: String) -> void:
	expect_out(src, [expected], src)


func expect_error(src: String, type: String, line: int, fragment: String = "") -> Dictionary:
	var r := py.run(src)
	assert_false(r["ok"], "se esperaba un %s en: %s" % [type, src])
	if r["ok"]:
		return {}
	var e: Dictionary = r["error"]
	assert_eq(e["type"], type, "tipo de error para: %s (mensaje: %s)" % [src, e["message"]])
	assert_eq(e["line"], line, "línea del error para: %s" % src)
	if not fragment.is_empty():
		assert_true(str(e["message"]).contains(fragment), "el mensaje '%s' debería contener '%s'" % [e["message"], fragment])
	return e


# ── Impresión idéntica a Python ──────────────────────────────────────────────

func test_print_numeros_como_python() -> void:
	expect_line("print(1/2)", "0.5")
	expect_line("print(2.0)", "2.0")
	expect_line("print(10/5)", "2.0")
	expect_line("print(0.1 + 0.2)", "0.30000000000000004")
	expect_line("print(1/3, 2/3)", "0.3333333333333333 0.6666666666666666")
	expect_line("print(1e16, 1e15, 1.5e-5, 0.0001, 0.00001)", "1e+16 1000000000000000.0 1.5e-05 0.0001 1e-05")
	expect_line("print(1e22, 1e-7, 123456789.0, -2.5, -0.0)", "1e+22 1e-07 123456789.0 -2.5 -0.0")
	expect_line("print(3.0 * 1.1, 0.1 * 3, 100.0)", "3.3000000000000003 0.30000000000000004 100.0")
	expect_line("print(float('inf'), -float('inf'), 2 ** 0.5)", "inf -inf 1.4142135623730951")
	expect_line("print(123456789012345680.0, 5e-324, 1.7976931348623157e308)", "1.2345678901234568e+17 5e-324 1.7976931348623157e+308")


func test_print_contenedores_como_python() -> void:
	expect_line("print([1, 'a', 2.5])", "[1, 'a', 2.5]")
	expect_line("print({'a': 1})", "{'a': 1}")
	expect_line("print(True, False, None)", "True False None")
	expect_line("print((1,), (), (1, 2), [None, True, (1, 'x')])", "(1,) () (1, 2) [None, True, (1, 'x')]")
	expect_line("print({'a': 1, 'b': [1, 2]}, {}, set(), {1})", "{'a': 1, 'b': [1, 2]} {} set() {1}")
	expect_line("print(\"it's\", 'say \"hi\"', repr(\"it's\"), repr('a\"b'), repr(\"x'y\\\"z\"))",
		"it's say \"hi\" \"it's\" 'a\"b' 'x\\'y\"z'")
	expect_line("print(repr('a\\tb\\\\c\\n'))", "'a\\tb\\\\c\\n'")
	expect_line("print(range(5), range(1, 10, 2), str([1.0, 2.50, 1e20]))", "range(0, 5) range(1, 10, 2) [1.0, 2.5, 1e+20]")
	expect_line("l = [1]\nl.append(l)\nprint(l)", "[1, [...]]")


func test_print_sep_end_y_lineas() -> void:
	expect_out("print(1, 2, 3, sep='-')\nprint('a', end='')\nprint('b', end='!\\n')\nprint()\nprint('x\\ny')",
		["1-2-3", "ab!", "", "x", "y"])
	expect_out("print('sin salto', end='')", ["sin salto"])


# ── Aritmética ───────────────────────────────────────────────────────────────

func test_division_entera_y_modulo_con_negativos() -> void:
	expect_line("print(7 // 2, -7 // 2, 7 // -2, -7 // -2)", "3 -4 -4 3")
	expect_line("print(7 % 3, -7 % 3, 7 % -3, -7 % -3)", "1 2 -2 -1")
	expect_line("print(-7.5 // 2, -7.5 % 2, 7.5 // -2, 7.5 % -2)", "-4.0 0.5 -4.0 -0.5")
	expect_line("print(divmod(-17, 5), divmod(17, -5), divmod(17.5, 5), 5 // 0.3, 5 % 0.3)", "(-4, 3) (-4, -3) (3.0, 2.5) 16.0 0.20000000000000018")
	expect_line("print(-0.0 % 5, 0 // -3, -1 % 10)", "0.0 0 9")


func test_potencias_y_division_real() -> void:
	expect_line("print(2 ** 10, 2 ** -1, -2 ** 2, (-2) ** 2, 2 ** 3 ** 2, 0 ** 0)", "1024 0.5 -4 4 512 1")
	expect_line("print(10 ** 18, 7 / 7, type(4 / 2) == float, 3 * 1.0)", "1000000000000000000 1.0 True 3.0")
	expect_line("print(True + True, True * 3, ~5, 6 & 3, 6 | 3, 6 ^ 3, 1 << 10, -16 >> 2)", "2 3 -6 2 7 5 1024 -4")


func test_potencias_de_float_exactas_como_cpython() -> void:
	# el pow() del motor falla en el último bit con exponentes enteros; el intérprete no
	expect_line("print(0.1 ** 10, 1.1 ** 2, 1.1 * 1.1, 2.5 ** -3, 0.7 ** 5)", "1.0000000000000006e-10 1.2100000000000002 1.2100000000000002 0.064 0.16806999999999994")


func test_desbordamiento_de_enteros_es_error_claro() -> void:
	expect_error("x = 2 ** 70", "OverflowError", 1, "demasiado grande")
	expect_error("x = 9223372036854775807\ny = x + 1", "OverflowError", 2)


func test_comparaciones_encadenadas_y_logica() -> void:
	expect_line("x = 5\nprint(0 <= x < 10, 0 < x < 3, 1 < 2 < 3 < 4, 3 > 2 == 2)", "True False True True")
	expect_line("print([1, 2] == [1, 2], {'a': 1} == {'a': 1}, [1] == (1,), 1 == 1.0, True == 1, [1, [2]] != [1, [3]])", "True True False True True True")
	expect_line("print(not 0, not [], [] or 'x', 0 and 1/0, 'a' and 'b', None or 0 or '')", "True True x 0 b ")
	expect_line("print(1 or 1/0, (1, 2) < (1, 3), [1, 2] < [1, 2, 0], 'abc' < 'abd', 'Z' < 'a')", "1 True True True True")
	expect_line("x = 7\nprint('grande' if x > 5 else 'pequeño', 1 if [] else 2)", "grande 2")


func test_in_y_not_in() -> void:
	expect_line("print(2 in [1, 2], 'a' in 'hola', 'k' in {'k': 1}, 1 in {'k': 1}, 3 not in (1, 2), 4 in range(0, 10, 2))", "True True True False True True")


# ── Secuencias ───────────────────────────────────────────────────────────────

func test_indices_y_slicing() -> void:
	expect_line("s = 'Hola Mundo'\nprint(s[0], s[-1], s[1:4], s[::-1], s[::2], s[-5:], s[:100], s[7:2] == '')",
		"H o ola odnuM aloH Hl ud Mundo Hola Mundo True")
	expect_line("l = list(range(10))\nprint(l[2:8:2], l[::-3], l[-3:-1], l[5:], l[:-7], l[10:], l[-100:2])",
		"[2, 4, 6] [9, 6, 3, 0] [7, 8] [5, 6, 7, 8, 9] [0, 1, 2] [] [0, 1]")
	expect_line("s = 'abcdef'\nprint(s[5:0:-1], s[5:0:-2], s[-1:-7:-1], (1, 2, 3)[::-1])", "fedcb fdb fedcba (3, 2, 1)")


func test_asignacion_por_indice_y_slice() -> void:
	expect_out("l = [0, 1, 2, 3, 4, 5]\nl[::2] = ['a', 'b', 'c']\nprint(l)\nl[1:1] = [9, 9]\nprint(l)\nl[-1] = 'z'\nprint(l)\ndel l[0]\ndel l[::2]\nprint(l)",
		["['a', 1, 'b', 3, 'c', 5]", "['a', 9, 9, 1, 'b', 3, 'c', 5]", "['a', 9, 9, 1, 'b', 3, 'c', 'z']", "[9, 'b', 'c']"])
	expect_line("d = {}\nd['k'] = 1\nd['k'] += 10\nd[(1, 2)] = 'tupla'\nprint(d, d[(1, 2)])", "{'k': 11, (1, 2): 'tupla'} tupla")


func test_comprensiones() -> void:
	expect_line("print([x * x for x in range(10) if x % 2 == 0])", "[0, 4, 16, 36, 64]")
	expect_line("print([(i, j) for i in range(3) for j in range(i)])", "[(1, 0), (2, 0), (2, 1)]")
	expect_line("print({x: x * x for x in range(4)}, sum(x for x in range(5)), sorted({c for c in 'hola'}))", "{0: 0, 1: 1, 2: 4, 3: 9} 10 ['a', 'h', 'l', 'o']")
	expect_line("m = [[1, 2, 3], [4, 5, 6]]\nprint([[r[i] for r in m] for i in range(3)], [x for r in m for x in r if x % 2])", "[[1, 4], [2, 5], [3, 6]] [1, 3, 5]")
	expect_line("x = 'fuera'\nl = [x for x in range(3)]\nprint(x)", "fuera")


# ── Sentencias ───────────────────────────────────────────────────────────────

func test_desempaquetado_de_tuplas() -> void:
	expect_out("a, b = 1, 2\na, b = b, a\nprint(a, b)\nfor i, x in enumerate(['x', 'y']):\n    print(i, x)\np, *q = [1, 2, 3]\n(m, n), o = (1, 2), 3\nprint(p, q, m, n, o)",
		["2 1", "0 x", "1 y", "1 [2, 3] 1 2 3"])
	expect_line("t = 1, 2, 3\nx, y, z = 'abc'\nprint(t, x + y + z)", "(1, 2, 3) abc")


func test_asignacion_aumentada() -> void:
	expect_out("x = 10\nx -= 3\nx *= 2\nx /= 4\nprint(x)\ny = 17\ny //= 5\nprint(y)\ns = 'ab'\ns *= 2\nl = [1]\nl += [2]\nprint(s, l)",
		["3.5", "3", "abab [1, 2]"])
	expect_line("a = [1]\nb = a\na += [2]\nprint(b)", "[1, 2]")


func test_if_elif_else_while_for() -> void:
	var src := """
def clasifica(n):
    if n < 0:
        return 'negativo'
    elif n == 0:
        return 'cero'
    else:
        return 'positivo'

print(clasifica(-3), clasifica(0), clasifica(8))
i = 0
while True:
    i += 1
    if i % 2 == 0:
        continue
    if i > 7:
        break
    print(i, end=' ')
print()
for x in range(3):
	pass
else:
    print('fin', x)
"""
	expect_out(src, ["negativo cero positivo", "1 3 5 7 ", "fin 2"])


func test_tabuladores_y_lineas_vacias() -> void:
	var src := "def f(x):\n\tif x:\n\n\t\treturn 1\n\t# comentario\n\treturn 2\n\n\nprint(f(0), f(1))  # fin\n"
	expect_line(src, "2 1")


func test_desempaquetado_con_asterisco_en_llamadas_y_literales() -> void:
	expect_out("l = [3, 1, 2]
print(*l)
print(*l, sep=', ')
print([*l, 4], (*l,), {*l} == {1, 2, 3})", ["3 1 2", "3, 1, 2", "[3, 1, 2, 4] (3, 1, 2) True"])
	expect_line("def f(): pass
print(f.__name__, len.__name__, type(3).__name__, ValueError.__name__)", "f len int ValueError")


func test_global_y_nonlocal() -> void:
	expect_line("x = 1\ndef g():\n    global x\n    x = 2\ng()\nprint(x)", "2")
	expect_line("def contador():\n    n = 0\n    def inc():\n        nonlocal n\n        n += 1\n        return n\n    return inc\nc = contador()\nc()\nc()\nprint(c())", "3")


# ── Funciones ────────────────────────────────────────────────────────────────

func test_funciones_argumentos() -> void:
	var src := """
def f(a, b=2, *args, c=10, **kw):
    return a, b, args, c, kw
print(f(1))
print(f(1, 3, 4, 5, c=7, z=9))
print(f(b=5, a=0))
def p(a, b=0):
    return a + b
print(p(*[1, 2]), p(**{'a': 4}))
"""
	expect_out(src, ["(1, 2, (), 10, {})", "(1, 3, (4, 5), 7, {'z': 9})", "(0, 5, (), 10, {})", "3 4"])


func test_cierres_y_recursion() -> void:
	var src := """
def fib(n):
    if n < 2:
        return n
    return fib(n - 1) + fib(n - 2)
print([fib(i) for i in range(12)])
def sumador(n):
    return lambda x: x + n
print(sumador(5)(10), list(map(sumador(1), [1, 2])))
def outer():
    funcs = []
    for i in range(3):
        funcs.append(lambda: i)
    return [g() for g in funcs]
print(outer())
def fact(n):
    return 1 if n <= 1 else n * fact(n - 1)
print(fact(20))
def anidada():
    v = 'fuera'
    def dentro():
        return v
    v = 'cambiada'
    return dentro()
print(anidada())
"""
	expect_out(src, ["[0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89]", "15 [2, 3]", "[2, 2, 2]", "2432902008176640000", "cambiada"])


func test_recursion_profunda_dentro_del_limite() -> void:
	expect_line("def s(n):\n    return 0 if n == 0 else n + s(n - 1)\nprint(s(150))", "11325")


# ── Builtins ─────────────────────────────────────────────────────────────────

func test_builtins_basicos() -> void:
	expect_line("nums = [3, 9, 4]\nprint(len(nums), max(nums) - min(nums), sum(nums), sorted(nums), sorted(nums, reverse=True))", "3 6 16 [3, 4, 9] [9, 4, 3]")
	expect_line("print(abs(-3), abs(-2.5), int('42'), int(' -7 '), int(3.9), int(-3.9), float('3.5'), float('1e-3'), str(1.0), bool(''), bool('0'))",
		"3 2.5 42 -7 3 -3 3.5 0.001 1.0 False True")
	expect_line("print(list(range(10, 0, -3)), list(range(-2)), len(range(0, 10, 3)), range(5)[2])", "[10, 7, 4, 1] [] 4 2")
	expect_line("print(max(3, 7, 2), min('b', 'a'), max([], default=None), max(['aa', 'b'], key=len), min([(2, 'b'), (1, 'z')]))", "7 a None aa (1, 'z')")
	expect_line("print(list(zip([1, 2, 3], 'ab')), dict(zip('ab', [1, 2])), list(reversed([1, 2, 3])), any([0, 1]), all([]))",
		"[(1, 'a'), (2, 'b')] {'a': 1, 'b': 2} [3, 2, 1] True True")
	expect_line("print(list(enumerate('ab', 1)), list(filter(None, [0, 1, '', 'a'])), list(map(str, [1, 2])))",
		"[(1, 'a'), (2, 'b')] [1, 'a'] ['1', '2']")
	expect_line("print(chr(65), ord('a'), hex(255), bin(5), oct(8), pow(3, 4, 5), isinstance(True, int), type(3) == int)", "A 97 0xff 0b101 0o10 1 True True")


func test_round_como_python() -> void:
	expect_line("print(round(2.5), round(3.5), round(-2.5), round(0.5), round(1.5), round(7.0))", "2 4 -2 0 2 7")
	expect_line("print(round(0.125, 2), round(2.675, 2), round(1234, -2), round(1250, -2), round(123.456, -1), round(1.005, 2))",
		"0.12 2.67 1200 1200 120.0 1.0")


func test_sum_de_floats_como_cpython() -> void:
	# CPython 3.12+ usa suma compensada: sum([0.1] * 10) == 1.0
	expect_line("print(sum([0.1] * 10), sum([1, 2.5]), sum([[1], [2]], []))", "1.0 3.5 [1, 2]")


func test_sorted_estable_con_key_y_reverse() -> void:
	expect_line("d = [('x', 3), ('y', 1), ('z', 3), ('w', 2)]\nprint(sorted(d, key=lambda t: t[1], reverse=True))",
		"[('x', 3), ('z', 3), ('w', 2), ('y', 1)]")
	expect_line("print(sorted(['banana', 'Apple', 'cherry', 'apple'], key=str.lower))", "['Apple', 'apple', 'banana', 'cherry']")
	expect_line("l = [3, 1, 2]\nl.sort(key=lambda v: -v)\nprint(l, sorted('hola'), sorted({3: 'a', 1: 'b'}))", "[3, 2, 1] ['a', 'h', 'l', 'o'] [1, 3]")


# ── Métodos ──────────────────────────────────────────────────────────────────

func test_metodos_de_lista() -> void:
	var src := """
l = [3, 1, 2]
l.append(5); l.extend([7, 0]); l.insert(0, 9); l.insert(100, 8)
print(l, l.pop(), l.pop(0), l.index(2), l.count(1))
l.sort(); print(l)
l.reverse(); print(l)
l.remove(5); print(l, l.copy() == l, l.copy() is l)
"""
	# print evalúa todos los argumentos antes de imprimir: la lista sale ya modificada
	expect_out(src, ["[3, 1, 2, 5, 7, 0] 8 9 2 1", "[0, 1, 2, 3, 5, 7]", "[7, 5, 3, 2, 1, 0]", "[7, 3, 2, 1, 0] True False"])


func test_metodos_de_str() -> void:
	expect_line("s = '  Hola, Mundo  '\nprint(s.strip(), s.lower(), s.upper(), s.split(), s.split(','))",
		"Hola, Mundo   hola, mundo     HOLA, MUNDO   ['Hola,', 'Mundo'] ['  Hola', ' Mundo  ']")
	expect_line("print('a,b,,c'.split(','), '-'.join(['a', 'b']), 'banana'.replace('a', 'o'), 'banana'.replace('a', 'o', 1))",
		"['a', 'b', '', 'c'] a-b bonono bonana")
	expect_line("print('hola'.startswith('ho'), 'hola'.endswith(('x', 'la')), 'banana'.count('a'), 'banana'.find('n'), 'banana'.find('z'), 'banana'.rfind('a'))",
		"True True 3 2 -1 5")
	expect_line("print('abc'.title(), 'hello world'.capitalize(), 'x'.center(5, '*'), '42'.zfill(5), '-42'.zfill(5), 'año'.isalpha(), '123'.isdigit())",
		"Abc Hello world **x** 00042 -0042 True True")
	expect_line("print('ñandú'.upper(), 'a1 b2 c3'.split(maxsplit=1), 'a,b,c'.rsplit(',', 1), 'k=v'.partition('='))",
		"ÑANDÚ ['a1', 'b2 c3'] ['a,b', 'c'] ('k', '=', 'v')")


func test_metodos_de_dict() -> void:
	var src := """
d = {'a': 1, 'b': 2}
d['c'] = 3
print(d.get('z'), d.get('z', 0), list(d.keys()), list(d.values()), list(d.items()))
print(d.pop('b'), d, d.keys(), d.items())
for k, v in d.items():
    print(k, v)
cuenta = {}
for w in 'el gato y el perro y el pez'.split():
    cuenta[w] = cuenta.get(w, 0) + 1
print(cuenta, max(cuenta, key=cuenta.get))
"""
	expect_out(src, ["None 0 ['a', 'b', 'c'] [1, 2, 3] [('a', 1), ('b', 2), ('c', 3)]",
		"2 {'a': 1, 'c': 3} dict_keys(['a', 'c']) dict_items([('a', 1), ('c', 3)])", "a 1", "c 3",
		"{'el': 3, 'gato': 1, 'y': 2, 'perro': 1, 'pez': 1} el"])


# ── Formato ──────────────────────────────────────────────────────────────────

func test_fstrings_con_especificaciones() -> void:
	expect_line("x = 3.14159\nname = 'Ana'\nprint(f'{x:.2f}|{x:8.3f}|{name:>6}|{name:<6}|{name:^7}|{42:05d}|{7:d}|{1234567:,}')",
		"3.14|   3.142|   Ana|Ana   |  Ana  |00042|7|1,234,567")
	expect_line("x = 3.5\nname = 'Ana'\nprint(f'{x!r} {name!r} {x=} {{}} {3 + 4} {x:>5}|{0.5:%} {0.25:.0%}')",
		"3.5 'Ana' x=3.5 {} 7   3.5|50.000000% 25%")
	expect_line("print(f'{2.675:.2f} {0.125:.2f} {-0.0:.1f} {12345.678:,.2f} {0.000123:e} {1234.5:g} {1e-7:g} {255:x} {255:#b}')",
		"2.67 0.12 -0.0 12,345.68 1.230000e-04 1234.5 1e-07 ff 0b11111111")
	expect_line("w = 6\nd = {'k': [1, 2]}\nprint(f'{\"ab\":>{w}}|{d[\"k\"][1]}|{True:>5}|{2.5:.0f}|{-1.5:+.1f}')", "    ab|2|    1|2|-1.5")


func test_format_y_porcentaje() -> void:
	expect_line("print('{} y {}'.format('a', 'b'), '{1}{0}'.format('x', 'y'), '{n:.1f}'.format(n=2.25), '{:>4}|'.format(1), '{0[1]}'.format([5, 6]))",
		"a y b yx 2.2    1| 6")
	expect_line("print('%d cosas cuestan %.2f (%s) %r %5d|%-5d| %x %%' % (3, 2.5, 'ok', 'ok', 42, 7, 255))",
		"3 cosas cuestan 2.50 (ok) 'ok'    42|7    | ff %")


# ── Módulos ──────────────────────────────────────────────────────────────────

func test_import_math() -> void:
	expect_line("import math\nprint(math.sqrt(16), math.floor(-2.5), math.ceil(2.1), math.log(8, 2), math.log2(1024), math.exp(0), math.factorial(5))",
		"4.0 -3 3 3.0 10.0 1.0 120")
	expect_line("from math import sqrt, pi, e, inf, log\nprint(sqrt(2), pi, e, inf, -inf, log(e))",
		"1.4142135623730951 3.141592653589793 2.718281828459045 inf -inf 1.0")
	expect_line("import math\nprint(math.isclose(0.1 + 0.2, 0.3), math.fsum([0.1] * 10), math.hypot(3, 4), math.gcd(12, 18))", "True 1.0 5.0 6")


func test_random_determinista_como_cpython() -> void:
	expect_out("import random\nrandom.seed(42)\nprint(random.random())\nprint(random.random())", ["0.6394267984578837", "0.025010755222666936"])
	expect_line("import random\nrandom.seed(42)\nprint(random.randint(1, 10), random.choice(['a', 'b', 'c']), random.randint(1, 100))", "2 a 95")
	expect_line("import random\nrandom.seed(12345)\nl = list(range(10))\nrandom.shuffle(l)\nprint(l)", "[8, 7, 3, 5, 1, 2, 9, 4, 0, 6]")
	# sin semilla explícita, cada ejecución empieza igual (reproducible en el Dojo)
	var a := run_ok("import random\nprint(random.random())")
	var b := run_ok("import random\nprint(random.random())")
	assert_eq(Array(a), Array(b))


func test_otros_modulos_dan_import_error() -> void:
	expect_error("import os", "ImportError", 1, "no está disponible en el Dojo")
	expect_error("x = 1\nimport numpy as np", "ImportError", 2, "numpy")
	expect_error("from subprocess import run", "ImportError", 1)
	expect_error("from math import nope", "ImportError", 1, "nope")


# ── Errores con tipo, línea y mensaje en español ─────────────────────────────

func test_errores_de_ejecucion_con_linea() -> void:
	expect_error("x = 1\nprint(y)", "NameError", 2, "el nombre 'y' no está definido")
	expect_error("x = 1\ny = 'a' + x", "TypeError", 2, "str")
	expect_error("l = [1, 2]\nprint(l[5])", "IndexError", 2, "fuera de rango")
	expect_error("d = {}\nd['k']", "KeyError", 2, "'k'")
	expect_error("def f():\n    return 1 / 0\nf()", "ZeroDivisionError", 2, "división entre cero")
	expect_error("int('abc')", "ValueError", 1, "'abc'")
	expect_error("x = [1]\nx.push(2)", "AttributeError", 2, "append")
	expect_error("x = 10\ndef f():\n    print(x)\n    x = 5\nf()", "UnboundLocalError", 3)
	expect_error("def f(a, b):\n    return a\nf(1)", "TypeError", 3, "'b'")
	expect_error("len(5)", "TypeError", 1)
	expect_error("print(5 % 0)", "ZeroDivisionError", 1)
	expect_error("t = (1, 2)\nt[0] = 5", "TypeError", 2, "inmutables")
	expect_error("a, b = [1, 2, 3]", "ValueError", 1, "desempaquetar")
	expect_error("print(sorted([1, 'a']))", "TypeError", 1)
	expect_error("import math\nmath.sqrt(-1)", "ValueError", 2, "dominio")


func test_recursion_infinita_da_recursion_error() -> void:
	var e := expect_error("def f(n):\n    return f(n + 1)\nf(0)", "RecursionError", 2)
	if not e.is_empty():
		assert_true(str(e["message"]).contains("caso base"), "el mensaje debería orientar sobre el caso base")


func test_errores_de_sintaxis_con_linea() -> void:
	expect_error("x = 1\nprint('hola'\ny = 2\n", "SyntaxError", 2, "nunca se cerró")
	expect_error("x = [1, 2\n", "SyntaxError", 1, "'['")
	expect_error("for i in range(3)\n    print(i)", "SyntaxError", 1, "':'")
	expect_error("x = 'abc", "SyntaxError", 1, "cadena sin cerrar")
	expect_error("x = 5\nif x = 5:\n    pass", "SyntaxError", 2, "==")
	expect_error("print 'hola'", "SyntaxError", 1, "print(...)")
	expect_error("x = )", "SyntaxError", 1)
	expect_error("break", "SyntaxError", 1, "fuera de un bucle")
	expect_error("return 1", "SyntaxError", 1, "fuera de una función")
	expect_error("x = 5 +", "SyntaxError", 1)
	expect_error("1 = x", "SyntaxError", 1)
	expect_error("class A:\n    pass", "SyntaxError", 1, "clases")


func test_errores_de_indentacion() -> void:
	expect_error("x = 1\n    y = 2", "IndentationError", 2, "inesperada")
	expect_error("def f():\nreturn 1", "IndentationError", 2, "sangría")
	expect_error("if True:\n    x = 1\n  y = 2", "IndentationError", 3, "no coincide")
	expect_error("if True:\n        x = 1\n\ty = 2", "IndentationError", 3)


func test_try_except_finally_raise_assert() -> void:
	var src := """
def div(a, b):
    try:
        return a / b
    except ZeroDivisionError as e:
        print('error:', e)
        return None
    finally:
        print('finally')
print(div(1, 2), div(1, 0))
try:
    [][1]
except (KeyError, IndexError):
    print('capturado')
try:
    raise ValueError('mal')
except Exception as e:
    print('E', e)
try:
    assert 1 == 2, 'no son iguales'
except AssertionError as e:
    print('assert:', e)
for i in range(3):
    try:
        if i == 1:
            continue
        print('try', i)
    finally:
        print('fin', i)
"""
	expect_out(src, ["finally", "error: división entre cero", "finally", "0.5 None", "capturado", "E mal",
		"assert: no son iguales", "try 0", "fin 0", "fin 1", "try 2", "fin 2"])
	expect_error("def f(x):\n    if x < 0:\n        raise ValueError('negativo')\n    return x\nf(-1)", "ValueError", 3, "negativo")


# ── Límite de pasos ──────────────────────────────────────────────────────────

func test_limite_de_pasos_detiene_bucles_infinitos() -> void:
	var r := py.run("print('antes')\nwhile True:\n    pass\n", 5000)
	assert_false(r["ok"])
	assert_eq(r["error"].get("type"), "StepLimitError")
	assert_eq(r["error"].get("message"), "tu programa ha superado el límite de pasos: ¿hay un bucle infinito?")
	assert_eq(r["error"].get("line"), 2)
	assert_eq(Array(r["output"]), ["antes"], "la salida anterior al bucle se conserva")


func test_limite_de_pasos_no_lo_atrapa_except() -> void:
	var r := py.run("try:\n    while True:\n        x = 1\nexcept Exception:\n    print('atrapado')\n", 3000)
	assert_false(r["ok"])
	assert_eq(r["error"].get("type"), "StepLimitError")
	assert_eq(Array(r["output"]), [])


func test_limite_de_pasos_en_recursion_y_builtins() -> void:
	var r1 := py.run("def f(n):\n    return f(n) if n > 1000 else 0\nl = [f(i) for i in range(100000)]", 2000)
	assert_eq(r1["error"].get("type"), "StepLimitError")
	var r2 := py.run("print(sum(range(10 ** 12)))", 2000)
	assert_eq(r2["error"].get("type"), "StepLimitError", "los builtins también cuentan pasos")


func test_programa_normal_cabe_en_el_limite() -> void:
	var r := py.run("t = 0\nfor i in range(1000):\n    t += i\nprint(t)", 2000)
	assert_true(r["ok"], str(r["error"]))
	assert_eq(Array(r["output"]), ["499500"])


# ── Aislamiento ──────────────────────────────────────────────────────────────

func test_aislamiento_sin_acceso_al_sistema() -> void:
	for name: String in ["open('f.txt')", "eval('1')", "exec('x=1')", "__import__('os')", "getattr([], 'append')", "globals()", "input()", "compile('1', 'f', 'exec')"]:
		var r := py.run(name)
		assert_false(r["ok"], "%s debería fallar" % name)
		assert_eq(r["error"].get("type"), "NameError", name)
		assert_true(str(r["error"].get("message")).contains("no está disponible en el Dojo"), name)
	for attr: String in ["().__class__", "print.__self__", "[].__dict__", "'a'.__class__", "len.call", "(lambda: 1).__globals__"]:
		var r := py.run("x = " + attr)
		assert_false(r["ok"], "%s debería fallar" % attr)
		assert_eq(r["error"].get("type"), "AttributeError", attr)
	expect_error("x = [1]\nx.foo = 3", "AttributeError", 2)


func test_aislamiento_el_codigo_del_motor_no_usa_apis_del_sistema() -> void:
	var forbidden := RegEx.create_from_string("\\b(FileAccess|DirAccess|OS\\s*\\.|ClassDB|Engine\\s*\\.|ResourceLoader|JavaScriptBridge|HTTPRequest|Expression|get_tree|preload\\s*\\(|load\\s*\\()")
	var dir := DirAccess.open("res://core/python")
	assert_true(dir != null, "no se encuentra res://core/python")
	if dir == null:
		return
	var checked := 0
	for file in dir.get_files():
		if not file.ends_with(".gd"):
			continue
		checked += 1
		var lines := FileAccess.get_file_as_string("res://core/python/" + file).split("\n")
		for i in lines.size():
			if forbidden.search(lines[i]) != null:
				fail("%s:%d usa una API no permitida: %s" % [file, i + 1, lines[i].strip_edges()])
	assert_true(checked >= 6, "deberían revisarse todos los ficheros del intérprete")


func test_los_datos_de_entrada_se_copian() -> void:
	var data := [1, [2, 3]]
	run_ok("def muta(l):\n    l[1].append(99)\n    l.append(0)\n    return l")
	var r := py.call_function("muta", [data])
	assert_true(r["ok"])
	assert_eq(r["value"], [1, [2, 3, 99], 0])
	assert_eq(data, [1, [2, 3]], "el Array original de GDScript no debe cambiar")


# ── API: globales persistentes, call_function y conversiones ─────────────────

func test_los_globales_se_conservan_entre_ejecuciones() -> void:
	run_ok("x = 41\ndef inc(n):\n    return n + 1")
	expect_line("print(inc(x))", "42")
	assert_true(py.has_function("inc"))
	assert_false(py.has_function("x"))
	assert_eq(py.get_global("x"), 41)


func test_call_function_devuelve_valores_planos() -> void:
	run_ok("""
def info(xs):
    print('procesando', len(xs))
    return {'n': len(xs), 'media': sum(xs) / len(xs), 'par': (min(xs), max(xs)), 'ok': True, 'nada': None, 'set': {1}}
""")
	var r := py.call_function("info", [[3, 9, 4]])
	assert_true(r["ok"], str(r["error"]))
	assert_eq(Array(r["output"]), ["procesando 3"])
	var v: Dictionary = r["value"]
	assert_eq(v["n"], 3)
	assert_almost_eq(v["media"], 16.0 / 3.0, 1e-12)
	assert_eq(v["par"], [3, 9], "las tuplas vuelven como Array")
	assert_eq(v["ok"], true)
	assert_eq(v["nada"], null)
	assert_eq(v["set"], [1])
	assert_eq(typeof(v["n"]), TYPE_INT)
	assert_eq(typeof(v["media"]), TYPE_FLOAT)


func test_call_function_convierte_argumentos() -> void:
	run_ok("def tipos(*a):\n    return [type(x).__name__ if False else str(type(x)) for x in a]")
	var r := py.call_function("tipos", [1, 2.5, "s", true, null, [1], {"k": 1}, PackedInt32Array([1, 2])])
	assert_true(r["ok"], str(r["error"]))
	assert_eq(r["value"], ["<class 'int'>", "<class 'float'>", "<class 'str'>", "<class 'bool'>", "<class 'NoneType'>", "<class 'list'>", "<class 'dict'>", "<class 'list'>"])
	var r2 := py.call_function("tipos", [Node])
	assert_eq(r2["value"], ["<class 'NoneType'>"], "los objetos del motor no entran en Python")


func test_call_function_errores() -> void:
	run_ok("def f(x):\n    return 10 / x\nvalor = 3")
	var r := py.call_function("f", [0])
	assert_false(r["ok"])
	assert_eq(r["error"]["type"], "ZeroDivisionError")
	assert_eq(r["error"]["line"], 2)
	var missing := py.call_function("g", [])
	assert_false(missing["ok"])
	assert_eq(missing["error"]["type"], "NameError")
	var not_fn := py.call_function("valor", [])
	assert_eq(not_fn["error"]["type"], "TypeError")
	var bad_args := py.call_function("f", [1, 2])
	assert_eq(bad_args["error"]["type"], "TypeError")


func test_conversion_ida_y_vuelta() -> void:
	var plain: Variant = {"a": [1, 2.5, "x", true, null], "b": {"c": []}}
	var back: Variant = py.to_plain(py.from_plain(plain))
	assert_eq(back, plain)
	var tup: Variant = py.from_plain({[1, 2]: "par"})
	assert_eq(py.py_repr(tup), "{(1, 2): 'par'}", "las claves Array se vuelven tuplas")


# ── PyExercise ───────────────────────────────────────────────────────────────

const RANGO_OK := """
def rango(xs):
    return max(xs) - min(xs)
"""


func test_ejercicio_que_pasa() -> void:
	var spec := {"function": "rango", "cases": [
		{"args": [[3, 9, 4]], "expected": 6},
		{"args": [[5]], "expected": 0},
		{"args": [[-2, 2.5]], "expected": 4.5, "tolerance": 1e-9},
	]}
	var r := PyExercise.check(RANGO_OK, spec)
	assert_true(r["ok"])
	assert_eq(r["passed"], 3)
	assert_eq(r["total"], 3)
	assert_true(r["error"].is_empty())
	assert_eq(r["results"][0]["got"], 6)
	assert_true(r["results"][2]["ok"])


func test_ejercicio_que_falla() -> void:
	var src := "def rango(xs):\n    return max(xs)\n"
	var r := PyExercise.check(src, {"function": "rango", "cases": [{"args": [[3, 9, 4]], "expected": 6}, {"args": [[0, 0]], "expected": 0}]})
	assert_true(r["ok"])
	assert_eq(r["passed"], 1)
	assert_false(r["results"][0]["ok"])
	assert_eq(r["results"][0]["got"], 9)
	assert_eq(r["results"][0]["expected"], 6)
	assert_true(r["results"][0]["error"].is_empty())


func test_ejercicio_que_revienta_en_un_caso() -> void:
	var src := "def media(xs):\n    return sum(xs) / len(xs)\n"
	var r := PyExercise.check(src, {"function": "media", "cases": [{"args": [[1, 2]], "expected": 1.5}, {"args": [[]], "expected": 0}]})
	assert_true(r["ok"])
	assert_eq(r["passed"], 1)
	var bad: Dictionary = r["results"][1]
	assert_false(bad["ok"])
	assert_eq(bad["error"]["type"], "ZeroDivisionError")
	assert_eq(bad["error"]["line"], 2)


func test_ejercicio_con_error_de_sintaxis() -> void:
	var r := PyExercise.check("def rango(xs)\n    return 0\n", {"function": "rango", "cases": [{"args": [[1]], "expected": 0}]})
	assert_false(r["ok"])
	assert_eq(r["passed"], 0)
	assert_eq(r["error"]["type"], "SyntaxError")
	assert_eq(r["error"]["line"], 1)
	assert_eq(r["results"].size(), 1)
	assert_false(r["results"][0]["ok"])


func test_ejercicio_sin_la_funcion() -> void:
	var r := PyExercise.check("def otra(xs):\n    return 0\n", {"function": "rango", "cases": [{"args": [[1]], "expected": 0}]})
	assert_true(r["ok"], "el código se ejecutó")
	assert_true(r["missing_function"])
	assert_eq(r["passed"], 0)
	assert_true(str(r["error"]["message"]).contains("no has definido la función 'rango'"), str(r["error"]))
	var r2 := PyExercise.check("rango = 5\n", {"function": "rango", "cases": [{"args": [[1]], "expected": 0}]})
	assert_true(str(r2["error"]["message"]).contains("no es una función"))


func test_ejercicio_compara_en_profundidad_con_tolerancia() -> void:
	var src := """
def resumen(xs):
    m = sum(xs) / len(xs)
    return {'media': m, 'extremos': (min(xs), max(xs)), 'normalizados': [x / max(xs) for x in xs]}
"""
	var spec := {"function": "resumen", "tolerance": 1e-6, "cases": [
		{"args": [[1, 2, 3]], "expected": {"media": 2, "extremos": [1, 3], "normalizados": [0.333333, 0.666667, 1]}},
		{"args": [[1, 2, 3]], "expected": {"media": 2, "extremos": [1, 4], "normalizados": [0.333333, 0.666667, 1]}},
	]}
	var r := PyExercise.check(src, spec)
	assert_true(r["results"][0]["ok"], str(r["results"][0]))
	assert_false(r["results"][1]["ok"])
	assert_eq(r["passed"], 1)


func test_ejercicio_reglas_de_igualdad() -> void:
	assert_true(PyExercise.values_match(6.0, 6))
	assert_false(PyExercise.values_match(0.30000000000000004, 0.3), "sin tolerancia la comparación es exacta")
	assert_true(PyExercise.values_match(0.30000000000000004, 0.3, 1e-9))
	assert_false(PyExercise.values_match(true, 1), "True no es igual a 1 en un ejercicio")
	assert_false(PyExercise.values_match([1, 2], [1, 2, 3]))
	assert_true(PyExercise.values_match({"a": [1, {"b": null}]}, {"a": [1, {"b": null}]}))
	assert_false(PyExercise.values_match("6", 6))


func test_ejercicio_con_bucle_infinito_y_kwargs() -> void:
	var src := "def espera(n, paso=1):\n    while n > 0:\n        n -= paso\n    return n\n"
	var r := PyExercise.check(src, {"function": "espera", "max_steps": 5000, "cases": [
		{"args": [3], "expected": 0},
		{"args": [3], "kwargs": {"paso": 2}, "expected": -1},
		{"args": [5], "kwargs": {"paso": 0}, "expected": 0},
	]})
	assert_eq(r["passed"], 2)
	assert_eq(r["results"][2]["error"].get("type"), "StepLimitError")


func test_ejercicio_salida_de_print_por_caso() -> void:
	var r := PyExercise.check("print('cargando')\ndef doble(x):\n    print('doble de', x)\n    return 2 * x\n",
		{"function": "doble", "cases": [{"args": [4], "expected": 8}]})
	assert_eq(Array(r["output"]), ["cargando"])
	assert_eq(Array(r["results"][0]["output"]), ["doble de 4"])
	assert_eq(r["passed"], 1)
