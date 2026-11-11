class_name PyNumpy
extends RefCounted
## «numpy» del Dojo: una NumPy mínima para aprender, con funciones sobre listas (vectores) y
## listas de listas (matrices). No es la NumPy real:
##   · los arrays son listas normales, así que a + b las une; para sumar usa np.add(a, b);
##   · sin .shape ni atributos: usa np.shape(a);
##   · se imprimen como listas de Python.
## Lo justo para escribir neuronas, capas, softmax, pérdidas y métricas como en la Forja.

const FUNCS: Array[String] = [
	"array", "zeros", "ones", "arange", "linspace", "shape", "transpose",
	"sum", "mean", "std", "var", "max", "min", "argmax", "argmin",
	"dot", "matmul", "outer",
	"add", "subtract", "multiply", "divide", "power", "maximum", "minimum",
	"exp", "log", "sqrt", "abs", "tanh", "square", "clip", "round", "sign",
]


static func module(vm: PyInterpreter) -> PyInterpreter.Module:
	var m := PyInterpreter.Module.new()
	m.name = "numpy"
	for f in FUNCS:
		m.members[f] = PyInterpreter.Builtin.new(f, "numpy")
	m.members["pi"] = PI
	m.members["e"] = exp(1.0)
	m.members["inf"] = INF
	return m


static func call_fn(vm: PyInterpreter, name: String, args: Array, kwargs: Dictionary) -> Variant:
	match name:
		"array":
			if not _need(vm, name, args, 1):
				return null
			return _copy(vm, args[0])
		"zeros", "ones":
			if not _need(vm, name, args, 1):
				return null
			return _filled(vm, name, args[0], 0.0 if name == "zeros" else 1.0)
		"arange":
			return _arange(vm, args)
		"linspace":
			if args.size() != 3:
				vm.raise_error("TypeError", "np.linspace(inicio, fin, n)")
				return null
			var n := int(args[2])
			var out: Array = []
			for i in n:
				out.append(float(args[0]) + (float(args[1]) - float(args[0])) * (float(i) / maxf(n - 1, 1)))
			return out
		"shape":
			if not _need(vm, name, args, 1):
				return null
			return vm.make_tuple(_shape(args[0]))
		"transpose":
			if not _need(vm, name, args, 1) or not _is_matrix(vm, name, args[0]):
				return null
			var mt: Array = args[0]
			var t: Array = []
			for j in (mt[0] as Array).size():
				var row: Array = []
				for i in mt.size():
					row.append(mt[i][j])
				t.append(row)
			return t
		"sum", "mean", "std", "var", "max", "min", "argmax", "argmin":
			if not _need(vm, name, args, 1):
				return null
			return _reduce(vm, name, args[0], kwargs.get("axis", null))
		"dot", "matmul":
			if args.size() != 2:
				vm.raise_error("TypeError", "np.%s(a, b) necesita dos argumentos" % name)
				return null
			return _dot(vm, args[0], args[1])
		"outer":
			if args.size() != 2:
				vm.raise_error("TypeError", "np.outer(a, b) necesita dos vectores")
				return null
			var o: Array = []
			for x: Variant in args[0]:
				var row: Array = []
				for y: Variant in args[1]:
					row.append(float(x) * float(y))
				o.append(row)
			return o
		"add", "subtract", "multiply", "divide", "power", "maximum", "minimum":
			if args.size() != 2:
				vm.raise_error("TypeError", "np.%s(a, b) necesita dos argumentos (listas o números)" % name)
				return null
			return _zip(vm, name, args[0], args[1])
		"exp", "log", "sqrt", "abs", "tanh", "square", "sign":
			if not _need(vm, name, args, 1):
				return null
			return _map(vm, name, args[0])
		"clip":
			if args.size() != 3:
				vm.raise_error("TypeError", "np.clip(a, minimo, maximo)")
				return null
			return _map_fn(vm, args[0], func(v: float) -> float: return clampf(v, float(args[1]), float(args[2])))
		"round":
			var d := int(args[1]) if args.size() > 1 else int(kwargs.get("decimals", 0))
			return _map_fn(vm, args[0], func(v: float) -> float: return snappedf(v, pow(10.0, -d)) if d > 0 else roundf(v))
	vm.raise_error("AttributeError", "np.%s no está en la NumPy del Dojo" % name)
	return null


static func _need(vm: PyInterpreter, name: String, args: Array, n: int) -> bool:
	if args.size() < n:
		vm.raise_error("TypeError", "np.%s() necesita %d argumento(s)" % [name, n])
		return false
	return true


static func _num(vm: PyInterpreter, v: Variant) -> bool:
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_BOOL:
		return true
	vm.raise_error("TypeError", "la NumPy del Dojo trabaja con números, no con '%s'" % vm.type_name(v))
	return false


static func _copy(vm: PyInterpreter, v: Variant) -> Variant:
	if typeof(v) == TYPE_ARRAY:
		var out: Array = []
		for x: Variant in v:
			out.append(_copy(vm, x))
		return out
	if not _num(vm, v):
		return null
	return v


static func _filled(vm: PyInterpreter, name: String, shape: Variant, value: float) -> Variant:
	if typeof(shape) == TYPE_INT:
		var out: Array = []
		out.resize(shape)
		out.fill(value)
		return out
	if typeof(shape) == TYPE_ARRAY and (shape as Array).size() == 2:
		var m: Array = []
		for i in int(shape[0]):
			var row: Array = []
			row.resize(int(shape[1]))
			row.fill(value)
			m.append(row)
		return m
	vm.raise_error("TypeError", "np.%s(n) o np.%s((filas, columnas))" % [name, name])
	return null


static func _arange(vm: PyInterpreter, args: Array) -> Variant:
	if args.is_empty() or args.size() > 3:
		vm.raise_error("TypeError", "np.arange(fin), np.arange(inicio, fin) o np.arange(inicio, fin, paso)")
		return null
	var start := 0.0 if args.size() == 1 else float(args[0])
	var stop := float(args[0]) if args.size() == 1 else float(args[1])
	var step := float(args[2]) if args.size() == 3 else 1.0
	var all_int := true
	for a: Variant in args:
		all_int = all_int and typeof(a) == TYPE_INT
	var out: Array = []
	var x := start
	while (step > 0 and x < stop) or (step < 0 and x > stop):
		out.append(int(x) if all_int else x)
		x += step
		if out.size() > 100000:
			break
	return out


static func _shape(v: Variant) -> Array:
	var s: Array = []
	var cur: Variant = v
	while typeof(cur) == TYPE_ARRAY:
		s.append((cur as Array).size())
		if (cur as Array).is_empty():
			break
		cur = cur[0]
	return s


static func _is_matrix(vm: PyInterpreter, name: String, v: Variant) -> bool:
	if typeof(v) == TYPE_ARRAY and not (v as Array).is_empty() and typeof(v[0]) == TYPE_ARRAY:
		return true
	vm.raise_error("TypeError", "np.%s necesita una matriz (lista de listas)" % name)
	return false


static func _flat(v: Variant, out: Array) -> void:
	if typeof(v) == TYPE_ARRAY:
		for x: Variant in v:
			_flat(x, out)
	else:
		out.append(float(v))


static func _reduce_list(vm: PyInterpreter, name: String, vals: Array) -> Variant:
	if vals.is_empty():
		vm.raise_error("ValueError", "np.%s de una lista vacía" % name)
		return null
	var s := 0.0
	for x: float in vals:
		s += x
	var mean := s / vals.size()
	match name:
		"sum":
			return s
		"mean":
			return mean
		"var", "std":
			var acc := 0.0
			for x: float in vals:
				acc += (x - mean) * (x - mean)
			return acc / vals.size() if name == "var" else sqrt(acc / vals.size())
		"max", "min":
			var best: float = vals[0]
			for x: float in vals:
				best = maxf(best, x) if name == "max" else minf(best, x)
			return best
		"argmax", "argmin":
			var bi := 0
			for i in vals.size():
				if (name == "argmax" and vals[i] > vals[bi]) or (name == "argmin" and vals[i] < vals[bi]):
					bi = i
			return bi
	return null


static func _reduce(vm: PyInterpreter, name: String, v: Variant, axis: Variant) -> Variant:
	if typeof(v) != TYPE_ARRAY:
		if not _num(vm, v):
			return null
		return float(v) if not name.begins_with("arg") else 0
	if axis == null:
		var flat: Array = []
		_flat(v, flat)
		return _reduce_list(vm, name, flat)
	if not _is_matrix(vm, name, v):
		return null
	var m: Array = v
	var out: Array = []
	if int(axis) == 0:
		for j in (m[0] as Array).size():
			var col: Array = []
			for row: Array in m:
				col.append(float(row[j]))
			out.append(_reduce_list(vm, name, col))
	else:
		for row: Array in m:
			var vals: Array = []
			_flat(row, vals)
			out.append(_reduce_list(vm, name, vals))
	return out


static func _dot(vm: PyInterpreter, a: Variant, b: Variant) -> Variant:
	if typeof(a) != TYPE_ARRAY or typeof(b) != TYPE_ARRAY:
		vm.raise_error("TypeError", "np.dot necesita listas (vectores o matrices)")
		return null
	var am: bool = not (a as Array).is_empty() and typeof(a[0]) == TYPE_ARRAY
	var bm: bool = not (b as Array).is_empty() and typeof(b[0]) == TYPE_ARRAY
	if not am and not bm:
		if (a as Array).size() != (b as Array).size():
			vm.raise_error("ValueError", "np.dot: los vectores tienen tamaños distintos (%d y %d)" % [(a as Array).size(), (b as Array).size()])
			return null
		var s := 0.0
		for i in (a as Array).size():
			s += float(a[i]) * float(b[i])
		return s
	if am and not bm:
		var out: Array = []
		for row: Variant in a:
			out.append(_dot(vm, row, b))
			if vm.has_error():
				return null
		return out
	if not am and bm:
		var rr: Variant = _dot(vm, [a], b)
		return rr[0] if rr != null else null
	var bt: Array = []
	for j in (b[0] as Array).size():
		var col: Array = []
		for row: Variant in b:
			col.append(row[j])
		bt.append(col)
	var res: Array = []
	for row: Variant in a:
		var r: Array = []
		for col: Array in bt:
			r.append(_dot(vm, row, col))
			if vm.has_error():
				return null
		res.append(r)
	return res


static func _scalar(name: String, x: float, y: float) -> float:
	match name:
		"add": return x + y
		"subtract": return x - y
		"multiply": return x * y
		"divide": return x / y if y != 0.0 else (INF if x > 0 else (-INF if x < 0 else NAN))
		"power": return pow(x, y)
		"maximum": return maxf(x, y)
		"minimum": return minf(x, y)
	return 0.0


static func _zip(vm: PyInterpreter, name: String, a: Variant, b: Variant) -> Variant:
	var la := typeof(a) == TYPE_ARRAY
	var lb := typeof(b) == TYPE_ARRAY
	if not la and not lb:
		if not _num(vm, a) or not _num(vm, b):
			return null
		return _scalar(name, float(a), float(b))
	if la and lb:
		if (a as Array).size() != (b as Array).size():
			vm.raise_error("ValueError", "np.%s: las listas tienen tamaños distintos (%d y %d)" % [name, (a as Array).size(), (b as Array).size()])
			return null
		var out: Array = []
		for i in (a as Array).size():
			out.append(_zip(vm, name, a[i], b[i]))
			if vm.has_error():
				return null
		return out
	var out2: Array = []
	for x: Variant in (a if la else b):
		out2.append(_zip(vm, name, x, b) if la else _zip(vm, name, a, x))
		if vm.has_error():
			return null
	return out2


static func _map(vm: PyInterpreter, name: String, v: Variant) -> Variant:
	return _map_fn(vm, v, func(x: float) -> float:
		match name:
			"exp": return exp(x)
			"log": return log(x) if x > 0 else (-INF if x == 0 else NAN)
			"sqrt": return sqrt(x) if x >= 0 else NAN
			"abs": return absf(x)
			"tanh": return tanh(x)
			"square": return x * x
			"sign": return signf(x)
		return x)


static func _map_fn(vm: PyInterpreter, v: Variant, f: Callable) -> Variant:
	if typeof(v) == TYPE_ARRAY:
		var out: Array = []
		for x: Variant in v:
			out.append(_map_fn(vm, x, f))
			if vm.has_error():
				return null
		return out
	if not _num(vm, v):
		return null
	return f.call(float(v))
