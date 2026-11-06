# AI RONIN

> «No te limites a usar la IA. Entiéndela, constrúyela, desafíala y protégela.»

AI RONIN es una academia interactiva de **AI Engineering, AI Security / Red Teaming y AI Operations**, construida en Godot 4 con GDScript.

El proyecto tiene dos planos:

| Plano | Qué es | Dónde | Restricciones |
|---|---|---|---|
| **El Dojo** | La aplicación Godot: hub de laboratorio, terminal ficticio, mentor RONIN, simulaciones y ML real en GDScript | `game/` | Offline, aislada, sin red, sin ejecutar código del sistema |
| **La Forja** | Laboratorios reales en Python, Docker y modelos locales (siempre en localhost) | `forja/` | Solo en tu máquina; el Dojo nunca la ejecuta, solo importa evidencias |

## Estado

Fase de diseño. Los documentos están pendientes de aprobación y todavía no hay implementación.

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
