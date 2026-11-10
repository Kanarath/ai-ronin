# Ejercicios 🛠 — tu código, tus manos

Cada misión del Dojo tiene un ejercicio en Python. Implementas tú las funciones y los tests te dicen si funcionan.

| Ejercicio | Misión | Qué implementas |
|---|---|---|
| `T1_01_estadisticas.py` | T1-01 | Leer un CSV, media, desviación típica, rango, recuento de clases |
| `T1_02_distancia.py` | T1-02 | Distancia euclídea y Manhattan, contribuciones, normalización min-max y z-score |
| `T2_01_knn.py` | T2-01 | División train/test, k-NN, accuracy y matriz de confusión |
| `T3_01_descenso.py` | T3-01 | MSE, gradientes y descenso por gradiente con parada por divergencia |
| `T3_02_metricas.py` | T3-02 | Precision, recall, F1, umbrales y curva precision-recall |
| `T4_01_neurona.py` | T4-01 | Sigmoide, neurona, entropía cruzada y entrenamiento de una neurona |
| `T4_02_backprop.py` | T4-02 | Red 2-H-1, backpropagation a mano y gradient check |
| `T5_01_bpe.py` | T5-01 | Tokenizador BPE: entrenamiento y codificación |
| `T5_02_embeddings.py` | T5-02 | Similitud coseno, vecinos y analogías |
| `T6_01_sampling.py` | T6-01 | Modelo de bigramas, temperatura y top-p |
| `T6_02_atencion.py` | T6-02 | Softmax estable, self-attention y máscara causal |
| `A2_01_rag.py` | A2-01 | Troceo con solapamiento, TF-IDF, coseno y búsqueda con control de acceso |
| `A3_01_agente.py` | A3-01 | Capa de autorización de herramientas: mínimo privilegio, validación, permisos por usuario y presupuesto de pasos |
| `A4_01_mcp.py` | A4-01…03 | Sellos de un host MCP: revisión de descripciones, huellas (pinning), espacios de nombres y tokens con destinatario |
| `A6_01_cadena.py` | A6-01…03 | Sellos de la cadena de suministro: huellas, formato por los primeros bytes, verificación de artefactos, lockfile y secretos en capas |
| `O5_01_riesgos.py` | O5-01…03 | Gobernanza en código: clasificador simplificado del AI Act, riesgo inherente y residual, tratamientos permitidos y resumen del registro frente al apetito |
| `O6_01_trazas.py` | O6-01…03 | Detección y respuesta: redactar datos personales, dominio de destino, regla de correlación, precision/recall de alertas y alcance de un incidente |
| `C1_01_matriz.py` | C1-01…C3-02 | Matriz de defensas en código: quién bloquea cada ataque, puntos únicos, cobertura mínima sin coste y ataques frágiles |
| `C5_01_encargo.py` | C5-01…03 | El motor del encargo final: validar hallazgos, estado del retest, priorizar por impacto y exposición, y resumen de cierre |

**Ayudas:**
- [PYTHON.md](PYTHON.md) explica, con ejemplos, todo el Python que usan los ejercicios, y tiene una tabla con las secciones que necesita cada uno. Léela antes de cada ejercicio.
- [PISTAS.md](PISTAS.md) tiene pistas progresivas (🟢 🟡 🔴) para cada función.

**Reglas:**
- Solo Python estándar: nada de numpy, pandas ni scikit-learn todavía. Primero entiendes qué hacen por dentro y después usas las librerías.
- No copies soluciones de internet ni de una IA. Si te atascas, pide pistas a Claude: tiene la misma escalera de 5 niveles que el Dojo.
- Los tests son la especificación. Léelos: también enseñan.

## 1. Instalar Python (una sola vez)

Dentro del Dojo, el comando `forja setup` muestra estos mismos pasos. Con `--os macos` o `--os linux` los muestra para otros sistemas. Si no puedes instalar Python en un equipo, sigue jugando: los ejercicios no bloquean el progreso del Dojo.

**Windows:**

Abre PowerShell y ejecuta:

```powershell
winget install --id Python.Python.3.13 -e
```

Cierra y vuelve a abrir la terminal y comprueba con `python --version`. Si sigue abriéndose la Microsoft Store, desactiva los alias en *Configuración → Aplicaciones → Configuración avanzada de aplicaciones → Alias de ejecución de aplicaciones* (python.exe y python3.exe).

No hace falta instalar nada más: los tests usan `unittest`, que viene con Python.

## 2. Flujo de trabajo

Desde la carpeta `forja/ejercicios`:

```powershell
python -m unittest -v test_T1_01_estadisticas
```

1. Abre el fichero del ejercicio (por ejemplo, `T1_01_estadisticas.py`).
2. Lee el docstring de cada función: explica qué debe hacer, con un ejemplo.
3. Sustituye `raise NotImplementedError(...)` por tu implementación.
4. Ejecuta los tests. Ve en orden: haz pasar uno, luego el siguiente.
5. Cuando todos estén en verde, genera la evidencia y llévala al Dojo (sección 3).
6. Dile a Claude «ejercicio T1-01 listo». Revisaremos tu código juntos.

Para ejecutar todos los ejercicios a la vez:

```powershell
python -m unittest discover -v
```

`apoyo.py` lo ha escrito Claude: carga el dataset para los tests. No hace falta tocarlo.

## 3. Llevar el resultado al Dojo

`ronin_check` ejecuta los tests de un ejercicio y guarda el resultado en `forja/evidencias/<ID>.json`:

```powershell
python -m ronin_check T1-01
```

Con `python -m ronin_check todos` revisa todos. Después, en el terminal del Dojo:

```text
evidence import
```

El Dojo marca el ejercicio como verificado (🛠 junto a sus misiones en el currículo, +50 XP la primera vez). Con `evidence list` ves cuáles llevas. Una evidencia parcial también se importa: el Dojo muestra cuántos tests pasan.

Qué hay en la evidencia: el recuento de tests, los nombres de los que fallan y una huella SHA-256 del fichero de tests. **No contiene tu código.** El Dojo compara la huella con la de los tests originales: si has modificado un test, la evidencia se rechaza. Restaura el fichero (por ejemplo, con `git checkout -- test_T1_01_estadisticas.py`) y vuelve a ejecutar `ronin_check`.

Nada se envía a ningún sitio. Las evidencias son tuyas y no se suben al repositorio (`.gitignore`).

`ronin_check.py` también lo ha escrito Claude y no forma parte de los ejercicios.
