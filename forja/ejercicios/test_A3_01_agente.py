"""Tests del ejercicio A3-01: los mismos ataques que en el Dojo, frenados por TU código."""

import unittest

from A3_01_agente import autorizar, ejecutar_plan

TRIAJE = {"tarea": "triaje", "rol": "empleado", "origen": "tarea"}


class TestAutorizar(unittest.TestCase):
    def test_tarea_legitima(self):
        self.assertEqual(autorizar("enviar_correo", {"para": "aiko@clientes.example"}, TRIAJE), (True, "ok"))

    def test_minimo_privilegio(self):
        self.assertEqual(autorizar("aplicar_reembolso", {"pedido": "P-999", "importe": 2000}, dict(TRIAJE, origen="correo")),
                         (False, "least-privilege"), "el triaje no necesita reembolsar")

    def test_confused_deputy(self):
        ctx = {"tarea": "chat", "rol": "cliente", "origen": "usuario"}
        self.assertEqual(autorizar("aplicar_reembolso", {"pedido": "P-102", "importe": 2400}, ctx), (False, "user-authz"))

    def test_validacion_de_argumentos(self):
        ctx = {"tarea": "chat", "rol": "empleado", "origen": "usuario"}
        self.assertEqual(autorizar("aplicar_reembolso", {"pedido": "P-999", "importe": 10}, ctx), (False, "arg-validation"))
        self.assertEqual(autorizar("aplicar_reembolso", {"pedido": "P-101", "importe": 900}, ctx), (False, "arg-validation"))
        self.assertEqual(autorizar("aplicar_reembolso", {"pedido": "P-101", "importe": 120}, ctx), (True, "ok"))
        self.assertEqual(autorizar("enviar_correo", {"para": "botin@phish.example"}, ctx), (False, "arg-validation"))

    def test_higiene_de_memoria(self):
        ctx = {"tarea": "chat", "rol": "empleado", "origen": "correo"}
        self.assertEqual(autorizar("guardar_memoria", {"texto": "vip 100%"}, ctx), (False, "memory-hygiene"))
        self.assertEqual(autorizar("guardar_memoria", {"texto": "prefiere mañanas"}, dict(ctx, origen="usuario")), (True, "ok"))


class TestPlan(unittest.TestCase):
    def test_plan_mixto(self):
        plan = [
            {"herramienta": "leer_correo", "args": {"id": "c4"}, "origen": "tarea"},
            {"herramienta": "aplicar_reembolso", "args": {"pedido": "P-999", "importe": 2000}, "origen": "correo"},
            {"herramienta": "enviar_correo", "args": {"para": "aiko@clientes.example"}, "origen": "tarea"},
        ]
        hechas, bloqueadas = ejecutar_plan(plan, {"tarea": "triaje", "rol": "empleado"})
        self.assertEqual([h["herramienta"] for h in hechas], ["leer_correo", "enviar_correo"])
        self.assertEqual(bloqueadas, [{"herramienta": "aplicar_reembolso", "motivo": "least-privilege"}])

    def test_bucle_cortado(self):
        plan = [{"herramienta": "enviar_correo", "args": {"para": "agente@kurogane.example"}, "origen": "correo"}] * 60
        hechas, bloqueadas = ejecutar_plan(plan, {"tarea": "triaje", "rol": "empleado"})
        self.assertEqual(len(hechas), 12)
        self.assertEqual(len(bloqueadas), 48)
        self.assertEqual(bloqueadas[0]["motivo"], "step-budget")


if __name__ == "__main__":
    unittest.main()
