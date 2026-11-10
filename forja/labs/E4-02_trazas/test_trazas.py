"""Tests del laboratorio E4-02. No necesitan red ni modelo: un Ollama SIMULADO responde y las trazas
se guardan en memoria (InMemorySpanExporter) en lugar de en un fichero."""

import asyncio
import json
import unittest
from dataclasses import dataclass

import httpx2
from fastapi.testclient import TestClient
from opentelemetry.sdk.metrics.export import InMemoryMetricReader
from opentelemetry.sdk.trace.export.in_memory_span_exporter import InMemorySpanExporter
from opentelemetry.trace import SpanKind, StatusCode

from trazas import (METRICA_DURACION, METRICA_TOKENS_ENTRADA, METRICA_TOKENS_SALIDA, atributos_peticion,
                    atributos_respuesta, configurar, crear_app, luhn_valido, mensajes, preguntar_con_traza, redactar,
                    redactar_valor)


@dataclass(frozen=True)
class Ajustes:
    ollama_url: str = "http://ollama.test"
    modelo: str = "llama3.2:1b"
    temperatura: float = 0.7
    timeout: float = 5.0


RESPUESTA = {"model": "llama3.2:1b", "message": {"role": "assistant", "content": " Anotado: ana@example.com \n"},
             "done": True, "done_reason": "stop", "total_duration": 1500000000, "prompt_eval_count": 31, "eval_count": 9}


def ollama(estado=200, cuerpo=None):
    def manejar(peticion):
        return httpx2.Response(estado, json=cuerpo if cuerpo is not None else RESPUESTA)
    return httpx2.MockTransport(manejar)


def telemetria(redactor=False):
    exp, lector = InMemorySpanExporter(), InMemoryMetricReader()
    tracer, metricas, _, _ = configurar(exp, lector, redactor=redactor)
    return tracer, metricas, exp, lector


def metricas_leidas(lector):
    """{nombre: [(atributos, count, sum)]} de los histogramas."""
    out = {}
    for rm in lector.get_metrics_data().resource_metrics:
        for sm in rm.scope_metrics:
            for m in sm.metrics:
                out[m.name] = [(dict(p.attributes), p.count, p.sum) for p in m.data.data_points]
    return out


def preguntar(contenido="no", estado=200, pregunta="Apunta mi correo: ana@example.com", redactor=False):
    tracer, metricas, exp, lector = telemetria(redactor)

    async def llamar():
        async with httpx2.AsyncClient(base_url="http://ollama.test", transport=ollama(estado)) as cliente:
            return await preguntar_con_traza(tracer, metricas, cliente, Ajustes(), pregunta, contenido)
    return llamar, exp, lector


class TestLuhn(unittest.TestCase):
    def test_validos(self):
        for n in ["4111111111111111", "5555555555554444", "378282246310005", "4012888888881881"]:
            self.assertTrue(luhn_valido(n), n)

    def test_no_validos(self):
        for n in ["4111111111111112", "79927398713", "1234567890123", "41111111111111111111", "4111 1111 1111 1111", ""]:
            self.assertFalse(luhn_valido(n), n)


class TestRedactar(unittest.TestCase):
    def test_ejemplo(self):
        self.assertEqual(redactar("Soy ana@example.com, tel. +34 612 345 678"), "Soy [EMAIL], tel. [TELEFONO]")

    def test_cada_tipo(self):
        casos = {
            "escribe a luis.perez+forja@correo.example.es hoy": "escribe a [EMAIL] hoy",
            "IBAN ES91 2100 0418 4502 0005 1332.": "IBAN [IBAN].",
            "iban es9121000418450200051332": "iban [IBAN]",
            "tarjeta 4111 1111 1111 1111 caduca": "tarjeta [TARJETA] caduca",
            "tarjeta 4111-1111-1111-1111": "tarjeta [TARJETA]",
            "DNI 12345678Z y NIE x1234567l": "DNI [DNI] y NIE [DNI]",
            "llama al 612345678 o al 912 34 56 78": "llama al [TELEFONO] o al [TELEFONO]",
        }
        for texto, esperado in casos.items():
            self.assertEqual(redactar(texto), esperado, texto)

    def test_no_redacta_lo_que_no_es(self):
        for texto in ["pedido 9876543 de la katana KT-2025", "referencia 4111 1111 1111 1112", "el año 2026 y 512345678",
                      "lote 2026-11-10", "teléfono 61234567"]:
            self.assertEqual(redactar(texto), texto, "falso positivo: " + texto)

    def test_el_orden_importa(self):
        self.assertEqual(redactar("ES91 2100 0418 4502 0005 1332 y 612 345 678"), "[IBAN] y [TELEFONO]")


class TestRedactarValor(unittest.TestCase):
    def test_anidado(self):
        original = [{"role": "user", "parts": [{"type": "text", "content": "mi DNI es 12345678Z"}]}]
        copia = json.loads(json.dumps(original))
        r = redactar_valor(original)
        self.assertEqual(r, ({"role": "user", "parts": ({"type": "text", "content": "mi DNI es [DNI]"},)},))
        self.assertIsInstance(r, tuple)
        self.assertEqual(original, copia, "no modifiques el valor original")

    def test_escalares(self):
        for v in [31, 0.7, True, None]:
            self.assertEqual(redactar_valor(v), v)
        self.assertEqual(redactar_valor(("ana@example.com", 3)), ("[EMAIL]", 3))


class TestAtributos(unittest.TestCase):
    def test_peticion(self):
        self.assertEqual(atributos_peticion("llama3.2:1b", 1, "127.0.0.1", 11434), {
            "gen_ai.operation.name": "chat", "gen_ai.provider.name": "ollama", "gen_ai.request.model": "llama3.2:1b",
            "gen_ai.request.temperature": 1.0, "server.address": "127.0.0.1", "server.port": 11434})

    def test_respuesta(self):
        self.assertEqual(atributos_respuesta(RESPUESTA), {
            "gen_ai.response.model": "llama3.2:1b", "gen_ai.response.finish_reasons": ["stop"],
            "gen_ai.usage.input_tokens": 31, "gen_ai.usage.output_tokens": 9})
        self.assertEqual(atributos_respuesta({"done": True}), {"gen_ai.usage.input_tokens": 0, "gen_ai.usage.output_tokens": 0})

    def test_mensajes(self):
        self.assertIsNone(mensajes("user", "ana@example.com", "no"))
        self.assertEqual(mensajes("user", "ana@example.com", "crudo"),
                         [{"role": "user", "parts": [{"type": "text", "content": "ana@example.com"}]}])
        self.assertEqual(mensajes("assistant", "ok ana@example.com", "redactado", "stop"),
                         [{"role": "assistant", "parts": [{"type": "text", "content": "ok [EMAIL]"}], "finish_reason": "stop"}])
        with self.assertRaises(ValueError):
            mensajes("user", "hola", "todo")


class TestTraza(unittest.TestCase):
    def test_span_con_las_convenciones(self):
        llamar, exp, _ = preguntar()
        r = asyncio.run(llamar())
        self.assertEqual(r["texto"], "Anotado: ana@example.com")
        (s,) = exp.get_finished_spans()
        self.assertEqual((s.name, s.kind), ("chat llama3.2:1b", SpanKind.CLIENT))
        a = s.attributes
        self.assertEqual((a["gen_ai.operation.name"], a["gen_ai.provider.name"], a["gen_ai.request.model"]), ("chat", "ollama", "llama3.2:1b"))
        self.assertEqual((a["server.address"], a["server.port"]), ("ollama.test", 80))
        self.assertEqual((a["gen_ai.usage.input_tokens"], a["gen_ai.usage.output_tokens"]), (31, 9))
        self.assertEqual(tuple(a["gen_ai.response.finish_reasons"]), ("stop",))
        self.assertNotIn("gen_ai.input.messages", a, "por defecto no se registra el contenido")
        self.assertNotIn("gen_ai.output.messages", a)

    def test_contenido_redactado(self):
        llamar, exp, _ = preguntar("redactado")
        asyncio.run(llamar())
        a = exp.get_finished_spans()[0].attributes
        self.assertEqual(a["gen_ai.input.messages"][0]["parts"][0]["content"], "Apunta mi correo: [EMAIL]")
        salida = a["gen_ai.output.messages"][0]
        self.assertEqual((salida["parts"][0]["content"], salida["finish_reason"]), ("Anotado: [EMAIL]", "stop"))

    def test_contenido_crudo_y_exportador_que_redacta(self):
        llamar, exp, _ = preguntar("crudo")
        asyncio.run(llamar())
        self.assertIn("ana@example.com", exp.get_finished_spans()[0].to_json())
        llamar, exp, _ = preguntar("crudo", redactor=True)
        asyncio.run(llamar())
        exportado = exp.get_finished_spans()[0].to_json()
        self.assertNotIn("ana@example.com", exportado, "el exportador redacta con tu redactar_valor")
        self.assertIn("[EMAIL]", exportado)

    def test_error_sin_filtrar_la_pregunta(self):
        llamar, exp, lector = preguntar("redactado", estado=404, pregunta="Mi DNI es 12345678Z")
        with self.assertRaises(httpx2.HTTPStatusError):
            asyncio.run(llamar())
        (s,) = exp.get_finished_spans()
        self.assertEqual((s.attributes["error.type"], s.status.status_code), ("404", StatusCode.ERROR))
        self.assertEqual(len(s.events), 0, "record_exception=False: sin eventos de excepción")
        self.assertNotIn("12345678Z", s.to_json())
        (punto,) = metricas_leidas(lector)[METRICA_DURACION]
        self.assertEqual(punto[0]["error.type"], "404")
        self.assertEqual(punto[1], 1)

    def test_metricas(self):
        llamar, _, lector = preguntar()
        asyncio.run(llamar())
        asyncio.run(llamar())
        m = metricas_leidas(lector)
        base = {"gen_ai.operation.name": "chat", "gen_ai.provider.name": "ollama", "gen_ai.request.model": "llama3.2:1b"}
        self.assertEqual(m[METRICA_TOKENS_ENTRADA], [(base, 2, 62)])
        self.assertEqual(m[METRICA_TOKENS_SALIDA], [(base, 2, 18)])
        ((atrs, n, total),) = m[METRICA_DURACION]
        self.assertEqual((atrs, n), (base, 2), "las métricas llevan solo los atributos base")
        self.assertGreater(total, 0)


class TestApp(unittest.TestCase):
    def test_chat_con_traza(self):
        exp, lector = InMemorySpanExporter(), InMemoryMetricReader()
        app = crear_app(transporte=ollama(), exportador=exp, lector=lector)
        with TestClient(app) as c:
            r = c.post("/chat", json={"pregunta": "¿Qué es el temple?"})
            self.assertEqual(r.status_code, 200, r.text)
            self.assertEqual(r.json()["tokens"], 9)
        self.assertEqual([s.name for s in exp.get_finished_spans()], ["chat llama3.2:1b"])


if __name__ == "__main__":
    unittest.main()
