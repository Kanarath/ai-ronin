extends TestCase
## Clases en el mini-Python del Dojo: la salida tiene que ser la misma que en CPython.

const PROGRAMAS := {
	"basica": ["class Katana:\n    material = \"tamahagane\"\n\n    def __init__(self, nombre, dureza):\n        self.nombre = nombre\n        self.dureza = dureza\n\n    def apta(self):\n        return 58 <= self.dureza <= 64\n\nk = Katana(\"hoja-001\", 62.6)\nprint(k.nombre, k.dureza, k.apta())\nprint(Katana.material, k.material)\nk.dureza = 70\nprint(k.apta())\n", ["hoja-001 62.6 True", "tamahagane tamahagane", "False"]],
	"metodos_y_estado": ["class Contador:\n    def __init__(self):\n        self.cuenta = {}\n\n    def ver(self, palabra):\n        self.cuenta[palabra] = self.cuenta.get(palabra, 0) + 1\n        return self\n\n    def top(self):\n        return max(self.cuenta, key=lambda p: self.cuenta[p])\n\nc = Contador()\nfor p in \"el maestro y el aprendiz y el temple\".split():\n    c.ver(p)\nprint(c.top(), c.cuenta[\"y\"])\nprint(c.ver(\"x\").cuenta[\"x\"])\n", ["el 2", "1"]],
	"herencia": ["class Modelo:\n    def __init__(self, nombre):\n        self.nombre = nombre\n\n    def predecir(self, x):\n        return 0\n\n    def describir(self):\n        return self.nombre + \" predice \" + str(self.predecir(3))\n\nclass Doble(Modelo):\n    def __init__(self):\n        Modelo.__init__(self, \"doble\")\n\n    def predecir(self, x):\n        return 2 * x\n\nm = Doble()\nprint(m.describir())\nprint(isinstance(m, Doble), isinstance(m, Modelo), isinstance(3, Modelo))\n", ["doble predice 6", "True True False"]],
	"str_repr": ["class Punto:\n    def __init__(self, x, y):\n        self.x = x\n        self.y = y\n\n    def __repr__(self):\n        return f\"Punto({self.x}, {self.y})\"\n\n    def __str__(self):\n        return f\"({self.x}, {self.y})\"\n\np = Punto(1, 2)\nprint(p)\nprint([p, Punto(3, 4)])\nprint(str(p) + \"!\")\n", ["(1, 2)", "[Punto(1, 2), Punto(3, 4)]", "(1, 2)!"]],
	"neurona": ["import math\n\nclass Neurona:\n    def __init__(self, pesos, sesgo):\n        self.pesos = pesos\n        self.sesgo = sesgo\n\n    def salida(self, x):\n        z = self.sesgo + sum(w * xi for w, xi in zip(self.pesos, x))\n        return 1 / (1 + math.exp(-z))\n\nn = Neurona([20, 20], -10)\nprint([round(n.salida(x), 4) for x in [[0, 0], [0, 1], [1, 1]]])\n", ["[0.0, 1.0, 1.0]"]],
}


func test_programas_con_clases_como_cpython() -> void:
	for k: String in PROGRAMAS:
		var res: Dictionary = PyInterpreter.new().run(PROGRAMAS[k][0])
		assert_true(res["ok"], "%s: %s" % [k, str(res.get("error", ""))])
		assert_eq(Array(res["output"]), PROGRAMAS[k][1], k)


func test_errores_de_clases_en_castellano() -> void:
	var r: Dictionary = PyInterpreter.new().run("class A:\n    pass\na = A()\nprint(a.x)\n")
	assert_false(r["ok"])
	assert_eq(r["error"]["type"], "AttributeError")
	assert_eq(r["error"]["line"], 4)
	r = PyInterpreter.new().run("class A:\n    def __init__(self, x):\n        self.x = x\nA()\n")
	assert_eq(r["error"]["type"], "TypeError")
	r = PyInterpreter.new().run("class A(int):\n    pass\n")
	assert_false(r["ok"], "solo se hereda de clases propias")
	r = PyInterpreter.new().run("class A:\n    pass\na = A()\na.__dict__ = 1\n")
	assert_false(r["ok"], "los atributos dunder no se tocan")
