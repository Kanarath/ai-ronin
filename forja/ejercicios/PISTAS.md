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

## A2-05 · lo que no se ve (forja/labs/A2-05_multimodal)

<details><summary>🟢 caracteres_invisibles</summary>Una comprensión: <code>[(i, "U+%04X" % ord(c)) for i, c in enumerate(texto) if es_invisible(c)]</code>. <code>%04X</code> rellena con ceros hasta 4 cifras y no recorta las de 5.</details>
<details><summary>🟡 quitar_invisibles</summary>Recorre con <code>enumerate</code> para tener el índice. Un carácter se queda si no es invisible, o si <code>c in (ZWJ, VS16) and i &gt; 0 and es_emoji(texto[i - 1])</code>. Mira <code>texto[i - 1]</code> en el texto ORIGINAL, no en lo que llevas construido.</details>
<details><summary>🟢 revelar_etiquetas</summary><code>"".join(chr(ord(c) - 0xE0000) for c in texto if 0xE0020 &lt;= ord(c) &lt;= 0xE007E)</code>.</details>
<details><summary>🟢 normalizar_unicode</summary><code>" ".join(unicodedata.normalize("NFKC", texto).split())</code>. <code>split()</code> sin argumentos también parte por el espacio de ancho completo (U+3000).</details>
<details><summary>🟡 oculto_por_estilo</summary>Primero <code>if "hidden" in atributos: return True</code>. Después <code>(atributos.get("style") or "").split(";")</code>; en cada declaración con <code>":"</code>, <code>prop, valor = decl.split(":", 1)</code>, <code>strip().lower()</code> y quita el <code>"!important"</code> final con <code>valor.removesuffix("!important").strip()</code>. Para opacity, <code>float(valor) == 0</code> dentro de <code>try / except ValueError</code>. Para font-size, <code>re.fullmatch(r"(0+(\.0*)?|\.0+)(px|pt|em|rem|%)?", valor)</code>. Para color, <code>valor.replace(" ", "") in BLANCOS</code>.</details>
<details><summary>🟡 texto_visible_html</summary>La pila guarda tuplas <code>(etiqueta, oculta)</code>. Al cerrar, recorre la pila desde el final con <code>range(len(pila) - 1, -1, -1)</code>; cuando encuentres la etiqueta, <code>del pila[i:]</code> y <code>break</code>. Un texto se guarda si <code>not any(oculta for _, oculta in pila)</code>.</details>
<details><summary>🟡 texto_visible_pdf</summary>Guarda el estado en un dict (<code>{"blanco": False, "modo": 0, "tam": 12.0}</code>): con <code>q</code>, <code>pila.append(dict(estado))</code> (una copia); con <code>Q</code>, <code>estado = pila.pop()</code> si la pila no está vacía. Para <code>TJ</code>, recorre la lista: si <code>isinstance(x, str)</code>, súmala; si es un número <code>&lt;= -200</code>, suma un espacio.</details>

## A2-06 · el segundo filtro (forja/labs/A2-06_reranking)

<details><summary>🟢 reordenar</summary><code>sorted(range(len(puntuaciones)), key=lambda i: -puntuaciones[i])[:k]</code>. <code>sorted</code> es estable: los empates conservan el orden de los índices. No olvides el <code>ValueError</code> si <code>k &lt; 1</code>.</details>
<details><summary>🟡 recuperar_reordenado</summary>Tres <code>return</code>: <code>[]</code> si no hay fragmentos, <code>frags[:k]</code> sin reordenador y, al final, <code>[dict(frags[i], puntuacion=float(puntos[i])) for i in reordenar(puntos, k)]</code>. <code>dict(f, clave=valor)</code> crea una copia con una clave más. Recuerda los dos <code>await</code>.</details>
<details><summary>🟢 recall_en_k</summary><code>rel = {d for d, g in relevancia.items() if g &gt;= umbral}</code> y, como en A2-04, <code>len(set(recuperados[:k]) &amp; rel) / len(rel)</code>.</details>
<details><summary>🟢 rango_reciproco</summary><code>for i, d in enumerate(recuperados, 1)</code> y <code>return 1 / i</code> en cuanto <code>relevancia.get(d, 0) &gt;= umbral</code>. Después del bucle, <code>return 0.0</code>.</details>
<details><summary>🟡 ndcg_en_k</summary>Ideal: <code>sorted((g for g in relevancia.values() if g &gt; 0), reverse=True)[:k]</code>. Para el DCG, un conjunto <code>vistos</code>: el grado de un documento ya visto es 0. Ganancia <code>(2 ** g - 1) / math.log2(i + 1)</code> con <code>i</code> desde 1.</details>
<details><summary>🟢 percentil</summary><code>v = sorted(valores)</code> (una lista nueva) y <code>v[math.ceil(p / 100 * len(v)) - 1]</code>: el <code>- 1</code> pasa de posición a índice.</details>
<details><summary>🟡 puntuacion_llm</summary><code>m = re.search(r"-?\d+(?:[.,]\d+)?", texto)</code>. Si hay coincidencia, <code>float(m.group().replace(",", "."))</code> y recórtalo con <code>min(10.0, max(0.0, x))</code>.</details>
