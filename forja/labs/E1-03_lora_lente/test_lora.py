"""Tests del laboratorio E1-03. Sin red ni descargas: capas pequeñas y un LlamaForCausalLM
diminuto (la arquitectura de SmolLM2, con pesos aleatorios y semilla fija)."""

import unittest

import torch
from torch import nn
from transformers import LlamaConfig, LlamaForCausalLM

from lora import LoRA, aplicar_lora, contar_parametros, entrenar, estados_residuales, fusionar, lente_logit, perdida_lm


def llama_diminuto():
    torch.manual_seed(0)
    config = LlamaConfig(vocab_size=48, hidden_size=32, intermediate_size=64, num_hidden_layers=2,
                         num_attention_heads=2, num_key_value_heads=1, max_position_embeddings=64)
    modelo = LlamaForCausalLM(config)
    modelo.eval()
    return modelo


def capa_base(n=6, m=4, sesgo=True):
    torch.manual_seed(1)
    return nn.Linear(n, m, bias=sesgo)


class TestLoRA(unittest.TestCase):
    def test_formas_y_congelado(self):
        base = capa_base()
        capa = LoRA(base, rango=2, alfa=4)
        self.assertIsInstance(capa, nn.Module)
        self.assertIs(capa.base, base)
        self.assertEqual(tuple(capa.A.shape), (2, 6))
        self.assertEqual(tuple(capa.B.shape), (4, 2))
        self.assertIsInstance(capa.A, nn.Parameter)
        self.assertIsInstance(capa.B, nn.Parameter)
        self.assertEqual(capa.escala, 2.0)
        self.assertEqual(capa.rango, 2)
        self.assertFalse(base.weight.requires_grad)
        self.assertFalse(base.bias.requires_grad)
        self.assertTrue(capa.A.requires_grad and capa.B.requires_grad)
        self.assertTrue(torch.equal(capa.B, torch.zeros(4, 2)))
        self.assertLess(capa.A.abs().max().item(), 0.1, "A empieza pequeña (× 0.01)")
        with self.assertRaises(ValueError):
            LoRA(capa_base(), rango=0, alfa=1)

    def test_recien_creada_da_lo_mismo_que_la_base(self):
        base = capa_base()
        capa = LoRA(base, 3, 3)
        x = torch.randn(2, 5, 6)
        self.assertTrue(torch.allclose(capa(x), base(x)))

    def test_forward_con_la_correccion(self):
        base = capa_base(sesgo=False)
        capa = LoRA(base, 2, 1)
        with torch.no_grad():
            capa.A.copy_(torch.tensor([[1.0, 0, 0, 0, 0, 0], [0, 1.0, 0, 0, 0, 0]]))
            capa.B.copy_(torch.tensor([[1.0, 0], [0, 1.0], [1.0, 1.0], [0, 0]]))
        x = torch.tensor([[2.0, 3.0, 0, 0, 0, 0]])
        esperado = base(x) + 0.5 * torch.tensor([[2.0, 3.0, 5.0, 0.0]])
        self.assertTrue(torch.allclose(capa(x), esperado), "escala = alfa / rango = 0.5")

    def test_generador_reproducible(self):
        a = LoRA(capa_base(), 2, 2, generador=torch.Generator().manual_seed(5)).A
        b = LoRA(capa_base(), 2, 2, generador=torch.Generator().manual_seed(5)).A
        self.assertTrue(torch.equal(a, b))


class TestFusionarYContar(unittest.TestCase):
    def test_fusionar_da_lo_mismo(self):
        for sesgo in (True, False):
            capa = LoRA(capa_base(sesgo=sesgo), 2, 4)
            with torch.no_grad():
                capa.B.normal_()
            fusionada = fusionar(capa)
            self.assertIsInstance(fusionada, nn.Linear)
            self.assertIsNot(fusionada, capa.base)
            self.assertEqual(fusionada.bias is None, not sesgo)
            x = torch.randn(3, 6)
            self.assertTrue(torch.allclose(fusionada(x), capa(x), atol=1e-6))
            antes = capa.base.weight.clone()
            fusionar(capa)
            self.assertTrue(torch.equal(capa.base.weight, antes), "no modifica la capa")

    def test_contar(self):
        capa = LoRA(capa_base(), 2, 2)
        self.assertEqual(contar_parametros(capa), (2 * 6 + 4 * 2, 6 * 4 + 4 + 2 * 6 + 4 * 2))
        self.assertEqual(contar_parametros(capa_base()), (28, 28))


class TestAplicar(unittest.TestCase):
    def test_sustituye_las_capas_objetivo(self):
        modelo = llama_diminuto()
        total = contar_parametros(modelo)[1]
        nombres = aplicar_lora(modelo, ["q_proj", "v_proj"], rango=4, alfa=8)
        self.assertEqual(nombres, ["model.layers.0.self_attn.q_proj", "model.layers.0.self_attn.v_proj",
                                   "model.layers.1.self_attn.q_proj", "model.layers.1.self_attn.v_proj"])
        self.assertIsInstance(modelo.model.layers[1].self_attn.v_proj, LoRA)
        self.assertIsInstance(modelo.model.layers[1].self_attn.k_proj, nn.Linear)
        entrenables, nuevo_total = contar_parametros(modelo)
        por_capa = 4 * (32 + 32) + 4 * (32 + 16)   # q: 32→32, v: 32→16 (una cabeza kv de 16)
        self.assertEqual(entrenables, 2 * por_capa)
        self.assertEqual(nuevo_total, total + 2 * por_capa)

    def test_el_modelo_sigue_igual_al_principio(self):
        modelo = llama_diminuto()
        ids = torch.tensor([[1, 4, 9, 20, 33]])
        with torch.no_grad():
            antes = modelo(ids).logits
            aplicar_lora(modelo, ["q_proj", "v_proj"], 2, 2)
            despues = modelo(ids).logits
        self.assertTrue(torch.allclose(antes, despues, atol=1e-6))

    def test_sin_objetivos_validos(self):
        with self.assertRaises(ValueError):
            aplicar_lora(llama_diminuto(), ["no_existe"], 2, 2)


class TestEntrenar(unittest.TestCase):
    def test_perdida_lm(self):
        logits = torch.zeros(1, 3, 5)
        logits[0, 0, 2] = 10.0
        logits[0, 1, 4] = 10.0
        ids = torch.tensor([[0, 2, 4]])
        self.assertLess(perdida_lm(logits, ids).item(), 0.01, "predice bien los tokens 1 y 2")
        self.assertEqual(perdida_lm(logits, ids).dim(), 0)
        malo = perdida_lm(logits, torch.tensor([[0, 1, 1]])).item()
        self.assertAlmostEqual(malo, torch.log(torch.tensor(4.0) + torch.exp(torch.tensor(10.0))).item(), places=3)

    def test_coincide_con_transformers(self):
        modelo = llama_diminuto()
        ids = torch.tensor([[1, 9, 3, 22, 17, 8]])
        with torch.no_grad():
            salida = modelo(ids, labels=ids)
        self.assertAlmostEqual(perdida_lm(salida.logits, ids).item(), salida.loss.item(), places=5)

    def test_lora_aprende_y_la_base_no_cambia(self):
        modelo = llama_diminuto()
        aplicar_lora(modelo, ["q_proj", "v_proj"], 4, 8, generador=torch.Generator().manual_seed(0))
        congelado = modelo.model.layers[0].mlp.up_proj.weight.clone()
        base_q = modelo.model.layers[0].self_attn.q_proj.base.weight.clone()
        ids = torch.tensor([[1, 7, 7, 30, 12, 5, 41, 2]])
        perdidas = entrenar(modelo, ids, pasos=40, lr=0.05)
        self.assertEqual(len(perdidas), 40)
        self.assertTrue(all(isinstance(p, float) for p in perdidas))
        self.assertLess(perdidas[-1], perdidas[0] - 0.4, perdidas[::10])
        self.assertFalse(modelo.training, "termina en modo evaluación")
        self.assertTrue(torch.equal(modelo.model.layers[0].mlp.up_proj.weight, congelado))
        self.assertTrue(torch.equal(modelo.model.layers[0].self_attn.q_proj.base.weight, base_q))
        self.assertGreater(modelo.model.layers[0].self_attn.q_proj.B.abs().sum().item(), 0)

    def test_sin_entrenables(self):
        modelo = llama_diminuto()
        for p in modelo.parameters():
            p.requires_grad = False
        with self.assertRaises(ValueError):
            entrenar(modelo, torch.tensor([[1, 2, 3]]), 1, 0.1)


class TestLente(unittest.TestCase):
    def test_la_ultima_capa_coincide_con_la_salida(self):
        modelo = llama_diminuto()
        ids = [1, 5, 12, 40, 3]
        estados = estados_residuales(modelo, ids)
        self.assertEqual(len(estados), 3, "embeddings + 2 capas")
        lente = lente_logit(estados, modelo.model.norm, modelo.lm_head)
        self.assertEqual(len(lente), 3)
        with torch.no_grad():
            probs = torch.softmax(modelo(torch.tensor([ids])).logits[0, -1], -1)
        token, p = lente[-1]
        self.assertIsInstance(token, int)
        self.assertIsInstance(p, float)
        self.assertEqual(token, int(torch.argmax(probs)))
        self.assertAlmostEqual(p, probs.max().item(), places=5)
        token0, _ = lente_logit(estados, modelo.model.norm, modelo.lm_head, posicion=0)[-1]
        with torch.no_grad():
            self.assertEqual(token0, int(torch.argmax(modelo(torch.tensor([ids])).logits[0, 0])))

    def test_con_modulos_simples(self):
        estados = [torch.tensor([[[1.0, 0.0], [0.0, 3.0]]]), torch.tensor([[[0.0, 0.0], [5.0, 0.0]]])]
        cabeza = nn.Linear(2, 2, bias=False)
        with torch.no_grad():
            cabeza.weight.copy_(torch.eye(2))
        r = lente_logit(estados, nn.Identity(), cabeza)
        self.assertEqual([t for t, _ in r], [1, 0])
        self.assertAlmostEqual(r[0][1], torch.softmax(torch.tensor([0.0, 3.0]), -1)[1].item(), places=6)
        self.assertEqual(lente_logit(estados, nn.Identity(), cabeza, posicion=0)[1], (0, 0.5))


if __name__ == "__main__":
    unittest.main()
