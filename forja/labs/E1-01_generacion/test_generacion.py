"""Tests del laboratorio E1-01. Sin red ni descargas.

Usan dos modelos creados aquí mismo:
  - ModeloBigramas: un nn.Module cuyos logits en cada posición dependen solo del token de esa
    posición (una tabla fija). Sirve para comprobar el bucle con resultados conocidos.
  - Un LlamaForCausalLM diminuto (la misma arquitectura que SmolLM2, con 2 capas de 16
    dimensiones y pesos aleatorios con semilla fija). Sirve para comparar tu bucle con
    model.generate() y con la pérdida que calcula Transformers.
"""

import math
import unittest
from types import SimpleNamespace

import torch
from torch import nn
from transformers import LlamaConfig, LlamaForCausalLM

from generacion import con_temperatura, filtro_top_p, generar, log_probs_secuencia, siguiente_token

V = 6


class ModeloBigramas(nn.Module):
    """Tras el token i, el más probable es (i + 1) % V. Devuelve un objeto con .logits como los
    modelos de Transformers, de forma (lotes, longitud, vocabulario)."""

    def __init__(self):
        super().__init__()
        tabla = torch.full((V, V), -2.0)
        for i in range(V):
            tabla[i, (i + 1) % V] = 3.0
            tabla[i, (i + 2) % V] = 1.0
        self.tabla = tabla
        self.llamadas = []

    def forward(self, input_ids):
        self.llamadas.append(tuple(input_ids.shape))
        return SimpleNamespace(logits=self.tabla[input_ids])


def llama_diminuto():
    torch.manual_seed(0)
    config = LlamaConfig(vocab_size=40, hidden_size=16, intermediate_size=32, num_hidden_layers=2,
                         num_attention_heads=2, num_key_value_heads=1, max_position_embeddings=64,
                         bos_token_id=1, eos_token_id=2, pad_token_id=0)
    modelo = LlamaForCausalLM(config)
    modelo.eval()
    return modelo


class TestTemperatura(unittest.TestCase):
    def test_divide_los_logits(self):
        logits = torch.tensor([2.0, -1.0, 0.5])
        self.assertTrue(torch.allclose(con_temperatura(logits, 1.0), logits))
        self.assertTrue(torch.allclose(con_temperatura(logits, 2.0), torch.tensor([1.0, -0.5, 0.25])))
        self.assertTrue(torch.allclose(con_temperatura(logits, 0.5), torch.tensor([4.0, -2.0, 1.0])))

    def test_temperatura_cero_es_voraz(self):
        logits = torch.tensor([1.0, 3.0, 3.0, -1.0])
        r = con_temperatura(logits, 0)
        self.assertEqual(r[1].item(), 0.0)
        self.assertTrue(torch.isinf(r[[0, 2, 3]]).all() and (r[[0, 2, 3]] < 0).all(), "empate: gana el primero")
        self.assertTrue(torch.allclose(torch.softmax(r, -1), torch.tensor([0.0, 1.0, 0.0, 0.0])))

    def test_no_modifica_y_valida(self):
        logits = torch.tensor([2.0, 1.0])
        con_temperatura(logits, 0.5)
        con_temperatura(logits, 0)
        self.assertTrue(torch.equal(logits, torch.tensor([2.0, 1.0])))
        with self.assertRaises(ValueError):
            con_temperatura(logits, -0.1)

    def test_afila_y_aplana(self):
        logits = torch.tensor([2.0, 1.0, 0.0])
        frio = torch.softmax(con_temperatura(logits, 0.5), -1)[0].item()
        normal = torch.softmax(logits, -1)[0].item()
        caliente = torch.softmax(con_temperatura(logits, 2.0), -1)[0].item()
        self.assertGreater(frio, normal)
        self.assertGreater(normal, caliente)


class TestTopP(unittest.TestCase):
    def test_nucleo_en_el_orden_original(self):
        r = filtro_top_p(torch.tensor([0.1, 0.5, 0.3, 0.1]), 0.75)
        self.assertTrue(torch.allclose(r, torch.tensor([0.0, 0.625, 0.375, 0.0])), r)

    def test_llega_justo_a_p(self):
        r = filtro_top_p(torch.tensor([0.25, 0.5, 0.125, 0.125]), 0.75)
        self.assertTrue(torch.allclose(r, torch.tensor([1 / 3, 2 / 3, 0.0, 0.0])), "0.5 + 0.25 ya llega a 0.75")

    def test_siempre_queda_uno_y_p_uno_conserva_todo(self):
        probs = torch.tensor([0.2, 0.7, 0.1])
        self.assertTrue(torch.allclose(filtro_top_p(probs, 0.01), torch.tensor([0.0, 1.0, 0.0])))
        self.assertTrue(torch.allclose(filtro_top_p(probs, 1.0), probs))
        self.assertTrue(torch.equal(probs, torch.tensor([0.2, 0.7, 0.1])), "no modifica la entrada")

    def test_empates_y_validacion(self):
        r = filtro_top_p(torch.tensor([0.3, 0.3, 0.4]), 0.6)
        self.assertTrue(torch.allclose(r, torch.tensor([3 / 7, 0.0, 4 / 7])), "en empate, primero el índice menor")
        for p in (0, -0.5, 1.5):
            with self.assertRaises(ValueError, msg=p):
                filtro_top_p(torch.tensor([0.5, 0.5]), p)


class TestSiguienteToken(unittest.TestCase):
    def test_voraz(self):
        self.assertEqual(siguiente_token(torch.tensor([0.1, 2.0, -1.0]), temperatura=0), 1)
        self.assertIsInstance(siguiente_token(torch.tensor([0.1, 2.0, -1.0]), temperatura=0), int)

    def test_semilla_reproducible(self):
        logits = torch.zeros(10)
        a = [siguiente_token(logits, 1.0, 1.0, torch.Generator().manual_seed(7)) for _ in range(3)]
        g = torch.Generator().manual_seed(7)
        b = [siguiente_token(logits, 1.0, 1.0, g) for _ in range(20)]
        g = torch.Generator().manual_seed(7)
        c = [siguiente_token(logits, 1.0, 1.0, g) for _ in range(20)]
        self.assertEqual(len(set(a)), 1, "misma semilla, mismo token")
        self.assertEqual(b, c)
        self.assertGreater(len(set(b)), 3, "con logits iguales, 20 muestras no salen siempre iguales")

    def test_frecuencias_y_nucleo(self):
        probs = torch.tensor([0.6, 0.3, 0.05, 0.05])
        logits = torch.log(probs)
        g = torch.Generator().manual_seed(0)
        muestras = [siguiente_token(logits, 1.0, 1.0, g) for _ in range(2000)]
        self.assertAlmostEqual(muestras.count(0) / 2000, 0.6, delta=0.05)
        self.assertAlmostEqual(muestras.count(1) / 2000, 0.3, delta=0.05)
        g = torch.Generator().manual_seed(0)
        con_p = {siguiente_token(logits, 1.0, 0.85, g) for _ in range(300)}
        self.assertEqual(con_p, {0, 1}, "top-p 0.85 deja fuera los dos tokens del 5 %")


class TestGenerar(unittest.TestCase):
    def test_bucle_voraz(self):
        m = ModeloBigramas()
        ids = [2]
        self.assertEqual(generar(m, ids, 5), [3, 4, 5, 0, 1])
        self.assertEqual(ids, [2], "no modifica el prompt")
        self.assertEqual(m.llamadas, [(1, 1), (1, 2), (1, 3), (1, 4), (1, 5)], "un paso por token, con toda la secuencia")

    def test_eos_y_limites(self):
        m = ModeloBigramas()
        self.assertEqual(generar(m, [0, 1], 10, eos_id=4), [2, 3, 4])
        self.assertEqual(generar(m, [0], 0), [])
        with self.assertRaises(ValueError):
            generar(m, [0], -1)

    def test_igual_que_generate_de_transformers(self):
        modelo = llama_diminuto()
        prompt = [1, 7, 12, 30, 5]
        esperado = modelo.generate(torch.tensor([prompt]), attention_mask=torch.ones(1, 5, dtype=torch.long),
                                   max_new_tokens=12, do_sample=False, eos_token_id=None, pad_token_id=0)[0, 5:].tolist()
        self.assertEqual(generar(modelo, prompt, 12), esperado)

    def test_muestreo_con_semilla(self):
        modelo = llama_diminuto()
        a = generar(modelo, [1, 4], 15, temperatura=1.5, top_p=0.95, generador=torch.Generator().manual_seed(3))
        b = generar(modelo, [1, 4], 15, temperatura=1.5, top_p=0.95, generador=torch.Generator().manual_seed(3))
        self.assertEqual(a, b)
        self.assertEqual(len(a), 15)
        self.assertTrue(all(isinstance(t, int) and 0 <= t < 40 for t in a))


class TestLogProbs(unittest.TestCase):
    def test_valores_conocidos(self):
        m = ModeloBigramas()
        lp = log_probs_secuencia(m, [0, 1, 3])
        esperado = torch.log_softmax(m.tabla, -1)
        self.assertEqual(len(lp), 2)
        self.assertAlmostEqual(lp[0], esperado[0, 1].item(), places=5)
        self.assertAlmostEqual(lp[1], esperado[1, 3].item(), places=5)
        self.assertEqual(m.llamadas, [(1, 3)], "una sola pasada")
        with self.assertRaises(ValueError):
            log_probs_secuencia(m, [3])

    def test_coincide_con_la_perdida_de_transformers(self):
        modelo = llama_diminuto()
        ids = [1, 9, 3, 22, 17, 8, 2]
        with torch.no_grad():
            perdida = modelo(torch.tensor([ids]), labels=torch.tensor([ids])).loss.item()
        lp = log_probs_secuencia(modelo, ids)
        self.assertAlmostEqual(-sum(lp) / len(lp), perdida, places=4)
        self.assertTrue(all(isinstance(x, float) and x <= 0 and math.isfinite(x) for x in lp))


if __name__ == "__main__":
    unittest.main()
