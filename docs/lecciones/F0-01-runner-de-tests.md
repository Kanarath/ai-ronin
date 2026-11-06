# Lección F0-01 · El runner de tests

**Fase 0 · Nivel 2 (Apprentice) · unos 60–90 min · Fichero: `game/tests/run_tests.gd`**

## Por qué lo construyes tú

Podríamos instalar GUT o gdUnit4, pero un runner propio cabe en unas 60 líneas. Al escribirlo aprendes cuatro piezas de Godot que usarás en todo el proyecto:
- `SceneTree` como punto de entrada.
- Recorrer carpetas con `DirAccess`.
- Cargar scripts en tiempo de ejecución.
- Reflexión: pedir a un objeto la lista de sus métodos y llamarlos por nombre.

Además, AI RONIN no tendrá dependencias que no entiendas.

## Conceptos

### 1. `SceneTree` como script principal
Godot normalmente arranca cargando una escena. Con `-s res://tests/run_tests.gd`, en cambio, ejecuta **un script que extiende `SceneTree`**, que es el propio bucle principal del motor. El método `_initialize()` se llama al arrancar, y `quit(código)` termina el proceso con ese código de salida.

Con `--headless` no se abre ninguna ventana. Así es como se ejecuta en un servidor de CI.

### 2. `res://` frente a `user://`
- `res://` es la carpeta del proyecto (`game/`). Una vez exportado, es de solo lectura.
- `user://` es la carpeta de datos del usuario (en Windows, `%APPDATA%\Godot\app_userdata\AI RONIN`). Allí irá el guardado.

### 3. Cargar un script y crear instancias
`load("res://ruta.gd")` devuelve un recurso `GDScript`, que es la *clase*. `script.new()` crea una *instancia*. Es lo mismo que hace `TestCase.new()`, pero sin conocer el nombre de la clase de antemano.

### 4. Reflexión
Todo objeto en Godot puede responder a dos preguntas:
- ¿Qué métodos tienes? → un método que devuelve un `Array` de `Dictionary`. Mira qué claves tiene cada diccionario.
- Ejecuta el método que se llama así → un método que recibe un `String`.

Busca los dos en la documentación de [`Object`](https://docs.godotengine.org/en/stable/classes/class_object.html). Pista: uno empieza por `get_`.

### 5. Una instancia por test
¿Por qué crear una instancia **nueva** para cada test, en lugar de una por fichero? Piensa qué pasaría con `_failures` y con los datos preparados en `before_each()`. Esta pregunta te la hará RONIN en la revisión.

## Tu tarea

Completa los `TODO` de `run_tests.gd`. Criterios de aceptación:

1. Ejecutando
   ```powershell
   & "C:\Users\Ruben\Desktop\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path game -s res://tests/run_tests.gd
   ```
   aparece una línea por test con ✓ o ✗ y su fichero.
2. Los fallos muestran sus mensajes.
3. El resumen final indica cuántos tests se han ejecutado y cuántos han fallado. Ahora mismo deberían ser **8 tests y 0 fallos**: 5 en `test_test_case.gd` y 3 en `test_isolation.gd`.
4. El código de salida es `0` si todo pasa y `1` si algo falla. Compruébalo con `echo $LASTEXITCODE` justo después de ejecutarlo.
5. **Prueba de que detecta fallos:** cambia temporalmente un `assert_eq(…, 0)` por `assert_eq(…, 99)`, comprueba que aparece ✗ y que el código de salida es 1, y deshaz el cambio.
6. **Prueba de aislamiento real:** añade temporalmente `var r := HTTPRequest.new()` en `ui/hub/hub_screen.gd`. El test de aislamiento debe fallar e indicar el fichero y la línea. Después deshazlo.

## Pistas (míralas solo si te atascas, una a una)

<details><summary>Nivel 1 · Pista sutil</summary>

Hay tres problemas pequeños e independientes: encontrar ficheros, encontrar métodos y llamarlos. Resuélvelos por separado e imprime resultados intermedios con `print()` antes de juntarlos.
</details>

<details><summary>Nivel 2 · Pista técnica</summary>

- `DirAccess.open(path)` devuelve `null` si la carpeta no existe.
- `get_files()` y `get_directories()` devuelven `PackedStringArray`.
- Para la ruta, usa `path.path_join(nombre)`.
- Los métodos de un objeto se obtienen con `get_method_list()`. Cada elemento tiene la clave `"name"`. Esa lista **también incluye métodos heredados**, pero el filtro por `"test_"` los descarta.
- Para llamar a un método por nombre: `objeto.call(nombre)`.
</details>

<details><summary>Nivel 3 · Paso a paso (reduce la maestría de la lección)</summary>

1. En `_find_test_files`, recursión: para cada subcarpeta, `result.append_array(_find_test_files(subruta))`. Para cada fichero que empiece por `test_` y termine en `.gd`, `result.append(ruta)`.
2. En `_run_file`:
   - `var script: GDScript = load(path)`.
   - Crea una instancia temporal para obtener los nombres de métodos que empiezan por `test_`.
   - Por cada nombre: `var t = script.new()` → `t.before_each()` → `t.call(nombre)` → `t.after_each()` → `t.get_failures()`.
3. Imprime `"  ✓ %s" % nombre` o `"  ✗ %s"`, seguido de cada fallo indentado.
4. En `_initialize`, suma los resultados y termina con `quit(0 if fallos == 0 else 1)`.
</details>

<details><summary>Nivel 4 · Explicación detallada (reduce más la maestría)</summary>

`get_method_list()` devuelve un diccionario por método: `name`, `args`, `flags`, `return`… Los métodos que define tu script aparecen junto a los de `RefCounted` y `Object`. Por eso filtrar por prefijo es la forma más simple de quedarse solo con los tests. Si un script tuviera un método duplicado por herencia, aparecería dos veces; usar un `Dictionary` como conjunto evita ejecutarlo doble.

Por qué una instancia por test: `_failures` es estado de la instancia. Si se reutilizara, los fallos de un test aparecerían también en el siguiente, y lo que preparase `before_each()` podría quedar contaminado. Que cada test sea independiente es un principio básico de los tests unitarios.

Sobre el código de salida: la CI de GitHub Actions marca el paso como fallido si el proceso termina con un código distinto de 0. Ese es el único «contrato» entre tu runner y la CI.
</details>

El ejemplo resuelto (nivel 5) no se incluye aquí. Pídemelo explícitamente si de verdad lo necesitas, sabiendo que cuenta como ayuda máxima.

## Revisión

Cuando termines, dime «runner listo». Revisaré tu código, lo ejecutaré y te haré dos preguntas de comprensión. Después añadiremos la CI de GitHub Actions, que usará tu runner.
