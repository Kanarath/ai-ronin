# A6-04 · La cadena de verdad

**Misión del Dojo:** A6-04 (requiere A6-03 y P0-01). Laboratorio real de la Forja, **defensivo**.

En A6-01…03, los controles de la cadena de suministro del taller Kurogane eran interruptores (`supply defend … on`). Aquí los construyes de verdad: un **verificador de artefactos de IA** que revisa una carpeta de proyecto y dice qué no debería pasar a producción. Revisa:

- **pickles** (`.pkl`, `.bin`, `.pt`…): qué importarían y qué llamarían, leyendo sus opcodes con `pickletools` **sin cargarlos nunca**;
- **safetensors**: la cabecera, los dtypes y que los offsets cubran el buffer sin solapes ni huecos;
- el **AI-BOM** (CycloneDX ML-BOM): que el SHA-256 de cada modelo y dataset coincida con el declarado y que no haya artefactos sin declarar;
- los **requirements**: dependencias sin fijar, inexistentes (paquetes inventados por un asistente de código: *slopsquatting*), recién publicadas o de otro índice;
- los **Dockerfile**: usuario root, secretos en `ENV` o `ARG` e imágenes sin versión.

Los artefactos de prueba son dos proyectos ficticios: `taller-bueno` (nada que objetar) y `taller-comprometido` (cada fichero con un problema de A6-02). **Los artefactos «malos» son inofensivos**: los pickles «con código» se escriben opcode a opcode en `generar_artefactos.py` y lo que llamarían está en módulos que no existen (`taller_ficticio`, `forja_falsa`). Aun así, **el verificador nunca hace `pickle.load`**, y un test comprueba que `verificador.py` ni siquiera importa `pickle`. Tú tampoco los cargues.

| Pieza | Quién la escribe |
|---|---|
| `imports_pickle`, `revisar_pickle`, `validar_safetensors`, `verificar_bom`, `revisar_requirements`, `revisar_dockerfile` en `verificador.py` | **Tú** |
| `verificar_proyecto` (recorre la carpeta y reparte cada fichero a su control), la línea de órdenes, `generar_artefactos.py`, `bateria.py`, `ataques.json`, `indice.json`, Docker | Claude |
| `test_verificador.py` (27 tests, sin red) | Claude |

## 1. Tests

Solo usa la biblioteca estándar de Python 3.13: no hay nada que instalar. Desde esta carpeta:

```powershell
py -3.13 -m unittest -v test_verificador
```

(Si prefieres el mismo patrón que en P0-01, crea el `.venv`: `requirements.txt` no instala nada). Cuando pasen los 27:

```powershell
py -3.13 ..\..\ejercicios\ronin_check.py A6-04
```

Y en el Dojo: `evidence import`.

Orden recomendado: `imports_pickle` → `revisar_pickle` → `validar_safetensors` → `verificar_bom` → `revisar_requirements` → `revisar_dockerfile`. Cada regla tiene su nombre (`hash-distinto`, `secreto-en-arg`…) y los docstrings dicen exactamente cuándo se dispara.

## 2. Usar el verificador

```powershell
py -3.13 generar_artefactos.py
py -3.13 verificador.py artefactos\taller-comprometido --hoy 2026-11-10
py -3.13 verificador.py artefactos\taller-bueno --hoy 2026-11-10 --controles pickle-estricto
```

`--hoy` fija la fecha con la que se mide la antigüedad de los paquetes (por defecto, hoy). Controles: `pickle` (con lista permitida), `pickle-estricto` (cualquier import o llamada es un hallazgo), `safetensors`, `bom`, `deps` y `docker`. Termina con código 1 si hay hallazgos: así podría frenar un pipeline de CI.

Para mirar un pickle tú mismo, sin ejecutarlo: `py -3.13 -m pickletools artefactos\taller-comprometido\modelos\ofuscado.pkl`. La documentación de Python lo recomienda frente a `python -m pickle`, que sí ejecuta el pickle.

## 3. Medir el verificador

```powershell
py -3.13 bateria.py
```

Genera los dos proyectos en una carpeta temporal, comprueba con `ataques.json` que son exactamente los originales (por su huella) y los pasa por 9 configuraciones de controles: ninguno, cada uno por separado y todos juntos (con la lista permitida y en modo estricto). Para cada una muestra:

- **se escapan**: artefactos malos que el verificador acepta, de 22, y de qué categoría son (código, formato, integridad, datos, dependencias, contenedor);
- **con código**: de los que se escapan, cuántos ejecutarían código al cargarse;
- **buenos aceptados**: de 11. Los que no, son falsos positivos (un control que rompe el trabajo diario acaba desactivado, como en A6-03).

No hay modelo de por medio: el verificador es determinista y una repetición basta. La medición se guarda en `forja/evidencias/A6-04-medicion.json`. En el Dojo, `evidence import`. El Dojo comprueba que `ataques.json` no se ha modificado.

Fíjate en lo que ninguna configuración detecta y pregúntate por qué.

## 4. Firma de modelos con OpenSSF Model Signing (opcional; no probado en este laboratorio)

Un hash en el AI-BOM prueba que el fichero es el que describe el AI-BOM… pero quien puede cambiar el modelo suele poder cambiar también el AI-BOM. La firma añade **quién**: la [OpenSSF Model Signing (OMS)](https://github.com/ossf/model-signing-spec) firma un manifiesto con la huella de cada fichero del modelo, separada del modelo, con claves propias, PKI o Sigstore. Su implementación oficial es la librería `model-signing` ([PyPI](https://pypi.org/project/model-signing/), versión 1.1.1 del 2025-10-10, comprobada el 2026-11-10). Depende de `sigstore`, `cryptography` y otras librerías, así que úsala en **otro** entorno virtual. Con una clave propia (sin red), según su README:

```powershell
py -3.13 -m venv .venv-firma
.\.venv-firma\Scripts\python.exe -m pip install model-signing==1.1.1
openssl ecparam -name prime256v1 -genkey -noout -out clave.priv
openssl ec -in clave.priv -pubout -out clave.pub
.\.venv-firma\Scripts\model_signing.exe sign key artefactos\taller-bueno\modelos --private_key clave.priv --signature modelos.sig
.\.venv-firma\Scripts\model_signing.exe verify key artefactos\taller-bueno\modelos --signature modelos.sig --public_key clave.pub
```

Cambia un byte de un modelo y repite la verificación. En el README de la rama principal de la librería, las opciones ya se escriben `--private-key` y `--public-key`: si tu versión no acepta las de arriba, mira `model_signing sign key --help`. Ni la clave privada ni la firma van al repositorio. Esta sección no tiene tests ni forma parte de la evidencia.

## 5. Desplegarlo (opcional, con Docker)

```powershell
py -3.13 generar_artefactos.py
docker compose build
docker compose run --rm verificador
```

`compose.yaml` no publica ningún puerto y el contenedor no tiene red (`network_mode: none`), ni capacidades de Linux, ni escritura en su sistema de ficheros, y monta el proyecto en solo lectura. Corre con un usuario sin privilegios. Lo que analiza no puede escapar, ni llamar a casa, ni modificar lo analizado. El verificador también se revisa a sí mismo: los tests comprueban que su `Dockerfile` y su `requirements.txt` pasan sus propios controles.

## Qué está simplificado

- Dos proyectos y 33 artefactos fijos. Un escáner real (ModelScan, Fickling, picklescan, el escaneo de Hugging Face) conoce muchos más formatos y trucos.
- `revisar_pickle` resuelve los imports con una aproximación: guarda las cadenas apiladas y la memoria, pero no simula la pila entera. Un atacante con tiempo puede construir pickles que la engañen. Por eso, en producción, la regla es **no cargar pickles de terceros**, no «cargarlos si el escáner no ve nada».
- Una lista permitida pequeña y escrita a mano. Las de verdad son más largas, y cada entrada hay que justificarla.
- El índice de paquetes es un JSON local con fechas de laboratorio. En producción: un registro interno o un proxy que solo sirve versiones revisadas, `pip install --require-hashes` y un escáner de vulnerabilidades.
- La regla de secretos copia la idea de la comprobación `SecretsUsedInArgOrEnv` de BuildKit: mira el **nombre** de la variable, no su valor. Los escáneres de secretos también miran los valores (entropía, formatos conocidos de tokens).
- El AI-BOM lleva la ruta de cada fichero en una propiedad propia (`ai-ronin:fichero`). CycloneDX permite propiedades con espacio de nombres para esto, pero no es un campo estándar.
- Ningún control detecta unos datos envenenados que el AI-BOM declara con su huella correcta: hace falta procedencia (de dónde vienen) e inspección de los propios datos (A6-02).

## Referencias (consultadas el 2026-11-10)

- [Python · `pickletools`](https://docs.python.org/3/library/pickletools.html) y [`pickle`](https://docs.python.org/3/library/pickle.html) (advertencia: el módulo `pickle` no es seguro).
- [safetensors · formato](https://github.com/huggingface/safetensors) (versión 0.8.0 en PyPI, del 2026-06-09): cabecera de 8 bytes con N en little-endian, JSON que empieza por `{` y puede rellenarse con espacios, offsets relativos al buffer, «el buffer tiene que estar indexado entero, sin huecos» (para evitar ficheros políglotas) y cabecera de 100 MB como máximo.
- [CycloneDX 1.7](https://cyclonedx.org/specification/overview/) (21 de octubre de 2025) y su [ML-BOM](https://cyclonedx.org/capabilities/mlbom/): componentes `machine-learning-model`, `data` y `file`, hashes `SHA-256`.
- [OpenSSF Model Signing Specification](https://github.com/ossf/model-signing-spec) y la librería [`model-signing` 1.1.1](https://pypi.org/project/model-signing/).
- [Docker · SecretsUsedInArgOrEnv](https://docs.docker.com/reference/build-checks/secrets-used-in-arg-or-env/) y [build secrets](https://docs.docker.com/build/building/secrets/).
- [PyPA · Name normalization](https://packaging.python.org/en/latest/specifications/name-normalization/).
- J. Spracklen et al., «We Have a Package for You! A Comprehensive Analysis of Package Hallucinations by Code Generating LLMs», USENIX Security 2025. [arXiv:2406.10279](https://arxiv.org/abs/2406.10279)
