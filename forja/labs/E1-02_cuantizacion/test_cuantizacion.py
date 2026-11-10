"""Tests del laboratorio E1-02. Sin red ni descargas: tensores pequeños y un LlamaForCausalLM
diminuto (la arquitectura de SmolLM2, con pesos aleatorios y semilla fija)."""

import math
import unittest

import torch
from transformers import LlamaConfig, LlamaForCausalLM

from cuantizacion import (QMAX, QMIN, bytes_esquema, cuantizar, cuantizar_modelo, cuantizar_q8_0, descuantizar,
                          error_relativo, log_probs_texto, parametros_afines, perplejidad)


def llama_diminuto():
    torch.manual_seed(0)
    config = LlamaConfig(vocab_size=64, hidden_size=32, intermediate_size=64, num_hidden_layers=2,
                         num_attention_heads=2, num_key_value_heads=1, max_position_embeddings=64,
                         tie_word_embeddings=True)
    modelo = LlamaForCausalLM(config)
    modelo.eval()
    return modelo


class TestAfin(unittest.TestCase):
    def test_parametros_del_ejemplo(self):
        escala, cero = parametros_afines(torch.tensor([-1.0, 0.0, 2.0]))
        self.assertIsInstance(escala, float)
        self.assertIsInstance(cero, int)
        self.assertAlmostEqual(escala, 3 / 255, places=7)
        self.assertEqual(cero, -43)

    def test_el_rango_incluye_el_cero(self):
        escala, cero = parametros_afines(torch.tensor([1.0, 2.0, 3.0]))
        self.assertAlmostEqual(escala, 3 / 255, places=7)
        self.assertEqual(cero, QMIN, "solo positivos: el 0 es el mínimo")
        escala, cero = parametros_afines(torch.tensor([-4.0, -2.0]))
        self.assertAlmostEqual(escala, 4 / 255, places=7)
        self.assertEqual(cero, QMAX, "solo negativos: el 0 es el máximo")
        self.assertEqual(parametros_afines(torch.zeros(5)), (1.0, round(QMIN)), "todo ceros: escala 1")

    def test_cuantizar_y_volver(self):
        w = torch.tensor([-1.0, 0.0, 0.5, 2.0])
        escala, cero = parametros_afines(w)
        q = cuantizar(w, escala, cero)
        self.assertEqual(q.dtype, torch.int8)
        self.assertEqual(q.tolist(), [-128, -43, -1, 127])
        w2 = descuantizar(q, escala, cero)
        self.assertEqual(w2.dtype, torch.float32)
        self.assertEqual(w2[1].item(), 0.0, "el cero vuelve exacto")
        self.assertLessEqual((w - w2).abs().max().item(), escala / 2 + 1e-6, "error máximo: media escala")

    def test_recorta_y_no_desborda(self):
        q = cuantizar(torch.tensor([-100.0, 100.0]), 0.1, 0)
        self.assertEqual(q.tolist(), [QMIN, QMAX])
        w = descuantizar(torch.tensor([-128, 127], dtype=torch.int8), 0.5, 100)
        self.assertEqual(w.tolist(), [-114.0, 13.5], "pasa a float antes de restar")
        filas = descuantizar(torch.tensor([[1, 2], [3, 4]], dtype=torch.int8), torch.tensor([[1.0], [0.5]]), 0)
        self.assertEqual(filas.tolist(), [[1.0, 2.0], [1.5, 2.0]], "escalas por fila con broadcast")


class TestQ8_0(unittest.TestCase):
    def test_un_bloque_a_mano(self):
        w = torch.zeros(32)
        w[0], w[1], w[2] = 1.27, -0.64, 0.3
        q, d = cuantizar_q8_0(w)
        self.assertEqual(tuple(q.shape), (1, 32))
        self.assertEqual(tuple(d.shape), (1, 1))
        self.assertEqual((q.dtype, d.dtype), (torch.int8, torch.float16))
        self.assertAlmostEqual(d.item(), 0.01, places=4)
        self.assertEqual(q[0, :3].tolist(), [127, -64, 30])
        self.assertEqual(q[0, 3:].abs().sum().item(), 0)

    def test_varios_bloques_y_ceros(self):
        w = torch.cat([torch.zeros(32), torch.linspace(-2, 2, 32)]).reshape(2, 32)
        q, d = cuantizar_q8_0(w)
        self.assertEqual(tuple(q.shape), (2, 32))
        self.assertEqual(d[0].item(), 0.0)
        self.assertEqual(q[0].abs().sum().item(), 0, "bloque de ceros: sin dividir por 0")
        self.assertEqual(q[1].abs().max().item(), 127)
        self.assertFalse(torch.isnan(d).any())
        with self.assertRaises(ValueError):
            cuantizar_q8_0(torch.ones(33))
        self.assertEqual(tuple(cuantizar_q8_0(torch.ones(4, 16), bloque=16)[0].shape), (4, 16))

    def test_los_bloques_aguantan_los_valores_atipicos(self):
        torch.manual_seed(1)
        w = torch.randn(64, 256) * 0.02
        w[3, 5] = 4.0   # un peso atípico, como los que describe LLM.int8()
        normales = torch.ones_like(w, dtype=torch.bool)
        normales[3, 5] = False
        escala, cero = parametros_afines(w)
        por_tensor = descuantizar(cuantizar(w, escala, cero), escala, cero)
        q, d = cuantizar_q8_0(w)
        por_bloques = descuantizar(q, d.float(), 0).reshape(w.shape)
        e_tensor = error_relativo(w[normales], por_tensor[normales])
        e_bloques = error_relativo(w[normales], por_bloques[normales])
        self.assertGreater(e_tensor, 0.1, "con una sola escala, los pesos normales pierden mucha precisión")
        self.assertLess(e_bloques, e_tensor / 5, (e_bloques, e_tensor))


class TestMedidas(unittest.TestCase):
    def test_error_relativo(self):
        w = torch.tensor([3.0, 4.0])
        self.assertEqual(error_relativo(w, w.clone()), 0.0)
        self.assertAlmostEqual(error_relativo(w, torch.tensor([3.0, 3.5])), 0.1, places=6)
        self.assertIsInstance(error_relativo(w, w), float)
        with self.assertRaises(ValueError):
            error_relativo(torch.zeros(3), torch.zeros(3))

    def test_bytes(self):
        self.assertEqual(bytes_esquema(1024, "fp32"), 4096)
        self.assertEqual(bytes_esquema(1024, "bf16"), 2048)
        self.assertEqual(bytes_esquema(1024, "fp16"), 2048)
        self.assertEqual(bytes_esquema(1024, "afin_tensor"), 1032)
        self.assertEqual(bytes_esquema(1024, "q8_0"), 1088)
        self.assertAlmostEqual(bytes_esquema(32 * 10 ** 6, "q8_0") * 8 / (32 * 10 ** 6), 8.5, msg="8,5 bits por peso")
        for n, e in [(33, "q8_0"), (10, "int3")]:
            with self.assertRaises(ValueError, msg=e):
                bytes_esquema(n, e)

    def test_perplejidad(self):
        self.assertAlmostEqual(perplejidad([math.log(0.25)] * 4), 4.0, places=9)
        self.assertAlmostEqual(perplejidad([0.0, 0.0]), 1.0)
        self.assertAlmostEqual(perplejidad([math.log(0.5), math.log(0.125)]), 4.0, places=9)
        with self.assertRaises(ValueError):
            perplejidad([])


class TestModeloEntero(unittest.TestCase):
    """Usa tus funciones a través de cuantizar_modelo (escrita por Claude)."""

    def setUp(self):
        self.ids = [1, 5, 9, 33, 60, 2, 17, 40, 8, 3, 11, 50]

    def test_q8_0_casi_no_cambia_la_perplejidad(self):
        modelo = llama_diminuto()
        base = perplejidad(log_probs_texto(modelo, self.ids))
        info = cuantizar_modelo(modelo, "q8_0")
        nueva = perplejidad(log_probs_texto(modelo, self.ids))
        self.assertLess(abs(nueva - base) / base, 0.01, (base, nueva))
        self.assertLess(info["error_medio"], 0.01)
        self.assertLess(info["bytes"], info["bytes_fp32"] * 0.3)

    def test_afin_por_tensor_tambien_funciona_y_cuenta_bien(self):
        modelo = llama_diminuto()
        n_mats = sum(w.numel() for n, w in modelo.named_parameters() if w.dim() == 2)
        n_vec = sum(w.numel() for n, w in modelo.named_parameters() if w.dim() == 1)
        info = cuantizar_modelo(modelo, "afin_tensor")
        self.assertEqual(info["bytes_fp32"], 4 * (n_mats + n_vec), "embeddings y lm_head compartidos: una vez")
        self.assertEqual(info["bytes"], n_mats + 8 * len(info["errores"]) + 4 * n_vec)
        self.assertTrue(0 < info["error_medio"] < 0.05, info["error_medio"])


if __name__ == "__main__":
    unittest.main()
