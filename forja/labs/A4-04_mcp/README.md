# A4-04 · El servidor de verdad

**Misión del Dojo:** A4-04 (requiere A4-03 y P0-01). Laboratorio real de la Forja.

En A4-01…03 el host y los servidores MCP eran una simulación dentro del Dojo. Aquí son de verdad: el almacén de la forja ficticia Kurogane es un **servidor MCP** hecho con el **SDK oficial de Python** (`mcp`, revisión de la especificación 2026-07-28), con transporte **Streamable HTTP**, que escucha solo en `127.0.0.1` y pide un token en cada petición. A su lado, `clima-samurai`, un servidor de terceros con una descripción envenenada y una actualización que cambia su definición (rug pull).

**Estos servidores son vulnerables a propósito.** Todo es ficticio y escucha solo en `127.0.0.1`.

- `datos/planos/` son planos ficticios (los que el almacén debe servir); `datos/privado/costes.txt` es un documento interno con un canario que **nunca** debería salir de esa carpeta.
- El almacén tiene tres herramientas (`buscar_pedido`, `aplicar_reembolso`, `leer_plano`) y dos recursos (`forja://catalogo`, `forja://planos`).

| Pieza | Quién la escribe |
|---|---|
| `validar_argumentos`, `scopes_que_faltan`, `ruta_segura`, `huella_definicion`, `revisar_definiciones`, `senales_sospechosas`, `audiencia_valida` en `servidor.py` | **Tú** |
| Los servidores MCP (`crear_almacen`, `crear_clima`), el verificador de tokens, la aplicación HTTP, `host.py` y `bateria.py` | Claude |
| `test_servidor.py` (28 tests, servidores reales dentro del proceso, sin red) | Claude |

Sin defensas, el almacén es vulnerable: cualquier token conocido vale para todo, aunque sea de otro servidor o esté caducado; no se comprueban los scopes; los argumentos solo se validan por tipo; y `leer_plano` junta la ruta pedida con la carpeta de planos sin sanearla.

## 1. Entorno y tests

Desde esta carpeta:

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe -m unittest -v test_servidor
```

Los tests no necesitan red: levantan los servidores MCP dentro del propio proceso y les hablan por HTTP con un transporte en memoria. Cuando pasen los 28:

```powershell
.\.venv\Scripts\python.exe ..\..\ejercicios\ronin_check.py A4-04
```

Y en el Dojo: `evidence import`.

## 2. Medir qué protege cada defensa

```powershell
.\.venv\Scripts\python.exe bateria.py
```

La batería **no necesita Ollama ni Docker**: levanta el almacén y `clima-samurai` reales dentro del proceso y los ataca con un host determinista. Mide 8 configuraciones de defensas (ninguna; cada una por separado; y todas juntas) contra 6 ataques y 4 tareas legítimas. Para ir más rápido:

```powershell
.\.venv\Scripts\python.exe bateria.py --configs "ninguna;scopes;audiencia;scopes,validacion,rutas,audiencia,pinning,revision"
```

Cada fila muestra:
- **éxito**: ataques que consiguieron su efecto, con su intervalo de confianza al 95 %;
- **llegó al servidor**: veces que la llamada maliciosa llegó a un servidor (la paró, si acaso, el propio servidor). Separa lo que el **host** frenó antes de que el modelo lo viera de lo que el **servidor** rechazó después;
- **legítimas**: tareas normales que salieron bien (detecta defensas que rompen el servicio).

Debajo, el desglose por categoría: `tool-poisoning`, `rug-pull`, `confusion-token`, `permisos-excesivos` y `validacion-ausente`. La medición se guarda en `forja/evidencias/A4-04-medicion.json`. En el Dojo, `evidence import`. El Dojo comprueba que `ataques.json` no se ha modificado.

### Por qué un host determinista y no `llama3.2:1b`

Un modelo de 1B en CPU no llama a herramientas de forma fiable, así que la medición no sería repetible. Aquí lo «real» es el protocolo (SDK MCP, Streamable HTTP, autorización por token), no el modelo. El modelo se sustituye por el **peor caso**: uno que obedece al pie de la letra las instrucciones que el host le deja ver. Lo que te protege no es el modelo, sino lo que el host le enseña (revisión, pinning) y lo que el servidor deja hacer (scopes, validación, rutas, audiencia).

## 3. Las defensas

Cuatro viven en el **servidor** (frenan la llamada antes de ejecutarla) y dos en el **host** (frenan antes de que el modelo vea la instrucción):

| Defensa | Dónde | Qué ataque corta |
|---|---|---|
| `validacion` | servidor | `leer_plano '../…'` (el patrón del esquema lo rechaza); argumentos fuera de rango o de más |
| `rutas` | servidor | path traversal: `ruta_segura` impide salir de `datos/planos/` |
| `scopes` | servidor | un token de solo lectura que aplica reembolsos (permisos excesivos) |
| `audiencia` | servidor | un token emitido para otro servidor, o caducado (confusión de token) |
| `pinning` | host | rug pull: la herramienta cambiada queda en cuarentena hasta aprobarla |
| `revision` | host | descripciones envenenadas: no se le enseñan al modelo |

## 4. Levantar los servidores de verdad (opcional)

```powershell
python servidor.py almacen      # http://127.0.0.1:8765/mcp
python servidor.py clima        # http://127.0.0.1:8770/mcp
```

Con `$env:DEFENSAS = "scopes,validacion,rutas,audiencia"` antes de arrancar el almacén se activan sus defensas. O con Docker (contenedor no root, puertos solo en `127.0.0.1`):

```powershell
docker compose up -d --build
```

## Qué está simplificado

- El servidor de autorización es ficticio: los tokens ya están emitidos y el verificador los mira en una tabla, en vez de validar un JWT firmado o introspeccionarlos (RFC 7662).
- El modelo es determinista (el peor caso), no un LLM real.
- La revisión de descripciones es una expresión regular; un atacante la reformula.
- Los tokens y sus scopes son fijos; en producción salen de tu sistema de identidad.
- Seis ataques y cuatro tareas legítimas: una evaluación real usa muchos más.

## Referencias (consultadas el 2026-11-10)

- [Model Context Protocol · especificación, revisión 2026-07-28](https://modelcontextprotocol.io/specification/2026-07-28) y sus [Security Best Practices](https://modelcontextprotocol.io/specification/latest/basic/security_best_practices) (tool poisoning, token passthrough, confused deputy, minimización de scopes).
- [SDK oficial de Python de MCP](https://github.com/modelcontextprotocol/python-sdk) (paquete `mcp` 2.3.0).
- [RFC 8707 · Resource Indicators for OAuth 2.0](https://www.rfc-editor.org/rfc/rfc8707) (2020): el parámetro `resource` y la audiencia del token.
- [RFC 9728 · OAuth 2.0 Protected Resource Metadata](https://www.rfc-editor.org/rfc/rfc9728) (2025).
- [OWASP Top 10 for Agentic Applications 2026](https://genai.owasp.org/resource/owasp-top-10-for-agentic-applications-for-2026/).
