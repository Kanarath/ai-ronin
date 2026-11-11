class_name PyInterpreter
extends RefCounted
## Intérprete de un subconjunto de Python escrito en GDScript, para el Dojo.
##
## Uso:
##   var py := PyInterpreter.new()
##   var r := py.run("def doble(x):\n    return 2 * x\nprint(doble(4))")
##   # r = {"ok": true, "output": ["8"], "error": {}}
##   var c := py.call_function("doble", [21])
##   # c = {"ok": true, "value": 42, "output": [], "error": {}}
##
## AISLAMIENTO: el código del alumno solo puede tocar valores de Python. No hay acceso a
## ficheros, red, procesos, objetos del motor ni a nada fuera de este intérprete: los
## atributos y métodos se resuelven con listas blancas (py_builtins.gd) y los módulos
## importables son únicamente math y random.
##
## Representación interna de los valores:
##   int, float, bool, None(null), str(String) → los nativos de GDScript
##   list → Array · tuple → Array de solo lectura · dict → Dictionary
##   set, range, funciones, módulos, excepciones, iteradores → clases internas de este fichero
## Los enteros son de 64 bits: si una operación se sale, se lanza OverflowError (Python
## tendría enteros ilimitados).

const MAX_DEPTH := 200
const MAX_ITEMS := 5000000
const MAX_OUTPUT_LINES := 5000
const MAX_SECONDS := 10
const STEP_LIMIT_MESSAGE := "tu programa ha superado el límite de pasos: ¿hay un bucle infinito?"

const EXC_PARENTS := {
	"BaseException": "",
	"Exception": "BaseException",
	"ArithmeticError": "Exception", "ZeroDivisionError": "ArithmeticError", "OverflowError": "ArithmeticError",
	"LookupError": "Exception", "IndexError": "LookupError", "KeyError": "LookupError",
	"ValueError": "Exception", "TypeError": "Exception", "NameError": "Exception",
	"UnboundLocalError": "NameError", "AttributeError": "Exception", "RuntimeError": "Exception",
	"RecursionError": "RuntimeError", "NotImplementedError": "RuntimeError", "ImportError": "Exception",
	"ModuleNotFoundError": "ImportError", "AssertionError": "Exception", "StopIteration": "Exception",
	"MemoryError": "Exception", "SyntaxError": "Exception", "IndentationError": "SyntaxError",
}


# ── Clases de valores ────────────────────────────────────────────────────────

class Scope:
	extends RefCounted
	var vars: Dictionary = {}
	var parent: Scope = null

	func _init(p: Scope = null) -> void:
		parent = p


class Func:
	extends RefCounted
	var code: PyCode
	var name := ""
	var defaults: Array = []
	var kw_defaults: Dictionary = {}
	var closure: Scope


class Builtin:
	extends RefCounted
	var name := ""
	var module := ""

	func _init(n: String, m: String = "") -> void:
		name = n
		module = m


class Method:
	extends RefCounted
	var obj: Variant
	var name := ""

	func _init(o: Variant, n: String) -> void:
		obj = o
		name = n


class Module:
	extends RefCounted
	var name := ""
	var members: Dictionary = {}


## Una clase definida con class: nombre, clase base (o null) y sus atributos y métodos.
class PyClass:
	extends RefCounted
	var name := ""
	var base: PyClass = null
	var attrs: Dictionary = {}

	func lookup(n: String) -> Variant:
		var c: PyClass = self
		while c != null:
			if c.attrs.has(n):
				return c.attrs[n]
			c = c.base
		return null

	func has(n: String) -> bool:
		var c: PyClass = self
		while c != null:
			if c.attrs.has(n):
				return true
			c = c.base
		return false

	func is_sub(other: PyClass) -> bool:
		var c: PyClass = self
		while c != null:
			if c == other:
				return true
			c = c.base
		return false


## Un objeto creado a partir de una clase: sus atributos propios (self.x = ...).
class PyInstance:
	extends RefCounted
	var cls: PyClass
	var fields: Dictionary = {}


## Un método ligado a su objeto (obj.metodo): al llamarlo, self es obj.
class BoundMethod:
	extends RefCounted
	var fn: Func
	var obj: Variant


class Exc:
	extends RefCounted
	var type := ""
	var message := ""
	var args: Array = []
	var line := 0
	var fatal := false


class ExcType:
	extends RefCounted
	var name := ""

	func _init(n: String) -> void:
		name = n


class PySet:
	extends RefCounted
	var d: Dictionary = {}


class PyRange:
	extends RefCounted
	var start := 0
	var stop := 0
	var step := 1

	func length() -> int:
		if step > 0 and start < stop:
			return (stop - start - 1) / step + 1
		if step < 0 and start > stop:
			return (start - stop - 1) / (-step) + 1
		return 0

	func at(i: int) -> int:
		return start + i * step


class PySlice:
	extends RefCounted
	var lo: Variant
	var hi: Variant
	var step: Variant


class DictView:
	extends RefCounted
	var d: Dictionary
	var kind := "keys"


class Starred:
	extends RefCounted
	var value: Variant


class Iter:
	extends RefCounted
	var kind := 0
	var seq: Variant
	var i := 0
	var stop := 0
	var step := 1
	var keys: Array = []
	var size := 0
	var inner: Array = []
	var fn: Variant
	var count := 0


enum { IT_SEQ, IT_STR, IT_RANGE, IT_KEYS, IT_VALUES, IT_ITEMS, IT_ENUM, IT_ZIP, IT_MAP, IT_FILTER, IT_SET }


## Un marco de ejecución es un Array (crear objetos es ~10 veces más caro en GDScript):
## [código, ip, pila, variables locales, ámbito padre (cierre), bloques try, excepciones
##  en manejo, Scope propio (se crea solo si una función interior lo captura)]
const F_CODE := 0
const F_IP := 1
const F_STACK := 2
const F_VARS := 3
const F_PARENT := 4
const F_BLOCKS := 5
const F_HANDLING := 6
const F_SCOPE := 7


# ── Estado ───────────────────────────────────────────────────────────────────

var _globals := Scope.new()
var _builtins: Dictionary = {}
var _modules: Dictionary = {}
var _frames: Array[Array] = []
var _exc: Exc = null
var _steps := 0
var _work := 0
var _max_steps := 200000
## Red de seguridad además de los pasos: ninguna ejecución dura más de MAX_SECONDS.
var _deadline := 0
var _output := PackedStringArray()
var _line_buf := ""
var _output_truncated := false
var _iter_value: Variant = null
var _repr_stack: Array = []
var _captured_scopes: Array[Scope] = []
## Estado del generador Mersenne Twister del módulo random (idéntico a CPython).
var mt_state := PackedInt64Array()
var mt_index := 625
var gauss_next: Variant = null


func _init() -> void:
	_builtins = PyBuiltins.make_builtins()
	PyBuiltins.random_seed(self, 0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# Sin llamar a métodos: durante PREDELETE solo se puede tocar el estado.
		for s in _captured_scopes:
			if s != null:
				s.vars.clear()
		_captured_scopes.clear()
		if _globals != null:
			_globals.vars.clear()


## Rompe los ciclos función ↔ ámbito para que la memoria se libere.
func _break_cycles() -> void:
	for s in _captured_scopes:
		if s != null:
			s.vars.clear()
	_captured_scopes.clear()
	_globals.vars.clear()


# ── API pública ──────────────────────────────────────────────────────────────

## Ejecuta un programa. Los globales se conservan entre llamadas.
func run(source: String, max_steps: int = 200000) -> Dictionary:
	_begin(max_steps)
	var parsed := PyParser.new().parse(source)
	if not parsed["error"].is_empty():
		return {"ok": false, "output": PackedStringArray(), "error": _clean_error(parsed["error"])}
	var compiled := PyCompiler.new().compile_module(parsed["ast"])
	if not compiled["error"].is_empty():
		return {"ok": false, "output": PackedStringArray(), "error": _clean_error(compiled["error"])}
	PyBuiltins.random_seed(self, 0)
	var f: Array = [compiled["code"], 0, [], _globals.vars, null, [], [], _globals]
	_frames.append(f)
	_execute(0)
	return _finish({})


## Llama a una función definida por el alumno con argumentos de GDScript.
func call_function(name: String, args: Array, max_steps: int = 200000) -> Dictionary:
	_begin(max_steps)
	if not _globals.vars.has(name):
		_flush_line()
		return {"ok": false, "value": null, "output": _output,
			"error": {"type": "NameError", "line": 0, "message": "no existe ninguna función llamada '%s' (¿la has definido con def %s(...):?)" % [name, name]}}
	var fn: Variant = _globals.vars[name]
	if not is_callable(fn):
		_flush_line()
		return {"ok": false, "value": null, "output": _output,
			"error": {"type": "TypeError", "line": 0, "message": "'%s' existe pero no es una función (es de tipo '%s')" % [name, type_name(fn)]}}
	var py_args: Array = []
	for a: Variant in args:
		py_args.append(from_plain(a))
	var v: Variant = call_sync(fn, py_args, {})
	var res := _finish({})
	res["value"] = null if not res["ok"] else to_plain(v)
	return res


## ¿Hay una función (o algo invocable) con ese nombre en los globales?
func has_function(name: String) -> bool:
	return _globals.vars.has(name) and is_callable(_globals.vars[name])


## Valor de una variable global convertido a datos de GDScript (o null si no existe).
func get_global(name: String) -> Variant:
	if not _globals.vars.has(name):
		return null
	return to_plain(_globals.vars[name])


func has_global(name: String) -> bool:
	return _globals.vars.has(name)


## Borra los globales y la salida (como empezar de cero).
func reset() -> void:
	_break_cycles()
	_globals = Scope.new()


func _begin(max_steps: int) -> void:
	_frames.clear()
	_exc = null
	_steps = 0
	_work = 0
	_max_steps = maxi(1, max_steps)
	_deadline = Time.get_ticks_msec() + MAX_SECONDS * 1000
	_output = PackedStringArray()
	_line_buf = ""
	_output_truncated = false
	_repr_stack.clear()


func _finish(_extra: Dictionary) -> Dictionary:
	_flush_line()
	_frames.clear()
	var err: Dictionary = {}
	if _exc != null:
		err = {"type": _exc.type, "line": _exc.line, "message": _exc.message}
		_exc = null
	return {"ok": err.is_empty(), "output": _output, "error": err, "value": null}


func _clean_error(e: Dictionary) -> Dictionary:
	return {"type": str(e.get("type", "SyntaxError")), "line": int(e.get("line", 0)), "message": str(e.get("message", ""))}


# ── Salida ───────────────────────────────────────────────────────────────────

func write(text: String) -> void:
	if _output_truncated:
		return
	var parts := text.split("\n")
	for i in parts.size():
		if i < parts.size() - 1:
			_output.append(_line_buf + parts[i])
			_line_buf = ""
			if _output.size() >= MAX_OUTPUT_LINES:
				_output.append("… (salida recortada: demasiadas líneas)")
				_output_truncated = true
				return
		else:
			_line_buf += parts[i]
	if _line_buf.length() > 100000:
		_output.append(_line_buf.substr(0, 100000) + "… (línea recortada)")
		_line_buf = ""


func _flush_line() -> void:
	if not _line_buf.is_empty():
		_output.append(_line_buf)
		_line_buf = ""


# ── Errores y pasos ──────────────────────────────────────────────────────────

func has_error() -> bool:
	return _exc != null


func raise_error(type: String, message: String) -> void:
	if _exc != null:
		return
	var e := Exc.new()
	e.type = type
	e.message = message
	e.args = [message]
	e.line = _current_line()
	_exc = e


func raise_exc(e: Exc) -> void:
	if _exc != null:
		return
	if e.line == 0:
		e.line = _current_line()
	_exc = e


func _current_line() -> int:
	if _frames.is_empty():
		return 0
	var f: Array = _frames.back()
	var code: PyCode = f[F_CODE]
	if code.lines.is_empty():
		return 0
	var i := clampi(int(f[F_IP]) - 1, 0, code.lines.size() - 1)
	return code.lines[i]


func _raise_fatal(type: String, message: String) -> void:
	raise_error(type, message)
	if _exc != null:
		_exc.fatal = true


## Cuenta un paso (iteración de bucle o llamada). Devuelve false si se agotan.
func tick() -> bool:
	_steps += 1
	if _steps > _max_steps or ((_steps & 1023) == 0 and Time.get_ticks_msec() > _deadline):
		_raise_fatal("StepLimitError", STEP_LIMIT_MESSAGE)
		return false
	return true


## Trabajo interno de los builtins: 10 elementos procesados = 1 paso.
func tick_work(n: int) -> bool:
	_work += n
	if _work >= 10:
		_steps += _work / 10
		_work = _work % 10
		if _steps > _max_steps or Time.get_ticks_msec() > _deadline:
			_raise_fatal("StepLimitError", STEP_LIMIT_MESSAGE)
			return false
	return true


# ── Bucle principal ──────────────────────────────────────────────────────────

# Copias locales de los códigos de operación: comparar con constantes de la propia clase
# es mucho más rápido que con PyCode.X o con match.
const _CONST := PyCode.CONST
const _LOAD_LOCAL := PyCode.LOAD_LOCAL
const _LOAD_GLOBAL := PyCode.LOAD_GLOBAL
const _STORE_LOCAL := PyCode.STORE_LOCAL
const _STORE_GLOBAL := PyCode.STORE_GLOBAL
const _BINARY := PyCode.BINARY
const _COMPARE := PyCode.COMPARE
const _POP_JUMP_IF_FALSE := PyCode.POP_JUMP_IF_FALSE
const _JUMP := PyCode.JUMP
const _FOR_ITER := PyCode.FOR_ITER
const _INPLACE := PyCode.INPLACE
const _LOAD_DEREF := PyCode.LOAD_DEREF
const _CALL := PyCode.CALL
const _RETURN := PyCode.RETURN
const _POP := PyCode.POP
const _SUBSCR := PyCode.SUBSCR
const _LOAD_ATTR := PyCode.LOAD_ATTR
const _POP_JUMP_IF_TRUE := PyCode.POP_JUMP_IF_TRUE
const _JUMP_IF_FALSE_OR_POP := PyCode.JUMP_IF_FALSE_OR_POP
const _JUMP_IF_TRUE_OR_POP := PyCode.JUMP_IF_TRUE_OR_POP
const _STORE_SUBSCR := PyCode.STORE_SUBSCR
const _DUP := PyCode.DUP
const _ROT2 := PyCode.ROT2
const _ROT3 := PyCode.ROT3
const _LIST_APPEND := PyCode.LIST_APPEND
const _BUILD_TUPLE := PyCode.BUILD_TUPLE
const _BUILD_LIST := PyCode.BUILD_LIST
const _UNPACK := PyCode.UNPACK
const _GET_ITER := PyCode.GET_ITER
const _UNARY := PyCode.UNARY


## Ejecuta marcos hasta que la pila vuelve a tener `base` marcos. Devuelve el último valor
## devuelto (o null si hay error: consulta has_error()).
func _execute(base: int) -> Variant:
	var result: Variant = null
	var gvars := _globals.vars
	while _frames.size() > base:
		if _exc != null:
			if not _unwind(base):
				return null
			continue
		var f: Array = _frames[_frames.size() - 1]
		var code: PyCode = f[F_CODE]
		var ops := code.ops
		var args := code.args
		var st: Array = f[F_STACK]
		var vars: Dictionary = f[F_VARS]
		var ip: int = f[F_IP]
		var depth := _frames.size()
		while true:
			var op := ops[ip]
			var arg: Variant = args[ip]
			ip += 1
			f[F_IP] = ip
			if op == _CONST:
				st.push_back(arg)
			elif op == _LOAD_LOCAL:
				if vars.has(arg):
					st.push_back(vars[arg])
				else:
					raise_error("UnboundLocalError", "la variable local '%s' se usa antes de darle un valor" % arg)
					break
			elif op == _LOAD_GLOBAL:
				if gvars.has(arg):
					st.push_back(gvars[arg])
				elif _builtins.has(arg):
					st.push_back(_builtins[arg])
				else:
					_name_error(arg)
					break
			elif op == _STORE_LOCAL:
				vars[arg] = st.pop_back()
			elif op == _STORE_GLOBAL:
				gvars[arg] = st.pop_back()
			elif op == _BINARY or op == _INPLACE:
				var b: Variant = st.pop_back()
				var a: Variant = st.pop_back()
				if typeof(a) == TYPE_INT and typeof(b) == TYPE_INT and arg == "+":
					var ia: int = a
					var ib: int = b
					var r: int = ia + ib
					if (ia >= 0) == (ib >= 0) and (r >= 0) != (ia >= 0):
						_overflow()
						break
					st.push_back(r)
				elif typeof(a) == TYPE_INT and typeof(b) == TYPE_INT and arg == "-":
					var ia: int = a
					var ib: int = b
					var r: int = ia - ib
					if (ia >= 0) != (ib >= 0) and (r >= 0) != (ia >= 0):
						_overflow()
						break
					st.push_back(r)
				else:
					var r2: Variant = binary_op(arg, a, b) if op == _BINARY else inplace_op(arg, a, b)
					if _exc != null:
						break
					st.push_back(r2)
			elif op == _COMPARE:
				var b: Variant = st.pop_back()
				var a: Variant = st.pop_back()
				if typeof(a) == TYPE_INT and typeof(b) == TYPE_INT:
					var ia: int = a
					var ib: int = b
					if arg == "<":
						st.push_back(ia < ib)
						continue
					if arg == ">":
						st.push_back(ia > ib)
						continue
					if arg == "==":
						st.push_back(ia == ib)
						continue
					if arg == "<=":
						st.push_back(ia <= ib)
						continue
					if arg == ">=":
						st.push_back(ia >= ib)
						continue
					if arg == "!=":
						st.push_back(ia != ib)
						continue
				var r: Variant = compare_op(arg, a, b)
				if _exc != null:
					break
				st.push_back(r)
			elif op == _POP_JUMP_IF_FALSE:
				var v: Variant = st.pop_back()
				var t := false
				if typeof(v) == TYPE_BOOL:
					t = v
				else:
					t = truthy(v)
				if not t:
					if arg < ip:
						_steps += 1
						if _steps > _max_steps or ((_steps & 1023) == 0 and Time.get_ticks_msec() > _deadline):
							_raise_fatal("StepLimitError", STEP_LIMIT_MESSAGE)
							break
					ip = arg
					f[F_IP] = ip
			elif op == _JUMP:
				if arg < ip:
					_steps += 1
					if _steps > _max_steps or ((_steps & 1023) == 0 and Time.get_ticks_msec() > _deadline):
						_raise_fatal("StepLimitError", STEP_LIMIT_MESSAGE)
						break
				ip = arg
				f[F_IP] = ip
			elif op == _FOR_ITER:
				var it: Iter = st.back()
				if it.kind == IT_RANGE:
					if (it.step > 0 and it.i < it.stop) or (it.step < 0 and it.i > it.stop):
						st.push_back(it.i)
						it.i += it.step
					else:
						st.pop_back()
						ip = arg
						f[F_IP] = ip
				elif it.kind == IT_SEQ:
					var sa: Array = it.seq
					if it.i < sa.size():
						st.push_back(sa[it.i])
						it.i += 1
					else:
						st.pop_back()
						ip = arg
						f[F_IP] = ip
				elif iter_next(it):
					st.push_back(_iter_value)
				elif _exc != null:
					break
				else:
					st.pop_back()
					ip = arg
					f[F_IP] = ip
			elif op == _LOAD_DEREF:
				var s: Scope = f[F_PARENT]
				var found := false
				while s != null:
					if s.vars.has(arg):
						st.push_back(s.vars[arg])
						found = true
						break
					s = s.parent
				if not found:
					if _builtins.has(arg):
						st.push_back(_builtins[arg])
					else:
						_name_error(arg)
						break
			elif op == _CALL:
				_op_call(f, arg)
				if _exc != null or _frames.size() != depth:
					break
			elif op == _RETURN:
				var v: Variant = st.pop_back()
				if f.size() > 8:
					v = f[8]
				_frames.pop_back()
				if _frames.size() > base:
					_frames[_frames.size() - 1][F_STACK].push_back(v)
				else:
					result = v
				break
			elif op == _POP:
				st.pop_back()
			elif op == _SUBSCR:
				var idx: Variant = st.pop_back()
				var obj: Variant = st.pop_back()
				if typeof(obj) == TYPE_ARRAY and typeof(idx) == TYPE_INT:
					var sa: Array = obj
					var ii: int = idx
					if ii < 0:
						ii += sa.size()
					if ii >= 0 and ii < sa.size():
						st.push_back(sa[ii])
						continue
				var r: Variant = get_item(obj, idx)
				if _exc != null:
					break
				st.push_back(r)
			elif op == _LOAD_ATTR:
				var target: Variant = st.pop_back()
				var r: Variant = get_object_attr(target, arg) if (target is PyInstance or target is PyClass) else PyBuiltins.get_attr(self, target, arg)
				if _exc != null:
					break
				st.push_back(r)
			elif op == _POP_JUMP_IF_TRUE:
				if truthy(st.pop_back()):
					ip = arg
					f[F_IP] = ip
			elif op == _JUMP_IF_FALSE_OR_POP:
				if not truthy(st.back()):
					ip = arg
					f[F_IP] = ip
				else:
					st.pop_back()
			elif op == _JUMP_IF_TRUE_OR_POP:
				if truthy(st.back()):
					ip = arg
					f[F_IP] = ip
				else:
					st.pop_back()
			elif op == _STORE_SUBSCR:
				var idx: Variant = st.pop_back()
				var obj: Variant = st.pop_back()
				var v: Variant = st.pop_back()
				set_item(obj, idx, v)
				if _exc != null:
					break
			elif op == _DUP:
				st.push_back(st.back())
			elif op == _ROT2:
				var n := st.size()
				var t: Variant = st[n - 1]
				st[n - 1] = st[n - 2]
				st[n - 2] = t
			elif op == _ROT3:
				var top: Variant = st.pop_back()
				st.insert(st.size() - 2, top)
			elif op == _LIST_APPEND:
				var v: Variant = st.pop_back()
				var l: Array = st.pop_back()
				l.append(v)
				if l.size() > MAX_ITEMS:
					_memory_error()
					break
			elif op == _BUILD_TUPLE or op == _BUILD_LIST:
				var n: int = arg
				var items: Array = st.slice(st.size() - n) if n > 0 else []
				st.resize(st.size() - n)
				items = _expand_starred(items)
				if _exc != null:
					break
				st.push_back(make_tuple(items) if op == _BUILD_TUPLE else items)
			elif op == _UNPACK:
				var v: Variant = st.pop_back()
				var arr: Array
				if typeof(v) == TYPE_ARRAY:
					arr = v
				else:
					var conv: Variant = to_array(v)
					if _exc != null:
						break
					arr = conv
				var n: int = arg
				if arr.size() != n:
					if arr.size() > n:
						raise_error("ValueError", "demasiados valores para desempaquetar (se esperaban %d y hay %d)" % [n, arr.size()])
					else:
						raise_error("ValueError", "no hay suficientes valores para desempaquetar (se esperaban %d y hay %d)" % [n, arr.size()])
					break
				var k := n - 1
				while k >= 0:
					st.push_back(arr[k])
					k -= 1
			elif op == _GET_ITER:
				var it: Iter = make_iter(st.pop_back())
				if _exc != null:
					break
				st.push_back(it)
			elif op == _UNARY:
				var r: Variant = unary_op(arg, st.pop_back())
				if _exc != null:
					break
				st.push_back(r)
			else:
				_exec_other(f, op, arg)
				if _exc != null:
					break
	return result


## Instrucciones poco frecuentes (fuera del bucle caliente).
func _exec_other(f: Array, op: int, arg: Variant) -> void:
	var st: Array = f[F_STACK]
	match op:
		PyCode.STORE_DEREF:
			var v: Variant = st.pop_back()
			var s: Scope = f[F_PARENT]
			while s != null and s != _globals:
				if s.vars.has(arg):
					s.vars[arg] = v
					return
				s = s.parent
			raise_error("SyntaxError", "no hay ninguna variable '%s' en una función exterior para usar con nonlocal" % arg)
		PyCode.DUP2:
			var n := st.size()
			st.push_back(st[n - 2])
			st.push_back(st[n - 1])
		PyCode.BUILD_SET:
			var n: int = arg
			var items: Array = st.slice(st.size() - n) if n > 0 else []
			st.resize(st.size() - n)
			items = _expand_starred(items)
			if _exc != null:
				return
			var s := make_set(items)
			if _exc == null:
				st.push_back(s)
		PyCode.BUILD_DICT:
			var n: int = arg
			var d := {}
			var base_i := st.size() - 2 * n
			for k in n:
				dict_set(d, st[base_i + 2 * k], st[base_i + 2 * k + 1])
				if _exc != null:
					return
			st.resize(base_i)
			st.push_back(d)
		PyCode.BUILD_SLICE:
			var sl := PySlice.new()
			sl.step = st.pop_back()
			sl.hi = st.pop_back()
			sl.lo = st.pop_back()
			st.push_back(sl)
		PyCode.BUILD_STRING:
			var n: int = arg
			var parts := PackedStringArray()
			for k in range(st.size() - n, st.size()):
				parts.append(st[k])
			st.resize(st.size() - n)
			st.push_back("".join(parts))
		PyCode.FORMAT:
			var spec := ""
			if arg["spec"]:
				spec = str(st.pop_back())
			var v: Variant = st.pop_back()
			match str(arg["conv"]):
				"r", "a":
					v = py_repr(v)
				"s":
					v = py_str(v)
			var r := PyBuiltins.format_value(self, v, spec)
			if _exc == null:
				st.push_back(r)
		PyCode.STAR:
			var sv := Starred.new()
			sv.value = st.pop_back()
			st.push_back(sv)
		PyCode.SET_ADD:
			var v: Variant = st.pop_back()
			var s: PySet = st.pop_back()
			set_add(s, v)
		PyCode.DICT_SET:
			var v: Variant = st.pop_back()
			var k: Variant = st.pop_back()
			var d: Dictionary = st.pop_back()
			dict_set(d, k, v)
		PyCode.DEL_SUBSCR:
			var idx: Variant = st.pop_back()
			var obj: Variant = st.pop_back()
			del_item(obj, idx)
		PyCode.STORE_ATTR:
			var obj: Variant = st.pop_back()
			var val: Variant = st.pop_back()
			if obj is PyInstance and not (arg as String).begins_with("__"):
				(obj as PyInstance).fields[arg] = val
			elif obj is PyClass and not (arg as String).begins_with("__"):
				(obj as PyClass).attrs[arg] = val
			else:
				raise_error("AttributeError", "no se pueden crear ni cambiar atributos de un objeto '%s' en el Dojo" % type_name(obj))
		PyCode.BUILD_CLASS:
			var names: Array = arg["names"]
			var vals: Array = st.slice(st.size() - names.size()) if names.size() > 0 else []
			st.resize(st.size() - names.size())
			var base_cls: Variant = st.pop_back()
			if base_cls != null and not base_cls is PyClass:
				raise_error("TypeError", "una clase solo puede heredar de otra clase definida con class, no de '%s'" % type_name(base_cls))
				return
			var cls := PyClass.new()
			cls.name = arg["name"]
			cls.base = base_cls
			for k in names.size():
				cls.attrs[names[k]] = vals[k]
			st.push_back(cls)
		PyCode.UNPACK_EX:
			var items: Variant = to_array(st.pop_back())
			if _exc != null:
				return
			var arr: Array = items
			var before: int = arg[0]
			var after: int = arg[1]
			if arr.size() < before + after:
				raise_error("ValueError", "no hay suficientes valores para desempaquetar (se esperaban al menos %d y hay %d)" % [before + after, arr.size()])
				return
			var k := arr.size() - 1
			while k >= arr.size() - after:
				st.push_back(arr[k])
				k -= 1
			st.push_back(arr.slice(before, arr.size() - after))
			k = before - 1
			while k >= 0:
				st.push_back(arr[k])
				k -= 1
		PyCode.MAKE_FUNCTION:
			var fn := Func.new()
			var c: PyCode = arg["code"]
			fn.code = c
			fn.name = c.name
			var kwn: Array = arg["kw_defaults"]
			var kwvals: Array = st.slice(st.size() - kwn.size()) if kwn.size() > 0 else []
			st.resize(st.size() - kwn.size())
			for k in kwn.size():
				fn.kw_defaults[kwn[k]] = kwvals[k]
			var nd: int = arg["n_defaults"]
			fn.defaults = st.slice(st.size() - nd) if nd > 0 else []
			st.resize(st.size() - nd)
			fn.closure = _frame_scope(f)
			st.push_back(fn)
		PyCode.DEL_LOCAL:
			if (f[F_VARS] as Dictionary).has(arg):
				(f[F_VARS] as Dictionary).erase(arg)
			else:
				raise_error("UnboundLocalError", "la variable local '%s' no tiene valor, no se puede borrar" % arg)
		PyCode.DEL_GLOBAL:
			if _globals.vars.has(arg):
				_globals.vars.erase(arg)
			else:
				_name_error(arg)
		PyCode.DEL_DEREF:
			raise_error("SyntaxError", "no se puede borrar '%s' desde una función interior" % arg)
		PyCode.IMPORT:
			var m: Variant = PyBuiltins.import_module(self, arg)
			if _exc == null:
				st.push_back(m)
		PyCode.IMPORT_FROM:
			var m: Module = st.pop_back()
			if m.members.has(arg):
				st.push_back(m.members[arg])
			else:
				raise_error("ImportError", "no se puede importar '%s' desde el módulo '%s': no existe en el Dojo" % [arg, m.name])
		PyCode.IMPORT_STAR:
			var m: Module = st.pop_back()
			for k: String in m.members:
				if not k.begins_with("_"):
					_globals.vars[k] = m.members[k]
		PyCode.SETUP_EXCEPT:
			f[F_BLOCKS].append([arg, st.size(), f[F_HANDLING].size()])
		PyCode.POP_BLOCK:
			f[F_BLOCKS].pop_back()
		PyCode.POP_EXCEPT:
			f[F_HANDLING].pop_back()
		PyCode.EXC_MATCH:
			var types: Variant = st.pop_back()
			var e: Exc = st.pop_back()
			var r := _exc_matches(e, types)
			if _exc == null:
				st.push_back(r)
		PyCode.RAISE:
			_op_raise(f, arg)
		PyCode.RERAISE:
			var e: Exc = st.pop_back()
			if not f[F_HANDLING].is_empty():
				f[F_HANDLING].pop_back()
			_exc = e
		PyCode.RAISE_ASSERT:
			var msg: Variant = st.pop_back()
			var e := Exc.new()
			e.type = "AssertionError"
			e.message = py_str(msg) if arg else ""
			e.args = [msg] if arg else []
			raise_exc(e)
		_:
			raise_error("RuntimeError", "instrucción interna desconocida (%d)" % op)


## Scope del marco (para cierres): se crea la primera vez que se necesita y comparte el
## diccionario de variables con el marco.
func _frame_scope(f: Array) -> Scope:
	if f[F_SCOPE] == null:
		var sc := Scope.new(f[F_PARENT])
		sc.vars = f[F_VARS]
		f[F_SCOPE] = sc
		_captured_scopes.append(sc)
	return f[F_SCOPE]


func _unwind(base: int) -> bool:
	while _frames.size() > base:
		var f: Array = _frames[_frames.size() - 1]
		if not _exc.fatal and not f[F_BLOCKS].is_empty():
			var b: Array = f[F_BLOCKS].pop_back()
			f[F_STACK].resize(b[1])
			f[F_HANDLING].resize(b[2])
			f[F_STACK].push_back(_exc)
			f[F_HANDLING].push_back(_exc)
			f[F_IP] = b[0]
			_exc = null
			return true
		_frames.pop_back()
	return false


func _name_error(name: String) -> void:
	raise_error("NameError", PyBuiltins.name_error_message(self, name))


func _overflow() -> void:
	raise_error("OverflowError", "el resultado es demasiado grande para los enteros del Dojo (máximo 9223372036854775807)")


func _memory_error() -> void:
	raise_error("MemoryError", "el resultado sería demasiado grande para el Dojo (más de %d elementos)" % MAX_ITEMS)


func _op_raise(f: Array, n: int) -> void:
	if n == 0:
		if f[F_HANDLING].is_empty():
			raise_error("RuntimeError", "'raise' sin nada que relanzar: no hay ninguna excepción activa")
			return
		var cur: Exc = f[F_HANDLING].back()
		_exc = cur
		return
	var v: Variant = f[F_STACK].pop_back()
	if v is ExcType:
		var e := Exc.new()
		e.type = (v as ExcType).name
		raise_exc(e)
	elif v is Exc:
		var e2: Exc = v
		e2.line = 0
		raise_exc(e2)
	else:
		raise_error("TypeError", "solo se pueden lanzar excepciones (p. ej. raise ValueError('mensaje')), no '%s'" % type_name(v))


func _exc_matches(e: Exc, types: Variant) -> bool:
	if types is ExcType:
		return exc_is_subclass(e.type, (types as ExcType).name)
	if typeof(types) == TYPE_ARRAY:
		for t: Variant in types:
			if _exc_matches(e, t):
				return true
		return false
	raise_error("TypeError", "en 'except' solo pueden ir tipos de excepción (p. ej. except ValueError:)")
	return false


func exc_is_subclass(name: String, ancestor: String) -> bool:
	var cur := name
	var guard := 0
	while not cur.is_empty() and guard < 20:
		if cur == ancestor:
			return true
		cur = str(EXC_PARENTS.get(cur, "Exception" if cur != "BaseException" and cur != "Exception" else ""))
		guard += 1
	return false


const _NO_KWARGS := {}


func _op_call(f: Array, arg: Array) -> void:
	var st: Array = f[F_STACK]
	var n: int = arg[0]
	var kwnames: Array = arg[1]
	var kwargs: Dictionary = _NO_KWARGS
	if arg[2] or not kwnames.is_empty():
		kwargs = {}
		if arg[2]:
			var dv: Variant = st.pop_back()
			if typeof(dv) != TYPE_DICTIONARY:
				raise_error("TypeError", "después de ** tiene que ir un diccionario, no '%s'" % type_name(dv))
				return
			for k: Variant in dv:
				if typeof(k) != TYPE_STRING:
					raise_error("TypeError", "las claves de ** tienen que ser cadenas")
					return
				kwargs[k] = dv[k]
		var nk := kwnames.size()
		if nk > 0:
			var base_k := st.size() - nk
			for i in nk:
				if kwargs.has(kwnames[i]):
					raise_error("TypeError", "el argumento '%s' se ha pasado dos veces" % kwnames[i])
					return
				kwargs[kwnames[i]] = st[base_k + i]
			st.resize(base_k)
	var args: Array = st.slice(st.size() - n) if n > 0 else []
	st.resize(st.size() - n)
	var fn: Variant = st.pop_back()
	if arg[3]:
		args = _expand_starred(args)
		if _exc != null:
			return
	if fn is Func:
		_push_call(fn, args, kwargs)
		return
	if fn is BoundMethod:
		_push_call((fn as BoundMethod).fn, [(fn as BoundMethod).obj] + args, kwargs)
		return
	if fn is PyClass:
		var inst := PyInstance.new()
		inst.cls = fn
		var init: Variant = (fn as PyClass).lookup("__init__")
		if init is Func:
			if _push_call(init, [inst] + args, kwargs):
				_frames[_frames.size() - 1].append(inst)
			return
		if not args.is_empty() or not kwargs.is_empty():
			raise_error("TypeError", "%s() no recibe argumentos: define __init__ para recibirlos" % (fn as PyClass).name)
			return
		st.push_back(inst)
		return
	var r: Variant = null
	if fn is Builtin:
		r = PyBuiltins.call_builtin(self, fn, args, kwargs)
	else:
		r = call_native(fn, args, kwargs)
	if _exc == null:
		st.push_back(r)


func _expand_starred(items: Array) -> Array:
	var has_star := false
	for x: Variant in items:
		if x is Starred:
			has_star = true
			break
	if not has_star:
		return items
	var out: Array = []
	for x: Variant in items:
		if x is Starred:
			var arr: Variant = to_array((x as Starred).value)
			if _exc != null:
				return []
			out.append_array(arr)
		else:
			out.append(x)
	return out


## Prepara el marco de una llamada a una función de Python. Devuelve false si hay error.
func _push_call(fn: Func, args: Array, kwargs: Dictionary) -> bool:
	if _frames.size() > MAX_DEPTH:
		raise_error("RecursionError", "se ha superado la profundidad máxima de recursión (%d llamadas anidadas): ¿falta el caso base o nunca se llega a él?" % MAX_DEPTH)
		return false
	_steps += 1
	if _steps > _max_steps or ((_steps & 1023) == 0 and Time.get_ticks_msec() > _deadline):
		_raise_fatal("StepLimitError", STEP_LIMIT_MESSAGE)
		return false
	var code := fn.code
	var vars := {}
	var np := code.params.size()
	var na := args.size()
	if na > np and code.vararg.is_empty():
		raise_error("TypeError", "%s() acepta %s pero se le pasaron %d" % [fn.name, _plural(np, "argumento posicional", "argumentos posicionales"), na])
		return false
	for i in mini(na, np):
		vars[code.params[i]] = args[i]
	if not code.vararg.is_empty():
		vars[code.vararg] = make_tuple(args.slice(np) if na > np else [])
	var extra := {}
	for k: String in kwargs:
		if code.params.has(k) or code.kwonly.has(k):
			if vars.has(k):
				raise_error("TypeError", "%s() recibió dos valores para el argumento '%s'" % [fn.name, k])
				return false
			vars[k] = kwargs[k]
		elif not code.kwarg.is_empty():
			extra[k] = kwargs[k]
		else:
			raise_error("TypeError", "%s() no tiene ningún parámetro llamado '%s'" % [fn.name, k])
			return false
	var missing: Array[String] = []
	var first_default := np - fn.defaults.size()
	for i in np:
		var pname: String = code.params[i]
		if not vars.has(pname):
			if i >= first_default:
				vars[pname] = fn.defaults[i - first_default]
			else:
				missing.append(pname)
	for k in code.kwonly:
		if not vars.has(k):
			if fn.kw_defaults.has(k):
				vars[k] = fn.kw_defaults[k]
			else:
				missing.append(k)
	if not missing.is_empty():
		var quoted := PackedStringArray()
		for m in missing:
			quoted.append("'%s'" % m)
		raise_error("TypeError", "a %s() le %s: %s" % [fn.name,
			"falta 1 argumento obligatorio" if missing.size() == 1 else "faltan %d argumentos obligatorios" % missing.size(),
			", ".join(quoted)])
		return false
	if not code.kwarg.is_empty():
		vars[code.kwarg] = extra
	_frames.append([code, 0, [], vars, fn.closure, [], [], null])
	return true


static func _plural(n: int, one: String, many: String) -> String:
	return "%d %s" % [n, one if n == 1 else many]


## Llama a cualquier valor invocable y espera el resultado (lo usan los builtins).
func call_sync(fn: Variant, args: Array, kwargs: Dictionary) -> Variant:
	if fn is Func:
		var base := _frames.size()
		if not _push_call(fn, args, kwargs):
			return null
		return _execute(base)
	return call_native(fn, args, kwargs)


func call_native(fn: Variant, args: Array, kwargs: Dictionary) -> Variant:
	if fn is Builtin:
		return PyBuiltins.call_builtin(self, fn, args, kwargs)
	if fn is Method:
		var m: Method = fn
		return PyBuiltins.call_method(self, m.obj, m.name, args, kwargs)
	if fn is ExcType:
		var e := Exc.new()
		e.type = (fn as ExcType).name
		e.args = args.duplicate()
		if args.size() == 1:
			e.message = py_str(args[0])
		elif args.size() > 1:
			e.message = py_repr(make_tuple(args))
		return e
	if fn is Func:
		return call_sync(fn, args, kwargs)
	if fn is BoundMethod:
		return call_sync((fn as BoundMethod).fn, [(fn as BoundMethod).obj] + args, kwargs)
	if fn is PyClass:
		var inst := PyInstance.new()
		inst.cls = fn
		var init: Variant = (fn as PyClass).lookup("__init__")
		if init is Func:
			call_sync(init, [inst] + args, kwargs)
		elif not args.is_empty() or not kwargs.is_empty():
			raise_error("TypeError", "%s() no recibe argumentos: define __init__ para recibirlos" % (fn as PyClass).name)
		return inst
	raise_error("TypeError", "el objeto de tipo '%s' no se puede llamar como una función (sobran los paréntesis)" % type_name(fn))
	return null


func is_callable(v: Variant) -> bool:
	return v is Func or v is Builtin or v is Method or v is ExcType or v is PyClass or v is BoundMethod


## Atributo de un objeto o de una clase definidos con class.
func get_object_attr(obj: Variant, n: String) -> Variant:
	if obj is PyInstance:
		var inst: PyInstance = obj
		if inst.fields.has(n):
			return inst.fields[n]
		if inst.cls.has(n):
			var v: Variant = inst.cls.lookup(n)
			if v is Func:
				var bm := BoundMethod.new()
				bm.fn = v
				bm.obj = inst
				return bm
			return v
		if n == "__class__":
			return inst.cls
		raise_error("AttributeError", "el objeto '%s' no tiene el atributo '%s'" % [inst.cls.name, n])
		return null
	var cls: PyClass = obj
	if cls.has(n):
		return cls.lookup(n)
	if n == "__name__":
		return cls.name
	raise_error("AttributeError", "la clase '%s' no tiene el atributo '%s'" % [cls.name, n])
	return null


# ── Tipos y verdad ───────────────────────────────────────────────────────────

func type_name(v: Variant) -> String:
	match typeof(v):
		TYPE_NIL:
			return "NoneType"
		TYPE_BOOL:
			return "bool"
		TYPE_INT:
			return "int"
		TYPE_FLOAT:
			return "float"
		TYPE_STRING:
			return "str"
		TYPE_ARRAY:
			return "tuple" if (v as Array).is_read_only() else "list"
		TYPE_DICTIONARY:
			return "dict"
		TYPE_OBJECT:
			if v is PyInstance:
				return (v as PyInstance).cls.name
			if v is PyClass:
				return "type"
			if v is BoundMethod:
				return "method"
			if v is Func:
				return "function"
			if v is Builtin:
				return "type" if PyBuiltins.TYPE_NAMES.has((v as Builtin).name) and (v as Builtin).module.is_empty() else "builtin_function_or_method"
			if v is Method:
				return "builtin_function_or_method"
			if v is PySet:
				return "set"
			if v is PyRange:
				return "range"
			if v is Module:
				return "module"
			if v is Exc:
				return (v as Exc).type
			if v is ExcType:
				return "type"
			if v is DictView:
				return "dict_" + (v as DictView).kind
			if v is PySlice:
				return "slice"
			if v is Iter:
				return ["list_iterator", "str_iterator", "range_iterator", "dict_keyiterator", "dict_valueiterator",
					"dict_itemiterator", "enumerate", "zip", "map", "filter", "set_iterator"][(v as Iter).kind]
	return "object"


static func is_num(v: Variant) -> bool:
	var t := typeof(v)
	return t == TYPE_INT or t == TYPE_FLOAT or t == TYPE_BOOL


static func is_int_like(v: Variant) -> bool:
	var t := typeof(v)
	return t == TYPE_INT or t == TYPE_BOOL


func truthy(v: Variant) -> bool:
	var t := typeof(v)
	if t == TYPE_BOOL:
		return v
	if t == TYPE_INT:
		return v != 0
	if t == TYPE_NIL:
		return false
	if t == TYPE_FLOAT:
		return v != 0.0
	if t == TYPE_STRING:
		return not (v as String).is_empty()
	if t == TYPE_ARRAY:
		return not (v as Array).is_empty()
	if t == TYPE_DICTIONARY:
		return not (v as Dictionary).is_empty()
	if v is PySet:
		return not (v as PySet).d.is_empty()
	if v is PyRange:
		return (v as PyRange).length() > 0
	if v is DictView:
		return not (v as DictView).d.is_empty()
	return true


func make_tuple(items: Array) -> Array:
	var t := items.duplicate() if items.is_read_only() else items
	t.make_read_only()
	return t


func make_set(items: Array) -> PySet:
	var s := PySet.new()
	for x: Variant in items:
		set_add(s, x)
		if _exc != null:
			return null
	return s


func set_add(s: PySet, v: Variant) -> void:
	if not check_hashable(v):
		return
	if _find_key_real(s.d, v) == null:
		s.d[v] = true
		if s.d.size() > MAX_ITEMS:
			_memory_error()


## ¿Se puede usar como clave de diccionario o elemento de un set? Si no, lanza TypeError.
func check_hashable(v: Variant) -> bool:
	match typeof(v):
		TYPE_ARRAY:
			var a: Array = v
			if not a.is_read_only():
				raise_error("TypeError", "una lista no puede ser clave de un diccionario ni elemento de un set (no es hashable): usa una tupla")
				return false
			for x: Variant in a:
				if not check_hashable(x):
					return false
			return true
		TYPE_DICTIONARY:
			raise_error("TypeError", "un diccionario no puede ser clave de otro diccionario ni elemento de un set (no es hashable)")
			return false
		TYPE_OBJECT:
			if v is PySet:
				raise_error("TypeError", "un set no puede ser clave de un diccionario ni elemento de otro set (no es hashable)")
				return false
	return true


## Busca en `d` una clave igual a `k` según Python (1 == 1.0 == True). Devuelve un Array
## [clave] si existe o null si no.
func _find_key_real(d: Dictionary, k: Variant) -> Variant:
	if d.has(k):
		return [k]
	match typeof(k):
		TYPE_FLOAT:
			var f: float = k
			if is_finite(f) and f == floorf(f) and absf(f) < 9.0e18:
				var ik := int(f)
				if d.has(ik):
					return [ik]
				if (ik == 0 or ik == 1) and d.has(ik == 1):
					return [ik == 1]
		TYPE_INT:
			if d.has(float(k)):
				return [float(k)]
			if (k == 0 or k == 1) and d.has(k == 1):
				return [k == 1]
		TYPE_BOOL:
			var ib := 1 if k else 0
			if d.has(ib):
				return [ib]
			if d.has(float(ib)):
				return [float(ib)]
	return null


func dict_has(d: Dictionary, k: Variant) -> bool:
	if not check_hashable(k):
		return false
	return _find_key_real(d, k) != null


func dict_get(d: Dictionary, k: Variant, default: Variant, raise_missing: bool) -> Variant:
	if not check_hashable(k):
		return null
	var found: Variant = _find_key_real(d, k)
	if found == null:
		if raise_missing:
			raise_error("KeyError", "la clave %s no existe en el diccionario" % py_repr(k))
		return default
	return d[found[0]]


func dict_set(d: Dictionary, k: Variant, v: Variant) -> void:
	if not check_hashable(k):
		return
	var found: Variant = _find_key_real(d, k)
	if found == null:
		d[k] = v
		if d.size() > MAX_ITEMS:
			_memory_error()
	else:
		d[found[0]] = v


func dict_erase(d: Dictionary, k: Variant) -> bool:
	if not check_hashable(k):
		return false
	var found: Variant = _find_key_real(d, k)
	if found == null:
		return false
	d.erase(found[0])
	return true


# ── Iteración ────────────────────────────────────────────────────────────────

func make_iter(v: Variant) -> Iter:
	var it := Iter.new()
	match typeof(v):
		TYPE_ARRAY:
			it.kind = IT_SEQ
			it.seq = v
			return it
		TYPE_STRING:
			it.kind = IT_STR
			it.seq = v
			return it
		TYPE_DICTIONARY:
			it.kind = IT_KEYS
			it.seq = v
			it.keys = (v as Dictionary).keys()
			it.size = (v as Dictionary).size()
			return it
		TYPE_OBJECT:
			if v is Iter:
				return v
			if v is PyRange:
				var r: PyRange = v
				it.kind = IT_RANGE
				it.i = r.start
				it.stop = r.stop
				it.step = r.step
				return it
			if v is PySet:
				it.kind = IT_SET
				it.seq = (v as PySet).d
				it.keys = (v as PySet).d.keys()
				it.size = it.keys.size()
				return it
			if v is DictView:
				var dv: DictView = v
				it.kind = {"keys": IT_KEYS, "values": IT_VALUES, "items": IT_ITEMS}[dv.kind]
				it.seq = dv.d
				it.keys = dv.d.keys()
				it.size = dv.d.size()
				return it
	raise_error("TypeError", "un valor de tipo '%s' no es iterable (no se puede recorrer con for)" % type_name(v))
	return null


## Avanza el iterador; el valor queda en _iter_value. false si se terminó (o hay error).
func iter_next(it: Iter) -> bool:
	match it.kind:
		IT_SEQ:
			var a: Array = it.seq
			if it.i < a.size():
				_iter_value = a[it.i]
				it.i += 1
				return true
			return false
		IT_RANGE:
			if (it.step > 0 and it.i < it.stop) or (it.step < 0 and it.i > it.stop):
				_iter_value = it.i
				it.i += it.step
				return true
			return false
		IT_STR:
			var s: String = it.seq
			if it.i < s.length():
				_iter_value = s[it.i]
				it.i += 1
				return true
			return false
		IT_KEYS, IT_VALUES, IT_ITEMS, IT_SET:
			var d: Dictionary = it.seq
			if d.size() != it.size:
				raise_error("RuntimeError", "el %s cambió de tamaño mientras se recorría" % ("set" if it.kind == IT_SET else "diccionario"))
				return false
			while it.i < it.keys.size():
				var k: Variant = it.keys[it.i]
				it.i += 1
				if not d.has(k):
					continue
				if it.kind == IT_VALUES:
					_iter_value = d[k]
				elif it.kind == IT_ITEMS:
					_iter_value = make_tuple([k, d[k]])
				else:
					_iter_value = k
				return true
			return false
		IT_ENUM:
			if iter_next(it.inner[0]):
				_iter_value = make_tuple([it.count, _iter_value])
				it.count += 1
				return true
			return false
		IT_ZIP:
			if it.inner.is_empty():
				return false
			var vals: Array = []
			for sub: Iter in it.inner:
				if not iter_next(sub):
					return false
				vals.append(_iter_value)
			_iter_value = make_tuple(vals)
			return true
		IT_MAP:
			var vals: Array = []
			for sub: Iter in it.inner:
				if not iter_next(sub):
					return false
				vals.append(_iter_value)
			var r: Variant = call_sync(it.fn, vals, {})
			if _exc != null:
				return false
			_iter_value = r
			return true
		IT_FILTER:
			while iter_next(it.inner[0]):
				var v: Variant = _iter_value
				var keep := false
				if it.fn == null:
					keep = truthy(v)
				else:
					var r: Variant = call_sync(it.fn, [v], {})
					if _exc != null:
						return false
					keep = truthy(r)
				if keep:
					_iter_value = v
					return true
				if not tick_work(1):
					return false
			return false
	return false


## Convierte cualquier iterable en un Array nuevo (o null si hay error).
func to_array(v: Variant) -> Variant:
	match typeof(v):
		TYPE_ARRAY:
			if not tick_work((v as Array).size()):
				return null
			return (v as Array).duplicate()
		TYPE_STRING:
			var s: String = v
			var out: Array = []
			for i in s.length():
				out.append(s[i])
			tick_work(s.length())
			return out
		TYPE_DICTIONARY:
			tick_work((v as Dictionary).size())
			return (v as Dictionary).keys()
	if v is PyRange:
		var r: PyRange = v
		var n := r.length()
		if n > MAX_ITEMS:
			_memory_error()
			return null
		if not tick_work(n):
			return null
		var out: Array = []
		out.resize(n)
		for i in n:
			out[i] = r.start + i * r.step
		return out
	if v is PySet:
		return (v as PySet).d.keys()
	var it := make_iter(v)
	if it == null:
		return null
	var out2: Array = []
	while iter_next(it):
		out2.append(_iter_value)
		if not tick_work(1):
			return null
		if out2.size() > MAX_ITEMS:
			_memory_error()
			return null
	if _exc != null:
		return null
	return out2


# ── Representación (str / repr) ──────────────────────────────────────────────

func py_str(v: Variant) -> String:
	if typeof(v) == TYPE_STRING:
		return v
	if v is PyInstance and (v as PyInstance).cls.has("__str__"):
		var r: Variant = call_sync((v as PyInstance).cls.lookup("__str__"), [v], _NO_KWARGS)
		return r if typeof(r) == TYPE_STRING else py_repr(r)
	if v is Exc:
		return (v as Exc).message
	return py_repr(v)


func py_repr(v: Variant) -> String:
	match typeof(v):
		TYPE_NIL:
			return "None"
		TYPE_BOOL:
			return "True" if v else "False"
		TYPE_INT:
			return str(v)
		TYPE_FLOAT:
			return PyNumber.float_repr(v)
		TYPE_STRING:
			return str_repr(v)
		TYPE_ARRAY:
			var a: Array = v
			for seen: Variant in _repr_stack:
				if is_same(seen, a):
					return "[...]" if not a.is_read_only() else "(...)"
			if _repr_stack.size() > 60:
				raise_error("RecursionError", "estructura demasiado anidada para mostrarla")
				return "..."
			_repr_stack.append(a)
			var parts := PackedStringArray()
			for x: Variant in a:
				parts.append(py_repr(x))
			_repr_stack.pop_back()
			if a.is_read_only():
				if a.size() == 1:
					return "(" + parts[0] + ",)"
				return "(" + ", ".join(parts) + ")"
			return "[" + ", ".join(parts) + "]"
		TYPE_DICTIONARY:
			var d: Dictionary = v
			for seen: Variant in _repr_stack:
				if is_same(seen, d):
					return "{...}"
			if _repr_stack.size() > 60:
				raise_error("RecursionError", "estructura demasiado anidada para mostrarla")
				return "..."
			_repr_stack.append(d)
			var parts := PackedStringArray()
			for k: Variant in d:
				parts.append(py_repr(k) + ": " + py_repr(d[k]))
			_repr_stack.pop_back()
			return "{" + ", ".join(parts) + "}"
		TYPE_OBJECT:
			if v is PySet:
				var s: PySet = v
				if s.d.is_empty():
					return "set()"
				var parts := PackedStringArray()
				for k: Variant in s.d:
					parts.append(py_repr(k))
				return "{" + ", ".join(parts) + "}"
			if v is PyRange:
				var r: PyRange = v
				if r.step == 1:
					return "range(%d, %d)" % [r.start, r.stop]
				return "range(%d, %d, %d)" % [r.start, r.stop, r.step]
			if v is PyInstance:
				var inst: PyInstance = v
				if inst.cls.has("__repr__"):
					var rr: Variant = call_sync(inst.cls.lookup("__repr__"), [v], _NO_KWARGS)
					return rr if typeof(rr) == TYPE_STRING else "<%s object>" % inst.cls.name
				return "<%s object>" % inst.cls.name
			if v is PyClass:
				return "<class '%s'>" % (v as PyClass).name
			if v is BoundMethod:
				return "<bound method %s of %s object>" % [(v as BoundMethod).fn.name, type_name((v as BoundMethod).obj)]
			if v is Func:
				return "<function %s>" % (v as Func).name
			if v is Builtin:
				var b: Builtin = v
				if (b.module.is_empty() and PyBuiltins.TYPE_NAMES.has(b.name)) or b.module == "<type>":
					return "<class '%s'>" % b.name
				if b.module.begins_with("unbound:"):
					return "<method '%s' of '%s' objects>" % [b.name, b.module.substr(8)]
				return "<built-in function %s>" % b.name
			if v is Method:
				return "<built-in method %s of %s object>" % [(v as Method).name, type_name((v as Method).obj)]
			if v is Module:
				return "<module '%s' (built-in)>" % (v as Module).name
			if v is Exc:
				var e: Exc = v
				var parts := PackedStringArray()
				for x: Variant in e.args:
					parts.append(py_repr(x))
				return "%s(%s)" % [e.type, ", ".join(parts)]
			if v is ExcType:
				return "<class '%s'>" % (v as ExcType).name
			if v is DictView:
				var dv: DictView = v
				var items: Array = []
				match dv.kind:
					"keys":
						items = dv.d.keys()
					"values":
						items = dv.d.values()
					"items":
						for k: Variant in dv.d:
							items.append(make_tuple([k, dv.d[k]]))
				return "dict_%s(%s)" % [dv.kind, py_repr(items)]
			if v is PySlice:
				var sl: PySlice = v
				return "slice(%s, %s, %s)" % [py_repr(sl.lo), py_repr(sl.hi), py_repr(sl.step)]
			if v is Iter:
				return "<%s object>" % type_name(v)
	return "<objeto>"


static func str_repr(s: String) -> String:
	var q := "'"
	if s.contains("'") and not s.contains("\""):
		q = "\""
	var out := q
	for i in s.length():
		var c := s[i]
		var u := s.unicode_at(i)
		if c == q or c == "\\":
			out += "\\" + c
		elif c == "\n":
			out += "\\n"
		elif c == "\t":
			out += "\\t"
		elif c == "\r":
			out += "\\r"
		elif u < 32 or u == 127:
			out += "\\x%02x" % u
		else:
			out += c
	return out + q


# ── Igualdad y orden ─────────────────────────────────────────────────────────

func py_eq(a: Variant, b: Variant, depth: int = 0) -> bool:
	var ta := typeof(a)
	var tb := typeof(b)
	if ta == TYPE_NIL or tb == TYPE_NIL:
		return ta == tb
	if is_num(a) and is_num(b):
		if ta == TYPE_FLOAT or tb == TYPE_FLOAT:
			return float(a) == float(b)
		return int(a) == int(b)
	if ta != tb:
		return false
	match ta:
		TYPE_STRING:
			return a == b
		TYPE_ARRAY:
			var x: Array = a
			var y: Array = b
			if is_same(x, y):
				return true
			if x.is_read_only() != y.is_read_only() or x.size() != y.size():
				return false
			if depth > 60:
				raise_error("RecursionError", "estructura demasiado anidada para compararla")
				return false
			for i in x.size():
				if not py_eq(x[i], y[i], depth + 1):
					return false
			return true
		TYPE_DICTIONARY:
			var x: Dictionary = a
			var y: Dictionary = b
			if is_same(x, y):
				return true
			if x.size() != y.size():
				return false
			if depth > 60:
				raise_error("RecursionError", "estructura demasiado anidada para compararla")
				return false
			for k: Variant in x:
				var found: Variant = _find_key_real(y, k)
				if found == null or not py_eq(x[k], y[found[0]], depth + 1):
					return false
			return true
		TYPE_OBJECT:
			if a is PySet and b is PySet:
				var x: PySet = a
				var y: PySet = b
				if x.d.size() != y.d.size():
					return false
				for k: Variant in x.d:
					if _find_key_real(y.d, k) == null:
						return false
				return true
			if a is PyRange and b is PyRange:
				var x: PyRange = a
				var y: PyRange = b
				var n := x.length()
				if n != y.length():
					return false
				if n == 0:
					return true
				return x.start == y.start and (n == 1 or x.step == y.step)
			if a is DictView and b is DictView:
				return (a as DictView).kind == (b as DictView).kind and py_eq((a as DictView).d.keys(), (b as DictView).d.keys(), depth + 1)
			return a == b
	return false


## Orden de Python para <, <=, >, >=.
func py_order(op: String, a: Variant, b: Variant) -> bool:
	if is_num(a) and is_num(b):
		var x: Variant = int(a) if typeof(a) == TYPE_BOOL else a
		var y: Variant = int(b) if typeof(b) == TYPE_BOOL else b
		match op:
			"<":
				return x < y
			"<=":
				return x <= y
			">":
				return x > y
			">=":
				return x >= y
	var ta := typeof(a)
	var tb := typeof(b)
	if ta == TYPE_STRING and tb == TYPE_STRING:
		match op:
			"<":
				return a < b
			"<=":
				return a <= b
			">":
				return a > b
			">=":
				return a >= b
	if ta == TYPE_ARRAY and tb == TYPE_ARRAY and (a as Array).is_read_only() == (b as Array).is_read_only():
		var x: Array = a
		var y: Array = b
		var n := mini(x.size(), y.size())
		for i in n:
			if not py_eq(x[i], y[i]):
				if _exc != null:
					return false
				return py_order(op, x[i], y[i])
		match op:
			"<":
				return x.size() < y.size()
			"<=":
				return x.size() <= y.size()
			">":
				return x.size() > y.size()
			">=":
				return x.size() >= y.size()
	if a is PySet and b is PySet:
		var x: PySet = a
		var y: PySet = b
		match op:
			"<=":
				return _subset(x, y)
			"<":
				return x.d.size() < y.d.size() and _subset(x, y)
			">=":
				return _subset(y, x)
			">":
				return y.d.size() < x.d.size() and _subset(y, x)
	raise_error("TypeError", "no se puede usar '%s' entre un valor '%s' y otro '%s'" % [op, type_name(a), type_name(b)])
	return false


func _subset(x: PySet, y: PySet) -> bool:
	for k: Variant in x.d:
		if _find_key_real(y.d, k) == null:
			return false
	return true


## a < b para ordenar (sorted, min, max).
func py_lt(a: Variant, b: Variant) -> bool:
	return py_order("<", a, b)


func compare_op(op: String, a: Variant, b: Variant) -> Variant:
	match op:
		"==":
			return py_eq(a, b)
		"!=":
			return not py_eq(a, b)
		"<", "<=", ">", ">=":
			return py_order(op, a, b)
		"in":
			return contains(b, a)
		"not in":
			var r := contains(b, a)
			return not r
		"is":
			return _identical(a, b)
		"is not":
			return not _identical(a, b)
	raise_error("SyntaxError", "comparación desconocida: %s" % op)
	return false


func _identical(a: Variant, b: Variant) -> bool:
	var ta := typeof(a)
	if ta != typeof(b):
		return false
	match ta:
		TYPE_NIL:
			return true
		TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return a == b
		TYPE_ARRAY, TYPE_DICTIONARY:
			return is_same(a, b)
		TYPE_OBJECT:
			return a == b
	return false


func contains(container: Variant, item: Variant) -> bool:
	match typeof(container):
		TYPE_STRING:
			if typeof(item) != TYPE_STRING:
				raise_error("TypeError", "para usar 'in' con una cadena, a la izquierda tiene que haber otra cadena, no '%s'" % type_name(item))
				return false
			return (container as String).contains(item)
		TYPE_ARRAY:
			for x: Variant in container:
				if py_eq(x, item):
					return true
			return false
		TYPE_DICTIONARY:
			return dict_has(container, item)
		TYPE_OBJECT:
			if container is PySet:
				return check_hashable(item) and _find_key_real((container as PySet).d, item) != null
			if container is PyRange:
				if not is_num(item):
					return false
				var r: PyRange = container
				if typeof(item) == TYPE_FLOAT and float(item) != floorf(item):
					return false
				var x := int(item)
				if r.step > 0 and (x < r.start or x >= r.stop):
					return false
				if r.step < 0 and (x > r.start or x <= r.stop):
					return false
				return (x - r.start) % r.step == 0
			if container is DictView:
				var dv: DictView = container
				match dv.kind:
					"keys":
						return dict_has(dv.d, item)
					"values":
						for k: Variant in dv.d:
							if py_eq(dv.d[k], item):
								return true
						return false
					"items":
						if typeof(item) != TYPE_ARRAY or (item as Array).size() != 2:
							return false
						var found: Variant = _find_key_real(dv.d, item[0])
						return found != null and py_eq(dv.d[found[0]], item[1])
			if container is Iter:
				while iter_next(container):
					if py_eq(_iter_value, item):
						return true
				return false
	raise_error("TypeError", "no se puede usar 'in' con un valor de tipo '%s'" % type_name(container))
	return false


# ── Operadores ───────────────────────────────────────────────────────────────

func unary_op(op: String, v: Variant) -> Variant:
	match op:
		"not":
			return not truthy(v)
		"-":
			match typeof(v):
				TYPE_INT:
					if v == PyNumber.INT_MIN:
						_overflow()
						return null
					return -v
				TYPE_BOOL:
					return -int(v)
				TYPE_FLOAT:
					return -float(v)
		"+":
			match typeof(v):
				TYPE_INT, TYPE_FLOAT:
					return v
				TYPE_BOOL:
					return int(v)
		"~":
			if is_int_like(v):
				return ~int(v)
	raise_error("TypeError", "el operador '%s' no se puede aplicar a un valor de tipo '%s'" % [op, type_name(v)])
	return null


func inplace_op(op: String, a: Variant, b: Variant) -> Variant:
	if op == "+" and typeof(a) == TYPE_ARRAY and not (a as Array).is_read_only():
		var items: Variant = to_array(b)
		if _exc != null:
			return null
		(a as Array).append_array(items)
		if (a as Array).size() > MAX_ITEMS:
			_memory_error()
		return a
	if a is PySet and b is PySet and op in ["|", "&", "-", "^"]:
		var r: PySet = binary_op(op, a, b)
		if _exc != null:
			return null
		(a as PySet).d = r.d
		return a
	if op == "|" and typeof(a) == TYPE_DICTIONARY and typeof(b) == TYPE_DICTIONARY:
		for k: Variant in b:
			dict_set(a, k, b[k])
		return a
	return binary_op(op, a, b)


func binary_op(op: String, a: Variant, b: Variant) -> Variant:
	var ta := typeof(a)
	var tb := typeof(b)
	if is_num(a) and is_num(b):
		if ta == TYPE_FLOAT or tb == TYPE_FLOAT:
			if op in ["&", "|", "^", "<<", ">>"]:
				raise_error("TypeError", "el operador '%s' solo funciona con enteros, no con '%s' y '%s'" % [op, type_name(a), type_name(b)])
				return null
			return float_op(op, float(a), float(b))
		if ta == TYPE_BOOL and tb == TYPE_BOOL and op in ["&", "|", "^"]:
			match op:
				"&":
					return a and b
				"|":
					return a or b
				"^":
					return a != b
		return int_op(op, int(a), int(b))
	match op:
		"+":
			if ta == TYPE_STRING and tb == TYPE_STRING:
				var s: String = a + b
				if s.length() > MAX_ITEMS * 2:
					_memory_error()
					return null
				return s
			if ta == TYPE_ARRAY and tb == TYPE_ARRAY and (a as Array).is_read_only() == (b as Array).is_read_only():
				var r: Array = (a as Array).duplicate()
				r.append_array(b)
				if r.size() > MAX_ITEMS:
					_memory_error()
					return null
				tick_work(r.size())
				return make_tuple(r) if (a as Array).is_read_only() else r
			if ta == TYPE_STRING:
				raise_error("TypeError", "solo se puede concatenar str con str, no con '%s': convierte el valor con str(...) o usa una f-string" % type_name(b))
				return null
			if tb == TYPE_STRING:
				raise_error("TypeError", "no se puede sumar un valor '%s' y una cadena (str): convierte con int(...)/float(...) o con str(...)" % type_name(a))
				return null
		"*":
			if (ta == TYPE_STRING or ta == TYPE_ARRAY) and is_int_like(b):
				return _repeat(a, int(b))
			if (tb == TYPE_STRING or tb == TYPE_ARRAY) and is_int_like(a):
				return _repeat(b, int(a))
			if (ta == TYPE_STRING or ta == TYPE_ARRAY) and tb == TYPE_FLOAT or (tb == TYPE_STRING or tb == TYPE_ARRAY) and ta == TYPE_FLOAT:
				raise_error("TypeError", "una secuencia solo se puede multiplicar por un entero, no por un float")
				return null
		"%":
			if ta == TYPE_STRING:
				return PyBuiltins.percent_format(self, a, b)
		"|", "&", "-", "^":
			if a is PySet and b is PySet:
				return _set_op(op, a, b)
			if op == "|" and ta == TYPE_DICTIONARY and tb == TYPE_DICTIONARY:
				var r: Dictionary = (a as Dictionary).duplicate()
				for k: Variant in b:
					dict_set(r, k, b[k])
				return r
	if (op == "-" or op == "/") and (ta == TYPE_STRING or tb == TYPE_STRING):
		raise_error("TypeError", "no se puede usar '%s' con cadenas (str): ¿necesitas convertir con int(...) o float(...)?" % op)
		return null
	raise_error("TypeError", "no se puede usar '%s' entre un valor '%s' y otro '%s'" % [op, type_name(a), type_name(b)])
	return null


func _repeat(seq: Variant, n: int) -> Variant:
	if n <= 0:
		if typeof(seq) == TYPE_STRING:
			return ""
		return make_tuple([]) if (seq as Array).is_read_only() else []
	if typeof(seq) == TYPE_STRING:
		var s: String = seq
		if s.length() * n > MAX_ITEMS * 2 or (s.length() > 0 and n > MAX_ITEMS * 2):
			_memory_error()
			return null
		if not tick_work(s.length() * n / 10):
			return null
		return s.repeat(n)
	var a: Array = seq
	if a.size() > 0 and (n > MAX_ITEMS or a.size() * n > MAX_ITEMS):
		_memory_error()
		return null
	if not tick_work(a.size() * n):
		return null
	var out: Array = []
	for _i in n:
		out.append_array(a)
	return make_tuple(out) if a.is_read_only() else out


func _set_op(op: String, x: PySet, y: PySet) -> PySet:
	var r := PySet.new()
	match op:
		"|":
			r.d = x.d.duplicate()
			for k: Variant in y.d:
				if _find_key_real(r.d, k) == null:
					r.d[k] = true
		"&":
			for k: Variant in x.d:
				if _find_key_real(y.d, k) != null:
					r.d[k] = true
		"-":
			for k: Variant in x.d:
				if _find_key_real(y.d, k) == null:
					r.d[k] = true
		"^":
			for k: Variant in x.d:
				if _find_key_real(y.d, k) == null:
					r.d[k] = true
			for k: Variant in y.d:
				if _find_key_real(x.d, k) == null:
					r.d[k] = true
	return r


func int_op(op: String, a: int, b: int) -> Variant:
	match op:
		"+":
			var r := a + b
			if (a >= 0) == (b >= 0) and (r >= 0) != (a >= 0):
				_overflow()
				return null
			return r
		"-":
			var r := a - b
			if (a >= 0) != (b >= 0) and (r >= 0) != (a >= 0):
				_overflow()
				return null
			return r
		"*":
			return mul_int(a, b)
		"/":
			if b == 0:
				raise_error("ZeroDivisionError", "división entre cero")
				return null
			return float(a) / float(b)
		"//":
			if b == 0:
				raise_error("ZeroDivisionError", "división entera entre cero")
				return null
			if b == -1:
				if a == PyNumber.INT_MIN:
					_overflow()
					return null
				return -a
			var q := a / b
			if (a % b != 0) and ((a < 0) != (b < 0)):
				q -= 1
			return q
		"%":
			if b == 0:
				raise_error("ZeroDivisionError", "módulo entre cero (x % 0 no está definido)")
				return null
			if b == -1:
				return 0
			var r := a % b
			if r != 0 and ((r < 0) != (b < 0)):
				r += b
			return r
		"**":
			if b < 0:
				if a == 0:
					raise_error("ZeroDivisionError", "0 no se puede elevar a una potencia negativa")
					return null
				return PyNumber.pow_float(float(a), float(b))
			return pow_int(a, b)
		"&":
			return a & b
		"|":
			return a | b
		"^":
			return a ^ b
		"<<":
			if b < 0:
				raise_error("ValueError", "no se puede desplazar un número negativo de bits")
				return null
			if a == 0:
				return 0
			if b >= 63 or ((a << b) >> b) != a:
				_overflow()
				return null
			return a << b
		">>":
			if b < 0:
				raise_error("ValueError", "no se puede desplazar un número negativo de bits")
				return null
			if b >= 63:
				return 0 if a >= 0 else -1
			return a >> b
	raise_error("TypeError", "operador desconocido '%s'" % op)
	return null


func mul_int(a: int, b: int) -> Variant:
	if a == 0 or b == 0:
		return 0
	if a == -1:
		if b == PyNumber.INT_MIN:
			_overflow()
			return null
		return -b
	if b == -1:
		if a == PyNumber.INT_MIN:
			_overflow()
			return null
		return -a
	var r := a * b
	if r / b != a:
		_overflow()
		return null
	return r


func pow_int(base: int, e: int) -> Variant:
	var result := 1
	var b := base
	var n := e
	while n > 0:
		if n & 1:
			var r: Variant = mul_int(result, b)
			if _exc != null:
				return null
			result = r
		n = n >> 1
		if n > 0:
			if absi(b) > 3037000499:
				_overflow()
				return null
			b = b * b
	return result


func float_op(op: String, a: float, b: float) -> Variant:
	match op:
		"+":
			return a + b
		"-":
			return a - b
		"*":
			return a * b
		"/":
			if b == 0.0:
				raise_error("ZeroDivisionError", "división entre cero")
				return null
			return a / b
		"//", "%":
			if b == 0.0:
				raise_error("ZeroDivisionError", "división entera entre cero" if op == "//" else "módulo entre cero (x % 0 no está definido)")
				return null
			var dm := float_divmod(a, b)
			return dm[0] if op == "//" else dm[1]
		"**":
			return float_pow(a, b)
	raise_error("TypeError", "operador desconocido '%s'" % op)
	return null


## divmod de floats exactamente como CPython (float_divmod).
static func float_divmod(vx: float, wx: float) -> Array[float]:
	var mod := fmod(vx, wx)
	var div := (vx - mod) / wx
	if mod != 0.0:
		if (wx < 0) != (mod < 0):
			mod += wx
			div -= 1.0
	else:
		mod = PyNumber.copysign(0.0, wx)
	var floordiv := 0.0
	if div != 0.0:
		floordiv = floorf(div)
		if div - floordiv > 0.5:
			floordiv += 1.0
	else:
		floordiv = PyNumber.copysign(0.0, vx / wx)
	return [floordiv, mod]


func float_pow(a: float, b: float) -> Variant:
	if a == 0.0 and b < 0.0:
		raise_error("ZeroDivisionError", "0.0 no se puede elevar a una potencia negativa")
		return null
	if a < 0.0 and is_finite(b) and b != floorf(b):
		raise_error("ValueError", "el resultado sería un número complejo (base negativa con exponente decimal): no disponible en el Dojo")
		return null
	var r := PyNumber.pow_float(a, b)
	if is_inf(r) and is_finite(a) and is_finite(b):
		raise_error("OverflowError", "el resultado es demasiado grande para un float")
		return null
	return r


# ── Índices y slices ─────────────────────────────────────────────────────────

func _index_of(v: Variant, what: String) -> Variant:
	if is_int_like(v):
		return int(v)
	raise_error("TypeError", "los índices de %s tienen que ser enteros (o slices), no '%s'" % [what, type_name(v)])
	return null


## [start, stop, step, length] como PySlice_AdjustIndices de CPython.
func slice_indices(sl: PySlice, length: int) -> Variant:
	var step := 1
	if sl.step != null:
		if not is_int_like(sl.step):
			raise_error("TypeError", "los valores de un slice tienen que ser enteros o None")
			return null
		step = int(sl.step)
		if step == 0:
			raise_error("ValueError", "el paso de un slice no puede ser cero")
			return null
	var lower := 0 if step > 0 else -1
	var upper := length if step > 0 else length - 1
	var start := lower if step > 0 else upper
	var stop := upper if step > 0 else lower
	if sl.lo != null:
		if not is_int_like(sl.lo):
			raise_error("TypeError", "los valores de un slice tienen que ser enteros o None")
			return null
		start = int(sl.lo)
		if start < 0:
			start += length
			if start < lower:
				start = lower
		elif start > upper:
			start = upper
	if sl.hi != null:
		if not is_int_like(sl.hi):
			raise_error("TypeError", "los valores de un slice tienen que ser enteros o None")
			return null
		stop = int(sl.hi)
		if stop < 0:
			stop += length
			if stop < lower:
				stop = lower
		elif stop > upper:
			stop = upper
	var n := 0
	if step > 0 and start < stop:
		n = (stop - start - 1) / step + 1
	elif step < 0 and stop < start:
		n = (start - stop - 1) / (-step) + 1
	return [start, stop, step, n]


func get_item(obj: Variant, idx: Variant) -> Variant:
	match typeof(obj):
		TYPE_ARRAY:
			var a: Array = obj
			if idx is PySlice:
				var si: Variant = slice_indices(idx, a.size())
				if si == null:
					return null
				var out: Array = []
				var k: int = si[0]
				for _i in int(si[3]):
					out.append(a[k])
					k += int(si[2])
				return make_tuple(out) if a.is_read_only() else out
			var what := "tupla" if a.is_read_only() else "lista"
			var iv: Variant = _index_of(idx, "una " + what)
			if iv == null:
				return null
			var i: int = iv
			if i < 0:
				i += a.size()
			if i < 0 or i >= a.size():
				raise_error("IndexError", "índice de %s fuera de rango: %d (la %s tiene %d elementos, índices de 0 a %d)" % [what, int(iv), what, a.size(), a.size() - 1])
				return null
			return a[i]
		TYPE_STRING:
			var s: String = obj
			if idx is PySlice:
				var si: Variant = slice_indices(idx, s.length())
				if si == null:
					return null
				if int(si[2]) == 1:
					return s.substr(int(si[0]), int(si[3]))
				var parts := PackedStringArray()
				var k: int = si[0]
				for _i in int(si[3]):
					parts.append(s[k])
					k += int(si[2])
				return "".join(parts)
			var iv: Variant = _index_of(idx, "una cadena")
			if iv == null:
				return null
			var i: int = iv
			if i < 0:
				i += s.length()
			if i < 0 or i >= s.length():
				raise_error("IndexError", "índice de cadena fuera de rango: %d (la cadena tiene %d caracteres)" % [int(iv), s.length()])
				return null
			return s[i]
		TYPE_DICTIONARY:
			return dict_get(obj, idx, null, true)
		TYPE_OBJECT:
			if obj is PyRange:
				var r: PyRange = obj
				var n := r.length()
				if idx is PySlice:
					var si: Variant = slice_indices(idx, n)
					if si == null:
						return null
					var nr := PyRange.new()
					nr.start = r.start + int(si[0]) * r.step
					nr.step = r.step * int(si[2])
					nr.stop = nr.start + int(si[3]) * nr.step
					return nr
				var iv: Variant = _index_of(idx, "un range")
				if iv == null:
					return null
				var i: int = iv
				if i < 0:
					i += n
				if i < 0 or i >= n:
					raise_error("IndexError", "índice de range fuera de rango")
					return null
				return r.at(i)
	if obj is DictView or obj is PySet:
		raise_error("TypeError", "un '%s' no admite índices: conviértelo antes con list(...)" % type_name(obj))
		return null
	raise_error("TypeError", "un valor de tipo '%s' no admite índices con [ ]" % type_name(obj))
	return null


func set_item(obj: Variant, idx: Variant, value: Variant) -> void:
	match typeof(obj):
		TYPE_ARRAY:
			var a: Array = obj
			if a.is_read_only():
				raise_error("TypeError", "las tuplas no se pueden modificar (son inmutables): usa una lista")
				return
			if idx is PySlice:
				var items: Variant = to_array(value)
				if _exc != null:
					return
				var si: Variant = slice_indices(idx, a.size())
				if si == null:
					return
				var arr: Array = items
				if int(si[2]) == 1:
					var start: int = si[0]
					var stop: int = maxi(int(si[1]), start)
					var tail := a.slice(stop)
					a.resize(start)
					a.append_array(arr)
					a.append_array(tail)
				else:
					if arr.size() != int(si[3]):
						raise_error("ValueError", "se intentan asignar %d elementos a un slice de %d" % [arr.size(), int(si[3])])
						return
					var k: int = si[0]
					for x: Variant in arr:
						a[k] = x
						k += int(si[2])
				return
			var iv: Variant = _index_of(idx, "una lista")
			if iv == null:
				return
			var i: int = iv
			if i < 0:
				i += a.size()
			if i < 0 or i >= a.size():
				raise_error("IndexError", "índice de lista fuera de rango al asignar: %d (la lista tiene %d elementos)" % [int(iv), a.size()])
				return
			a[i] = value
			return
		TYPE_DICTIONARY:
			dict_set(obj, idx, value)
			return
		TYPE_STRING:
			raise_error("TypeError", "las cadenas no se pueden modificar (son inmutables): crea una nueva, p. ej. con replace() o slices")
			return
	raise_error("TypeError", "un valor de tipo '%s' no admite asignación con [ ]" % type_name(obj))


func del_item(obj: Variant, idx: Variant) -> void:
	match typeof(obj):
		TYPE_ARRAY:
			var a: Array = obj
			if a.is_read_only():
				raise_error("TypeError", "las tuplas no se pueden modificar (son inmutables)")
				return
			if idx is PySlice:
				var si: Variant = slice_indices(idx, a.size())
				if si == null:
					return
				var remove := {}
				var k: int = si[0]
				for _i in int(si[3]):
					remove[k] = true
					k += int(si[2])
				var kept: Array = []
				for j in a.size():
					if not remove.has(j):
						kept.append(a[j])
				a.assign(kept)
				return
			var iv: Variant = _index_of(idx, "una lista")
			if iv == null:
				return
			var i: int = iv
			if i < 0:
				i += a.size()
			if i < 0 or i >= a.size():
				raise_error("IndexError", "índice de lista fuera de rango al borrar")
				return
			a.remove_at(i)
			return
		TYPE_DICTIONARY:
			if not dict_erase(obj, idx) and _exc == null:
				raise_error("KeyError", "la clave %s no existe en el diccionario" % py_repr(idx))
			return
	raise_error("TypeError", "no se pueden borrar elementos de un valor de tipo '%s'" % type_name(obj))


# ── Conversión con datos de GDScript ─────────────────────────────────────────

## Valor de Python → int, float, String, bool, null, Array o Dictionary de GDScript.
func to_plain(v: Variant, depth: int = 0) -> Variant:
	if depth > 60:
		return null
	match typeof(v):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return v
		TYPE_ARRAY:
			var out: Array = []
			for x: Variant in v:
				out.append(to_plain(x, depth + 1))
			return out
		TYPE_DICTIONARY:
			var out := {}
			for k: Variant in v:
				out[to_plain(k, depth + 1)] = to_plain(v[k], depth + 1)
			return out
	if v is PySet:
		var out: Array = []
		for k: Variant in (v as PySet).d:
			out.append(to_plain(k, depth + 1))
		return out
	if v is PyRange:
		var r: PyRange = v
		var out: Array = []
		for i in mini(r.length(), MAX_ITEMS):
			out.append(r.at(i))
		return out
	if v is DictView:
		var dv: DictView = v
		var out: Array = []
		for k: Variant in dv.d:
			match dv.kind:
				"keys":
					out.append(to_plain(k, depth + 1))
				"values":
					out.append(to_plain(dv.d[k], depth + 1))
				_:
					out.append([to_plain(k, depth + 1), to_plain(dv.d[k], depth + 1)])
		return out
	return py_repr(v)


## Datos de GDScript → valor de Python (copia profunda; lo que no sea dato simple → None).
func from_plain(v: Variant, depth: int = 0) -> Variant:
	if depth > 60:
		return null
	match typeof(v):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return v
		TYPE_STRING_NAME:
			return str(v)
		TYPE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, \
				TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY:
			var out: Array = []
			for x: Variant in v:
				out.append(from_plain(x, depth + 1))
			return out
		TYPE_DICTIONARY:
			var out := {}
			for k: Variant in v:
				var pk: Variant = from_plain(k, depth + 1)
				if typeof(pk) == TYPE_ARRAY:
					pk = make_tuple(pk)
				out[pk] = from_plain(v[k], depth + 1)
			return out
	return null
