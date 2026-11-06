# AI RONIN

> «No te limites a usar la IA. Entiéndela, constrúyela, desafíala y protégela.»

AI RONIN es una academia interactiva de **AI Engineering, AI Security / Red Teaming y AI Operations**, construida en Godot 4 con GDScript.

El proyecto tiene dos planos:

| Plano | Qué es | Dónde | Restricciones |
|---|---|---|---|
| **El Dojo** | La aplicación Godot: hub de laboratorio, terminal ficticio, mentor RONIN, simulaciones y ML real en GDScript | `game/` | Offline, aislada, sin red, sin ejecutar código del sistema |
| **La Forja** | Laboratorios reales en Python, Docker y modelos locales (siempre en localhost) | `forja/` | Solo en tu máquina; el Dojo nunca la ejecuta, solo importa evidencias |

## Estado

- Diseño aprobado el 2026-11-06.
- Fase 0 (cimientos) completada: proyecto Godot, tests y CI. La CI está bloqueada por un problema de facturación de la cuenta de GitHub; los tests se ejecutan en local.
- **Contenido jugable:** 23 misiones.
  - Tutorial T0.
  - Tronco común T1–T6: datos, k-NN, descenso por gradiente, métricas, redes neuronales con backprop, tokens BPE, embeddings, modelo de lenguaje, muestreo y atención.
  - Arco de seguridad A1 completo (construir, atacar, defender y desplegar un chatbot), con informes de vulnerabilidad.
  - Arco A2 (RAG y embeddings): construir un RAG con índice TF-IDF real; inyección indirecta, envenenamiento, fuga sin control de acceso e inversión de embeddings; defensas en capas.
  - Arco A3 (agentes): agente con herramientas y memoria; secuestro del objetivo, exfiltración, confused deputy, envenenamiento de memoria y bucles; controles en el código frente a spotlight y supervisión humana.
- **En cada misión:** lecciones antes de cada objetivo, pistas en 5 niveles, prueba de dominio y debrief.
- **Gamificación:** 18 sellos (logros), rangos Initiate→Master, retos rápidos con solución paso a paso, notificaciones y barra de XP.
- **Ejercicios Python:** 17, en `forja/ejercicios/`, con guía de Python (`PYTHON.md`) y pistas (`PISTAS.md`).
- **Siguiente paso:** arco A4 (MCP y superficies de herramientas).

### Jugar

Abre `game/project.godot` con Godot 4.7 y pulsa F5, o ejecuta:

```powershell
& "C:\Users\Ruben\Desktop\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe" --path game
```

**Alcance del aprendizaje:** solo IA. La plataforma Godot la construye Claude y no forma parte de la formación. Tus ejercicios se escriben en Python, en `forja/ejercicios/`.

### Ejecutar los tests de la plataforma

```powershell
& "C:\Users\Ruben\Desktop\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path game -s res://tests/run_tests.gd
```

## Documentación

1. [PRD — Documento de requisitos de producto](docs/01-PRD.md)
2. [Arquitectura Godot](docs/02-arquitectura.md)
3. [Currículo y mapa de dependencias](docs/03-curriculo.md)
4. [Especificación de misiones](docs/04-especificacion-misiones.md)
5. [Diseño visual](docs/05-diseno-visual.md)
6. [Roadmap y primer hito jugable](docs/06-roadmap.md)

## Requisitos

- Godot 4.7.x (estable)
- Fase Forja: Python 3.12+ y Docker Desktop (con WSL2). Todavía no hacen falta.
