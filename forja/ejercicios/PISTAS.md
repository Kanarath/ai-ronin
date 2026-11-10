# Pistas de los ejercicios

Ábrelas de una en una, solo si te atascas. 🟢 = empujoncito · 🟡 = técnica · 🔴 = casi la solución.
Antes de abrir una pista, ejecuta el test y lee el mensaje de error: suele decir exactamente qué falla.

---

## T1_01 · estadísticas

<details><summary>🟢 cargar_csv</summary>Lee todas las líneas; la primera es la cabecera y el resto, los datos. Cada línea de datos se convierte en un diccionario.</details>
<details><summary>🟡 cargar_csv</summary><code>lineas = f.read().splitlines()</code> · <code>claves = lineas[0].split(",")</code> · para cada línea no vacía: <code>dict(zip(claves, linea.split(",")))</code>. Ver PYTHON.md §10.</details>
<details><summary>🔴 desviacion_tipica</summary>Calcula primero la media m. Después, la media de <code>(x − m) ** 2</code> para todos los x. Por último, la raíz cuadrada: <code>** 0.5</code>.</details>
<details><summary>🟡 recuento</summary>Diccionario vacío y, para cada etiqueta, <code>d[e] = d.get(e, 0) + 1</code> (PYTHON.md §8).</details>

## T1_02 · distancia

<details><summary>🟢 distancia_euclidea</summary>Primero comprueba <code>len(a) != len(b)</code> y lanza ValueError. Después, suma las diferencias al cuadrado de cada pareja de coordenadas.</details>
<details><summary>🟡 distancia_euclidea</summary><code>sum((x - y) ** 2 for x, y in zip(a, b)) ** 0.5</code></details>
<details><summary>🟢 ajustar_minmax</summary>Necesitas las COLUMNAS de X, no las filas: <code>zip(*X)</code> te las da (PYTHON.md §6).</details>
<details><summary>🔴 aplicar_minmax</summary>Una fila nueva por cada fila de X: para cada valor x de la columna j con parámetros (lo, hi): <code>0.0 if hi == lo else (x - lo) / (hi - lo)</code>. Construye listas nuevas; no modifiques X.</details>

## T2_01 · k-NN

<details><summary>🟢 dividir</summary>Crea <code>indices = list(range(n))</code>, barájalos con <code>random.Random(semilla).shuffle(indices)</code> (no asignes el resultado: devuelve None), corta y ordena las dos partes.</details>
<details><summary>🟡 dividir</summary><code>n_test = min(max(int(n * proporcion_test), 1), n - 1)</code> · test = <code>sorted(indices[:n_test])</code> · train = <code>sorted(indices[n_test:])</code></details>
<details><summary>🟡 vecinos</summary>Construye una tupla <code>(i, distancia, y_train[i])</code> por cada ejemplo, ordénalas con <code>key=lambda t: (t[1], t[0])</code> y quédate con las k primeras (PYTHON.md §7).</details>
<details><summary>🔴 predecir</summary>Cuenta votos con un diccionario. Halla el máximo de votos. Recorre los vecinos EN ORDEN y devuelve la etiqueta del primero cuya clase tenga ese máximo: así se resuelven los empates.</details>
<details><summary>🟡 matriz_confusion</summary><code>m = [[0] * len(clases) for _ in clases]</code> y, para cada pareja (real, pred): <code>m[clases.index(real)][clases.index(pred)] += 1</code>.</details>

## T3_01 · descenso por gradiente

<details><summary>🟢 gradientes</summary>Recorre los ejemplos calculando el error <code>e = w*x + b - y</code>; acumula <code>e*x</code> para dw y <code>e</code> para db. Al final, multiplica por 2/n.</details>
<details><summary>🟡 entrenar</summary>w = b = 0; historial = [mse inicial]. En cada época: gradientes → actualizar → <code>historial.append(mse(...))</code> → si <code>ha_divergido(historial)</code>: <code>break</code>.</details>
<details><summary>🔴 ha_divergido</summary><code>ultima = historial[-1]</code>; devuelve <code>not math.isfinite(ultima) or ultima > LIMITE_DIVERGENCIA</code>. En mse usa <code>e * e</code>, no <code>e ** 2</code> (PYTHON.md §12).</details>

## T3_02 · métricas

<details><summary>🟢 contar</summary>Recorre <code>zip(y_true, y_pred)</code>. Pregúntate en cada pareja: ¿era positiva? ¿la predije positiva? Las cuatro combinaciones son TP, FP, FN y TN.</details>
<details><summary>🟡 precision / recall</summary>Reutiliza <code>contar</code>. Para evitar dividir entre cero: <code>c["tp"] / (c["tp"] + c["fp"]) if c["tp"] + c["fp"] > 0 else 0.0</code>.</details>
<details><summary>🟡 curva</summary>Para cada umbral: <code>pred = aplicar_umbral(...)</code> y añade <code>(umbral, precision(...), recall(...))</code> a la lista.</details>

## T4_01 · neurona

<details><summary>🟢 neurona</summary>z = suma de pesos[i] · x[i] + sesgo; devuelve sigmoide(z). <code>sum(w * xi for w, xi in zip(pesos, x))</code>.</details>
<details><summary>🟡 entropia_cruzada</summary>Recorta primero: <code>p = min(max(p, 1e-12), 1 - 1e-12)</code>. Después, <code>-(y * math.log(p) + (1 - y) * math.log(1 - p))</code>.</details>
<details><summary>🔴 entrenar_neurona</summary><code>pesos = list(pesos_iniciales)</code>. En cada época, para cada ejemplo: <code>err = neurona(x, pesos, sesgo) - y</code>; acumula <code>err * x[i]</code> para cada peso y <code>err</code> para el sesgo; divide entre n; actualiza con lr; añade la pérdida media al historial.</details>

## T4_02 · backpropagation

<details><summary>🟢 crear_red</summary><code>rng = random.Random(semilla)</code>. Primero W1 fila a fila (<code>rng.uniform(-1, 1)</code> por cada peso), después w2. b1 = ceros y b2 = 0.0.</details>
<details><summary>🟡 gradientes</summary>Prepara un diccionario de ceros con la misma forma que la red (comprensiones, PYTHON.md §5). Para cada ejemplo: forward → d2 = p − y → acumula los de la salida → d1[j] = d2·w2[j]·a1[j]·(1 − a1[j]) → acumula los de la capa oculta. Al final, divide todo entre n.</details>
<details><summary>🟡 gradiente_numerico</summary><code>mas = copy.deepcopy(red)</code> y <code>menos = copy.deepcopy(red)</code>. Suma eps al parámetro de la ruta en <code>mas</code> y réstalo en <code>menos</code>. Para llegar al parámetro: si la ruta es ("b2",), cambia <code>red["b2"]</code>; si tiene 2 elementos, <code>red[ruta[0]][ruta[1]]</code>; si tiene 3, <code>red[ruta[0]][ruta[1]][ruta[2]]</code>.</details>
<details><summary>🔴 paso</summary>Devuelve un diccionario nuevo: <code>{"W1": [[w - lr*g for w, g in zip(fw, fg)] for fw, fg in zip(red["W1"], grads["W1"])], ...}</code> y lo mismo para b1, w2 y b2.</details>

## T5_01 · BPE

<details><summary>🟢 entrenar_bpe</summary>Cuenta las palabras con <code>Counter(pre_tokenizar(texto))</code>. Guarda cada palabra como lista de símbolos junto a su frecuencia. En cada vuelta: cuenta pares, elige el mejor, fusiónalo en todas las palabras.</details>
<details><summary>🟡 contar pares</summary><code>pares = Counter()</code>; para cada (simbolos, freq): <code>for a, b in zip(simbolos, simbolos[1:]): pares[(a, b)] += freq</code>.</details>
<details><summary>🔴 elegir el par</summary><code>mejor = min(pares, key=lambda p: (-pares[p], p))</code>: el que más aparece y, si empatan, la tupla menor. (<code>most_common</code> no garantiza este desempate).</details>
<details><summary>🟡 aplicar_fusion</summary>Usa un índice i y un <code>while i &lt; len(syms)</code>: si <code>syms[i] == a</code> y <code>syms[i+1] == b</code>, añade a+b y salta 2; si no, añade syms[i] y salta 1.</details>

## T5_02 · embeddings

<details><summary>🟢 coseno</summary>Producto escalar: <code>sum(x*y for x, y in zip(a, b))</code>. Longitud: <code>math.sqrt(sum(x*x for x in a))</code>. Si alguna longitud es 0, devuelve 0.0.</details>
<details><summary>🟡 vecinos</summary>Lista de <code>(palabra, coseno(vector, tabla[palabra]))</code> para las palabras que no estén en <code>excluir</code>; ordénala con <code>key=lambda t: (-t[1], t[0])</code> y corta <code>[:k]</code>.</details>
<details><summary>🔴 analogia</summary><code>v = [x - y + z for x, y, z in zip(tabla[a], tabla[b], tabla[c])]</code> y devuelve <code>vecinos(tabla, v, 1, excluir=(a, b, c))[0][0]</code>.</details>

## T6_01 · muestreo

<details><summary>🟢 contar_bigramas</summary>Recorre las parejas consecutivas: <code>for a, b in zip(tokens, tokens[1:])</code> y cuenta en un diccionario de diccionarios (<code>setdefault</code>, PYTHON.md §8).</details>
<details><summary>🟡 con_temperatura</summary>Si t == 0: <code>[(dist[0][0], 1.0)]</code>. Si no: <code>nuevas = [(tok, p ** (1 / t)) for tok, p in dist]</code>, suma total y divide cada una entre el total.</details>
<details><summary>🔴 top_p</summary>Recorre dist acumulando probabilidad; añade cada token y para (<code>break</code>) en cuanto <code>acumulada &gt;= p - 1e-9</code>. Después, renormaliza los que quedan.</details>

## T6_02 · atención

<details><summary>🟢 softmax</summary><code>m = max(fila)</code>; <code>exps = [math.exp(x - m) for x in fila]</code>; divide cada una entre la suma. <code>math.exp(float("-inf"))</code> vale 0.0.</details>
<details><summary>🟡 pesos_atencion</summary>d = <code>len(vectores[0])</code>. Puntuación (i, j) = producto escalar / <code>math.sqrt(d)</code> (si escalar). Con causal y j &gt; i: <code>float("-inf")</code>. Softmax a cada fila.</details>
<details><summary>🔴 salida_atencion</summary>Para cada i: <code>[sum(pesos[i][j] * vectores[j][k] for j in range(n)) for k in range(d)]</code>.</details>

## A2_01 · RAG

<details><summary>🟢 trocear</summary><code>palabras = texto.split()</code>; un <code>while</code> con un índice <code>inicio</code> que avanza <code>tam - solape</code>; añade <code>" ".join(palabras[inicio:inicio + tam])</code> y para (<code>break</code>) cuando <code>inicio + tam &gt;= len(palabras)</code>.</details>
<details><summary>🟡 construir_idf</summary>Para contar df, convierte los términos de cada fragmento en un <code>set</code> (cada fragmento cuenta una vez por término) y suma en un diccionario.</details>
<details><summary>🟡 vectorizar</summary><code>tf</code> con un diccionario de conteos; pesos = <code>conteo / len(terminos) * idf.get(t, 1.0)</code>; norma = <code>math.sqrt(sum(w*w for w in pesos.values()))</code>; divide cada peso entre la norma (si no es 0).</details>
<details><summary>🔴 buscar</summary>Filtra primero: <code>[e for e in indice if not acl or rol == "empleado" or e["acceso"] == "publico"]</code>. Después calcula <code>(e["id"], coseno(q, e["vector"]))</code> y ordena con <code>key=lambda t: (-t[1], t[0])</code>; corta <code>[:k]</code>.</details>
## A3_01 · autorización del agente

<details><summary>🟢 autorizar</summary>Cuatro <code>if</code> en el orden indicado; cada uno devuelve <code>(False, "motivo")</code>. Si ninguno salta, <code>return True, "ok"</code>.</details>
<details><summary>🟡 dominio de un correo</summary><code>dominio = args.get("para", "").split("@")[-1]</code> y comprueba <code>dominio in DOMINIOS_PERMITIDOS</code>.</details>
<details><summary>🟡 importe válido</summary><code>pedido in PEDIDOS and 0 &lt; importe &lt;= PEDIDOS[pedido]</code>.</details>
<details><summary>🔴 ejecutar_plan</summary>Un contador de pasos. Para cada llamada: si el contador ya llegó a PRESUPUESTO_PASOS, bloquea con "step-budget" (sin autorizar). Si no, construye <code>ctx = dict(contexto, origen=llamada["origen"])</code>, llama a <code>autorizar</code>, suma 1 al contador y añade a la lista que toque.</details>

## A4_01 · sellos de un host MCP

<details><summary>🟢 descripcion_sospechosa</summary><code>[p for p in PATRONES_SOSPECHOSOS if re.search(p, descripcion, re.IGNORECASE)]</code>. Una comprensión de listas conserva el orden de la lista original.</details>
<details><summary>🟢 huella</summary><code>texto = json.dumps(herramientas, sort_keys=True, ensure_ascii=False)</code>; <code>hashlib.sha256(texto.encode("utf-8")).hexdigest()[:12]</code>.</details>
<details><summary>🟡 comprobar_pin</summary>Primero <code>if servidor not in aprobadas</code>; después compara <code>huella(herramientas) != aprobadas[servidor]</code>.</details>
<details><summary>🟡 tabla_herramientas</summary>Recorre servidores y herramientas: <code>tabla[f"{s['id']}.{h}"] = s["id"]</code>. Para las colisiones, cuenta en un diccionario cuántos servidores exponen cada nombre y quédate con los que tienen 2 o más: <code>sorted(n for n, c in cuenta.items() if c &gt;= 2)</code>.</details>
<details><summary>🔴 aceptar_token</summary>Dos <code>if</code> en orden: <code>token.get("aud") != servidor</code> → "audiencia"; <code>permiso not in token.get("scopes", [])</code> → "permiso". Es exactamente lo que la especificación MCP exige a un servidor: no aceptar tokens que no se emitieron para él.</details>
## A6_01 · sellos de la cadena de suministro

<details><summary>🟢 huella_fichero</summary><code>hashlib.sha256(contenido).hexdigest()</code>. Aquí ya recibes bytes: no hace falta <code>encode</code>.</details>
<details><summary>🟡 formato_artefacto</summary>Primero <code>if cabecera[:1] == b"\x80"</code>. Para safetensors: <code>n = int.from_bytes(cabecera[:8], "little")</code> y comprueba <code>len(cabecera) &gt;= 9 and n &gt; 0 and cabecera[8:9] == b"{"</code>. Usa cortes (<code>[8:9]</code>), no índices: <code>b"{"[0]</code> es un entero.</details>
<details><summary>🟡 verificar_artefacto</summary>Tres <code>if</code> en orden: <code>nombre not in manifiesto</code>; <code>manifiesto[nombre]["firmante"] not in claves_confianza</code>; <code>huella_fichero(contenido) != manifiesto[nombre]["sha256"]</code>.</details>
<details><summary>🔴 revisar_dependencias</summary>Para cada requisito <code>r</code>, busca <code>aprobado = lockfile.get(r["nombre"])</code> y encadena <code>if / elif</code> con los cuatro motivos; la edad con <code>edades.get(r["nombre"], 0) &lt; EDAD_MINIMA_DIAS</code>. Acumula <code>(nombre, motivo)</code> y devuelve <code>sorted(problemas)</code>.</details>
<details><summary>🟢 secretos_en_capas</summary><code>[i for i, capa in enumerate(capas) if re.search(PATRON_SECRETO, capa, re.IGNORECASE)]</code>.</details>

## O6_01 · trazas, detección y respuesta

<details><summary>🟢 redactar</summary>Dos sustituciones seguidas: <code>re.sub(PATRON_CORREO, r"***@\1", texto)</code> y después <code>re.sub(PATRON_TELEFONO, "[teléfono]", ...)</code>. El grupo <code>\1</code> es el dominio.</details>
<details><summary>🟢 dominio_destino</summary><code>m = re.search(PATRON_DOMINIO, argumentos)</code>; devuelve <code>m.group(1) if m else ""</code>.</details>
<details><summary>🟡 regla_correlacion</summary>Recorre la sesión con dos banderas, <code>instruccion</code> y <code>salida</code>. Para «recuperacion»: <code>MARCA_INSTRUCCION in e["contenido"].lower()</code>. Para «herramienta»: nombre en <code>HERRAMIENTAS_SALIDA</code> y <code>dominio_destino(e["args"]) not in permitidos</code> (cuidado con el dominio vacío). Devuelve <code>instruccion and salida</code>.</details>
<details><summary>🟢 metricas</summary><code>vp = len(alertas &amp; maliciosas)</code>. Precision = <code>vp / len(alertas)</code> y recall = <code>vp / len(maliciosas)</code>, cada una con su <code>if</code> para el 0.</details>
<details><summary>🟢 alcance</summary><code>sorted(sid for sid, eventos in sesiones.items() if any(e.get("tipo") == "recuperacion" and e.get("fuente") == fuente for e in eventos))</code>.</details>

## P0-01 · servicio con un LLM local (forja/labs/P0-01_servicio_llm)

<details><summary>🟢 validar_pregunta</summary><code>t = texto.strip()</code>; si <code>not t</code> o <code>len(t) &gt; MAX_CARACTERES</code>, <code>raise ValueError(...)</code>; si no, <code>return t</code>.</details>
<details><summary>🟢 construir_peticion</summary>Empieza con una lista vacía de mensajes y añade el de sistema solo <code>if sistema is not None</code>. Igual con <code>options["seed"]</code>: comprueba <code>is not None</code>, porque la semilla 0 es válida y <code>if semilla:</code> la descartaría.</details>
<details><summary>🟡 extraer_respuesta</summary>Primero las comprobaciones: <code>if datos.get("done") is not True or "message" not in datos: raise ValueError(...)</code>. Después, <code>datos.get("eval_count", 0)</code> y <code>round(datos.get("total_duration", 0) / 1e9, 3)</code>.</details>
<details><summary>🟡 preguntar</summary>Elige la temperatura (<code>ajustes.temperatura if temperatura is None else temperatura</code>), haz <code>r = await cliente.post("/api/chat", json=construir_peticion(...))</code>, luego <code>r.raise_for_status()</code> y <code>return extraer_respuesta(r.json())</code>.</details>

## A1-05 · el mostrador de verdad (forja/labs/A1-05_chatbot)

<details><summary>🟡 normalizar</summary>Quita tildes con <code>"".join(c for c in unicodedata.normalize("NFD", texto.lower()) if not unicodedata.combining(c))</code>. Después recorre los caracteres: los que cumplen <code>c.isalnum()</code> van formando una palabra y cualquier otro la cierra. Al final, <code>" ".join(palabras)</code> o <code>"".join(palabras)</code>.</details>
<details><summary>🟢 contiene_secreto</summary>Una línea: <code>normalizar(secreto, espacios=False) in normalizar(texto, espacios=False)</code>.</details>
<details><summary>🟢 filtrar_entrada</summary>Normaliza una vez y recorre <code>patrones</code> en orden; devuelve en cuanto encuentres el primero.</details>
<details><summary>🟢 filtrar_salida</summary>Un <code>if contiene_secreto(texto, secreto)</code> y dos <code>return</code>.</details>
<details><summary>🟡 delimitar</summary><code>re.sub(r"&lt;/?entrada_usuario&gt;", "[etiqueta]", texto, flags=re.IGNORECASE)</code> quita la apertura y el cierre de una vez. Después concatena la etiqueta, <code>"
"</code>, el texto, <code>"
"</code> y la etiqueta de cierre.</details>
<details><summary>🟡 intervalo_wilson</summary>Copia la fórmula del docstring paso a paso, con variables intermedias (<code>p</code>, <code>z2 = z * z</code>, <code>d = 1 + z2 / n</code>). Usa <code>math.sqrt</code>; y <code>max(0.0, ...)</code> y <code>min(1.0, ...)</code> antes de redondear.</details>

## A2-04 · la biblioteca de verdad (forja/labs/A2-04_rag)

<details><summary>🟡 trocear</summary>Valida primero los tres casos del <code>ValueError</code>. Después <code>w = texto.split()</code>, <code>paso = palabras - solape</code> y un bucle <code>while</code> con <code>i</code> desde 0: añade <code>" ".join(w[i:i + palabras])</code> y haz <code>break</code> si <code>i + palabras &gt;= len(w)</code>. El <code>while w:</code> resuelve el texto vacío.</details>
<details><summary>🟡 bm25</summary>Calcula <code>N</code> y <code>avgdl</code> antes del bucle. Para cada <code>q in set(consulta)</code>: <code>n_q = sum(1 for d in documentos if q in d)</code>, su <code>idf</code> con <code>math.log</code>, y suma a cada documento su término con <code>f = d.count(q)</code>.</details>
<details><summary>🟢 fusion_rrf</summary>Un dict de puntuaciones y <code>for pos, x in enumerate(lista, 1)</code>. Los dict recuerdan el orden de inserción y <code>sorted</code> es estable: <code>sorted(puntos, key=lambda x: -puntos[x])</code> ya desempata por aparición.</details>
<details><summary>🟢 recall_en_k</summary><code>rel = set(relevantes)</code> y <code>len(set(recuperados[:k]) &amp; rel) / len(rel)</code>.</details>
<details><summary>🟢 filtro_acceso</summary><code>ACCESOS_POR_ROL.get(rol, [])</code> ya deniega por defecto; envuélvelo en <code>sorted(...)</code>, que devuelve una lista nueva. Cuidado: <code>None</code> no es una clave válida si haces <code>rol.lower()</code>, y <code>"Empleado"</code> no es <code>"empleado"</code>.</details>
<details><summary>🟢 firmar</summary><code>hmac.new(clave.encode("utf-8"), canonico.encode("utf-8"), hashlib.sha256).hexdigest()</code>, con <code>canonico = "
".join([...])</code>.</details>
<details><summary>🟢 verificar_firma</summary><code>f = doc.get("firma")</code>; <code>isinstance(f, str) and hmac.compare_digest(firmar(doc, clave), f)</code>.</details>
<details><summary>🟡 ensamblar_contexto</summary>Escapa con <code>re.sub(r"&lt;/?documento_no_confiable&gt;", "[etiqueta]", texto, flags=re.IGNORECASE)</code>, como en A1-05. Para el presupuesto, antes de añadir un bloque comprueba <code>len("

".join(bloques + [bloque])) &gt; max_caracteres</code> y haz <code>break</code>.</details>

## C1_01 · la matriz de defensas

<details><summary>🟢 bloqueado_por</summary><code>sorted(d for d, ataques in matriz.items() if ataque in ataques)</code>.</details>
<details><summary>🟢 puntos_unicos</summary>Reutiliza <code>bloqueado_por</code>: <code>sorted(a for a in ataques if len(bloqueado_por(matriz, a)) == 1)</code>.</details>
<details><summary>🟡 cobertura_minima</summary>Candidatas: <code>sorted(d for d in matriz if d not in con_coste)</code>. Bucle <code>for n in range(len(candidatas) + 1)</code> y dentro <code>for combo in combinations(candidatas, n)</code>. Una combinación cubre si <code>all(any(a in matriz[d] for d in combo) for a in ataques)</code>; devuelve la primera. Si acaba el bucle, <code>return None</code>.</details>
<details><summary>🟡 resiliencia</summary>Para cada ataque, <code>n = sum(1 for d in activas if a in matriz.get(d, set()))</code>: 0 → pasa, 1 → frágil, 2 o más → robusto.</details>

## C5_01 · el motor del encargo

<details><summary>🟡 validar_hallazgo</summary>Seis comprobaciones en orden, cada una con su <code>return</code>. La categoría con <code>re.match(PATRON_OWASP, categoria)</code>. La evidencia con <code>evidencias.get(activo_id, 0) &gt; 0</code>: cubre a la vez «sin batería» y «0 éxitos».</details>
<details><summary>🟢 estado_retest</summary>Cuatro <code>if</code> en el orden del docstring: <code>is None</code>, <code>&gt; 0</code>, <code>is None</code>, <code>&lt; 1.0</code>; si ninguno se cumple, <code>"corregido"</code>.</details>
<details><summary>🟡 priorizar</summary>Una función <code>puntos(h)</code> con la fórmula y <code>sorted(hallazgos, key=lambda h: (-puntos(h), h["id"]))</code>. El signo menos ordena de mayor a menor sin romper el desempate por id ascendente.</details>
<details><summary>🟢 resumen</summary><code>c = sum(1 for e in estados.values() if e == "corregido")</code> y <code>n = len(estados)</code>.</details>

## O5_01 · gobernanza en código

<details><summary>🟡 clasificar_ai_act</summary>Cuatro <code>if</code> en orden. El primero junta tres condiciones: <code>s["infiere_emociones"] and s["contexto"] in CONTEXTOS_PROHIBIDOS_EMOCIONES and s["motivo"] not in MOTIVOS_EXCEPCION_EMOCIONES</code>.</details>
<details><summary>🟢 riesgo</summary>Comprueba cada valor con <code>isinstance(x, int) and 1 &lt;= x &lt;= 5</code>; si no, <code>raise ValueError(...)</code>. Después, <code>return probabilidad * impacto</code>.</details>
<details><summary>🟢 residual</summary>Un <code>if / elif</code> por tratamiento y <code>riesgo(r["p"], r["i"])</code> por defecto. Reutiliza <code>riesgo</code>.</details>
<details><summary>🟢 tratamiento_permitido</summary><code>if tratamiento == "mitigar" and r["p_mitigada"] is None</code> · <code>if tratamiento == "aceptar" and riesgo(r["p"], r["i"]) &gt; apetito</code>.</details>
<details><summary>🟡 resumen_registro</summary>Recorre los riesgos con <code>t = tratamientos.get(r["id"])</code> y <code>res = residual(r, t)</code>. Un riesgo evitado es innecesario si <code>t == "evitar" and r["p_mitigada"] is not None</code>. Ordena las listas con <code>sorted</code>.</details>

## P0_02 · regresión logística (clases y NumPy)

<details><summary>🟢 estandarizar</summary>Tres líneas: <code>X = np.asarray(X, dtype=float)</code>, medias y desviaciones con <code>.mean(axis=0)</code> y <code>.std(axis=0)</code>. Después, <code>desv = np.where(desv == 0, 1.0, desv)</code> y devuelve <code>((X - medias) / desv, medias, desv)</code>. El broadcasting resta a cada fila (PYTHON.md §16).</details>
<details><summary>🟢 ampliar_cuadrados</summary><code>np.hstack([Xs, Xs ** 2])</code>: la lista lleva los dos arrays que se pegan columna a columna.</details>
<details><summary>🟢 __init__</summary>Cinco asignaciones a <code>self.</code>: lr, epocas, pesos (None), sesgo (0.0) e historial ([]). Sin <code>return</code> (PYTHON.md §15).</details>
<details><summary>🟡 probabilidades (pura)</summary>Primero <code>if self.pesos is None: raise RuntimeError(...)</code>. Para cada fila: <code>z = sum(w * xi for w, xi in zip(self.pesos, x)) + self.sesgo</code> y <code>1 / (1 + math.exp(-z))</code>.</details>
<details><summary>🟡 ajustar (pura)</summary>Reinicia pesos y sesgo, guarda la pérdida inicial y en cada época: <code>ps = self.probabilidades(X)</code>; acumula <code>e = p - t</code> por ejemplo en una lista de gradientes; actualiza con la media (divide entre n) y añade <code>self.perdida(X, y)</code> al historial. <code>return self</code> al final.</details>
<details><summary>🔴 ajustar (NumPy)</summary><code>X = np.asarray(X, dtype=float)</code> · <code>y = np.asarray(y, dtype=float)</code> · <code>n, d = X.shape</code> · <code>self.pesos = np.zeros(d)</code>. En el bucle: <code>e = self.probabilidades(X) - y</code> · <code>self.pesos = self.pesos - self.lr * (X.T @ e) / n</code> · <code>self.sesgo -= self.lr * float(e.mean())</code>.</details>
<details><summary>🟢 cronometrar</summary><code>t0 = time.perf_counter()</code>, <code>modelo.ajustar(X, y)</code> y <code>return time.perf_counter() - t0</code>.</details>

## P0_03 · MLP en matrices

<details><summary>🟢 __init__</summary>Un único <code>rng = np.random.default_rng(semilla)</code> y dos llamadas a <code>rng.uniform(-1.0, 1.0, size=...)</code>, primero W1 y luego W2. Si creas dos rng distintos, W2 sale igual que el principio de W1.</details>
<details><summary>🟡 forward</summary><code>A1 = sigmoide(X @ self.W1 + self.b1)</code> y <code>P = sigmoide(A1 @ self.W2 + self.b2)</code>. Escribe al lado las formas: (n, d)·(d, H) + (H,) → (n, H).</details>
<details><summary>🟡 gradientes</summary>Llama a <code>self.forward(X)</code>, <code>n = X.shape[0]</code> y sigue el docstring línea a línea. Si ∂b1 tiene forma (n, H), falta <code>.sum(axis=0)</code>. Si ∂W1 tiene forma (H, d), has traspuesto al revés: es <code>X.T @ D1</code>.</details>
<details><summary>🔴 gradientes</summary><code>D2 = (P - Y) / n</code> · <code>D1 = (D2 @ self.W2.T) * A1 * (1 - A1)</code> · <code>return {"W1": X.T @ D1, "b1": D1.sum(axis=0), "W2": A1.T @ D2, "b2": D2.sum(axis=0)}</code></details>
<details><summary>🟢 paso / entrenar / predecir</summary><code>self.W1 -= lr * grads["W1"]</code> (×4) · historial con la pérdida inicial y una por época · <code>(self.forward(X)[1][:, 0] &gt;= 0.5).astype(int)</code>.</details>

## P0_04 · Unicode en streaming

<details><summary>🟢 longitudes</summary>Cuatro <code>len</code>: del texto, de <code>texto.encode("utf-8")</code> y de <code>unicodedata.normalize("NFC", texto)</code> y <code>"NFD"</code> (PYTHON.md §17).</details>
<details><summary>🟢 recortar_bytes</summary>Después de comprobar <code>max_bytes &lt; 0</code>: <code>texto.encode("utf-8")[:max_bytes].decode("utf-8", errors="ignore")</code>. Al cortar solo puede quedar a medias el último carácter, y <code>errors="ignore"</code> lo descarta.</details>
<details><summary>🟡 decodificar</summary>Crea <code>dec</code> fuera del bucle. Dentro: <code>t = dec.decode(b)</code> y <code>if t: yield t</code>. Después del bucle, lo mismo con <code>dec.decode(b"", final=True)</code> (PYTHON.md §18).</details>
<details><summary>🟡 lineas</summary><code>bufer = ""</code>; por cada trozo, <code>bufer += t</code> y <code>while "\n" in bufer:</code> parte con <code>bufer.split("\n", 1)</code> y haz yield de la primera parte sin <code>"\r"</code>. Al final, <code>if bufer: yield ...</code>.</details>
<details><summary>🔴 tokens</summary><code>for linea in lineas_: yield from PATRON.findall(unicodedata.normalize("NFC", linea.casefold()))</code>. <code>yield from</code> entrega uno a uno los elementos de una lista.</details>

## P0_05 · generación token a token

<details><summary>🟡 muestrear</summary><code>u = rng.random()</code> una vez; <code>acum = 0.0</code>; para cada <code>(tok, p)</code>: <code>acum += p</code> y <code>if u &lt; acum: return tok</code>. Después del bucle, <code>return dist[-1][0]</code>.</details>
<details><summary>🟡 generar</summary><code>actual = inicio</code> y <code>for _ in range(max_tokens):</code> con el orden exacto del docstring. Las tres salidas son <code>return</code> (sin valor); el token fin se entrega con yield ANTES del return.</details>
<details><summary>🟢 en_streaming</summary>Una variable <code>primero = True</code>: si es el primero o <code>t in PUNTUACION</code>, <code>yield t</code>; si no, <code>yield " " + t</code>. Después, <code>primero = False</code>.</details>
<details><summary>🟢 con_presupuesto</summary><code>usados = 0</code>; por cada pieza, <code>n = len(p.encode("utf-8"))</code>; si <code>usados + n &gt; max_bytes</code>, <code>return</code>; si no, súmalo y <code>yield p</code>.</details>
<details><summary>🟢 frecuencias</summary>Cuenta con un diccionario y <code>.get(t, 0) + 1</code> (PYTHON.md §8); al final, <code>{t: c / n for t, c in cuenta.items()}</code>.</details>
## A3-04 · el agente de verdad (forja/labs/A3-04_agente)

<details><summary>🟡 validar_argumentos</summary>Un dict de comprobadores de tipo: <code>"number": lambda v: isinstance(v, (int, float)) and not isinstance(v, bool)</code>. Tres bucles en el orden del docstring: <code>required</code>, las claves sobrantes con <code>sorted(...)</code> y, por último, <code>for nombre, p in esquema["properties"].items()</code>. Si el tipo falla, <code>continue</code>; si no, un <code>if "maxLength" in p</code> por cada restricción.</details>
<details><summary>🟢 permitido</summary>Primero <code>if herramienta not in HERRAMIENTAS: return False</code>. Después <code>HERRAMIENTAS[herramienta]["nivel"] in PERMISOS_POR_ROL.get(rol, [])</code>: <code>.get</code> con <code>[]</code> ya deniega a los roles desconocidos y a <code>None</code>.</details>
<details><summary>🟡 necesita_aprobacion</summary>El dominio es <code>para.rsplit("@", 1)[1].strip().lower()</code>, y antes comprueba <code>isinstance(para, str) and "@" in para</code>. Con <code>rsplit</code>, <code>x@clientes.example@botin.example</code> da <code>botin.example</code>.</details>
<details><summary>🟢 autorizar</summary>Cuatro <code>if</code> con su <code>return</code>, en el orden del docstring. En el último, <code>aprobador(herramienta, argumentos) is not True</code>: <code>"sí"</code> no es <code>True</code>. Pon <code>necesita_aprobacion(...)</code> antes que la llamada al aprobador en el <code>and</code>, para no preguntar al humano si no hace falta.</details>
<details><summary>🟢 marcar_no_confiable</summary><code>re.sub(r"&lt;/?salida_herramienta\b[^&gt;]*&gt;", "[etiqueta]", salida, flags=re.IGNORECASE)</code> y después concatena la apertura con <code>herramienta="..."</code>, el texto y el cierre.</details>
<details><summary>🟢 comprobar_limites</summary>Tres <code>if</code> en orden. Para el bucle: <code>sum(1 for n, a in llamadas if n == nueva[0] and a == nueva[1])</code>. Dos dict son iguales con <code>==</code> aunque sus claves estén en otro orden.</details>
<details><summary>🟡 detectar_exfiltracion</summary>Normaliza el texto una vez. Recorre <code>datos_sensibles.items()</code>; salta los datos cuyo propietario es <code>para.strip().lower()</code> y los que normalizados quedan en <code>""</code> (la cadena vacía está dentro de cualquier texto). Junta los encontrados en un <code>set</code> y devuelve <code>sorted(...)</code>.</details>
<details><summary>🟡 recortar_memoria</summary>Cuenta los <code>system</code> del principio con un <code>while</code>. Con <code>cupo = max_mensajes - n</code>, la cola es <code>resto[-cupo:]</code>: <code>[-0:]</code> sería TODA la lista, así que trata antes <code>cupo &lt;= 0</code>. Después, quita los <code>tool</code> del principio de la cola con otro <code>while</code>.</details>
## A4_04 · el servidor de verdad (forja/labs)

<details><summary>🟡 validar_argumentos</summary>Si no es <code>dict</code>, devuelve <code>["no es un objeto"]</code> y para. Primero los <code>falta …</code> recorriendo <code>required</code>. Después recorre <code>argumentos.items()</code>: si el nombre no está en <code>properties</code> y <code>additionalProperties is False</code>, <code>sobra …</code> (si no, <code>continue</code>). Comprueba el tipo (ojo: <code>isinstance(True, int)</code> es <code>True</code>, así que para "integer" exige <code>not isinstance(valor, bool)</code>); si el tipo falla, <code>continue</code>. Luego longitud, formato (<code>re.fullmatch</code>) y rango, en ese orden.</details>
<details><summary>🟡 scopes_que_faltan</summary>Normaliza <code>concedidos</code> a lista (<code>None</code>→[], <code>str</code>→<code>.split()</code>). Expande con la jerarquía usando una pila y un conjunto <code>cubiertos</code>: saca uno, si ya está <code>continue</code>, si no añádelo y mete <code>jerarquia.get(s, [])</code>. El conjunto evita el bucle infinito del ciclo. Devuelve <code>sorted({s for s in requeridos if s not in cubiertos})</code>.</details>
<details><summary>🟡 ruta_segura</summary>Primero rechaza lo evidente: no <code>str</code>, vacío, con <code>"\x00"</code> o <code>"\\"</code>; absoluto (empieza por <code>/</code> o <code>nombre[1] == ":"</code>). Resuelve <code>base_r = Path(base).resolve()</code> y <code>destino = (base_r / nombre).resolve()</code>. <code>ValueError</code> si <code>destino == base_r</code> o <code>not destino.is_relative_to(base_r)</code>.</details>
<details><summary>🟢 huella_definicion</summary>Arma el dict con solo <code>name</code>, <code>description</code> (o <code>""</code>) e <code>inputSchema</code> (o <code>{}</code>), serialízalo con <code>json.dumps(..., sort_keys=True, ensure_ascii=False, separators=(",", ":"))</code> y devuelve <code>hashlib.sha256(...).hexdigest()</code>.</details>
<details><summary>🟡 revisar_definiciones</summary>Recorre <code>actuales</code> guardando <code>{name: huella}</code> y apuntando los nombres repetidos. <code>nuevas</code>: están en actuales y no en fijadas. <code>cambiadas</code>: están en las dos y (la huella difiere <code>or</code> el nombre está repetido). <code>desaparecidas</code>: en fijadas y no en actuales. Devuelve las tres listas con <code>sorted</code>.</details>
<details><summary>🟡 senales_sospechosas</summary>Un conjunto. Etiqueta: <code>re.search(r"&lt;\s*/?\s*[A-Za-z_][\w-]*\s*&gt;", d)</code>. Ocultación: <code>any(f in normalizar(d) for f in FRASES_OCULTACION)</code>. Otra herramienta: por cada nombre, <code>re.search(r"\b%s\b" % re.escape(h), d, re.IGNORECASE)</code>. Ruta: <code>"../" in d or "..\\" in d</code>. Larga: <code>len(d) &gt; MAX_DESCRIPCION</code>. Devuelve <code>sorted</code>. <code>None</code> → trátalo como <code>""</code>.</details>
<details><summary>🟡 audiencia_valida</summary>En orden: <code>mal_formado</code> si no es dict o falta <code>iss</code>/<code>aud</code>/<code>exp</code> o <code>exp</code> no es número (<code>isinstance(exp, bool)</code> no cuenta); <code>emisor</code> si <code>iss != emisor</code>; <code>audiencia</code> si <code>aud</code> (str o lista) no contiene <code>recurso</code> comparando <code>canonica(a) == canonica(recurso)</code>; <code>caducado</code> si <code>exp &lt;= ahora</code>; si no, <code>ok</code>.</details>
## A6-04 · la cadena de verdad (forja/labs/A6-04_cadena)

<details><summary>🔴 imports_pickle</summary>Un bucle <code>for op, arg, _ in pickletools.genops(datos)</code> con <code>n = op.name</code> y tres variables: <code>cadenas = []</code>, <code>memo = {}</code> y <code>previa = None</code> (lo que apiló el opcode anterior si fue una cadena). El orden de los <code>if</code> importa: primero GLOBAL/INST (<code>arg.replace(" ", ".", 1)</code>), después STACK_GLOBAL (<code>cadenas[-2]</code> y <code>cadenas[-1]</code>), después MEMOIZE (<code>memo[len(memo)] = previa</code>), los PUT (<code>memo[arg] = previa</code>), los GET y, al final, <code>isinstance(arg, str)</code>. MEMOIZE y PUT no tocan <code>previa</code>; todo lo demás que no apile una cadena la pone a <code>None</code>.</details>
<details><summary>🟡 revisar_pickle</summary>Mete en un <code>try</code> las dos pasadas: <code>nombres = [op.name for op, _, _ in pickletools.genops(datos)]</code> e <code>imports_pickle(datos)</code>; con <code>except ValueError</code> devuelve el hallazgo de ilegible. Después, un <code>if permitidos is None</code> para cada modo, y comprueba <code>not in out</code> antes de añadir para no repetir.</details>
<details><summary>🔴 validar_safetensors</summary><code>(n,) = struct.unpack("&lt;Q", datos[:8])</code>. Para el JSON: <code>try: ... json.loads(cab.decode("utf-8")) except ValueError</code> (<code>UnicodeDecodeError</code> y <code>JSONDecodeError</code> son <code>ValueError</code>). Una función auxiliar <code>entero(x)</code> con <code>isinstance(x, int) and not isinstance(x, bool) and x &gt;= 0</code> simplifica el punto 5. Guarda <code>(inicio, fin, nombre)</code> de los válidos en una lista: <code>sorted(lista)</code> ya ordena por esas tres cosas.</details>
<details><summary>🟡 verificar_bom</summary><code>next((p.get("value") for p in c.get("properties", []) if p.get("name") == PROPIEDAD_FICHERO), None)</code> encuentra la ruta; lo mismo con <code>"hashes"</code> y <code>"alg"</code>. Guarda las rutas declaradas en un <code>set</code> para el último paso. Y <code>huella.lower() != sha256_hex(...)</code>.</details>
<details><summary>🟡 revisar_requirements</summary>El comentario: <code>re.sub(r"(^|[ \t])#.*$", "", linea).strip()</code>. El marcador: <code>linea.split(";", 1)[0]</code>. Con <code>m = re.match(...)</code>, el nombre es <code>m.group(1)</code> y el especificador <code>re.sub(r"\s+", "", m.group(3))</code>. La antigüedad: <code>(hoy - datetime.date.fromisoformat(fecha)).days</code>.</details>
<details><summary>🔴 revisar_dockerfile</summary>Primero une las continuaciones en una lista de líneas lógicas (acumula en <code>actual</code> mientras la línea acabe en <code>\</code>). Después, <code>ins, args</code> con <code>linea.split(None, 1)</code>. Lleva un <code>set</code> de alias y una variable <code>usuario</code> que cada FROM pone a <code>None</code>. Para la etiqueta: <code>i = img.rfind(":")</code> y solo cuenta si <code>i &gt; img.rfind("/")</code>. Para los secretos, una función <code>es_secreta(clave)</code> con <code>clave.lower().split("_")</code>, <code>any(...)</code> y <code>not any(...)</code>.</details>
## E1-01 · el bucle de generación (forja/labs/E1-01_generacion)

<details><summary>🟢 con_temperatura</summary>Primero el <code>ValueError</code>. Para t == 0: <code>out = torch.full_like(logits, float("-inf"))</code> y <code>out[torch.argmax(logits)] = 0.0</code>. Si no, <code>logits / t</code> ya crea un tensor nuevo.</details>
<details><summary>🟡 filtro_top_p</summary><code>orden = torch.sort(probs, descending=True, stable=True)</code> da <code>orden.values</code> y <code>orden.indices</code>. Con <code>acum = torch.cumsum(orden.values, 0)</code>, el número de tokens es 1 + cuántos acumulados quedan por debajo de p: <code>n = int((acum &lt; p).sum()) + 1</code> (recórtalo a <code>len(probs)</code>). Después <code>out = torch.zeros_like(probs)</code>, <code>idx = orden.indices[:n]</code>, <code>out[idx] = probs[idx]</code> y <code>out / out.sum()</code>.</details>
<details><summary>🟢 siguiente_token</summary>Voraz: <code>int(torch.argmax(logits))</code>. Si no: <code>probs = torch.softmax(con_temperatura(logits, t), dim=-1)</code>, el filtro, y <code>int(torch.multinomial(probs, 1, generator=generador))</code>.</details>
<details><summary>🟡 generar</summary><code>secuencia = list(ids)</code> (copia). <code>for _ in range(max_nuevos):</code> con <code>with torch.no_grad(): salida = modelo(torch.tensor([secuencia]))</code>, el token de <code>salida.logits[0, -1]</code>, <code>append</code> a las dos listas y <code>break</code> si es el eos.</details>
<details><summary>🟢 log_probs_secuencia</summary><code>lp = torch.log_softmax(logits, dim=-1)</code> y <code>[float(lp[i, ids[i + 1]]) for i in range(len(ids) - 1)]</code>.</details>

## E1-02 · cuantizar a mano (forja/labs/E1-02_cuantizacion)

<details><summary>🟢 parametros_afines</summary><code>lo = min(float(w.min()), 0.0)</code>, <code>hi = max(float(w.max()), 0.0)</code>. El punto cero: <code>round(QMIN - lo / escala)</code>, recortado con <code>max(QMIN, min(QMAX, ...))</code>.</details>
<details><summary>🟢 cuantizar / descuantizar</summary><code>torch.clamp(torch.round(w / escala) + punto_cero, QMIN, QMAX).to(torch.int8)</code> · <code>(q.to(torch.float32) - punto_cero) * escala</code>.</details>
<details><summary>🟡 cuantizar_q8_0</summary><code>x = w.reshape(-1, bloque).float()</code> · <code>d = x.abs().amax(dim=1, keepdim=True) / 127</code> · <code>divisor = torch.where(d &gt; 0, d, torch.ones_like(d))</code> · <code>q = torch.round(x / divisor)</code> (en los bloques con d == 0, x ya es todo ceros) · devuelve <code>q.to(torch.int8), d.to(torch.float16)</code>. Comprueba antes <code>w.numel() % bloque</code>.</details>
<details><summary>🟢 error_relativo</summary><code>torch.linalg.norm(w - w_aprox) / torch.linalg.norm(w)</code>, con <code>float(...)</code> y el <code>ValueError</code> si el denominador es 0.</details>
<details><summary>🟢 bytes_esquema</summary>Un <code>if</code> por esquema. Q8_0: <code>n_pesos // 32 * 34</code>.</details>
<details><summary>🟢 perplejidad</summary><code>math.exp(-sum(log_probs) / len(log_probs))</code>.</details>

## E1-03 · LoRA y la lente de logits (forja/labs/E1-03_lora_lente)

<details><summary>🟡 LoRA</summary><code>for p in base.parameters(): p.requires_grad = False</code>. Las formas salen de <code>base.in_features</code> y <code>base.out_features</code>. En <code>forward</code>: <code>self.base(x) + self.escala * (x @ self.A.T @ self.B.T)</code>.</details>
<details><summary>🟢 fusionar</summary><code>nueva = nn.Linear(n, m, bias=base.bias is not None)</code> y, dentro de <code>torch.no_grad()</code>, <code>nueva.weight.copy_(base.weight + capa.escala * capa.B @ capa.A)</code>; el sesgo, con <code>nueva.bias.copy_(base.bias)</code>.</details>
<details><summary>🟢 contar_parametros</summary>Dos <code>sum(p.numel() for p in modelo.parameters() ...)</code>, uno con <code>if p.requires_grad</code>.</details>
<details><summary>🟡 aplicar_lora</summary>Congela todo primero. Después <code>for nombre, m in list(modelo.named_modules()):</code>, comprueba <code>isinstance(m, nn.Linear)</code> y <code>nombre.rpartition(".")[2] in objetivos</code>, y sustituye con <code>setattr(modelo.get_submodule(padre), hijo, LoRA(...))</code>.</details>
<details><summary>🟢 perdida_lm</summary><code>v = logits.shape[-1]</code> · <code>torch.nn.functional.cross_entropy(logits[:, :-1].reshape(-1, v), ids[:, 1:].reshape(-1))</code>.</details>
<details><summary>🟡 entrenar</summary><code>params = [p for p in modelo.parameters() if p.requires_grad]</code> (el <code>ValueError</code> si está vacía) · <code>opt = torch.optim.AdamW(params, lr=lr)</code> · en el bucle, <code>perdidas.append(perdida.item())</code>: aunque lo hagas después de <code>step()</code>, el valor es el de antes del paso.</details>
<details><summary>🟢 lente_logit</summary>Para cada estado: <code>p = torch.softmax(cabeza(norma(e[0, posicion])), dim=-1)</code>, <code>i = int(torch.argmax(p))</code> y <code>(i, float(p[i]))</code>.</details>
