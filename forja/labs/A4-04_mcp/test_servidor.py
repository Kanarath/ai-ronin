"""Tests del laboratorio A4-04. Sin red: los servidores MCP (SDK oficial `mcp`) se levantan dentro
del proceso y el cliente MCP les habla por HTTP con httpx2.ASGITransport. Los servidores usan anyio,
así que las pruebas con servidor se ejecutan con anyio.run; las de funciones puras, no.

Con los stubs sin implementar, todo falla como «no implementado». Cuando implementes las siete
funciones de servidor.py, los tests pasan.
"""

import re
import unittest

import anyio

import servidor
from servidor import (CANARIO, EMISOR, EMISOR_URL, ESQUEMAS, FUTURO, MARCA_REEMBOLSO, PASADO, PLANOS,
                      RECURSO_ALMACEN, audiencia_valida, huella_definicion, revisar_definiciones, ruta_segura,
                      scopes_que_faltan, senales_sospechosas, validar_argumentos)
from host import escenario, ordenes_ocultas

AHORA = 2_000_000_000  # entre PASADO y FUTURO


def _def(nombre, descripcion="d", esquema=None):
    return {"name": nombre, "description": descripcion, "inputSchema": esquema or {"type": "object"}}


class TestValidarArgumentos(unittest.TestCase):
    def test_no_es_objeto(self):
        self.assertEqual(validar_argumentos(ESQUEMAS["buscar_pedido"], "P-101"), ["no es un objeto"])

    def test_falta_required(self):
        self.assertEqual(validar_argumentos(ESQUEMAS["aplicar_reembolso"], {"pedido": "P-101"}), ["falta importe"])

    def test_sobra_con_additional_false(self):
        self.assertEqual(validar_argumentos(ESQUEMAS["buscar_pedido"], {"pedido": "P-101", "x": 1}), ["sobra x"])

    def test_tipo_booleano_no_es_entero(self):
        self.assertEqual(validar_argumentos(ESQUEMAS["aplicar_reembolso"], {"pedido": "P-101", "importe": True}), ["importe: tipo"])

    def test_rango_y_formato(self):
        self.assertEqual(validar_argumentos(ESQUEMAS["aplicar_reembolso"], {"pedido": "P-101", "importe": 99999}), ["importe: rango"])
        # Una ruta con «..» no cumple el patrón del nombre del plano.
        self.assertEqual(validar_argumentos(ESQUEMAS["leer_plano"], {"nombre": "../privado/costes.txt"}), ["nombre: formato"])

    def test_longitud_y_formato_a_la_vez_y_en_orden(self):
        self.assertEqual(validar_argumentos(ESQUEMAS["leer_plano"], {"nombre": ""}), ["nombre: longitud", "nombre: formato"])

    def test_validos(self):
        self.assertEqual(validar_argumentos(ESQUEMAS["buscar_pedido"], {"pedido": "P-101"}), [])
        self.assertEqual(validar_argumentos(ESQUEMAS["aplicar_reembolso"], {"pedido": "P-999", "importe": 150}), [])
        self.assertEqual(validar_argumentos(ESQUEMAS["leer_plano"], {"nombre": "aceros/tamahagane.txt"}), [])


class TestScopes(unittest.TestCase):
    def test_jerarquia(self):
        self.assertEqual(scopes_que_faltan("pedidos:read", ["pedidos:read"]), [])
        self.assertEqual(scopes_que_faltan("pedidos:write", ["pedidos:read"]), [])
        self.assertEqual(scopes_que_faltan("pedidos:admin", ["pedidos:read", "pedidos:write"]), [])

    def test_faltan_ordenados(self):
        self.assertEqual(scopes_que_faltan("pedidos:read", ["pedidos:write"]), ["pedidos:write"])
        self.assertEqual(scopes_que_faltan(["clima:read"], ["planos:read", "pedidos:read"]), ["pedidos:read", "planos:read"])
        self.assertEqual(scopes_que_faltan(None, ["x"]), ["x"])
        self.assertEqual(scopes_que_faltan("", ["x"]), ["x"])

    def test_distingue_mayusculas(self):
        self.assertEqual(scopes_que_faltan("Pedidos:Read", ["pedidos:read"]), ["pedidos:read"])

    def test_ciclo_no_cuelga(self):
        self.assertEqual(scopes_que_faltan("a", ["c"], {"a": ["b"], "b": ["a"]}), ["c"])
        self.assertEqual(scopes_que_faltan("a", ["b"], {"a": ["b"], "b": ["a"]}), [])


class TestRutaSegura(unittest.TestCase):
    def test_validas(self):
        base = PLANOS.resolve()
        self.assertTrue(ruta_segura(PLANOS, "katana-basica.txt").is_relative_to(base))
        self.assertTrue(ruta_segura(PLANOS, "aceros/tamahagane.txt").is_relative_to(base))
        # «..» que no se sale de la carpeta es válido.
        self.assertEqual(ruta_segura(PLANOS, "aceros/../katana-basica.txt"), base / "katana-basica.txt")

    def test_traversal_y_absolutas(self):
        for nombre in ["../privado/costes.txt", "aceros/../../privado/costes.txt", "/etc/passwd", "C:/windows", "a\\b.txt"]:
            with self.assertRaises(ValueError, msg=nombre):
                ruta_segura(PLANOS, nombre)

    def test_entradas_no_validas(self):
        for nombre in ["", "aceros/..", ".", "x\x00.txt", 123, None]:
            with self.assertRaises(ValueError, msg=repr(nombre)):
                ruta_segura(PLANOS, nombre)


class TestHuellaYRevision(unittest.TestCase):
    def test_huella(self):
        h = huella_definicion(_def("t", "hola", {"type": "object"}))
        self.assertEqual(len(h), 64)
        self.assertTrue(re.fullmatch(r"[0-9a-f]{64}", h))
        self.assertEqual(huella_definicion({"name": "t"}), huella_definicion({"name": "t", "description": "", "inputSchema": {}}))
        self.assertNotEqual(huella_definicion(_def("t", "a")), huella_definicion(_def("t", "b")))
        # title/annotations no cuentan.
        self.assertEqual(h, huella_definicion(dict(_def("t", "hola", {"type": "object"}), title="T", annotations={"x": 1})))

    def test_revisar(self):
        fijadas = {"a": huella_definicion(_def("a", "v1")), "b": huella_definicion(_def("b", "vb"))}
        actuales = [_def("a", "v2"), _def("c", "vc")]
        self.assertEqual(revisar_definiciones(fijadas, actuales),
                         {"nuevas": ["c"], "cambiadas": ["a"], "desaparecidas": ["b"]})

    def test_duplicado_es_cambio(self):
        fijadas = {"a": huella_definicion(_def("a", "v1"))}
        actuales = [_def("a", "v1"), _def("a", "v1")]
        self.assertEqual(revisar_definiciones(fijadas, actuales)["cambiadas"], ["a"])


class TestSenales(unittest.TestCase):
    def test_cada_senal(self):
        self.assertIn("etiqueta", senales_sospechosas("texto <IMPORTANT> ... </IMPORTANT>"))
        self.assertIn("ocultacion", senales_sospechosas("Hazlo y No lo menciones al usuario"))
        self.assertIn("otra_herramienta", senales_sospechosas("luego usa leer_plano", ["leer_plano", "x"]))
        self.assertIn("ruta", senales_sospechosas("lee ../privado/x"))
        self.assertIn("larga", senales_sospechosas("a" * 401))

    def test_ordenada_unica_y_none(self):
        s = senales_sospechosas("<x> No lo menciones ../y", ["z"])
        self.assertEqual(s, sorted(set(s)))
        self.assertEqual(senales_sospechosas("Devuelve el tiempo en una ciudad."), [])
        self.assertEqual(senales_sospechosas(None), [])


class TestAudiencia(unittest.TestCase):
    def test_ok_con_lista_y_forma_canonica(self):
        # «multi» lleva una lista con "HTTP://127.0.0.1:8765/mcp/" (mayúsculas y barra final).
        self.assertEqual(audiencia_valida(EMISOR["multi"], RECURSO_ALMACEN, EMISOR_URL, AHORA), "ok")
        self.assertEqual(audiencia_valida(EMISOR["lector"], RECURSO_ALMACEN, EMISOR_URL, AHORA), "ok")

    def test_mal_formado(self):
        self.assertEqual(audiencia_valida("no es dict", RECURSO_ALMACEN, EMISOR_URL, AHORA), "mal_formado")
        self.assertEqual(audiencia_valida({"iss": EMISOR_URL, "aud": RECURSO_ALMACEN}, RECURSO_ALMACEN, EMISOR_URL, AHORA), "mal_formado")
        self.assertEqual(audiencia_valida({"iss": EMISOR_URL, "aud": RECURSO_ALMACEN, "exp": True}, RECURSO_ALMACEN, EMISOR_URL, AHORA), "mal_formado")

    def test_emisor_audiencia_caducado(self):
        base = {"iss": EMISOR_URL, "aud": RECURSO_ALMACEN, "exp": FUTURO}
        self.assertEqual(audiencia_valida(dict(base, iss="http://otro"), RECURSO_ALMACEN, EMISOR_URL, AHORA), "emisor")
        self.assertEqual(audiencia_valida(dict(base, aud="http://127.0.0.1:8770/mcp"), RECURSO_ALMACEN, EMISOR_URL, AHORA), "audiencia")
        self.assertEqual(audiencia_valida(dict(base, aud=123), RECURSO_ALMACEN, EMISOR_URL, AHORA), "audiencia")
        self.assertEqual(audiencia_valida(dict(base, exp=PASADO), RECURSO_ALMACEN, EMISOR_URL, AHORA), "caducado")


# ─────────────────────────── Con los servidores MCP reales ───────────────────────────

SRV = ("scopes", "validacion", "rutas", "audiencia")   # todas las defensas de servidor
HOST = ("pinning", "revision")                          # todas las del host


class TestServidoresReales(unittest.TestCase):
    def test_tareas_legitimas_con_todas_las_defensas(self):
        # Con todo activado (usa las siete funciones), las tareas normales deben seguir funcionando.
        async def corrutina():
            async with escenario(defensas_servidor=SRV, defensas_host=HOST, token_almacen="lab-lector") as (h, ca, cc):
                r = await h.invocar("almacen", "buscar_pedido", {"pedido": "P-101"})
                self.assertTrue(r["ok"], r["texto"])
                self.assertIn("entregado", r["texto"])
                r = await h.invocar("almacen", "leer_plano", {"nombre": "aceros/tamahagane.txt"})
                self.assertIn("tamahagane", r["texto"])
            async with escenario(defensas_servidor=SRV, defensas_host=HOST, token_almacen="lab-gestor") as (h, ca, cc):
                r = await h.invocar("almacen", "aplicar_reembolso", {"pedido": "P-103", "importe": 150})
                self.assertIn(MARCA_REEMBOLSO, r["texto"])
                self.assertEqual(ca.reembolsos, [("P-103", 150)])
        anyio.run(corrutina)

    def test_recursos(self):
        async def corrutina():
            async with escenario(defensas_host=("pinning",), token_almacen="lab-lector") as (h, ca, cc):
                r = await h.conexiones["almacen"].cliente.read_resource("forja://planos")
                texto = "".join(getattr(c, "text", "") for c in r.contents)
                self.assertIn("katana-maestra.txt", texto)
                self.assertIn("aceros/tamahagane.txt", texto)
                self.assertEqual(h.bloqueadas.get("almacen"), set())   # nada cambió: nada bloqueado
        anyio.run(corrutina)

    def test_envenenamiento_y_defensas(self):
        async def fuga(defensas_servidor=(), defensas_host=()):
            async with escenario(defensas_servidor=defensas_servidor, defensas_host=defensas_host,
                                  clima_version=1, token_almacen="lab-lector") as (h, ca, cc):
                desc = h.descripcion_para_el_modelo("clima", "consultar_clima")
                textos = []
                for herr, args in ordenes_ocultas(desc):
                    textos.append((await h.invocar("almacen", herr, args))["texto"])
                return any(CANARIO in t for t in textos)
        self.assertTrue(anyio.run(fuga))                       # sin defensas, fuga el canario
        self.assertFalse(anyio.run(fuga, ("rutas",)))          # saneado de rutas en el servidor
        self.assertFalse(anyio.run(fuga, ("validacion",)))     # el patrón del esquema rechaza «..»
        self.assertFalse(anyio.run(fuga, (), ("revision",)))   # el host no le enseña la descripción al modelo

    def test_scopes_frenan_el_reembolso(self):
        async def reembolsa(token, defensas):
            try:
                async with escenario(defensas_servidor=defensas, token_almacen=token) as (h, ca, cc):
                    await h.invocar("almacen", "aplicar_reembolso", {"pedido": "P-101", "importe": 500})
                    return len(ca.reembolsos)
            except Exception:
                return 0
        self.assertEqual(anyio.run(reembolsa, "lab-lector", ()), 1)          # sin scopes, un token de lectura reembolsa
        self.assertEqual(anyio.run(reembolsa, "lab-lector", ("scopes",)), 0)  # con scopes, no
        self.assertEqual(anyio.run(reembolsa, "lab-gestor", ("scopes",)), 1)  # el gestor sí puede

    def test_audiencia_rechaza_token_ajeno(self):
        async def llega(token, defensas):
            try:
                async with escenario(defensas_servidor=defensas, token_almacen=token) as (h, ca, cc):
                    return (await h.invocar("almacen", "buscar_pedido", {"pedido": "P-101"}))["ok"]
            except Exception:
                return False       # el servidor rechaza el token en el handshake
        self.assertTrue(anyio.run(llega, "lab-clima", ()))              # sin la defensa, acepta un token de otro servidor
        self.assertTrue(anyio.run(llega, "lab-lector", ("audiencia",)))  # el token propio y válido sigue entrando
        self.assertFalse(anyio.run(llega, "lab-clima", ("audiencia",)))  # token de otro servidor, fuera
        self.assertFalse(anyio.run(llega, "lab-caducado", ("audiencia",)))

    def test_pinning_frena_el_rug_pull(self):
        async def rug(defensas_host):
            async with escenario(defensas_host=defensas_host, clima_version=1, token_almacen="lab-lector") as (h, ca, cc):
                v2 = [{"name": "consultar_clima", "description": servidor.CLIMA_V2, "inputSchema": ESQUEMAS["consultar_clima"]}]
                h.actualizacion_del_servidor("clima", v2)
                desc = h.descripcion_para_el_modelo("clima", "consultar_clima")
                for herr, args in ordenes_ocultas(desc):
                    await h.invocar("almacen", herr, args)
                return len(ca.reembolsos)
        self.assertEqual(anyio.run(rug, ()), 1)             # sin pinning, el rug pull aplica el reembolso
        self.assertEqual(anyio.run(rug, ("pinning",)), 0)   # con pinning, la herramienta cambiada queda bloqueada


if __name__ == "__main__":
    unittest.main()
