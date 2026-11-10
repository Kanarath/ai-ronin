class_name PyCode
extends RefCounted
## Código compilado (bytecode de pila) de una función, lambda, comprensión o del módulo.
## Lo genera PyCompiler y lo ejecuta PyInterpreter sin recursión de GDScript, así que la
## profundidad de recursión de Python no depende de la pila del motor.

## Orden por frecuencia: el intérprete despacha primero las más usadas.
enum {
	CONST, LOAD_LOCAL, LOAD_GLOBAL, STORE_LOCAL, STORE_GLOBAL, BINARY, COMPARE,
	POP_JUMP_IF_FALSE, JUMP, FOR_ITER, INPLACE, LOAD_DEREF, CALL, RETURN, POP, SUBSCR,
	LOAD_ATTR, POP_JUMP_IF_TRUE, JUMP_IF_FALSE_OR_POP, JUMP_IF_TRUE_OR_POP, STORE_SUBSCR,
	DUP, ROT2, ROT3, LIST_APPEND, BUILD_TUPLE, BUILD_LIST, UNPACK, GET_ITER, UNARY,
	STORE_DEREF, DEL_LOCAL, DEL_DEREF, DEL_GLOBAL, DUP2,
	BUILD_DICT, BUILD_SET, BUILD_SLICE, BUILD_STRING, FORMAT, STAR,
	SET_ADD, DICT_SET, DEL_SUBSCR, STORE_ATTR,
	UNPACK_EX, MAKE_FUNCTION, IMPORT, IMPORT_FROM, IMPORT_STAR,
	SETUP_EXCEPT, POP_BLOCK, POP_EXCEPT, EXC_MATCH, RAISE, RERAISE, RAISE_ASSERT,
}

var name := "<module>"
var ops := PackedInt32Array()
var args: Array = []
var lines := PackedInt32Array()
## Parámetros posicionales (en orden), solo-nombre, *args y **kwargs.
var params: Array[String] = []
var kwonly: Array[String] = []
var vararg := ""
var kwarg := ""
var is_module := false


func emit(op: int, arg: Variant, line: int) -> int:
	ops.append(op)
	args.append(arg)
	lines.append(line)
	return ops.size() - 1


func here() -> int:
	return ops.size()


func patch(index: int, target: Variant) -> void:
	args[index] = target
