class_name PyBuiltins
extends RefCounted
## Funciones integradas, métodos de los tipos, formato de texto y módulos (math, random)
## del Python del Dojo. Todo es estático y trabaja sobre un PyInterpreter (`vm`).
##
## Seguridad: los métodos y atributos accesibles están en listas blancas (METHODS) y solo
## existen los módulos math y random. No hay open, input, eval, exec, getattr, etc.

const TYPE_NAMES := {
	"int": true, "float": true, "str": true, "bool": true, "list": true, "dict": true,
	"tuple": true, "set": true, "range": true, "type": true,
	"NoneType": true, "function": true, "module": true, "builtin_function_or_method": true,
}

const FUNCTIONS: Array[String] = [
	"print", "len", "range", "abs", "min", "max", "sum", "round", "sorted", "int", "float", "str",
	"bool", "list", "dict", "tuple", "set", "enumerate", "zip", "map", "filter", "reversed", "any",
	"all", "isinstance", "type", "chr", "ord", "divmod", "pow", "hex", "bin", "oct", "iter", "next",
	"repr", "format", "callable",
]

const EXCEPTIONS: Array[String] = [
	"BaseException", "Exception", "ValueError", "TypeError", "IndexError", "KeyError", "ZeroDivisionError",
	"NameError", "AttributeError", "RuntimeError", "RecursionError", "ArithmeticError", "LookupError",
	"OverflowError", "AssertionError", "ImportError", "ModuleNotFoundError", "NotImplementedError",
	"StopIteration", "UnboundLocalError", "MemoryError",
]

const UNAVAILABLE := {
	"open": "en el Dojo no hay ficheros",
	"input": "en el Dojo no se teclean datos: llegan como argumentos de tus funciones",
	"eval": "no se puede ejecutar texto como código",
	"exec": "no se puede ejecutar texto como código",
	"compile": "no se puede compilar texto como código",
	"__import__": "usa import math o import random",
	"globals": "", "locals": "", "vars": "", "getattr": "", "setattr": "", "delattr": "",
	"hasattr": "", "exit": "", "quit": "", "help": "", "dir": "", "breakpoint": "", "object": "",
	"super": "", "property": "", "classmethod": "", "staticmethod": "", "memoryview": "",
	"bytes": "", "bytearray": "", "frozenset": "", "id": "", "hash": "", "issubclass": "",
	"complex": "los números complejos no existen en el Dojo",
}

const NAME_HINTS := {
	"true": "True", "false": "False", "none": "None", "null": "None", "nil": "None",
	"length": "len", "lenght": "len", "size": "len", "count": "len", "println": "print",
	"printf": "print", "echo": "print", "string": "str", "integer": "int", "boolean": "bool",
	"array": "list", "elseif": "elif", "else_if": "elif", "sqrt": "math.sqrt (después de import math)",
	"pi": "math.pi (después de import math)", "inf": "float('inf') o math.inf",
}

const METHODS := {
	"list": ["append", "extend", "pop", "insert", "index", "count", "sort", "reverse", "remove", "clear", "copy"],
	"str": ["lower", "upper", "strip", "lstrip", "rstrip", "split", "rsplit", "join", "replace", "startswith",
		"endswith", "count", "find", "rfind", "index", "rindex", "isdigit", "isalpha", "isalnum", "isspace",
		"isupper", "islower", "isnumeric", "isdecimal", "title", "capitalize", "swapcase", "center", "ljust",
		"rjust", "zfill", "format", "splitlines", "partition", "rpartition", "casefold", "removeprefix",
		"removesuffix"],
	"dict": ["get", "keys", "values", "items", "pop", "setdefault", "update", "clear", "copy", "popitem"],
	"set": ["add", "remove", "discard", "pop", "clear", "copy", "union", "intersection", "difference",
		"symmetric_difference", "issubset", "issuperset", "isdisjoint", "update"],
	"tuple": ["count", "index"],
	"int": ["bit_length"],
	"bool": ["bit_length"],
	"float": ["is_integer"],
	"range": ["count", "index"],
}

const ATTR_HINTS := {
	"push": "append", "push_back": "append", "add": "append", "length": "len(...)", "size": "len(...)",
	"len": "len(...)", "contains": "el operador in", "has": "el operador in", "has_key": "el operador in",
	"to_upper": "upper", "to_lower": "lower", "trim": "strip", "toUpperCase": "upper",
	"toLowerCase": "lower", "indexOf": "index o find", "remove_at": "pop", "sum": "sum(...)",
}

const MATH_FUNCS: Array[String] = [
	"sqrt", "log", "log2", "log10", "exp", "pow", "fabs", "floor", "ceil", "trunc", "sin", "cos", "tan",
	"asin", "acos", "atan", "atan2", "hypot", "degrees", "radians", "factorial", "gcd", "lcm", "isclose",
	"isnan", "isinf", "isfinite", "fsum", "prod", "comb", "perm", "copysign", "fmod", "isqrt", "dist",
]

const RANDOM_FUNCS: Array[String] = [
	"seed", "random", "randint", "choice", "shuffle", "uniform", "randrange", "sample", "gauss", "choices",
]


static func make_builtins() -> Dictionary:
	var d := {}
	for n in FUNCTIONS:
		d[n] = PyInterpreter.Builtin.new(n)
	for n in EXCEPTIONS:
		d[n] = PyInterpreter.ExcType.new(n)
	return d


static func name_error_message(vm: PyInterpreter, name: String) -> String:
	if UNAVAILABLE.has(name):
		var why: String = UNAVAILABLE[name]
		return "'%s' no está disponible en el Dojo%s" % [name, "" if why.is_empty() else " (" + why + ")"]
	var msg := "el nombre '%s' no está definido" % name
	if name == "math" or name == "random":
		return msg + ": ¿has olvidado escribir import %s al principio?" % name
	if NAME_HINTS.has(name):
		return msg + ": ¿querías decir %s?" % NAME_HINTS[name]
	if name != name.to_lower() and vm._builtins.has(name.to_lower()):
		return msg + ": ¿querías decir %s? (Python distingue mayúsculas y minúsculas)" % name.to_lower()
	return msg + " (¿está bien escrito? ¿le has dado un valor antes de usarlo?)"


static func _plural(n: int, one: String, many: String) -> String:
	return "%d %s" % [n, one if n == 1 else many]


## Comprueba número de argumentos y argumentos con nombre permitidos.
const _NONE: Array = []


static func _check(vm: PyInterpreter, fname: String, args: Array, kwargs: Dictionary, min_n: int, max_n: int, allowed: Array = _NONE) -> bool:
	if not kwargs.is_empty():
		for k: String in kwargs:
			if not allowed.has(k):
				vm.raise_error("TypeError", "%s() no acepta el argumento con nombre '%s'" % [fname, k])
				return false
	var n := args.size()
	if n >= min_n and (max_n < 0 or n <= max_n):
		return true
	if n < min_n or (max_n >= 0 and n > max_n):
		var expect := ""
		if min_n == max_n:
			expect = "exactamente " + _plural(min_n, "argumento", "argumentos")
		elif max_n < 0:
			expect = "al menos " + _plural(min_n, "argumento", "argumentos")
		else:
			expect = "entre %d y %d argumentos" % [min_n, max_n]
		vm.raise_error("TypeError", "%s() necesita %s (se le pasaron %d)" % [fname, expect, n])
		return false
	return true


static func _int_arg(vm: PyInterpreter, fname: String, v: Variant) -> Variant:
	if PyInterpreter.is_int_like(v):
		return int(v)
	vm.raise_error("TypeError", "%s() necesita un número entero, no '%s'" % [fname, vm.type_name(v)])
	return null


static func _num_arg(vm: PyInterpreter, fname: String, v: Variant) -> Variant:
	if PyInterpreter.is_num(v):
		return float(v)
	vm.raise_error("TypeError", "%s() necesita un número, no '%s'" % [fname, vm.type_name(v)])
	return null


# ── Llamadas a builtins ──────────────────────────────────────────────────────

static func call_builtin(vm: PyInterpreter, b: PyInterpreter.Builtin, args: Array, kwargs: Dictionary) -> Variant:
	if b.module == "math":
		return _math(vm, b.name, args, kwargs)
	if b.module == "random":
		return _random(vm, b.name, args, kwargs)
	if b.module.begins_with("unbound:"):
		var tname := b.module.substr(8)
		if args.is_empty() or vm.type_name(args[0]) != tname:
			vm.raise_error("TypeError", "%s.%s() necesita como primer argumento un valor de tipo '%s'" % [tname, b.name, tname])
			return null
		return call_method(vm, args[0], b.name, args.slice(1), kwargs)
	if b.module == "<type>":
		vm.raise_error("TypeError", "no se pueden crear valores de tipo '%s'" % b.name)
		return null
	var fn: Variant = _BUILTIN_TABLE.get(b.name)
	if fn != null:
		return (fn as Callable).call(vm, b, args, kwargs)
	vm.raise_error("NameError", "función integrada desconocida: %s" % b.name)
	return null


static var _BUILTIN_TABLE := {
	"print": _b_print,
	"len": _b_len,
	"range": _b_range,
	"abs": _b_abs,
	"min": _b_min,
	"max": _b_min,
	"sum": _b_sum,
	"round": _b_round,
	"sorted": _b_sorted,
	"int": _b_int,
	"float": _b_float,
	"str": _b_str,
	"repr": _b_repr,
	"bool": _b_bool,
	"list": _b_list,
	"tuple": _b_tuple,
	"set": _b_set,
	"dict": _b_dict,
	"enumerate": _b_enumerate,
	"zip": _b_zip,
	"map": _b_map,
	"filter": _b_filter,
	"reversed": _b_reversed,
	"any": _b_any,
	"all": _b_any,
	"isinstance": _b_isinstance,
	"type": _b_type,
	"chr": _b_chr,
	"ord": _b_ord,
	"divmod": _b_divmod,
	"pow": _b_pow,
	"hex": _b_hex,
	"bin": _b_hex,
	"oct": _b_hex,
	"iter": _b_iter,
	"next": _b_next,
	"format": _b_format,
	"callable": _b_callable,
}


static func _b_print(vm: PyInterpreter, b: PyInterpreter.Builtin, args: Array, kwargs: Dictionary) -> Variant:
	for k: String in kwargs:
		if k != "sep" and k != "end":
			vm.raise_error("TypeError", "print() no acepta el argumento '%s' en el Dojo" % k)
			return null
	var sep: Variant = kwargs.get("sep", " ")
	var end: Variant = kwargs.get("end", "\n")
	if sep == null:
		sep = " "
	if end == null:
		end = "\n"
	if typeof(sep) != TYPE_STRING or typeof(end) != TYPE_STRING:
		vm.raise_error("TypeError", "sep y end de print() tienen que ser cadenas")
		return null
	var parts := PackedStringArray()
	for a: Variant in args:
		parts.append(vm.py_str(a))
		if vm.has_error():
			return null
	vm.write(str(sep).join(parts) + str(end))
	return null


static func _b_len(vm: PyInterpreter, b: PyInterpreter.Builtin, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, "len", args, kwargs, 1, 1):
		return null
	return _len(vm, args[0])


static func _b_range(vm: PyInterpreter, b: PyInterpreter.Builtin, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, "range", args, kwargs, 1, 3):
		return null
	for a: Variant in args:
		if not PyInterpreter.is_int_like(a):
			if typeof(a) == TYPE_FLOAT:
				vm.raise_error("TypeError", "range() solo acepta enteros, no 'float': convierte con int(...)")
			else:
				vm.raise_error("TypeError", "range() solo acepta enteros, no '%s'" % vm.type_name(a))
			return null
	var r := PyInterpreter.PyRange.new()
	if args.size() == 1:
		r.stop = int(args[0])
	else:
		r.start = int(args[0])
		r.stop = int(args[1])
		if args.size() == 3:
			r.step = int(args[2])
			if r.step == 0:
				vm.raise_error("ValueError", "el paso de range() no puede ser cero")
				return null
	return r


static func _b_abs(vm: PyInterpreter, b: PyInterpreter.Builtin, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, "abs", args, kwargs, 1, 1):
		return null
	var v: Variant = args[0]
	match typeof(v):
		TYPE_INT:
			if v == PyNumber.INT_MIN:
				vm.raise_error("OverflowError", "el resultado es demasiado grande para los enteros del Dojo")
				return null
			return absi(v)
		TYPE_BOOL:
			return int(v)
		TYPE_FLOAT:
			return absf(v)
	vm.raise_error("TypeError", "abs() necesita un número, no '%s'" % vm.type_name(v))
	return null


static func _b_min(vm: PyInterpreter, b: PyInterpreter.Builtin, args: Array, kwargs: Dictionary) -> Variant:
	return _minmax(vm, b.name, args, kwargs)


static func _b_sum(vm: PyInterpreter, b: PyInterpreter.Builtin, args: Array, kwargs: Dictionary) -> Variant:
	return _sum(vm, args, kwargs)


static func _b_round(vm: PyInterpreter, b: PyInterpreter.Builtin, args: Array, kwargs: Dictionary) -> Variant:
	return _round(vm, args, kwargs)


static func _b_sorted(vm: PyInterpreter, b: PyInterpreter.Builtin, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, "sorted", args, kwargs, 1, 1, ["key", "reverse"]):
		return null
	var items: Variant = vm.to_array(args[0])
	if vm.has_error():
		return null
	return sort_values(vm, items, kwargs.get("key", null), vm.truthy(kwargs.get("reverse", false)))


static func _b_int(vm: PyInterpreter, b: PyInterpreter.Builtin, args: Array, kwargs: Dictionary) -> Variant:
	return _to_int(vm, args, kwargs)


static func _b_float(vm: PyInterpreter, b: PyInterpreter.Builtin, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, "float", args, kwargs, 0, 1):
		return null
	if args.is_empty():
		return 0.0
	var v: Variant = args[0]
	if PyInterpreter.is_num(v):
		return float(v)
	if typeof(v) == TYPE_STRING:
		var r: Array = PyNumber.parse_float(v)
		if r[0]:
			return r[1]
		vm.raise_error("ValueError", "no se puede convertir la cadena %s en float" % vm.py_repr(v))
		return null
	vm.raise_error("TypeError", "float() necesita un número o una cadena, no '%s'" % vm.type_name(v))
	return null


static func _b_str(vm: PyInterpreter, b: PyInterpreter.Builtin, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, "str", args, kwargs, 0, 1):
		return null
	return "" if args.is_empty() else vm.py_str(args[0])


static func _b_repr(vm: PyInterpreter, b: PyInterpreter.Builtin, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, "repr", args, kwargs, 1, 1):
		return null
	return vm.py_repr(args[0])


static func _b_bool(vm: PyInterpreter, b: PyInterpreter.Builtin, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, "bool", args, kwargs, 0, 1):
		return null
	return false if args.is_empty() else vm.truthy(args[0])


static func _b_list(vm: PyInterpreter, b: PyInterpreter.Builtin, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, "list", args, kwargs, 0, 1):
		return null
	if args.is_empty():
		return []
	return vm.to_array(args[0])


static func _b_tuple(vm: PyInterpreter, b: PyInterpreter.Builtin, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, "tuple", args, kwargs, 0, 1):
		return null
	if args.is_empty():
		return vm.make_tuple([])
	var items: Variant = vm.to_array(args[0])
	if vm.has_error():
		return null
	return vm.make_tuple(items)


static func _b_set(vm: PyInterpreter, b: PyInterpreter.Builtin, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, "set", args, kwargs, 0, 1):
		return null
	if args.is_empty():
		return PyInterpreter.PySet.new()
	var items: Variant = vm.to_array(args[0])
	if vm.has_error():
		return null
	return vm.make_set(items)


static func _b_dict(vm: PyInterpreter, b: PyInterpreter.Builtin, args: Array, kwargs: Dictionary) -> Variant:
	if args.size() > 1:
		vm.raise_error("TypeError", "dict() acepta como mucho 1 argumento posicional")
		return null
	var d := {}
	if args.size() == 1 and not _dict_update(vm, d, args[0]):
		return null
	for k: String in kwargs:
		d[k] = kwargs[k]
	return d


static func _b_enumerate(vm: PyInterpreter, b: PyInterpreter.Builtin, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, "enumerate", args, kwargs, 1, 2, ["start"]):
		return null
	var it := PyInterpreter.Iter.new()
	it.kind = PyInterpreter.IT_ENUM
	var inner := vm.make_iter(args[0])
	if inner == null:
		return null
	it.inner = [inner]
	var start: Variant = args[1] if args.size() > 1 else kwargs.get("start", 0)
	var sv: Variant = _int_arg(vm, "enumerate", start)
	if sv == null:
		return null
	it.count = sv
	return it


static func _b_zip(vm: PyInterpreter, b: PyInterpreter.Builtin, args: Array, kwargs: Dictionary) -> Variant:
	for k: String in kwargs:
		if k != "strict":
			vm.raise_error("TypeError", "zip() no acepta el argumento '%s'" % k)
			return null
	var it := PyInterpreter.Iter.new()
	it.kind = PyInterpreter.IT_ZIP
	for a: Variant in args:
		var inner := vm.make_iter(a)
		if inner == null:
			return null
		it.inner.append(inner)
	return it


static func _b_map(vm: PyInterpreter, b: PyInterpreter.Builtin, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, "map", args, kwargs, 2, -1):
		return null
	var it := PyInterpreter.Iter.new()
	it.kind = PyInterpreter.IT_MAP
	it.fn = args[0]
	if not vm.is_callable(args[0]):
		vm.raise_error("TypeError", "el primer argumento de map() tiene que ser una función")
		return null
	for a: Variant in args.slice(1):
		var inner := vm.make_iter(a)
		if inner == null:
			return null
		it.inner.append(inner)
	return it


static func _b_filter(vm: PyInterpreter, b: PyInterpreter.Builtin, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, "filter", args, kwargs, 2, 2):
		return null
	var it := PyInterpreter.Iter.new()
	it.kind = PyInterpreter.IT_FILTER
	it.fn = args[0]
	if args[0] != null and not vm.is_callable(args[0]):
		vm.raise_error("TypeError", "el primer argumento de filter() tiene que ser una función o None")
		return null
	var inner := vm.make_iter(args[1])
	if inner == null:
		return null
	it.inner = [inner]
	return it


static func _b_reversed(vm: PyInterpreter, b: PyInterpreter.Builtin, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, "reversed", args, kwargs, 1, 1):
		return null
	var v: Variant = args[0]
	if typeof(v) == TYPE_ARRAY or typeof(v) == TYPE_STRING or v is PyInterpreter.PyRange or typeof(v) == TYPE_DICTIONARY:
		var items: Variant = vm.to_array(v)
		if vm.has_error():
			return null
		var arr: Array = items
		arr.reverse()
		return vm.make_iter(arr)
	vm.raise_error("TypeError", "reversed() no funciona con un valor de tipo '%s'" % vm.type_name(v))
	return null


static func _b_any(vm: PyInterpreter, b: PyInterpreter.Builtin, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, b.name, args, kwargs, 1, 1):
		return null
	var it := vm.make_iter(args[0])
	if it == null:
		return null
	var want_any := b.name == "any"
	while vm.iter_next(it):
		var t := vm.truthy(vm._iter_value)
		if want_any and t:
			return true
		if not want_any and not t:
			return false
		if not vm.tick_work(1):
			return null
	if vm.has_error():
		return null
	return not want_any


static func _b_isinstance(vm: PyInterpreter, b: PyInterpreter.Builtin, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, "isinstance", args, kwargs, 2, 2):
		return null
	return _isinstance(vm, args[0], args[1])


static func _b_type(vm: PyInterpreter, b: PyInterpreter.Builtin, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, "type", args, kwargs, 1, 1):
		return null
	return type_of(vm, args[0])


static func _b_chr(vm: PyInterpreter, b: PyInterpreter.Builtin, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, "chr", args, kwargs, 1, 1):
		return null
	var c: Variant = _int_arg(vm, "chr", args[0])
	if c == null:
		return null
	if c < 0 or c > 0x10FFFF:
		vm.raise_error("ValueError", "chr() necesita un número entre 0 y 1114111")
		return null
	return String.chr(c)


static func _b_ord(vm: PyInterpreter, b: PyInterpreter.Builtin, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, "ord", args, kwargs, 1, 1):
		return null
	if typeof(args[0]) != TYPE_STRING:
		vm.raise_error("TypeError", "ord() necesita una cadena de un carácter, no '%s'" % vm.type_name(args[0]))
		return null
	var s: String = args[0]
	if s.length() != 1:
		vm.raise_error("TypeError", "ord() espera un solo carácter, pero la cadena tiene %d" % s.length())
		return null
	return s.unicode_at(0)


static func _b_divmod(vm: PyInterpreter, b: PyInterpreter.Builtin, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, "divmod", args, kwargs, 2, 2):
		return null
	var q: Variant = vm.binary_op("//", args[0], args[1])
	if vm.has_error():
		return null
	var m: Variant = vm.binary_op("%", args[0], args[1])
	if vm.has_error():
		return null
	return vm.make_tuple([q, m])


static func _b_pow(vm: PyInterpreter, b: PyInterpreter.Builtin, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, "pow", args, kwargs, 2, 3):
		return null
	if args.size() == 2:
		return vm.binary_op("**", args[0], args[1])
	return _pow_mod(vm, args[0], args[1], args[2])


static func _b_hex(vm: PyInterpreter, b: PyInterpreter.Builtin, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, b.name, args, kwargs, 1, 1):
		return null
	var v: Variant = _int_arg(vm, b.name, args[0])
	if v == null:
		return null
	var base := {"hex": 16, "bin": 2, "oct": 8}[b.name] as int
	var prefix := {"hex": "0x", "bin": "0b", "oct": "0o"}[b.name] as String
	return ("-" if v < 0 else "") + prefix + _int_to_base(absi(v) if v != PyNumber.INT_MIN else v, base)


static func _b_iter(vm: PyInterpreter, b: PyInterpreter.Builtin, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, "iter", args, kwargs, 1, 1):
		return null
	return vm.make_iter(args[0])


static func _b_next(vm: PyInterpreter, b: PyInterpreter.Builtin, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, "next", args, kwargs, 1, 2):
		return null
	if not (args[0] is PyInterpreter.Iter):
		vm.raise_error("TypeError", "next() necesita un iterador (usa iter(...)), no '%s'" % vm.type_name(args[0]))
		return null
	if vm.iter_next(args[0]):
		return vm._iter_value
	if vm.has_error():
		return null
	if args.size() == 2:
		return args[1]
	vm.raise_error("StopIteration", "el iterador no tiene más elementos")
	return null


static func _b_format(vm: PyInterpreter, b: PyInterpreter.Builtin, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, "format", args, kwargs, 1, 2):
		return null
	return format_value(vm, args[0], "" if args.size() == 1 else vm.py_str(args[1]))


static func _b_callable(vm: PyInterpreter, b: PyInterpreter.Builtin, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, "callable", args, kwargs, 1, 1):
		return null
	return vm.is_callable(args[0])


static func _len(vm: PyInterpreter, v: Variant) -> Variant:
	match typeof(v):
		TYPE_STRING:
			return (v as String).length()
		TYPE_ARRAY:
			return (v as Array).size()
		TYPE_DICTIONARY:
			return (v as Dictionary).size()
	if v is PyInterpreter.PySet:
		return (v as PyInterpreter.PySet).d.size()
	if v is PyInterpreter.PyRange:
		return (v as PyInterpreter.PyRange).length()
	if v is PyInterpreter.DictView:
		return (v as PyInterpreter.DictView).d.size()
	vm.raise_error("TypeError", "un valor de tipo '%s' no tiene longitud: len() no funciona con él" % vm.type_name(v))
	return null


static func type_of(vm: PyInterpreter, v: Variant) -> Variant:
	if v is PyInterpreter.Exc:
		return vm._builtins.get((v as PyInterpreter.Exc).type, PyInterpreter.ExcType.new((v as PyInterpreter.Exc).type))
	var tn := vm.type_name(v)
	if vm._builtins.has(tn) and vm._builtins[tn] is PyInterpreter.Builtin:
		return vm._builtins[tn]
	if not vm._modules.has("<type>" + tn):
		vm._modules["<type>" + tn] = PyInterpreter.Builtin.new(tn, "<type>")
	return vm._modules["<type>" + tn]


static func _isinstance(vm: PyInterpreter, obj: Variant, info: Variant) -> Variant:
	if typeof(info) == TYPE_ARRAY:
		for t: Variant in info:
			var r: Variant = _isinstance(vm, obj, t)
			if vm.has_error():
				return null
			if r:
				return true
		return false
	if info is PyInterpreter.ExcType:
		return obj is PyInterpreter.Exc and vm.exc_is_subclass((obj as PyInterpreter.Exc).type, (info as PyInterpreter.ExcType).name)
	if info is PyInterpreter.Builtin and TYPE_NAMES.has((info as PyInterpreter.Builtin).name):
		var want: String = (info as PyInterpreter.Builtin).name
		var tn := vm.type_name(obj)
		if want == "int" and tn == "bool":
			return true
		return tn == want
	vm.raise_error("TypeError", "el segundo argumento de isinstance() tiene que ser un tipo (int, str, list...) o una tupla de tipos")
	return null


static func _int_to_base(v: int, base: int) -> String:
	if v == 0:
		return "0"
	if v == PyNumber.INT_MIN:
		match base:
			2:
				return "1" + "0".repeat(63)
			8:
				return "1" + "0".repeat(21)
			16:
				return "8" + "0".repeat(15)
		return "9223372036854775808"
	var digits := "0123456789abcdef"
	var s := ""
	while v > 0:
		s = digits[v % base] + s
		v = v / base
	return s


static func _pow_mod(vm: PyInterpreter, a: Variant, e: Variant, m: Variant) -> Variant:
	if not (PyInterpreter.is_int_like(a) and PyInterpreter.is_int_like(e) and PyInterpreter.is_int_like(m)):
		vm.raise_error("TypeError", "pow() con 3 argumentos solo funciona con enteros")
		return null
	var mod := int(m)
	var ex := int(e)
	if mod == 0:
		vm.raise_error("ValueError", "el tercer argumento de pow() no puede ser 0")
		return null
	if ex < 0:
		vm.raise_error("ValueError", "pow() con módulo y exponente negativo no está disponible en el Dojo")
		return null
	var am := absi(mod)
	var result := 1 % am
	var base := int(a) % am
	if base < 0:
		base += am
	while ex > 0:
		if ex & 1:
			result = _mulmod(result, base, am)
		base = _mulmod(base, base, am)
		ex = ex >> 1
	if mod < 0 and result != 0:
		result += mod
	return result


static func _mulmod(a: int, b: int, m: int) -> int:
	if m <= 3037000499:
		return (a * b) % m
	var r := 0
	a = a % m
	while b > 0:
		if b & 1:
			r = (r + a) % m if r <= m - a else r - (m - a)
		a = a + a if a < m - a else a - (m - a)
		b = b >> 1
	return r


static func _to_int(vm: PyInterpreter, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, "int", args, kwargs, 0, 2, ["base"]):
		return null
	if args.is_empty():
		return 0
	var v: Variant = args[0]
	var has_base := args.size() == 2 or kwargs.has("base")
	if has_base:
		var bv: Variant = args[1] if args.size() == 2 else kwargs["base"]
		if typeof(v) != TYPE_STRING:
			vm.raise_error("TypeError", "int() con base solo funciona con cadenas")
			return null
		var base: Variant = _int_arg(vm, "int", bv)
		if base == null:
			return null
		if base != 0 and (base < 2 or base > 36):
			vm.raise_error("ValueError", "la base de int() tiene que estar entre 2 y 36 (o ser 0)")
			return null
		return _parse_int_or_error(vm, v, base)
	match typeof(v):
		TYPE_INT:
			return v
		TYPE_BOOL:
			return int(v)
		TYPE_FLOAT:
			return float_to_int(vm, v)
		TYPE_STRING:
			return _parse_int_or_error(vm, v, 10)
	vm.raise_error("TypeError", "int() necesita un número o una cadena, no '%s'" % vm.type_name(v))
	return null


static func float_to_int(vm: PyInterpreter, f: float) -> Variant:
	if is_nan(f):
		vm.raise_error("ValueError", "no se puede convertir NaN (nan) en un entero")
		return null
	if is_inf(f):
		vm.raise_error("OverflowError", "no se puede convertir infinito en un entero")
		return null
	var t := f
	if t >= 9.2233720368547758e18 or t < -9.2233720368547758e18:
		vm.raise_error("OverflowError", "el número es demasiado grande para los enteros del Dojo")
		return null
	return int(t)


static func _parse_int_or_error(vm: PyInterpreter, s: String, base: int) -> Variant:
	var r: Array = PyNumber.parse_int(s, base)
	match int(r[0]):
		0:
			return r[1]
		2:
			vm.raise_error("OverflowError", "el número es demasiado grande para los enteros del Dojo (máximo 9223372036854775807)")
			return null
	vm.raise_error("ValueError", "texto no válido para int() en base %d: %s" % [base if base != 0 else 10, vm.py_repr(s)])
	return null


static func _minmax(vm: PyInterpreter, fname: String, args: Array, kwargs: Dictionary) -> Variant:
	for k: String in kwargs:
		if k != "key" and k != "default":
			vm.raise_error("TypeError", "%s() no acepta el argumento '%s'" % [fname, k])
			return null
	if args.is_empty():
		vm.raise_error("TypeError", "%s() necesita al menos 1 argumento" % fname)
		return null
	var items: Array = []
	if args.size() == 1:
		var r: Variant = vm.to_array(args[0])
		if vm.has_error():
			return null
		items = r
	else:
		if kwargs.has("default"):
			vm.raise_error("TypeError", "%s() no acepta default si se le pasan varios valores" % fname)
			return null
		items = args
	if items.is_empty():
		if kwargs.has("default"):
			return kwargs["default"]
		vm.raise_error("ValueError", "%s() de una secuencia vacía: no hay ningún valor que elegir" % fname)
		return null
	var key: Variant = kwargs.get("key", null)
	var op := ">" if fname == "max" else "<"
	var best: Variant = items[0]
	var best_k: Variant = best if key == null else vm.call_sync(key, [best], {})
	if vm.has_error():
		return null
	for i in range(1, items.size()):
		var x: Variant = items[i]
		var k: Variant = x if key == null else vm.call_sync(key, [x], {})
		if vm.has_error():
			return null
		if vm.py_order(op, k, best_k):
			best = x
			best_k = k
		if vm.has_error():
			return null
		if not vm.tick_work(1):
			return null
	return best


static func _sum(vm: PyInterpreter, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, "sum", args, kwargs, 1, 2, ["start"]):
		return null
	var result: Variant = args[1] if args.size() == 2 else kwargs.get("start", 0)
	if typeof(result) == TYPE_STRING:
		vm.raise_error("TypeError", "sum() no sirve para unir cadenas: usa ''.join(lista)")
		return null
	var it := vm.make_iter(args[0])
	if it == null:
		return null
	# enteros
	if PyInterpreter.is_int_like(result):
		var acc := int(result)
		var pending := false
		while vm.iter_next(it):
			var x: Variant = vm._iter_value
			if PyInterpreter.is_int_like(x):
				var r: Variant = vm.int_op("+", acc, int(x))
				if vm.has_error():
					return null
				acc = r
				if not vm.tick_work(1):
					return null
				continue
			result = vm.binary_op("+", acc, x)
			if vm.has_error():
				return null
			pending = true
			break
		if vm.has_error():
			return null
		if not pending:
			return acc
	# floats con suma compensada (Neumaier), como CPython 3.12+
	if typeof(result) == TYPE_FLOAT:
		var f: float = result
		var c := 0.0
		var generic := false
		while vm.iter_next(it):
			var x: Variant = vm._iter_value
			if typeof(x) == TYPE_FLOAT or PyInterpreter.is_int_like(x):
				var xf := float(x)
				var t := f + xf
				if absf(f) >= absf(xf):
					c += (f - t) + xf
				else:
					c += (xf - t) + f
				f = t
				if not vm.tick_work(1):
					return null
				continue
			if c != 0.0 and is_finite(c):
				f += c
			result = vm.binary_op("+", f, x)
			if vm.has_error():
				return null
			generic = true
			break
		if vm.has_error():
			return null
		if not generic:
			if c != 0.0 and is_finite(c):
				f += c
			return f
	while vm.iter_next(it):
		result = vm.binary_op("+", result, vm._iter_value)
		if vm.has_error():
			return null
		if not vm.tick_work(1):
			return null
	if vm.has_error():
		return null
	return result


static func _round(vm: PyInterpreter, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, "round", args, kwargs, 1, 2, ["ndigits"]):
		return null
	var x: Variant = args[0]
	var nd: Variant = args[1] if args.size() == 2 else kwargs.get("ndigits", null)
	if nd != null and not PyInterpreter.is_int_like(nd):
		vm.raise_error("TypeError", "el número de decimales de round() tiene que ser un entero")
		return null
	match typeof(x):
		TYPE_INT, TYPE_BOOL:
			var iv := int(x)
			if nd == null or int(nd) >= 0:
				return iv
			var p := int(nd)
			if -p >= 19:
				return 0
			var m := 1
			for _i in -p:
				m *= 10
			var q: int = vm.int_op("//", iv, m)
			var r := iv - q * m
			var half := m / 2
			if r > half or (r == half and q % 2 != 0):
				q += 1
			var res: Variant = vm.mul_int(q, m)
			return res
		TYPE_FLOAT:
			var f: float = x
			if nd == null:
				if is_nan(f):
					vm.raise_error("ValueError", "no se puede redondear NaN a un entero")
					return null
				if is_inf(f):
					vm.raise_error("OverflowError", "no se puede redondear infinito a un entero")
					return null
				return float_to_int(vm, PyNumber.round_half_even(f))
			return PyNumber.round_ndigits(f, int(nd))
	vm.raise_error("TypeError", "round() necesita un número, no '%s'" % vm.type_name(x))
	return null


## Ordenación estable (mergesort) con key y reverse, como list.sort de Python.
static func sort_values(vm: PyInterpreter, items: Array, key_fn: Variant, reverse: bool) -> Variant:
	var n := items.size()
	var keys: Array = items
	if key_fn != null:
		if not vm.is_callable(key_fn):
			vm.raise_error("TypeError", "key= tiene que ser una función (por ejemplo key=len o key=lambda x: x[1])")
			return null
		keys = []
		for x: Variant in items:
			var k: Variant = vm.call_sync(key_fn, [x], {})
			if vm.has_error():
				return null
			keys.append(k)
	var idx := PackedInt64Array()
	idx.resize(n)
	for i in n:
		idx[i] = i
	var tmp := PackedInt64Array()
	tmp.resize(n)
	var width := 1
	while width < n:
		var lo := 0
		while lo < n:
			var mid := mini(lo + width, n)
			var hi := mini(lo + 2 * width, n)
			var i := lo
			var j := mid
			var k := lo
			while i < mid and j < hi:
				var take_right := false
				if reverse:
					take_right = vm.py_lt(keys[idx[i]], keys[idx[j]])
				else:
					take_right = vm.py_lt(keys[idx[j]], keys[idx[i]])
				if vm.has_error():
					return null
				if take_right:
					tmp[k] = idx[j]
					j += 1
				else:
					tmp[k] = idx[i]
					i += 1
				k += 1
			while i < mid:
				tmp[k] = idx[i]
				i += 1
				k += 1
			while j < hi:
				tmp[k] = idx[j]
				j += 1
				k += 1
			if not vm.tick_work(hi - lo):
				return null
			lo += 2 * width
		var sw := idx
		idx = tmp
		tmp = sw
		width *= 2
	var out: Array = []
	out.resize(n)
	for i in n:
		out[i] = items[idx[i]]
	return out


static func _dict_update(vm: PyInterpreter, d: Dictionary, src: Variant) -> bool:
	if typeof(src) == TYPE_DICTIONARY:
		for k: Variant in src:
			d[k] = src[k]
		return true
	var items: Variant = vm.to_array(src)
	if vm.has_error():
		return false
	var i := 0
	for pair: Variant in items:
		var p: Variant = vm.to_array(pair)
		if vm.has_error():
			vm._exc = null
			vm.raise_error("TypeError", "para crear un diccionario cada elemento tiene que ser un par (clave, valor)")
			return false
		if (p as Array).size() != 2:
			vm.raise_error("ValueError", "el elemento %d tiene %d valores y para crear un diccionario hacen falta 2 (clave, valor)" % [i, (p as Array).size()])
			return false
		vm.dict_set(d, p[0], p[1])
		if vm.has_error():
			return false
		i += 1
	return true


# ── Atributos y métodos ──────────────────────────────────────────────────────

static func get_attr(vm: PyInterpreter, obj: Variant, name: String) -> Variant:
	if obj is PyInterpreter.Module:
		var m: PyInterpreter.Module = obj
		if m.members.has(name):
			return m.members[name]
		vm.raise_error("AttributeError", "el módulo '%s' no tiene '%s' en el Dojo" % [m.name, name])
		return null
	if name == "__name__":
		if obj is PyInterpreter.Func:
			return (obj as PyInterpreter.Func).name
		if obj is PyInterpreter.Builtin:
			return (obj as PyInterpreter.Builtin).name
		if obj is PyInterpreter.ExcType:
			return (obj as PyInterpreter.ExcType).name
	if obj is PyInterpreter.Exc and name == "args":
		return vm.make_tuple((obj as PyInterpreter.Exc).args)
	if obj is PyInterpreter.Builtin and (obj as PyInterpreter.Builtin).module.is_empty() and METHODS.has((obj as PyInterpreter.Builtin).name):
		# método sin enlazar, p. ej. str.lower para key=str.lower
		var tname: String = (obj as PyInterpreter.Builtin).name
		if (METHODS[tname] as Array).has(name):
			return PyInterpreter.Builtin.new(name, "unbound:" + tname)
	var tn := vm.type_name(obj)
	var table: Array = METHODS.get(tn, [])
	if table.has(name):
		return PyInterpreter.Method.new(obj, name)
	var msg := "un valor de tipo '%s' no tiene el atributo o método '%s'" % [tn, name]
	if ATTR_HINTS.has(name):
		msg += ": ¿quizás buscas %s?" % ATTR_HINTS[name]
	vm.raise_error("AttributeError", msg)
	return null


static func call_method(vm: PyInterpreter, obj: Variant, name: String, args: Array, kwargs: Dictionary) -> Variant:
	match typeof(obj):
		TYPE_STRING:
			return _str_method(vm, obj, name, args, kwargs)
		TYPE_ARRAY:
			if (obj as Array).is_read_only():
				return _seq_count_index(vm, obj, name, args, kwargs, "tupla")
			return _list_method(vm, obj, name, args, kwargs)
		TYPE_DICTIONARY:
			return _dict_method(vm, obj, name, args, kwargs)
		TYPE_INT, TYPE_BOOL:
			if not _check(vm, name, args, kwargs, 0, 0):
				return null
			var v := absi(int(obj))
			var bits := 0
			while v > 0:
				bits += 1
				v = v >> 1
			return bits
		TYPE_FLOAT:
			if not _check(vm, name, args, kwargs, 0, 0):
				return null
			var f: float = obj
			return is_finite(f) and f == floorf(f)
	if obj is PyInterpreter.PySet:
		return _set_method(vm, obj, name, args, kwargs)
	if obj is PyInterpreter.PyRange:
		var items: Variant = vm.to_array(obj)
		if vm.has_error():
			return null
		return _seq_count_index(vm, items, name, args, kwargs, "range")
	vm.raise_error("AttributeError", "método desconocido '%s'" % name)
	return null


static func _seq_count_index(vm: PyInterpreter, a: Array, name: String, args: Array, kwargs: Dictionary, what: String) -> Variant:
	if name == "count":
		if not _check(vm, "count", args, kwargs, 1, 1):
			return null
		var n := 0
		for x: Variant in a:
			if vm.py_eq(x, args[0]):
				n += 1
		vm.tick_work(a.size())
		return n
	if not _check(vm, "index", args, kwargs, 1, 3):
		return null
	var start := 0
	var stop := a.size()
	if args.size() > 1:
		var sv: Variant = _int_arg(vm, "index", args[1])
		if sv == null:
			return null
		start = sv if sv >= 0 else maxi(0, a.size() + sv)
	if args.size() > 2:
		var ev: Variant = _int_arg(vm, "index", args[2])
		if ev == null:
			return null
		stop = mini(a.size(), ev if ev >= 0 else a.size() + ev)
	for i in range(start, stop):
		if vm.py_eq(a[i], args[0]):
			return i
	vm.tick_work(a.size())
	vm.raise_error("ValueError", "%s no está en la %s" % [vm.py_repr(args[0]), what if what != "range" else "secuencia"])
	return null


static func _list_method(vm: PyInterpreter, a: Array, name: String, args: Array, kwargs: Dictionary) -> Variant:
	var fn: Variant = _LIST_TABLE.get(name)
	if fn != null:
		return (fn as Callable).call(vm, a, name, args, kwargs)
	return null


static var _LIST_TABLE := {
	"append": _lm_append,
	"extend": _lm_extend,
	"pop": _lm_pop,
	"insert": _lm_insert,
	"index": _lm_index,
	"count": _lm_index,
	"sort": _lm_sort,
	"reverse": _lm_reverse,
	"remove": _lm_remove,
	"clear": _lm_clear,
	"copy": _lm_copy,
}


static func _lm_append(vm: PyInterpreter, a: Array, name: String, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, "append", args, kwargs, 1, 1):
		return null
	a.append(args[0])
	if a.size() > PyInterpreter.MAX_ITEMS:
		vm._memory_error()
	return null


static func _lm_extend(vm: PyInterpreter, a: Array, name: String, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, "extend", args, kwargs, 1, 1):
		return null
	var items: Variant = vm.to_array(args[0])
	if vm.has_error():
		return null
	a.append_array(items)
	if a.size() > PyInterpreter.MAX_ITEMS:
		vm._memory_error()
	return null


static func _lm_pop(vm: PyInterpreter, a: Array, name: String, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, "pop", args, kwargs, 0, 1):
		return null
	if a.is_empty():
		vm.raise_error("IndexError", "no se puede hacer pop() de una lista vacía")
		return null
	var i := a.size() - 1
	if args.size() == 1:
		var iv: Variant = _int_arg(vm, "pop", args[0])
		if iv == null:
			return null
		i = iv
		if i < 0:
			i += a.size()
		if i < 0 or i >= a.size():
			vm.raise_error("IndexError", "índice de pop() fuera de rango: %d (la lista tiene %d elementos)" % [int(iv), a.size()])
			return null
	var v: Variant = a[i]
	a.remove_at(i)
	return v


static func _lm_insert(vm: PyInterpreter, a: Array, name: String, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, "insert", args, kwargs, 2, 2):
		return null
	var iv: Variant = _int_arg(vm, "insert", args[0])
	if iv == null:
		return null
	var i: int = iv
	if i < 0:
		i = maxi(0, i + a.size())
	i = mini(i, a.size())
	a.insert(i, args[1])
	return null


static func _lm_index(vm: PyInterpreter, a: Array, name: String, args: Array, kwargs: Dictionary) -> Variant:
	return _seq_count_index(vm, a, name, args, kwargs, "lista")


static func _lm_sort(vm: PyInterpreter, a: Array, name: String, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, "sort", args, kwargs, 0, 0, ["key", "reverse"]):
		if args.size() > 0 and kwargs.is_empty():
			vm._exc = null
			vm.raise_error("TypeError", "sort() no acepta argumentos posicionales: usa key=... o reverse=True")
		return null
	var sorted_items: Variant = sort_values(vm, a, kwargs.get("key", null), vm.truthy(kwargs.get("reverse", false)))
	if vm.has_error():
		return null
	a.assign(sorted_items)
	return null


static func _lm_reverse(vm: PyInterpreter, a: Array, name: String, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, "reverse", args, kwargs, 0, 0):
		return null
	a.reverse()
	return null


static func _lm_remove(vm: PyInterpreter, a: Array, name: String, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, "remove", args, kwargs, 1, 1):
		return null
	for i in a.size():
		if vm.py_eq(a[i], args[0]):
			a.remove_at(i)
			return null
	vm.raise_error("ValueError", "list.remove(x): %s no está en la lista" % vm.py_repr(args[0]))
	return null


static func _lm_clear(vm: PyInterpreter, a: Array, name: String, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, "clear", args, kwargs, 0, 0):
		return null
	a.clear()
	return null


static func _lm_copy(vm: PyInterpreter, a: Array, name: String, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, "copy", args, kwargs, 0, 0):
		return null
	return a.duplicate()


static func _dict_method(vm: PyInterpreter, d: Dictionary, name: String, args: Array, kwargs: Dictionary) -> Variant:
	var fn: Variant = _DICT_TABLE.get(name)
	if fn != null:
		return (fn as Callable).call(vm, d, name, args, kwargs)
	return null


static var _DICT_TABLE := {
	"get": _dm_get,
	"keys": _dm_keys,
	"values": _dm_keys,
	"items": _dm_keys,
	"pop": _dm_pop,
	"setdefault": _dm_setdefault,
	"update": _dm_update,
	"clear": _dm_clear,
	"copy": _dm_copy,
	"popitem": _dm_popitem,
}


static func _dm_get(vm: PyInterpreter, d: Dictionary, name: String, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, "get", args, kwargs, 1, 2):
		return null
	return vm.dict_get(d, args[0], args[1] if args.size() == 2 else null, false)


static func _dm_keys(vm: PyInterpreter, d: Dictionary, name: String, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, name, args, kwargs, 0, 0):
		return null
	var dv := PyInterpreter.DictView.new()
	dv.d = d
	dv.kind = name
	return dv


static func _dm_pop(vm: PyInterpreter, d: Dictionary, name: String, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, "pop", args, kwargs, 1, 2):
		return null
	if not vm.check_hashable(args[0]):
		return null
	if vm.dict_has(d, args[0]):
		var v: Variant = vm.dict_get(d, args[0], null, true)
		vm.dict_erase(d, args[0])
		return v
	if args.size() == 2:
		return args[1]
	vm.raise_error("KeyError", "la clave %s no existe en el diccionario" % vm.py_repr(args[0]))
	return null


static func _dm_setdefault(vm: PyInterpreter, d: Dictionary, name: String, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, "setdefault", args, kwargs, 1, 2):
		return null
	if vm.dict_has(d, args[0]):
		return vm.dict_get(d, args[0], null, true)
	if vm.has_error():
		return null
	var dv: Variant = args[1] if args.size() == 2 else null
	vm.dict_set(d, args[0], dv)
	return dv


static func _dm_update(vm: PyInterpreter, d: Dictionary, name: String, args: Array, kwargs: Dictionary) -> Variant:
	if args.size() > 1:
		vm.raise_error("TypeError", "update() acepta como mucho 1 argumento posicional")
		return null
	if args.size() == 1:
		if typeof(args[0]) == TYPE_DICTIONARY:
			for k: Variant in args[0]:
				vm.dict_set(d, k, args[0][k])
		elif not _dict_update(vm, d, args[0]):
			return null
	for k: String in kwargs:
		vm.dict_set(d, k, kwargs[k])
	return null


static func _dm_clear(vm: PyInterpreter, d: Dictionary, name: String, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, "clear", args, kwargs, 0, 0):
		return null
	d.clear()
	return null


static func _dm_copy(vm: PyInterpreter, d: Dictionary, name: String, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, "copy", args, kwargs, 0, 0):
		return null
	return d.duplicate()


static func _dm_popitem(vm: PyInterpreter, d: Dictionary, name: String, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, "popitem", args, kwargs, 0, 0):
		return null
	if d.is_empty():
		vm.raise_error("KeyError", "popitem(): el diccionario está vacío")
		return null
	var k: Variant = d.keys().back()
	var v: Variant = d[k]
	d.erase(k)
	return vm.make_tuple([k, v])


static func _set_method(vm: PyInterpreter, s: PyInterpreter.PySet, name: String, args: Array, kwargs: Dictionary) -> Variant:
	var fn: Variant = _SET_TABLE.get(name)
	if fn != null:
		return (fn as Callable).call(vm, s, name, args, kwargs)
	return null


static var _SET_TABLE := {
	"add": _setm_add,
	"remove": _setm_remove,
	"discard": _setm_remove,
	"pop": _setm_pop,
	"clear": _setm_clear,
	"copy": _setm_copy,
	"union": _setm_union,
	"intersection": _setm_union,
	"difference": _setm_union,
	"symmetric_difference": _setm_union,
	"update": _setm_union,
	"issubset": _setm_issubset,
	"issuperset": _setm_issubset,
	"isdisjoint": _setm_issubset,
}


static func _setm_add(vm: PyInterpreter, s: PyInterpreter.PySet, name: String, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, "add", args, kwargs, 1, 1):
		return null
	vm.set_add(s, args[0])
	return null


static func _setm_remove(vm: PyInterpreter, s: PyInterpreter.PySet, name: String, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, name, args, kwargs, 1, 1):
		return null
	if not vm.check_hashable(args[0]):
		return null
	var found: Variant = vm._find_key_real(s.d, args[0])
	if found == null:
		if name == "remove":
			vm.raise_error("KeyError", "%s no está en el set" % vm.py_repr(args[0]))
		return null
	s.d.erase(found[0])
	return null


static func _setm_pop(vm: PyInterpreter, s: PyInterpreter.PySet, name: String, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, "pop", args, kwargs, 0, 0):
		return null
	if s.d.is_empty():
		vm.raise_error("KeyError", "pop() de un set vacío")
		return null
	var k: Variant = s.d.keys()[0]
	s.d.erase(k)
	return k


static func _setm_clear(vm: PyInterpreter, s: PyInterpreter.PySet, name: String, args: Array, kwargs: Dictionary) -> Variant:
	s.d.clear()
	return null


static func _setm_copy(vm: PyInterpreter, s: PyInterpreter.PySet, name: String, args: Array, kwargs: Dictionary) -> Variant:
	var c := PyInterpreter.PySet.new()
	c.d = s.d.duplicate()
	return c


static func _setm_union(vm: PyInterpreter, s: PyInterpreter.PySet, name: String, args: Array, kwargs: Dictionary) -> Variant:
	var op := {"union": "|", "update": "|", "intersection": "&", "difference": "-", "symmetric_difference": "^"}[name] as String
	var result := s
	if name != "update":
		result = PyInterpreter.PySet.new()
		result.d = s.d.duplicate()
	for other: Variant in args:
		var items: Variant = vm.to_array(other)
		if vm.has_error():
			return null
		var os := vm.make_set(items)
		if os == null:
			return null
		var r: PyInterpreter.PySet = vm.binary_op(op, result, os)
		result.d = r.d
	return null if name == "update" else result


static func _setm_issubset(vm: PyInterpreter, s: PyInterpreter.PySet, name: String, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, name, args, kwargs, 1, 1):
		return null
	var items: Variant = vm.to_array(args[0])
	if vm.has_error():
		return null
	var os := vm.make_set(items)
	if os == null:
		return null
	match name:
		"issubset":
			return vm.py_order("<=", s, os)
		"issuperset":
			return vm.py_order(">=", s, os)
		_:
			var inter: PyInterpreter.PySet = vm.binary_op("&", s, os)
			return inter.d.is_empty()
	return null


static func _is_ws(c: String) -> bool:
	return c == " " or c == "\t" or c == "\n" or c == "\r" or c == "\f" or c == "\v" or c.unicode_at(0) == 0xA0


static func _ws_split(s: String, maxsplit: int, from_right: bool) -> Array:
	var words: Array = []
	if from_right:
		var i := s.length() - 1
		while i >= 0:
			while i >= 0 and _is_ws(s[i]):
				i -= 1
			if i < 0:
				break
			if maxsplit >= 0 and words.size() == maxsplit:
				var rest := s.substr(0, i + 1)
				var a := 0
				while a < rest.length() and _is_ws(rest[a]):
					a += 1
				words.push_front(rest.substr(a))
				return words
			var end := i
			while i >= 0 and not _is_ws(s[i]):
				i -= 1
			words.push_front(s.substr(i + 1, end - i))
		return words
	var j := 0
	var n := s.length()
	while j < n:
		while j < n and _is_ws(s[j]):
			j += 1
		if j >= n:
			break
		if maxsplit >= 0 and words.size() == maxsplit:
			var rest := s.substr(j)
			var b := rest.length()
			while b > 0 and _is_ws(rest[b - 1]):
				b -= 1
			words.append(rest.substr(0, b))
			return words
		var start := j
		while j < n and not _is_ws(s[j]):
			j += 1
		words.append(s.substr(start, j - start))
	return words


static func _is_cased_upper(c: String) -> bool:
	return c != c.to_lower() and c == c.to_upper()


static func _is_cased_lower(c: String) -> bool:
	return c != c.to_upper() and c == c.to_lower()


static func _str_arg(vm: PyInterpreter, fname: String, v: Variant) -> Variant:
	if typeof(v) == TYPE_STRING:
		return v
	vm.raise_error("TypeError", "%s() necesita una cadena, no '%s'" % [fname, vm.type_name(v)])
	return null


static func _str_method(vm: PyInterpreter, s: String, name: String, args: Array, kwargs: Dictionary) -> Variant:
	var fn: Variant = _STR_TABLE.get(name)
	if fn != null:
		return (fn as Callable).call(vm, s, name, args, kwargs)
	return null


static var _STR_TABLE := {
	"lower": _sm_lower,
	"casefold": _sm_lower,
	"upper": _sm_upper,
	"swapcase": _sm_swapcase,
	"strip": _sm_strip,
	"lstrip": _sm_strip,
	"rstrip": _sm_strip,
	"split": _sm_split,
	"rsplit": _sm_split,
	"splitlines": _sm_splitlines,
	"join": _sm_join,
	"replace": _sm_replace,
	"startswith": _sm_startswith,
	"endswith": _sm_startswith,
	"count": _sm_count,
	"find": _sm_find,
	"index": _sm_find,
	"rfind": _sm_find,
	"rindex": _sm_find,
	"isdigit": _sm_isdigit,
	"isnumeric": _sm_isdigit,
	"isdecimal": _sm_isdigit,
	"isalpha": _sm_isalpha,
	"isalnum": _sm_isalpha,
	"isspace": _sm_isspace,
	"isupper": _sm_isupper,
	"islower": _sm_isupper,
	"title": _sm_title,
	"capitalize": _sm_capitalize,
	"center": _sm_center,
	"ljust": _sm_center,
	"rjust": _sm_center,
	"zfill": _sm_zfill,
	"format": _sm_format,
	"partition": _sm_partition,
	"rpartition": _sm_partition,
	"removeprefix": _sm_removeprefix,
	"removesuffix": _sm_removesuffix,
}


static func _sm_lower(vm: PyInterpreter, s: String, name: String, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, name, args, kwargs, 0, 0):
		return null
	return s.to_lower()


static func _sm_upper(vm: PyInterpreter, s: String, name: String, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, name, args, kwargs, 0, 0):
		return null
	return s.to_upper()


static func _sm_swapcase(vm: PyInterpreter, s: String, name: String, args: Array, kwargs: Dictionary) -> Variant:
	var out := ""
	for i in s.length():
		var c := s[i]
		out += c.to_lower() if _is_cased_upper(c) else c.to_upper()
	return out


static func _sm_strip(vm: PyInterpreter, s: String, name: String, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, name, args, kwargs, 0, 1):
		return null
	var chars: Variant = args[0] if args.size() == 1 else null
	if chars == null:
		var a := 0
		var b := s.length()
		if name != "rstrip":
			while a < b and _is_ws(s[a]):
				a += 1
		if name != "lstrip":
			while b > a and _is_ws(s[b - 1]):
				b -= 1
		return s.substr(a, b - a)
	if _str_arg(vm, name, chars) == null:
		return null
	var r := s
	if name != "rstrip":
		r = r.lstrip(chars)
	if name != "lstrip":
		r = r.rstrip(chars)
	return r


static func _sm_split(vm: PyInterpreter, s: String, name: String, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, name, args, kwargs, 0, 2, ["sep", "maxsplit"]):
		return null
	var sep: Variant = args[0] if args.size() > 0 else kwargs.get("sep", null)
	var msv: Variant = args[1] if args.size() > 1 else kwargs.get("maxsplit", -1)
	var maxsplit: Variant = _int_arg(vm, name, msv)
	if maxsplit == null:
		return null
	if sep == null:
		return _ws_split(s, maxsplit, name == "rsplit")
	if _str_arg(vm, name, sep) == null:
		return null
	if (sep as String).is_empty():
		vm.raise_error("ValueError", "el separador de split() no puede ser una cadena vacía")
		return null
	if maxsplit == 0:
		return [s]
	var parts: PackedStringArray
	if name == "split":
		parts = s.split(sep, true, maxi(0, maxsplit))
	else:
		parts = s.rsplit(sep, true, maxi(0, maxsplit))
	return Array(parts)


static func _sm_splitlines(vm: PyInterpreter, s: String, name: String, args: Array, kwargs: Dictionary) -> Variant:
	var t := s.replace("\r\n", "\n").replace("\r", "\n")
	var parts := t.split("\n")
	var out: Array = Array(parts)
	if not out.is_empty() and t.ends_with("\n"):
		out.pop_back()
	return out


static func _sm_join(vm: PyInterpreter, s: String, name: String, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, "join", args, kwargs, 1, 1):
		return null
	var items: Variant = vm.to_array(args[0])
	if vm.has_error():
		return null
	var parts := PackedStringArray()
	var i := 0
	for x: Variant in items:
		if typeof(x) != TYPE_STRING:
			vm.raise_error("TypeError", "join() solo une cadenas, pero el elemento %d es de tipo '%s': conviértelo con str(...)" % [i, vm.type_name(x)])
			return null
		parts.append(x)
		i += 1
	return s.join(parts)


static func _sm_replace(vm: PyInterpreter, s: String, name: String, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, "replace", args, kwargs, 2, 3, ["count"]):
		return null
	if _str_arg(vm, "replace", args[0]) == null or _str_arg(vm, "replace", args[1]) == null:
		return null
	var old: String = args[0]
	var new: String = args[1]
	var cv: Variant = args[2] if args.size() == 3 else kwargs.get("count", -1)
	var count: Variant = _int_arg(vm, "replace", cv)
	if count == null:
		return null
	if count < 0 and not old.is_empty():
		return s.replace(old, new)
	var out := ""
	var done := 0
	if old.is_empty():
		for i in s.length():
			if count < 0 or done < count:
				out += new
				done += 1
			out += s[i]
		if count < 0 or done < count:
			out += new
		return out
	var pos := 0
	while count < 0 or done < count:
		var f := s.find(old, pos)
		if f < 0:
			break
		out += s.substr(pos, f - pos) + new
		pos = f + old.length()
		done += 1
	return out + s.substr(pos)


static func _sm_startswith(vm: PyInterpreter, s: String, name: String, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, name, args, kwargs, 1, 1):
		return null
	var opts: Array = []
	if typeof(args[0]) == TYPE_ARRAY:
		opts = args[0]
	else:
		opts = [args[0]]
	for o: Variant in opts:
		if _str_arg(vm, name, o) == null:
			return null
		if (name == "startswith" and s.begins_with(o)) or (name == "endswith" and s.ends_with(o)):
			return true
	return false


static func _sm_count(vm: PyInterpreter, s: String, name: String, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, "count", args, kwargs, 1, 1):
		return null
	if _str_arg(vm, "count", args[0]) == null:
		return null
	var sub: String = args[0]
	if sub.is_empty():
		return s.length() + 1
	var n := 0
	var pos := s.find(sub)
	while pos >= 0:
		n += 1
		pos = s.find(sub, pos + sub.length())
	return n


static func _sm_find(vm: PyInterpreter, s: String, name: String, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, name, args, kwargs, 1, 3):
		return null
	if _str_arg(vm, name, args[0]) == null:
		return null
	var start := 0
	var stop := s.length()
	if args.size() > 1 and args[1] != null:
		var sv: Variant = _int_arg(vm, name, args[1])
		if sv == null:
			return null
		start = sv if sv >= 0 else maxi(0, s.length() + sv)
	if args.size() > 2 and args[2] != null:
		var ev: Variant = _int_arg(vm, name, args[2])
		if ev == null:
			return null
		stop = clampi(ev if ev >= 0 else s.length() + ev, 0, s.length())
	var region := s.substr(0, stop)
	var r := -1
	if start <= region.length():
		if name.begins_with("r"):
			r = region.rfind(args[0])
			if r < start:
				r = -1
		else:
			r = region.find(args[0], start)
	if r < 0 and name.ends_with("index"):
		vm.raise_error("ValueError", "la subcadena %s no está en la cadena" % vm.py_repr(args[0]))
		return null
	return r


static func _sm_isdigit(vm: PyInterpreter, s: String, name: String, args: Array, kwargs: Dictionary) -> Variant:
	if s.is_empty():
		return false
	for i in s.length():
		var u := s.unicode_at(i)
		if u < 48 or u > 57:
			return false
	return true


static func _sm_isalpha(vm: PyInterpreter, s: String, name: String, args: Array, kwargs: Dictionary) -> Variant:
	if s.is_empty():
		return false
	for i in s.length():
		var c := s[i]
		var is_letter := c.to_upper() != c.to_lower() or (c.unicode_at(0) >= 0x3040 and c.unicode_at(0) < 0xFFFF and not _is_ws(c))
		var is_digit := c.unicode_at(0) >= 48 and c.unicode_at(0) <= 57
		if not (is_letter or (name == "isalnum" and is_digit)):
			return false
	return true


static func _sm_isspace(vm: PyInterpreter, s: String, name: String, args: Array, kwargs: Dictionary) -> Variant:
	if s.is_empty():
		return false
	for i in s.length():
		if not _is_ws(s[i]):
			return false
	return true


static func _sm_isupper(vm: PyInterpreter, s: String, name: String, args: Array, kwargs: Dictionary) -> Variant:
	var cased := false
	for i in s.length():
		var c := s[i]
		if _is_cased_upper(c):
			if name == "islower":
				return false
			cased = true
		elif _is_cased_lower(c):
			if name == "isupper":
				return false
			cased = true
	return cased


static func _sm_title(vm: PyInterpreter, s: String, name: String, args: Array, kwargs: Dictionary) -> Variant:
	var out := ""
	var prev_cased := false
	for i in s.length():
		var c := s[i]
		var is_cased := c.to_upper() != c.to_lower()
		if is_cased:
			out += c.to_lower() if prev_cased else c.to_upper()
		else:
			out += c
		prev_cased = is_cased
	return out


static func _sm_capitalize(vm: PyInterpreter, s: String, name: String, args: Array, kwargs: Dictionary) -> Variant:
	if s.is_empty():
		return s
	return s.substr(0, 1).to_upper() + s.substr(1).to_lower()


static func _sm_center(vm: PyInterpreter, s: String, name: String, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, name, args, kwargs, 1, 2):
		return null
	var wv: Variant = _int_arg(vm, name, args[0])
	if wv == null:
		return null
	var fill := " "
	if args.size() == 2:
		if typeof(args[1]) != TYPE_STRING or (args[1] as String).length() != 1:
			vm.raise_error("TypeError", "el carácter de relleno tiene que ser una cadena de exactamente 1 carácter")
			return null
		fill = args[1]
	var width: int = wv
	var marg := width - s.length()
	if marg <= 0:
		return s
	match name:
		"ljust":
			return s + fill.repeat(marg)
		"rjust":
			return fill.repeat(marg) + s
	var left := marg / 2 + (marg & width & 1)
	return fill.repeat(left) + s + fill.repeat(marg - left)


static func _sm_zfill(vm: PyInterpreter, s: String, name: String, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, "zfill", args, kwargs, 1, 1):
		return null
	var wv: Variant = _int_arg(vm, "zfill", args[0])
	if wv == null:
		return null
	var width: int = wv
	if s.length() >= width:
		return s
	var pad := "0".repeat(width - s.length())
	if s.begins_with("-") or s.begins_with("+"):
		return s.substr(0, 1) + pad + s.substr(1)
	return pad + s


static func _sm_format(vm: PyInterpreter, s: String, name: String, args: Array, kwargs: Dictionary) -> Variant:
	return str_format(vm, s, args, kwargs)


static func _sm_partition(vm: PyInterpreter, s: String, name: String, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, name, args, kwargs, 1, 1):
		return null
	if _str_arg(vm, name, args[0]) == null:
		return null
	var sep: String = args[0]
	if sep.is_empty():
		vm.raise_error("ValueError", "el separador no puede estar vacío")
		return null
	var p := s.find(sep) if name == "partition" else s.rfind(sep)
	if p < 0:
		return vm.make_tuple([s, "", ""] if name == "partition" else ["", "", s])
	return vm.make_tuple([s.substr(0, p), sep, s.substr(p + sep.length())])


static func _sm_removeprefix(vm: PyInterpreter, s: String, name: String, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, name, args, kwargs, 1, 1) or _str_arg(vm, name, args[0]) == null:
		return null
	return s.substr((args[0] as String).length()) if s.begins_with(args[0]) else s


static func _sm_removesuffix(vm: PyInterpreter, s: String, name: String, args: Array, kwargs: Dictionary) -> Variant:
	if not _check(vm, name, args, kwargs, 1, 1) or _str_arg(vm, name, args[0]) == null:
		return null
	var suf: String = args[0]
	return s.substr(0, s.length() - suf.length()) if (not suf.is_empty() and s.ends_with(suf)) else s


# ── Formato ──────────────────────────────────────────────────────────────────

## format(valor, especificación) con la mini-gramática de Python:
## [[relleno]alineación][signo][#][0][ancho][,|_][.precisión][tipo]
static func format_value(vm: PyInterpreter, v: Variant, spec: String) -> String:
	if spec.is_empty():
		return vm.py_str(v)
	var i := 0
	var n := spec.length()
	var fill := " "
	var align := ""
	if n >= 2 and spec[1] in ["<", ">", "=", "^"]:
		fill = spec[0]
		align = spec[1]
		i = 2
	elif n >= 1 and spec[0] in ["<", ">", "=", "^"]:
		align = spec[0]
		i = 1
	var sign := ""
	if i < n and spec[i] in ["+", "-", " "]:
		sign = spec[i]
		i += 1
	if i < n and spec[i] == "z":
		i += 1
	var alt := false
	if i < n and spec[i] == "#":
		alt = true
		i += 1
	var zero := false
	if i < n and spec[i] == "0":
		zero = true
		i += 1
	var width_s := ""
	while i < n and spec[i] >= "0" and spec[i] <= "9":
		width_s += spec[i]
		i += 1
	var grouping := ""
	if i < n and (spec[i] == "," or spec[i] == "_"):
		grouping = spec[i]
		i += 1
	var prec := -1
	if i < n and spec[i] == ".":
		i += 1
		var ps := ""
		while i < n and spec[i] >= "0" and spec[i] <= "9":
			ps += spec[i]
			i += 1
		if ps.is_empty():
			vm.raise_error("ValueError", "especificación de formato no válida: falta la precisión después de '.'")
			return ""
		prec = ps.to_int()
	var type := spec.substr(i)
	if type.length() > 1:
		vm.raise_error("ValueError", "especificación de formato no válida: '%s'" % spec)
		return ""
	var width := width_s.to_int() if not width_s.is_empty() else 0
	if zero and align.is_empty():
		fill = "0"
		align = "="
	var body := ""
	var neg := false
	var numeric := false
	var prefix := ""
	var tv := typeof(v)
	if tv == TYPE_BOOL and type.is_empty() and prec < 0 and sign.is_empty() and grouping.is_empty():
		tv = TYPE_INT
		v = int(v)
	elif tv == TYPE_BOOL:
		tv = TYPE_INT
		v = int(v)
	if tv == TYPE_STRING or (tv != TYPE_INT and tv != TYPE_FLOAT):
		if not type.is_empty() and type != "s":
			vm.raise_error("ValueError", "el código de formato '%s' no sirve para un valor de tipo '%s'" % [type, vm.type_name(v)])
			return ""
		if not sign.is_empty() or not grouping.is_empty() or align == "=":
			vm.raise_error("ValueError", "el signo, la agrupación y '=' solo sirven para números")
			return ""
		body = vm.py_str(v)
		if prec >= 0:
			body = body.substr(0, prec)
		if align.is_empty():
			align = "<"
	elif tv == TYPE_INT and type in ["", "d", "n", "b", "o", "x", "X", "c"]:
		numeric = true
		var iv: int = v
		if prec >= 0:
			vm.raise_error("ValueError", "los enteros no admiten precisión en el formato: usa {x:.2f} para decimales")
			return ""
		neg = iv < 0
		var mag := absi(iv)
		match type:
			"", "d", "n":
				body = str(mag) if iv != PyNumber.INT_MIN else "9223372036854775808"
				if not grouping.is_empty():
					body = _group(body, grouping, 3)
			"b", "o", "x", "X":
				var base := {"b": 2, "o": 8, "x": 16, "X": 16}[type] as int
				body = _int_to_base(mag, base)
				if type == "X":
					body = body.to_upper()
				if not grouping.is_empty():
					body = _group(body, grouping, 4)
				if alt:
					prefix = {"b": "0b", "o": "0o", "x": "0x", "X": "0X"}[type]
			"c":
				body = String.chr(iv)
				numeric = false
	elif tv == TYPE_INT or tv == TYPE_FLOAT:
		if not type in ["", "f", "F", "e", "E", "g", "G", "%"]:
			vm.raise_error("ValueError", "el código de formato '%s' no sirve para un float: usa 'f' (p. ej. {x:.2f}) o convierte con int()" % type)
			return ""
		numeric = true
		var f := float(v)
		neg = PyNumber.is_negative(f) and not is_nan(f)
		var p := prec if prec >= 0 else 6
		match type:
			"f", "F":
				body = PyNumber.format_fixed(f, p, false)
			"e", "E":
				body = PyNumber.format_sci(f, p, false)
			"g", "G":
				body = PyNumber.format_general(f, p, alt, false)
			"%":
				body = PyNumber.format_fixed(f * 100.0, p, false) + "%"
			"":
				if tv == TYPE_INT:
					body = str(absi(v))
				elif prec < 0:
					body = PyNumber.float_repr(absf(f))
				else:
					body = PyNumber.format_general(f, p, alt, false, true)
		if type in ["F", "E", "G"]:
			body = body.to_upper()
		if not grouping.is_empty():
			var dot := body.find(".")
			var e_pos := body.find("e")
			var cut := dot if dot >= 0 else (e_pos if e_pos >= 0 else body.length())
			if body.ends_with("%") and dot < 0:
				cut = body.length() - 1
			body = _group(body.substr(0, cut), grouping, 3) + body.substr(cut)
	var sign_s := ""
	if numeric:
		if neg:
			sign_s = "-"
		elif sign == "+":
			sign_s = "+"
		elif sign == " ":
			sign_s = " "
		if align.is_empty():
			align = ">"
	var total := sign_s + prefix + body
	var pad := width - total.length()
	if pad <= 0:
		return total
	match align:
		"<":
			return total + fill.repeat(pad)
		"^":
			var left := pad / 2
			return fill.repeat(left) + total + fill.repeat(pad - left)
		"=":
			return sign_s + prefix + fill.repeat(pad) + body
	return fill.repeat(pad) + total


static func _group(digits: String, sep: String, size: int) -> String:
	var out := ""
	var count := 0
	var i := digits.length() - 1
	while i >= 0:
		out = digits[i] + out
		count += 1
		if count % size == 0 and i > 0:
			out = sep + out
		i -= 1
	return out


## "texto {} {nombre:.2f}".format(...)
static func str_format(vm: PyInterpreter, fmt: String, args: Array, kwargs: Dictionary) -> Variant:
	var out := ""
	var i := 0
	var n := fmt.length()
	var auto := 0
	while i < n:
		var c := fmt[i]
		if c == "{":
			if i + 1 < n and fmt[i + 1] == "{":
				out += "{"
				i += 2
				continue
			var depth := 1
			var j := i + 1
			while j < n and depth > 0:
				if fmt[j] == "{":
					depth += 1
				elif fmt[j] == "}":
					depth -= 1
				j += 1
			if depth != 0:
				vm.raise_error("ValueError", "format(): falta una '}' de cierre")
				return null
			var field := fmt.substr(i + 1, j - i - 2)
			i = j
			var spec := ""
			var conv := ""
			var colon := field.find(":")
			if colon >= 0:
				spec = field.substr(colon + 1)
				field = field.substr(0, colon)
			var bang := field.find("!")
			if bang >= 0:
				conv = field.substr(bang + 1)
				field = field.substr(0, bang)
			if spec.contains("{"):
				var sv: Variant = str_format(vm, spec, args, kwargs)
				if vm.has_error():
					return null
				spec = sv
			var name := field
			var rest := ""
			var br := field.find("[")
			if br >= 0:
				name = field.substr(0, br)
				rest = field.substr(br)
			var val: Variant = null
			if name.is_empty():
				if auto >= args.size():
					vm.raise_error("IndexError", "format(): hay más {} que valores")
					return null
				val = args[auto]
				auto += 1
			elif name.is_valid_int():
				var k := name.to_int()
				if k >= args.size():
					vm.raise_error("IndexError", "format(): no hay ningún valor en la posición %d" % k)
					return null
				val = args[k]
			elif kwargs.has(name):
				val = kwargs[name]
			else:
				vm.raise_error("KeyError", "format(): falta el valor con nombre '%s'" % name)
				return null
			while rest.begins_with("["):
				var close := rest.find("]")
				if close < 0:
					vm.raise_error("ValueError", "format(): falta ']'")
					return null
				var key := rest.substr(1, close - 1)
				rest = rest.substr(close + 1)
				val = vm.get_item(val, key.to_int() if key.is_valid_int() else key)
				if vm.has_error():
					return null
			match conv:
				"r", "a":
					val = vm.py_repr(val)
				"s":
					val = vm.py_str(val)
			out += format_value(vm, val, spec)
			if vm.has_error():
				return null
		elif c == "}":
			if i + 1 < n and fmt[i + 1] == "}":
				out += "}"
				i += 2
				continue
			vm.raise_error("ValueError", "format(): una '}' suelta debe escribirse '}}'")
			return null
		else:
			out += c
			i += 1
	return out


## "%d %s" % (a, b)
static func percent_format(vm: PyInterpreter, fmt: String, values: Variant) -> Variant:
	var items: Array = []
	if typeof(values) == TYPE_ARRAY and (values as Array).is_read_only():
		items = values
	else:
		items = [values]
	var out := ""
	var i := 0
	var n := fmt.length()
	var k := 0
	while i < n:
		var c := fmt[i]
		if c != "%":
			out += c
			i += 1
			continue
		i += 1
		if i >= n:
			vm.raise_error("ValueError", "formato con % incompleto al final")
			return null
		if fmt[i] == "%":
			out += "%"
			i += 1
			continue
		var flags := ""
		while i < n and fmt[i] in ["-", "+", " ", "0", "#"]:
			flags += fmt[i]
			i += 1
		var width := ""
		while i < n and fmt[i] >= "0" and fmt[i] <= "9":
			width += fmt[i]
			i += 1
		var prec := ""
		if i < n and fmt[i] == ".":
			i += 1
			prec = "."
			while i < n and fmt[i] >= "0" and fmt[i] <= "9":
				prec += fmt[i]
				i += 1
			if prec == ".":
				prec = ".0"
		if i >= n:
			vm.raise_error("ValueError", "formato con % incompleto")
			return null
		var t := fmt[i]
		i += 1
		if k >= items.size():
			vm.raise_error("TypeError", "faltan valores para el formato con %")
			return null
		var v: Variant = items[k]
		k += 1
		var spec := ""
		if flags.contains("-"):
			spec += "<"
		elif not width.is_empty() and t in ["s", "r"]:
			spec += ">"
		if flags.contains("+"):
			spec += "+"
		elif flags.contains(" "):
			spec += " "
		if flags.contains("0") and not flags.contains("-") and not t in ["s", "r"]:
			spec += "0"
		spec += width
		match t:
			"d", "i", "u":
				if typeof(v) == TYPE_FLOAT:
					var iv: Variant = float_to_int(vm, v)
					if iv == null:
						return null
					v = iv
				if not PyInterpreter.is_int_like(v):
					vm.raise_error("TypeError", "%%d necesita un número, no '%s'" % vm.type_name(v))
					return null
				out += format_value(vm, int(v), spec + "d")
			"f", "F", "e", "E", "g", "G":
				if not PyInterpreter.is_num(v):
					vm.raise_error("TypeError", "%%%s necesita un número, no '%s'" % [t, vm.type_name(v)])
					return null
				out += format_value(vm, float(v), spec + prec + t)
			"s":
				out += format_value(vm, vm.py_str(v), spec + prec)
			"r":
				out += format_value(vm, vm.py_repr(v), spec + prec)
			"x", "X", "o":
				if not PyInterpreter.is_int_like(v):
					vm.raise_error("TypeError", "%%%s necesita un entero" % t)
					return null
				out += format_value(vm, int(v), spec + ("#" if flags.contains("#") else "") + t)
			"c":
				out += vm.py_str(v) if typeof(v) == TYPE_STRING else String.chr(int(v))
			_:
				vm.raise_error("ValueError", "código de formato desconocido '%%%s'" % t)
				return null
		if vm.has_error():
			return null
	if k < items.size():
		vm.raise_error("TypeError", "sobran valores para el formato con %: hay %d y solo se usan %d" % [items.size(), k])
		return null
	return out


# ── Módulos ──────────────────────────────────────────────────────────────────

static func import_module(vm: PyInterpreter, name: String) -> Variant:
	if vm._modules.has(name):
		return vm._modules[name]
	var m := PyInterpreter.Module.new()
	m.name = name
	match name:
		"math":
			for f in MATH_FUNCS:
				m.members[f] = PyInterpreter.Builtin.new(f, "math")
			m.members["pi"] = PI
			m.members["e"] = exp(1.0)
			m.members["tau"] = TAU
			m.members["inf"] = INF
			m.members["nan"] = NAN
		"random":
			for f in RANDOM_FUNCS:
				m.members[f] = PyInterpreter.Builtin.new(f, "random")
		_:
			vm.raise_error("ImportError", "el módulo '%s' no está disponible en el Dojo (solo se pueden importar math y random)" % name)
			return null
	vm._modules[name] = m
	return m


static func _math(vm: PyInterpreter, name: String, args: Array, kwargs: Dictionary) -> Variant:
	var fn: Variant = _MATH_TABLE.get(name)
	if fn != null:
		return (fn as Callable).call(vm, name, args, kwargs)
	vm.raise_error("AttributeError", "math.%s no está disponible" % name)
	return null


static var _MATH_TABLE := {
	"sqrt": _math_sqrt,
	"exp": _math_sqrt,
	"fabs": _math_sqrt,
	"sin": _math_sqrt,
	"cos": _math_sqrt,
	"tan": _math_sqrt,
	"asin": _math_sqrt,
	"acos": _math_sqrt,
	"atan": _math_sqrt,
	"degrees": _math_sqrt,
	"radians": _math_sqrt,
	"log2": _math_sqrt,
	"log10": _math_sqrt,
	"isnan": _math_sqrt,
	"isinf": _math_sqrt,
	"isfinite": _math_sqrt,
	"log": _math_log,
	"pow": _math_pow,
	"floor": _math_floor,
	"ceil": _math_floor,
	"trunc": _math_floor,
	"atan2": _math_atan2,
	"hypot": _math_hypot,
	"dist": _math_hypot,
	"factorial": _math_factorial,
	"gcd": _math_gcd,
	"lcm": _math_gcd,
	"isclose": _math_isclose,
	"fsum": _math_fsum,
	"prod": _math_prod,
	"comb": _math_comb,
	"perm": _math_comb,
	"copysign": _math_copysign,
	"fmod": _math_fmod,
	"isqrt": _math_isqrt,
}


static func _math_sqrt(vm: PyInterpreter, name: String, args: Array, kwargs: Dictionary) -> Variant:
	var fname := "math." + name
	if not _check(vm, fname, args, kwargs, 1, 1):
		return null
	var xv: Variant = _num_arg(vm, fname, args[0])
	if xv == null:
		return null
	var x: float = xv
	match name:
		"sqrt":
			if x < 0.0:
				vm.raise_error("ValueError", "error de dominio matemático: no existe la raíz cuadrada de un número negativo")
				return null
			return sqrt(x)
		"exp":
			var r := exp(x)
			if is_inf(r) and is_finite(x):
				vm.raise_error("OverflowError", "math.exp(): el resultado es demasiado grande")
				return null
			return r
		"fabs":
			return absf(x)
		"sin":
			return sin(x)
		"cos":
			return cos(x)
		"tan":
			return tan(x)
		"asin", "acos":
			if x < -1.0 or x > 1.0:
				vm.raise_error("ValueError", "error de dominio matemático: %s() necesita un valor entre -1 y 1" % fname)
				return null
			return asin(x) if name == "asin" else acos(x)
		"atan":
			return atan(x)
		"degrees":
			return x * (180.0 / PI)
		"radians":
			return x * (PI / 180.0)
		"log2", "log10":
			if x <= 0.0:
				vm.raise_error("ValueError", "error de dominio matemático: el logaritmo solo existe para números positivos")
				return null
			return _log2(args[0]) if name == "log2" else _log10(x)
		"isnan":
			return is_nan(x)
		"isinf":
			return is_inf(x)
		"isfinite":
			return is_finite(x)
	return null


static func _math_log(vm: PyInterpreter, name: String, args: Array, kwargs: Dictionary) -> Variant:
	var fname := "math." + name
	if not _check(vm, fname, args, kwargs, 1, 2):
		return null
	var xv: Variant = _num_arg(vm, fname, args[0])
	if xv == null:
		return null
	if float(xv) <= 0.0:
		vm.raise_error("ValueError", "error de dominio matemático: el logaritmo solo existe para números positivos")
		return null
	var num := _ln(args[0])
	if args.size() == 1:
		return num
	var bv: Variant = _num_arg(vm, fname, args[1])
	if bv == null:
		return null
	if float(bv) <= 0.0:
		vm.raise_error("ValueError", "error de dominio matemático: la base del logaritmo tiene que ser positiva")
		return null
	var den := _ln(args[1])
	if den == 0.0:
		vm.raise_error("ZeroDivisionError", "la base del logaritmo no puede ser 1")
		return null
	return num / den


static func _math_pow(vm: PyInterpreter, name: String, args: Array, kwargs: Dictionary) -> Variant:
	var fname := "math." + name
	if not _check(vm, fname, args, kwargs, 2, 2):
		return null
	var a: Variant = _num_arg(vm, fname, args[0])
	var b: Variant = _num_arg(vm, fname, args[1])
	if a == null or b == null:
		return null
	if float(a) == 0.0 and float(b) < 0.0:
		vm.raise_error("ValueError", "error de dominio matemático: 0 elevado a un exponente negativo")
		return null
	return vm.float_pow(a, b)


static func _math_floor(vm: PyInterpreter, name: String, args: Array, kwargs: Dictionary) -> Variant:
	var fname := "math." + name
	if not _check(vm, fname, args, kwargs, 1, 1):
		return null
	if PyInterpreter.is_int_like(args[0]):
		return int(args[0])
	var xv: Variant = _num_arg(vm, fname, args[0])
	if xv == null:
		return null
	var f: float = xv
	var r := floorf(f) if name == "floor" else (ceilf(f) if name == "ceil" else (floorf(f) if f >= 0 else ceilf(f)))
	return float_to_int(vm, r)


static func _math_atan2(vm: PyInterpreter, name: String, args: Array, kwargs: Dictionary) -> Variant:
	var fname := "math." + name
	if not _check(vm, fname, args, kwargs, 2, 2):
		return null
	var y: Variant = _num_arg(vm, fname, args[0])
	var x: Variant = _num_arg(vm, fname, args[1])
	if y == null or x == null:
		return null
	return atan2(y, x)


static func _math_hypot(vm: PyInterpreter, name: String, args: Array, kwargs: Dictionary) -> Variant:
	var fname := "math." + name
	var vals: Array = []
	if name == "dist":
		if not _check(vm, fname, args, kwargs, 2, 2):
			return null
		var p: Variant = vm.to_array(args[0])
		var q: Variant = vm.to_array(args[1])
		if vm.has_error():
			return null
		if (p as Array).size() != (q as Array).size():
			vm.raise_error("ValueError", "math.dist(): los dos puntos tienen que tener las mismas dimensiones")
			return null
		for i in (p as Array).size():
			var d: Variant = vm.binary_op("-", p[i], q[i])
			if vm.has_error():
				return null
			vals.append(d)
	else:
		vals = args
	var acc := 0.0
	for v: Variant in vals:
		var fv: Variant = _num_arg(vm, fname, v)
		if fv == null:
			return null
		acc += float(fv) * float(fv)
	return sqrt(acc)


static func _math_factorial(vm: PyInterpreter, name: String, args: Array, kwargs: Dictionary) -> Variant:
	var fname := "math." + name
	if not _check(vm, fname, args, kwargs, 1, 1):
		return null
	if not PyInterpreter.is_int_like(args[0]):
		vm.raise_error("TypeError" if typeof(args[0]) != TYPE_FLOAT else "ValueError", "math.factorial() solo acepta enteros")
		return null
	var nf := int(args[0])
	if nf < 0:
		vm.raise_error("ValueError", "math.factorial() no está definido para números negativos")
		return null
	var r := 1
	for k in range(2, nf + 1):
		var m: Variant = vm.mul_int(r, k)
		if vm.has_error():
			return null
		r = m
	return r


static func _math_gcd(vm: PyInterpreter, name: String, args: Array, kwargs: Dictionary) -> Variant:
	var fname := "math." + name
	var acc := 0 if name == "gcd" else 1
	for v: Variant in args:
		var iv: Variant = _int_arg(vm, fname, v)
		if iv == null:
			return null
		if name == "gcd":
			acc = _gcd(acc, absi(iv))
		else:
			if iv == 0 or acc == 0:
				acc = 0
			else:
				var g := _gcd(acc, absi(iv))
				var m: Variant = vm.mul_int(acc / g, absi(iv))
				if vm.has_error():
					return null
				acc = m
	return acc


static func _math_isclose(vm: PyInterpreter, name: String, args: Array, kwargs: Dictionary) -> Variant:
	var fname := "math." + name
	if not _check(vm, fname, args, kwargs, 2, 2, ["rel_tol", "abs_tol"]):
		return null
	var a: Variant = _num_arg(vm, fname, args[0])
	var b: Variant = _num_arg(vm, fname, args[1])
	var rt: Variant = _num_arg(vm, fname, kwargs.get("rel_tol", 1e-9))
	var at: Variant = _num_arg(vm, fname, kwargs.get("abs_tol", 0.0))
	if a == null or b == null or rt == null or at == null:
		return null
	if a == b:
		return true
	if is_inf(a) or is_inf(b):
		return false
	var diff := absf(a - b)
	return diff <= absf(rt * b) or diff <= absf(rt * a) or diff <= at


static func _math_fsum(vm: PyInterpreter, name: String, args: Array, kwargs: Dictionary) -> Variant:
	var fname := "math." + name
	if not _check(vm, fname, args, kwargs, 1, 1):
		return null
	var items: Variant = vm.to_array(args[0])
	if vm.has_error():
		return null
	var floats: Array[float] = []
	for v: Variant in items:
		var fv: Variant = _num_arg(vm, fname, v)
		if fv == null:
			return null
		floats.append(fv)
	return _fsum(floats)


static func _math_prod(vm: PyInterpreter, name: String, args: Array, kwargs: Dictionary) -> Variant:
	var fname := "math." + name
	if not _check(vm, fname, args, kwargs, 1, 1, ["start"]):
		return null
	var items: Variant = vm.to_array(args[0])
	if vm.has_error():
		return null
	var acc: Variant = kwargs.get("start", 1)
	for v: Variant in items:
		acc = vm.binary_op("*", acc, v)
		if vm.has_error():
			return null
	return acc


static func _math_comb(vm: PyInterpreter, name: String, args: Array, kwargs: Dictionary) -> Variant:
	var fname := "math." + name
	if not _check(vm, fname, args, kwargs, 1 if name == "perm" else 2, 2):
		return null
	var nv: Variant = _int_arg(vm, fname, args[0])
	var kv: Variant = _int_arg(vm, fname, args[1]) if args.size() > 1 else nv
	if nv == null or kv == null:
		return null
	if nv < 0 or kv < 0:
		vm.raise_error("ValueError", "%s() necesita números no negativos" % fname)
		return null
	if kv > nv:
		return 0
	var r := 1
	if name == "perm":
		for i in kv:
			var m: Variant = vm.mul_int(r, nv - i)
			if vm.has_error():
				return null
			r = m
		return r
	var kk: int = mini(kv, nv - kv)
	for i in kk:
		var m: Variant = vm.mul_int(r, nv - i)
		if vm.has_error():
			return null
		r = m / (i + 1)
	return r


static func _math_copysign(vm: PyInterpreter, name: String, args: Array, kwargs: Dictionary) -> Variant:
	var fname := "math." + name
	if not _check(vm, fname, args, kwargs, 2, 2):
		return null
	var a: Variant = _num_arg(vm, fname, args[0])
	var b: Variant = _num_arg(vm, fname, args[1])
	if a == null or b == null:
		return null
	return PyNumber.copysign(a, b)


static func _math_fmod(vm: PyInterpreter, name: String, args: Array, kwargs: Dictionary) -> Variant:
	var fname := "math." + name
	if not _check(vm, fname, args, kwargs, 2, 2):
		return null
	var a: Variant = _num_arg(vm, fname, args[0])
	var b: Variant = _num_arg(vm, fname, args[1])
	if a == null or b == null:
		return null
	if float(b) == 0.0:
		vm.raise_error("ValueError", "error de dominio matemático: fmod(x, 0)")
		return null
	return fmod(a, b)


static func _math_isqrt(vm: PyInterpreter, name: String, args: Array, kwargs: Dictionary) -> Variant:
	var fname := "math." + name
	if not _check(vm, fname, args, kwargs, 1, 1):
		return null
	var nv: Variant = _int_arg(vm, fname, args[0])
	if nv == null:
		return null
	if nv < 0:
		vm.raise_error("ValueError", "math.isqrt() no acepta números negativos")
		return null
	var r := int(sqrt(float(nv)))
	while r * r > nv:
		r -= 1
	while (r + 1) * (r + 1) <= nv and (r + 1) <= 3037000499:
		r += 1
	return r


static func _gcd(a: int, b: int) -> int:
	while b != 0:
		var t := a % b
		a = b
		b = t
	return a


## Logaritmo natural; para enteros enormes no hay problema con float.
static func _ln(v: Variant) -> float:
	return log(float(v))


static func _log2(v: Variant) -> float:
	# exacto para potencias de 2 (math.log2(8) == 3.0)
	if PyInterpreter.is_int_like(v) and int(v) > 0 and (int(v) & (int(v) - 1)) == 0:
		var n := int(v)
		var e := 0
		while n > 1:
			n = n >> 1
			e += 1
		return float(e)
	var f := float(v)
	var r := log(f) / log(2.0)
	var rr := roundf(r)
	if absf(r - rr) < 1e-12 and pow(2.0, rr) == f:
		return rr
	return r


static func _log10(x: float) -> float:
	var r := log(x) / log(10.0)
	var rr := roundf(r)
	if absf(r - rr) < 1e-12 and pow(10.0, rr) == x:
		return rr
	return r


## Suma exacta de Shewchuk, con el redondeo final de CPython (math.fsum).
static func _fsum(values: Array[float]) -> float:
	var partials: Array[float] = []
	for xv in values:
		var x := xv
		var i := 0
		for j in partials.size():
			var y := partials[j]
			if absf(x) < absf(y):
				var t := x
				x = y
				y = t
			var hi := x + y
			var lo := y - (hi - x)
			if lo != 0.0:
				partials[i] = lo
				i += 1
			x = hi
		partials.resize(i)
		partials.append(x)
	var n := partials.size()
	var hi2 := 0.0
	if n > 0:
		n -= 1
		hi2 = partials[n]
		var lo2 := 0.0
		while n > 0:
			var x := hi2
			n -= 1
			var y := partials[n]
			hi2 = x + y
			var yr := hi2 - x
			lo2 = y - yr
			if lo2 != 0.0:
				break
		if n > 0 and ((lo2 < 0.0 and partials[n - 1] < 0.0) or (lo2 > 0.0 and partials[n - 1] > 0.0)):
			var y := lo2 * 2.0
			var x := hi2 + y
			var yr := x - hi2
			if y == yr:
				hi2 = x
	return hi2


# ── random: Mersenne Twister idéntico a CPython ──────────────────────────────

const _MT_N := 624
const _MT_M := 397
const _MASK32 := 0xFFFFFFFF


static func _mt_init_genrand(vm: PyInterpreter, s: int) -> void:
	var mt := PackedInt64Array()
	mt.resize(_MT_N)
	mt[0] = s & _MASK32
	for i in range(1, _MT_N):
		var prev := mt[i - 1]
		mt[i] = (1812433253 * (prev ^ (prev >> 30)) + i) & _MASK32
	vm.mt_state = mt
	vm.mt_index = _MT_N


static func _mt_init_by_array(vm: PyInterpreter, key: Array[int]) -> void:
	_mt_init_genrand(vm, 19650218)
	var mt := vm.mt_state
	var i := 1
	var j := 0
	var k := maxi(_MT_N, key.size())
	while k > 0:
		var prev := mt[i - 1]
		mt[i] = ((mt[i] ^ ((prev ^ (prev >> 30)) * 1664525)) + key[j] + j) & _MASK32
		i += 1
		j += 1
		if i >= _MT_N:
			mt[0] = mt[_MT_N - 1]
			i = 1
		if j >= key.size():
			j = 0
		k -= 1
	k = _MT_N - 1
	while k > 0:
		var prev := mt[i - 1]
		mt[i] = ((mt[i] ^ ((prev ^ (prev >> 30)) * 1566083941)) - i) & _MASK32
		i += 1
		if i >= _MT_N:
			mt[0] = mt[_MT_N - 1]
			i = 1
		k -= 1
	mt[0] = 0x80000000
	vm.mt_state = mt
	vm.mt_index = _MT_N


static func _mt_next(vm: PyInterpreter) -> int:
	var mt := vm.mt_state
	if vm.mt_index >= _MT_N:
		for kk in _MT_N:
			var y := (mt[kk] & 0x80000000) | (mt[(kk + 1) % _MT_N] & 0x7fffffff)
			var v := mt[(kk + _MT_M) % _MT_N] ^ (y >> 1)
			if y & 1:
				v ^= 0x9908b0df
			mt[kk] = v
		vm.mt_index = 0
		vm.mt_state = mt
	var y := mt[vm.mt_index]
	vm.mt_index += 1
	y ^= (y >> 11)
	y ^= (y << 7) & 0x9d2c5680
	y ^= (y << 15) & 0xefc60000
	y ^= (y >> 18)
	return y & _MASK32


## random.seed(n) para enteros, igual que CPython (abs(n) troceado en palabras de 32 bits).
static func random_seed(vm: PyInterpreter, n: int) -> void:
	var a := absi(n) if n != PyNumber.INT_MIN else PyNumber.INT_MAX
	var key: Array[int] = []
	if a == 0:
		key.append(0)
	while a > 0:
		key.append(a & _MASK32)
		a = a >> 32
	_mt_init_by_array(vm, key)
	vm.gauss_next = null


static func _random_float(vm: PyInterpreter) -> float:
	var a := _mt_next(vm) >> 5
	var b := _mt_next(vm) >> 6
	return (a * 67108864.0 + b) * (1.0 / 9007199254740992.0)


static func _getrandbits(vm: PyInterpreter, k: int) -> int:
	if k <= 32:
		return _mt_next(vm) >> (32 - k)
	var result := 0
	var shift := 0
	var left := k
	while left > 0:
		var r := _mt_next(vm)
		if left < 32:
			r = r >> (32 - left)
		result |= r << shift
		shift += 32
		left -= 32
	return result


static func _randbelow(vm: PyInterpreter, n: int) -> int:
	if n <= 0:
		return 0
	var k := 0
	var t := n
	while t > 0:
		k += 1
		t = t >> 1
	var r := _getrandbits(vm, k)
	while r >= n:
		r = _getrandbits(vm, k)
	return r


static func _random(vm: PyInterpreter, name: String, args: Array, kwargs: Dictionary) -> Variant:
	var fn: Variant = _RANDOM_TABLE.get(name)
	if fn != null:
		return (fn as Callable).call(vm, name, args, kwargs)
	vm.raise_error("AttributeError", "random.%s no está disponible" % name)
	return null


static var _RANDOM_TABLE := {
	"seed": _rnd_seed,
	"random": _rnd_random,
	"uniform": _rnd_uniform,
	"randint": _rnd_randint,
	"randrange": _rnd_randint,
	"choice": _rnd_choice,
	"choices": _rnd_choices,
	"shuffle": _rnd_shuffle,
	"sample": _rnd_sample,
	"gauss": _rnd_gauss,
}


static func _rnd_seed(vm: PyInterpreter, name: String, args: Array, kwargs: Dictionary) -> Variant:
	var fname := "random." + name
	if not _check(vm, fname, args, kwargs, 0, 1):
		return null
	var s: Variant = args[0] if args.size() == 1 else 0
	match typeof(s):
		TYPE_NIL:
			random_seed(vm, 0)
		TYPE_INT, TYPE_BOOL:
			random_seed(vm, int(s))
		TYPE_FLOAT:
			random_seed(vm, int(s) if float(s) == floorf(s) else PyNumber.bits_of(s))
		TYPE_STRING:
			random_seed(vm, hash(s) & PyNumber.INT_MAX)
		_:
			vm.raise_error("TypeError", "random.seed() acepta un entero, un float o una cadena")
	return null


static func _rnd_random(vm: PyInterpreter, name: String, args: Array, kwargs: Dictionary) -> Variant:
	var fname := "random." + name
	if not _check(vm, fname, args, kwargs, 0, 0):
		return null
	return _random_float(vm)


static func _rnd_uniform(vm: PyInterpreter, name: String, args: Array, kwargs: Dictionary) -> Variant:
	var fname := "random." + name
	if not _check(vm, fname, args, kwargs, 2, 2):
		return null
	var a: Variant = _num_arg(vm, fname, args[0])
	var b: Variant = _num_arg(vm, fname, args[1])
	if a == null or b == null:
		return null
	return float(a) + (float(b) - float(a)) * _random_float(vm)


static func _rnd_randint(vm: PyInterpreter, name: String, args: Array, kwargs: Dictionary) -> Variant:
	var fname := "random." + name
	if not _check(vm, fname, args, kwargs, 1 if name == "randrange" else 2, 3 if name == "randrange" else 2):
		return null
	var vals: Array[int] = []
	for v: Variant in args:
		var iv: Variant = _int_arg(vm, fname, v)
		if iv == null:
			return null
		vals.append(iv)
	var start := 0
	var stop := 0
	var step := 1
	if name == "randint":
		start = vals[0]
		stop = vals[1] + 1
	elif vals.size() == 1:
		stop = vals[0]
	else:
		start = vals[0]
		stop = vals[1]
		if vals.size() == 3:
			step = vals[2]
	if step == 0:
		vm.raise_error("ValueError", "el paso no puede ser cero")
		return null
	var width := stop - start
	var count := 0
	if step == 1:
		count = width
	elif step > 0:
		count = (width + step - 1) / step
	else:
		count = (width + step + 1) / step
	if count <= 0:
		vm.raise_error("ValueError", "rango vacío para %s(%s)" % [fname, ", ".join(PackedStringArray(vals.map(func(x: int) -> String: return str(x))))])
		return null
	return start + step * _randbelow(vm, count)


static func _rnd_choice(vm: PyInterpreter, name: String, args: Array, kwargs: Dictionary) -> Variant:
	var fname := "random." + name
	if not _check(vm, fname, args, kwargs, 1, 1):
		return null
	var seq: Variant = args[0]
	var n: Variant = _len(vm, seq)
	if vm.has_error():
		return null
	if n == 0:
		vm.raise_error("IndexError", "random.choice() de una secuencia vacía")
		return null
	return vm.get_item(seq, _randbelow(vm, n))


static func _rnd_choices(vm: PyInterpreter, name: String, args: Array, kwargs: Dictionary) -> Variant:
	var fname := "random." + name
	if not _check(vm, fname, args, kwargs, 1, 1, ["k"]):
		return null
	var items: Variant = vm.to_array(args[0])
	if vm.has_error():
		return null
	var kv: Variant = _int_arg(vm, fname, kwargs.get("k", 1))
	if kv == null:
		return null
	var n: int = (items as Array).size()
	if n == 0:
		vm.raise_error("IndexError", "random.choices() de una secuencia vacía")
		return null
	var out: Array = []
	for _i in kv:
		out.append(items[int(floorf(_random_float(vm) * n))])
	return out


static func _rnd_shuffle(vm: PyInterpreter, name: String, args: Array, kwargs: Dictionary) -> Variant:
	var fname := "random." + name
	if not _check(vm, fname, args, kwargs, 1, 1):
		return null
	if typeof(args[0]) != TYPE_ARRAY or (args[0] as Array).is_read_only():
		vm.raise_error("TypeError", "random.shuffle() necesita una lista")
		return null
	var a: Array = args[0]
	var i := a.size() - 1
	while i >= 1:
		var j := _randbelow(vm, i + 1)
		var t: Variant = a[i]
		a[i] = a[j]
		a[j] = t
		i -= 1
	return null


static func _rnd_sample(vm: PyInterpreter, name: String, args: Array, kwargs: Dictionary) -> Variant:
	var fname := "random." + name
	if not _check(vm, fname, args, kwargs, 2, 2):
		return null
	var pop: Variant = vm.to_array(args[0])
	if vm.has_error():
		return null
	var population: Array = pop
	var kv: Variant = _int_arg(vm, fname, args[1])
	if kv == null:
		return null
	var k: int = kv
	var n := population.size()
	if k < 0 or k > n:
		vm.raise_error("ValueError", "random.sample(): la muestra es más grande que la población o negativa")
		return null
	var result: Array = []
	result.resize(k)
	var setsize := 21
	if k > 5:
		setsize += int(pow(4.0, ceilf(log(3.0 * k) / log(4.0))))
	if n <= setsize:
		var pool := population.duplicate()
		for i in k:
			var j := _randbelow(vm, n - i)
			result[i] = pool[j]
			pool[j] = pool[n - i - 1]
	else:
		var selected := {}
		for i in k:
			var j := _randbelow(vm, n)
			while selected.has(j):
				j = _randbelow(vm, n)
			selected[j] = true
			result[i] = population[j]
	return result


static func _rnd_gauss(vm: PyInterpreter, name: String, args: Array, kwargs: Dictionary) -> Variant:
	var fname := "random." + name
	if not _check(vm, fname, args, kwargs, 0, 2, ["mu", "sigma"]):
		return null
	var mu: Variant = _num_arg(vm, fname, args[0] if args.size() > 0 else kwargs.get("mu", 0.0))
	var sigma: Variant = _num_arg(vm, fname, args[1] if args.size() > 1 else kwargs.get("sigma", 1.0))
	if mu == null or sigma == null:
		return null
	var z: Variant = vm.gauss_next
	vm.gauss_next = null
	if z == null:
		var x2pi := _random_float(vm) * TAU
		var g2rad := sqrt(-2.0 * log(1.0 - _random_float(vm)))
		z = cos(x2pi) * g2rad
		vm.gauss_next = sin(x2pi) * g2rad
	return float(mu) + float(z) * float(sigma)


