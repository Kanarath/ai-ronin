"""Ejercicio A3-01 · La capa de autorización de las herramientas de un agente.

En un agente real, el LLM solo PROPONE llamadas a herramientas; el código decide si se ejecutan.
Vas a escribir ese código: la puerta que el modelo no puede convencer.
Python que practicas: diccionarios de configuración, funciones que devuelven (bool, motivo),
str.split y bucles con contador (PYTHON.md §3, §4, §8).

Ejecuta los tests desde forja/ejercicios:
    python -m unittest -v test_A3_01_agente
"""

HERRAMIENTAS_POR_TAREA = {
    "triaje": {"leer_correo", "buscar_pedido", "enviar_correo"},
    "chat": {"buscar_pedido", "aplicar_reembolso", "enviar_correo", "guardar_memoria", "leer_memoria"},
    "presupuesto": {"buscar_pedido", "leer_memoria"},
}
DOMINIOS_PERMITIDOS = {"kurogane.example", "clientes.example"}
PEDIDOS = {"P-101": 800, "P-102": 2400, "P-103": 3200}   # pedido → importe
PRESUPUESTO_PASOS = 12


def autorizar(herramienta, args, contexto):
    """Decide si una llamada a herramienta se ejecuta. Devuelve (permitido, motivo).

    contexto = {"tarea": "triaje"|"chat"|"presupuesto", "rol": "empleado"|"cliente", "origen": "usuario"|"tarea"|"correo"}

    Comprueba EN ESTE ORDEN y devuelve el primer motivo de bloqueo:
      1. "least-privilege": la herramienta no está en HERRAMIENTAS_POR_TAREA[tarea].
      2. "user-authz": aplicar_reembolso y el rol no es "empleado".
      3. "arg-validation":
         - aplicar_reembolso: el pedido no existe, o el importe es <= 0 o mayor que el del pedido.
         - enviar_correo: el dominio de args["para"] (lo que va detrás de la @) no está permitido.
      4. "memory-hygiene": guardar_memoria cuyo origen es "correo".
    Si todo está bien: (True, "ok").
    """
    raise NotImplementedError("Tu turno: implementa autorizar")


def ejecutar_plan(plan, contexto):
    """Recorre una lista de llamadas propuestas [{"herramienta", "args", "origen"}] y devuelve
    (ejecutadas, bloqueadas): dos listas de diccionarios.

    - Cada llamada se autoriza con un contexto que tiene su propio "origen".
    - Las bloqueadas se guardan como {"herramienta", "motivo"}.
    - Presupuesto de pasos: cuando ya se han procesado PRESUPUESTO_PASOS llamadas (ejecutadas o
      bloqueadas), el resto se bloquea con motivo "step-budget".
    """
    raise NotImplementedError("Tu turno: implementa ejecutar_plan")
