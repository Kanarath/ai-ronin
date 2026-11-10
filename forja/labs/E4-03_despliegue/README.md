# E4-03 · La puerta de la forja

**Misión del Dojo:** E4-03 (requiere E4-02). Especialización E4, AI Ops avanzado. Laboratorio real de la Forja.

Antes de que una versión nueva del servicio llegue a producción, pasa por una puerta: **política como código**. Son unas reglas que se ejecutan en cada despliegue y dicen sí o no, siempre igual y con el motivo:

| Regla | Qué exige | Violación |
|---|---|---|
| `modelo` | El modelo está en la lista permitida y su huella (digest SHA-256) coincide | `modelo-no-permitido`, `modelo-huella` |
| `usuario` | El contenedor declara un usuario que no es root y no es privilegiado | `usuario-sin-declarar`, `usuario-root`, `privilegiado` |
| `recursos` | Límites de CPU y de memoria | `sin-limite-cpu`, `sin-limite-memoria` |
| `puertos` | Ningún puerto publicado fuera de la interfaz local | `puerto-expuesto` |
| `imagen` | La imagen está fijada (etiqueta que no es `latest`, o digest) | `imagen-sin-fijar` |

Lo que no se declara se deniega: un servicio sin `user:` corre con el usuario de la imagen, que muchas veces es root, y un puerto sin IP se publica en todas las interfaces (documentación de Compose).

Si el despliegue pasa, no se cambia todo de golpe. Un **canary** envía el 25 % del tráfico a la versión nueva, compara sus errores y su p95 con los de la estable después de cada petición, y decide si **promover**, **continuar** o **revertir** (rollback).

| Pieza | Quién la escribe |
|---|---|
| `regla_modelo`, `regla_usuario`, `regla_recursos`, `puerto_expuesto`, `regla_puertos`, `regla_imagen`, `evaluar`, `repartir` y `decidir_canary` en `politica.py` | **Tú** |
| La traducción de `compose.yaml` y del `Dockerfile` al formato de las reglas, `bateria.py`, `ataques.json`, Docker | Claude |
| `test_politica.py` (18 tests, sin red ni Docker) | Claude |

## 1. Entorno y tests

Desde esta carpeta:

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe -m unittest -v test_politica
```

Cuando pasen los 18:

```powershell
.\.venv\Scripts\python.exe ..\..\ejercicios\ronin_check.py E4-03
```

Y en el Dojo: `evidence import`.

## 2. Medir la puerta y lanzar el canary

```powershell
.\.venv\Scripts\python.exe bateria.py
```

Hace cuatro cosas:

1. **La política frente a la batería.** 12 despliegues malos (cada uno con un fallo) y 5 buenos, con cuatro configuraciones de reglas: `ninguna`, `modelo`, `modelo,usuario` y todas. Muestra cuántos malos se cuelan y si alguna regla rechaza un despliegue bueno.
2. **Tu modelo instalado.** Pregunta a Ollama (`GET /api/tags`) la huella de tu `llama3.2:1b` y la compara con la lista permitida. La huella permitida es el digest del manifiesto en el registro de Ollama, comprobado el 2026-11-10: es el identificador que ves en `ollama list` (`baf6a787fdff`).
3. **Los `compose.yaml` de la Forja.** Pasa por la política los servicios de los laboratorios que ya has desplegado (P0-01, A1-05, A2-04, E4-01, E4-02...). Predice antes cuántos pasan.
4. **El canary contra el modelo real.** Para cada versión candidata (`ataques.json`), 32 peticiones como mucho, el 25 % a la nueva. Unas candidatas son buenas y otras no: un modelo que no está descargado, un plazo demasiado corto, una versión que responde demasiado largo. Unos 10 minutos en CPU.

Sin Ollama (solo la política, en segundos):

```powershell
.\.venv\Scripts\python.exe bateria.py --sin-canary
```

La medición se guarda en `forja/evidencias/E4-03-medicion.json`; en el Dojo, `evidence import`. Aquí la política es determinista: no hay modelo entre la regla y el resultado. Por eso `fugas_crudas` repite `ataques_exitos` y basta una repetición.

## 3. La puerta como contenedor (opcional, con Docker)

```powershell
docker compose run --rm puerta
```

La puerta se ejecuta aislada: sin red (`network_mode: none`), con el sistema de ficheros de solo lectura, sin root, con límites y con los laboratorios montados en solo lectura. Escribe solo la evidencia. Y pasa su propia política: búscala en la sección 3 de la salida.

## Qué está simplificado

- Los despliegues se describen con un diccionario pequeño. Un motor real evalúa el objeto completo (el `compose.yaml` entero, o el manifiesto de Kubernetes) y muchas más reglas: capacidades de Linux, `no-new-privileges`, secretos en variables de entorno, redes, volúmenes...
- La lista permitida es un JSON sin firmar dentro del propio laboratorio. En producción vive en un repositorio con revisión obligatoria, y los modelos se firman y se verifican (OpenSSF Model Signing), igual que las imágenes.
- La política solo se ejecuta cuando lanzas `bateria.py`. En producción va en el pipeline de CI/CD y en la admisión del clúster, para que nadie pueda saltársela desplegando a mano.
- La huella comprobada es la del manifiesto de Ollama, que a su vez fija las huellas de los pesos. No se recalcula el SHA-256 de los pesos en disco.
- El canary compara errores y p95 con pocas peticiones y sin pruebas estadísticas, y no mide la calidad de las respuestas: una versión que responde mal pero rápido pasaría.
- El motor de políticas es Python. En la industria se usan motores dedicados como **Open Policy Agent** (lenguaje Rego; versión 1.22.3, publicada el 2026-11-10) o Kyverno. La idea es la misma: reglas versionadas y probadas que reciben un documento y devuelven las violaciones.

## Referencias (consultadas el 2026-11-10)

- [Docker Compose · services](https://docs.docker.com/reference/compose-file/services/): `ports` (sin IP del host, todas las interfaces), `user` (sin `USER` ni `user:`, root), `privileged`, `read_only`, `network_mode`.
- [Ollama · API `GET /api/tags`](https://docs.ollama.com/api/tags): modelos descargados con su `digest`. Versión 0.40.16.
- [OWASP Docker Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html): reglas 2 (usuario), 7 (límites de recursos) y 8 (solo lectura).
- B. Beyer et al. (eds.), *The Site Reliability Workbook*, O'Reilly (2018), capítulo 16, [«Canarying Releases»](https://sre.google/workbook/canarying-releases/).
- [Open Policy Agent](https://www.openpolicyagent.org/docs) (política como código).
- [OpenSSF Model Signing](https://github.com/ossf/model-signing-spec) y [SLSA v1.0](https://slsa.dev/spec/v1.0/), ya vistos en A6.
