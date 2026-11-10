"""Tests del laboratorio E4-01. No necesitan red ni modelo: un modelo SIMULADO responde con retardo."""

import asyncio
import unittest

from fastapi.testclient import TestClient

from carga import (RESPUESTA_DEGRADADA, CacheRespuestas, CuboDeTokens, Estado, Politica, atender, clave_cache,
                   crear_app, normalizar_pregunta, percentil, resumen_latencias)


class Reloj:
    """Reloj falso: el tiempo solo avanza cuando el test lo dice."""
    def __init__(self):
        self.t = 1000.0

    def __call__(self):
        return self.t


class Caida(Exception):
    """Error simulado del modelo (no uses RuntimeError: NotImplementedError es un RuntimeError)."""


class ModeloSimulado:
    """Modelo simulado: tarda `retardo` segundos y apunta cuántas llamadas hay a la vez."""
    def __init__(self, retardo=0.0, error=None):
        self.retardo, self.error = retardo, error
        self.llamadas, self.en_curso, self.max_en_curso = [], 0, 0

    async def __call__(self, pregunta):
        self.llamadas.append(pregunta)
        self.en_curso += 1
        self.max_en_curso = max(self.max_en_curso, self.en_curso)
        try:
            await asyncio.sleep(self.retardo)
            if self.error is not None:
                raise self.error
            return "respuesta a: " + pregunta
        finally:
            self.en_curso -= 1


def estado(defensas=(), **numeros):
    return Estado(Politica.desde_defensas(defensas, **numeros), modelo="llama3.2:1b", temperatura=0.0)


class TestPercentil(unittest.TestCase):
    def test_ejemplos(self):
        self.assertAlmostEqual(percentil([4, 1, 3, 2], 50), 2.5)
        self.assertAlmostEqual(percentil([5], 95), 5)
        self.assertAlmostEqual(percentil([1, 2, 3, 4, 5], 95), 4.8)
        self.assertAlmostEqual(percentil([10, 20, 30], 50), 20)

    def test_extremos_y_no_modifica(self):
        datos = [3.0, 1.0, 2.0]
        self.assertEqual(percentil(datos, 0), 1.0)
        self.assertEqual(percentil(datos, 100), 3.0)
        self.assertEqual(datos, [3.0, 1.0, 2.0], "no ordenes la lista original")

    def test_errores(self):
        for valores, p in [([], 50), ([1, 2], -1), ([1, 2], 101)]:
            with self.assertRaises(ValueError):
                percentil(valores, p)


class TestResumen(unittest.TestCase):
    def test_resumen(self):
        r = resumen_latencias([1.0, 2.0, 3.0, 4.0, 10.0], 20.0)
        self.assertEqual(r, {"n": 5, "p50": 3.0, "p95": 8.8, "max": 10.0, "throughput": 0.25})

    def test_redondeo_y_vacia(self):
        self.assertEqual(resumen_latencias([0.1234567], 3.0)["throughput"], 0.333)
        self.assertEqual(resumen_latencias([], 5.0), {"n": 0, "p50": 0.0, "p95": 0.0, "max": 0.0, "throughput": 0.0})

    def test_duracion_no_valida(self):
        for s in [0, -1.0]:
            with self.assertRaises(ValueError):
                resumen_latencias([1.0], s)
        with self.assertRaises(ValueError):
            resumen_latencias([], 0)


class TestCubo(unittest.TestCase):
    def test_rafaga_hasta_la_capacidad(self):
        c = CuboDeTokens(3, 1.0, Reloj())
        self.assertEqual([c.permitir() for _ in range(4)], [True, True, True, False])

    def test_recarga_y_tope(self):
        reloj = Reloj()
        c = CuboDeTokens(2, 0.5, reloj)
        c.permitir(), c.permitir()
        self.assertFalse(c.permitir())
        reloj.t += 2.0                         # 2 s × 0,5 = 1 token
        self.assertTrue(c.permitir())
        self.assertFalse(c.permitir())
        reloj.t += 3600                        # mucho tiempo: no pasa de la capacidad
        self.assertEqual([c.permitir() for _ in range(3)], [True, True, False])

    def test_coste_y_rechazo_sin_gasto(self):
        reloj = Reloj()
        c = CuboDeTokens(5, 1.0, reloj)
        self.assertTrue(c.permitir(4))
        self.assertFalse(c.permitir(2), "solo queda 1 token")
        self.assertTrue(c.permitir(1), "el rechazo no debe gastar tokens")
        self.assertAlmostEqual(c.tokens, 0.0)

    def test_parametros_no_validos(self):
        for cap, rec in [(0, 1.0), (-1, 1.0), (3, -0.1)]:
            with self.assertRaises(ValueError):
                CuboDeTokens(cap, rec, Reloj())


class TestClave(unittest.TestCase):
    def test_normalizar(self):
        self.assertEqual(normalizar_pregunta("  ¿Qué   GARANTÍA tienen?? "), "qué garantía tienen")
        self.assertEqual(normalizar_pregunta("Straße abierta!"), "strasse abierta")
        self.assertEqual(normalizar_pregunta("ﬁlo"), "filo", "NFKC separa la ligadura")

    def test_variantes_comparten_clave(self):
        a = clave_cache("publico", "llama3.2:1b", 0, "¿A qué hora abrís?")
        self.assertEqual(a, clave_cache("publico", "llama3.2:1b", 0.0, "a qué  HORA abrís"))
        self.assertEqual(len(a), 64)
        int(a, 16)

    def test_ambito_modelo_y_temperatura_separan(self):
        base = clave_cache("publico", "llama3.2:1b", 0, "hola")
        for otra in [clave_cache("ana", "llama3.2:1b", 0, "hola"), clave_cache("publico", "llama3.2:3b", 0, "hola"),
                     clave_cache("publico", "llama3.2:1b", 0.7, "hola")]:
            self.assertNotEqual(base, otra)

    def test_valor_exacto(self):
        import hashlib
        esperado = hashlib.sha256("publico\nllama3.2:1b\n0.0\nhola".encode("utf-8")).hexdigest()
        self.assertEqual(clave_cache("publico", "llama3.2:1b", 0, "¡Hola!"), esperado)


class TestCache(unittest.TestCase):
    def test_guardar_y_obtener(self):
        c = CacheRespuestas(10, 60, Reloj())
        self.assertIsNone(c.obtener("a"))
        c.guardar("a", "texto")
        self.assertEqual(c.obtener("a"), "texto")

    def test_caducidad(self):
        reloj = Reloj()
        c = CacheRespuestas(10, 60, reloj)
        c.guardar("a", "texto")
        reloj.t += 59.9
        self.assertEqual(c.obtener("a"), "texto")
        reloj.t += 0.1
        self.assertIsNone(c.obtener("a"))
        self.assertNotIn("a", c.datos, "la entrada caducada se borra")

    def test_expulsa_la_menos_usada(self):
        c = CacheRespuestas(2, 60, Reloj())
        c.guardar("a", 1)
        c.guardar("b", 2)
        c.obtener("a")                         # «a» pasa a ser la más reciente
        c.guardar("c", 3)
        self.assertIsNone(c.obtener("b"))
        self.assertEqual((c.obtener("a"), c.obtener("c")), (1, 3))
        self.assertEqual(len(c.datos), 2)


class TestAtender(unittest.TestCase):
    def test_sin_defensas_llama_al_modelo(self):
        m = ModeloSimulado()
        r = asyncio.run(atender(estado(), "ana", "hola", m))
        self.assertEqual(r, {"estado": 200, "texto": "respuesta a: hola", "cache": False})
        self.assertEqual(m.llamadas, ["hola"])

    def test_limite_por_cliente(self):
        e, m = estado(["limite"], capacidad=2, recarga=0.0), ModeloSimulado()

        async def prueba():
            return [await atender(e, c, "hola", m) for c in ["abusador"] * 3 + ["ana"]]
        r = asyncio.run(prueba())
        self.assertEqual([x["estado"] for x in r], [200, 200, 429, 200], "el límite es por cliente")
        self.assertEqual(r[2], {"estado": 429, "motivo": "limite"})
        self.assertEqual(len(m.llamadas), 3, "la petición rechazada no llega al modelo")

    def test_cache_evita_el_modelo(self):
        e, m = estado(["cache"]), ModeloSimulado()

        async def prueba():
            a = await atender(e, "ana", "¿A qué hora abrís?", m)
            b = await atender(e, "luis", "a que hora abrís", m)      # «que» sin tilde: otra clave
            c = await atender(e, "luis", "¿a qué HORA abrís", m)
            return a, b, c
        a, b, c = asyncio.run(prueba())
        self.assertEqual(c, {"estado": 200, "texto": a["texto"], "cache": True})
        self.assertFalse(b["cache"])
        self.assertEqual(len(m.llamadas), 2)

    def test_cola_acotada(self):
        e, m = estado(["cola"], concurrencia=1, max_cola=2), ModeloSimulado(retardo=0.05)

        async def prueba():
            return await asyncio.gather(*[atender(e, "c%d" % i, "p%d" % i, m) for i in range(5)])
        r = asyncio.run(prueba())
        self.assertEqual(sorted(x["estado"] for x in r), [200, 200, 200, 503, 503])
        self.assertIn({"estado": 503, "motivo": "cola llena"}, r)
        self.assertEqual(m.max_en_curso, 1, "con concurrencia 1, el modelo atiende de una en una")
        self.assertEqual(e.admitidas, 0)

    def test_la_cola_se_libera_con_errores(self):
        e, m = estado(["cola"], concurrencia=1, max_cola=0), ModeloSimulado(error=Caida("se cayó"))
        for _ in range(2):
            with self.assertRaises(Caida):
                asyncio.run(atender(e, "ana", "hola", m))
        self.assertEqual(e.admitidas, 0, "usa try/finally: si no, la cola se queda llena para siempre")

    def test_timeout_degrada_y_no_guarda(self):
        e, m = estado(["timeout", "cache"], timeout=0.02), ModeloSimulado(retardo=0.5)
        r = asyncio.run(atender(e, "ana", "ensayo larguísimo", m))
        self.assertEqual(r, {"estado": 504, "motivo": "timeout", "texto": RESPUESTA_DEGRADADA})
        m.retardo = 0.0
        r = asyncio.run(atender(e, "ana", "ensayo larguísimo", m))
        self.assertEqual(r["cache"], False, "una respuesta degradada no se guarda en la caché")

    def test_orden_limite_antes_que_cache(self):
        e, m = estado(["limite", "cache"], capacidad=1, recarga=0.0), ModeloSimulado()

        async def prueba():
            return [await atender(e, "abusador", "misma pregunta", m) for _ in range(2)]
        self.assertEqual([x["estado"] for x in asyncio.run(prueba())], [200, 429])


class TestApp(unittest.TestCase):
    def test_token_y_limite(self):
        m = ModeloSimulado()
        app = crear_app(defensas=["limite"], llamar_modelo=m, tokens={"t-ana": "ana"},
                        politica=Politica.desde_defensas(["limite"], capacidad=1, recarga=0.05))
        with TestClient(app) as c:
            self.assertEqual(c.post("/chat", json={"pregunta": "hola"}).status_code, 401)
            cab = {"Authorization": "Bearer t-ana"}
            r = c.post("/chat", json={"pregunta": "hola"}, headers=cab)
            self.assertEqual((r.status_code, r.json()["texto"]), (200, "respuesta a: hola"))
            r = c.post("/chat", json={"pregunta": "hola"}, headers=cab)
            self.assertEqual(r.status_code, 429)
            self.assertEqual(r.headers["Retry-After"], "20")
            self.assertEqual(c.get("/recuento").json()["respuestas"], {"200": 1, "429": 1})


if __name__ == "__main__":
    unittest.main()
