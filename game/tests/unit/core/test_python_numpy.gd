extends TestCase
## numpy del Dojo: cada expresión da lo mismo que la NumPy real (2.5.4), con tolerancia 1e-9.

const CASOS := {
	"array": ["np.array([[1, 2], [3, 4]])", [[1.0, 2.0], [3.0, 4.0]]],
	"zeros": ["np.zeros((2, 3))", [[0.0, 0.0, 0.0], [0.0, 0.0, 0.0]]],
	"ones": ["np.ones(3)", [1.0, 1.0, 1.0]],
	"arange": ["np.arange(0, 1, 0.25)", [0.0, 0.25, 0.5, 0.75]],
	"arange_int": ["np.arange(5)", [0.0, 1.0, 2.0, 3.0, 4.0]],
	"linspace": ["np.linspace(0, 1, 5)", [0.0, 0.25, 0.5, 0.75, 1.0]],
	"shape": ["np.shape([[1, 2, 3], [4, 5, 6]])", [2.0, 3.0]],
	"transpose": ["np.transpose([[1, 2, 3], [4, 5, 6]])", [[1.0, 4.0], [2.0, 5.0], [3.0, 6.0]]],
	"sum": ["np.sum([[1, 2], [3, 4]])", 10.0],
	"sum_axis0": ["np.sum([[1, 2], [3, 4]], axis=0)", [4.0, 6.0]],
	"mean_axis1": ["np.mean([[1, 2], [3, 5]], axis=1)", [1.5, 4.0]],
	"std": ["np.std([2, 4, 4, 4, 5, 5, 7, 9])", 2.0],
	"var": ["np.var([1, 2, 3, 4])", 1.25],
	"max": ["np.max([3, 9, 2])", 9.0],
	"argmax": ["np.argmax([0.1, 0.7, 0.2])", 1.0],
	"argmin_axis1": ["np.argmin([[3, 1, 2], [0, 5, 4]], axis=1)", [1.0, 0.0]],
	"dot_vv": ["np.dot([1, 2, 3], [4, 5, 6])", 32.0],
	"dot_mv": ["np.dot([[1, 2], [3, 4]], [5, 6])", [17.0, 39.0]],
	"dot_mm": ["np.dot([[1, 2], [3, 4]], [[5, 6], [7, 8]])", [[19.0, 22.0], [43.0, 50.0]]],
	"dot_vm": ["np.dot([1, 2], [[1, 0, 2], [0, 1, 3]])", [1.0, 2.0, 8.0]],
	"outer": ["np.outer([1, 2], [3, 4, 5])", [[3.0, 4.0, 5.0], [6.0, 8.0, 10.0]]],
	"add_scalar": ["np.add([1, 2, 3], 10)", [11.0, 12.0, 13.0]],
	"subtract": ["np.subtract([[5, 6], [7, 8]], [[1, 1], [2, 2]])", [[4.0, 5.0], [5.0, 6.0]]],
	"multiply": ["np.multiply([1, 2, 3], [4, 5, 6])", [4.0, 10.0, 18.0]],
	"divide": ["np.divide([1, 2, 3], 2)", [0.5, 1.0, 1.5]],
	"power": ["np.power([1, 2, 3], 2)", [1.0, 4.0, 9.0]],
	"maximum_relu": ["np.maximum([-1.5, 0.0, 2.0], 0)", [0.0, 0.0, 2.0]],
	"exp": ["np.exp([0, 1, 2])", [1.0, 2.718281828459045, 7.38905609893065]],
	"log": ["np.log([1, 2.718281828459045])", [0.0, 1.0]],
	"sqrt": ["np.sqrt([4, 9, 2])", [2.0, 3.0, 1.4142135623730951]],
	"tanh": ["np.tanh([-1, 0, 1])", [-0.7615941559557649, 0.0, 0.7615941559557649]],
	"clip": ["np.clip([0.0, 0.5, 1.2], 1e-12, 1 - 1e-12)", [1e-12, 0.5, 0.999999999999]],
	"abs": ["np.abs([-2, 3, -0.5])", [2.0, 3.0, 0.5]],
	"softmax": ["np.divide(np.exp([2.0, 1.0, 0.1]), np.sum(np.exp([2.0, 1.0, 0.1])))", [0.6590011388859679, 0.2424329707047139, 0.09856589040931818]],
}


func _num(v: Variant) -> Variant:
	if typeof(v) == TYPE_ARRAY:
		return (v as Array).map(func(x: Variant) -> Variant: return _num(x))
	return float(v)


func _close(a: Variant, b: Variant) -> bool:
	if typeof(a) == TYPE_ARRAY and typeof(b) == TYPE_ARRAY:
		if (a as Array).size() != (b as Array).size():
			return false
		for i in (a as Array).size():
			if not _close(a[i], b[i]):
				return false
		return true
	if typeof(a) == TYPE_ARRAY or typeof(b) == TYPE_ARRAY:
		return false
	return absf(float(a) - float(b)) <= 1e-9 * maxf(1.0, absf(float(b)))


func test_numpy_del_dojo_como_la_real() -> void:
	for k: String in CASOS:
		var vm := PyInterpreter.new()
		var res: Dictionary = vm.run("import numpy as np\nr = " + CASOS[k][0] + "\n")
		assert_true(res["ok"], "%s: %s" % [k, str(res.get("error", ""))])
		var got: Variant = _num(vm.to_plain(vm.get_global("r")))
		assert_true(_close(got, CASOS[k][1]), "%s: %s frente a %s" % [k, str(got), str(CASOS[k][1])])


func test_numpy_neurona_con_clase() -> void:
	var src := "import numpy as np\nclass Capa:\n    def __init__(self, W, b):\n        self.W = W\n        self.b = b\n    def forward(self, x):\n        return np.maximum(np.add(np.dot(self.W, x), self.b), 0)\nc = Capa([[1, -1], [0.5, 2]], [0, -1])\nprint(c.forward([2, 1]))\n"
	var res: Dictionary = PyInterpreter.new().run(src)
	assert_true(res["ok"], str(res.get("error", "")))
	assert_eq(Array(res["output"]), ["[1.0, 2.0]"])


func test_numpy_errores_claros() -> void:
	var res: Dictionary = PyInterpreter.new().run("import numpy as np\nnp.dot([1, 2], [1, 2, 3])\n")
	assert_eq(res["error"]["type"], "ValueError")
	res = PyInterpreter.new().run("import numpy as np\nnp.fft([1])\n")
	assert_eq(res["error"]["type"], "AttributeError")
