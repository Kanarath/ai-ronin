"""Tests del laboratorio P0-01. No necesitan red ni modelo: un Ollama SIMULADO responde."""

import asyncio
import json
import unittest

import httpx2
from fastapi.testclient import TestClient

from servicio import Ajustes, construir_peticion, crear_app, extraer_respuesta, preguntar, validar_pregunta

AJUSTES = Ajustes(ollama_url="http://ollama.test", modelo="llama3.2:1b", temperatura=0.7, timeout=5.0)
RESPUESTA_OLLAMA = {
    "model": "llama3.2:1b",
    "message": {"role": "assistant", "content": "  Una katana se forja en acero tamahagane.\n"},
    "done": True,
    "done_reason": "stop",
    "total_duration": 1834567000,
    "prompt_eval_count": 31,
    "eval_count": 12,
    "eval_duration": 900000000,
}


def ollama_simulado(respuestas=None, estado=200, error=None):
    """Transporte que imita a Ollama y guarda las peticiones recibidas."""
    recibidas = []

    def manejar(peticion):
        recibidas.append({"metodo": peticion.method, "ruta": peticion.url.path, "json": json.loads(peticion.content or b"{}")})
        if error is not None:
            raise error
        return httpx2.Response(estado, json=respuestas if respuestas is not None else RESPUESTA_OLLAMA)

    return httpx2.MockTransport(manejar), recibidas


class TestValidar(unittest.TestCase):
    def test_recorta(self):
        self.assertEqual(validar_pregunta("  ¿Cómo se templa?  "), "¿Cómo se templa?")

    def test_vacia(self):
        for texto in ["", "   ", "\n\t"]:
            with self.assertRaises(ValueError):
                validar_pregunta(texto)

    def test_demasiado_larga(self):
        validar_pregunta("a" * 2000)
        with self.assertRaises(ValueError):
            validar_pregunta("a" * 2001)


class TestPeticion(unittest.TestCase):
    def test_minima(self):
        self.assertEqual(construir_peticion("hola", "llama3.2:1b", 0.7), {
            "model": "llama3.2:1b", "messages": [{"role": "user", "content": "hola"}],
            "stream": False, "options": {"temperature": 0.7}})

    def test_con_semilla_y_sistema(self):
        p = construir_peticion("hola", "m", 0.0, semilla=42, sistema="Eres un herrero.")
        self.assertEqual(p["messages"], [{"role": "system", "content": "Eres un herrero."}, {"role": "user", "content": "hola"}])
        self.assertEqual(p["options"], {"temperature": 0.0, "seed": 42})

    def test_semilla_cero_cuenta(self):
        self.assertEqual(construir_peticion("hola", "m", 0.5, semilla=0)["options"]["seed"], 0)


class TestExtraer(unittest.TestCase):
    def test_respuesta_completa(self):
        self.assertEqual(extraer_respuesta(RESPUESTA_OLLAMA), {
            "texto": "Una katana se forja en acero tamahagane.", "tokens": 12, "segundos": 1.835, "motivo": "stop"})

    def test_campos_opcionales(self):
        r = extraer_respuesta({"message": {"content": "ok"}, "done": True})
        self.assertEqual(r, {"texto": "ok", "tokens": 0, "segundos": 0.0, "motivo": ""})

    def test_incompleta(self):
        with self.assertRaises(ValueError):
            extraer_respuesta({"message": {"content": "a medias"}, "done": False})
        with self.assertRaises(ValueError):
            extraer_respuesta({"done": True})


class TestPreguntar(unittest.TestCase):
    def _ejecutar(self, transporte, **kw):
        async def corrutina():
            async with httpx2.AsyncClient(base_url=AJUSTES.ollama_url, transport=transporte) as cliente:
                return await preguntar(cliente, AJUSTES, "¿Qué acero?", **kw)
        return asyncio.run(corrutina())

    def test_llama_a_ollama(self):
        t, recibidas = ollama_simulado()
        r = self._ejecutar(t)
        self.assertEqual(r["texto"], "Una katana se forja en acero tamahagane.")
        self.assertEqual(len(recibidas), 1)
        self.assertEqual((recibidas[0]["metodo"], recibidas[0]["ruta"]), ("POST", "/api/chat"))
        self.assertEqual(recibidas[0]["json"]["options"], {"temperature": 0.7}, "usa la temperatura de los ajustes")
        self.assertFalse(recibidas[0]["json"]["stream"])

    def test_temperatura_y_semilla_de_la_peticion(self):
        t, recibidas = ollama_simulado()
        self._ejecutar(t, temperatura=0.0, semilla=7)
        self.assertEqual(recibidas[0]["json"]["options"], {"temperature": 0.0, "seed": 7})

    def test_error_http(self):
        t, _ = ollama_simulado(respuestas={"error": "model 'llama3.2:1b' not found"}, estado=404)
        with self.assertRaises(httpx2.HTTPStatusError):
            self._ejecutar(t)


class TestServicio(unittest.TestCase):
    def _cliente(self, **kw):
        transporte, recibidas = ollama_simulado(**kw)
        return TestClient(crear_app(AJUSTES, transporte)), recibidas

    def test_salud(self):
        c, _ = self._cliente()
        with c:
            self.assertEqual(c.get("/salud").json(), {"ok": True, "modelo": "llama3.2:1b"})

    def test_chat(self):
        c, recibidas = self._cliente()
        with c:
            r = c.post("/chat", json={"pregunta": "  ¿Qué acero?  ", "semilla": 1})
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.json()["texto"], "Una katana se forja en acero tamahagane.")
        self.assertEqual(r.json()["modelo"], "llama3.2:1b")
        self.assertEqual(recibidas[0]["json"]["messages"][-1]["content"], "¿Qué acero?")

    def test_pregunta_vacia_es_400_y_no_llega_al_modelo(self):
        c, recibidas = self._cliente()
        with c:
            self.assertEqual(c.post("/chat", json={"pregunta": "   "}).status_code, 400)
        self.assertEqual(recibidas, [])

    def test_modelo_no_descargado_es_502_sin_detalles_internos(self):
        c, _ = self._cliente(respuestas={"error": "model not found"}, estado=404)
        with c:
            r = c.post("/chat", json={"pregunta": "hola"})
        self.assertEqual(r.status_code, 502)
        self.assertNotIn("ollama.test", r.text)

    def test_timeout_es_504(self):
        c, _ = self._cliente(error=httpx2.ReadTimeout("lento"))
        with c:
            self.assertEqual(c.post("/chat", json={"pregunta": "hola"}).status_code, 504)


if __name__ == "__main__":
    unittest.main()
