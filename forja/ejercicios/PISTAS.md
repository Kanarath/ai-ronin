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

## T2_02 · detector de abuso

<details><summary>🟢 cargar_peticiones</summary>Dentro del <code>with open(...)</code>: <code>filas = list(csv.DictReader(f))</code>. Después, tres comprensiones: <code>[f["id"] for f in filas]</code>, <code>[[float(f[c]) for c in FEATURES] for f in filas]</code> y <code>[f["tipo"] for f in filas]</code> (PYTHON.md §10).</details>
<details><summary>🟡 dividir_estratificado</summary>Crea <code>rng</code> una sola vez, fuera del bucle de clases. Para cada clase: <code>idx = [i for i, e in enumerate(y) if e == clase]</code>, <code>rng.shuffle(idx)</code>, <code>n = round(len(idx) * proporcion_test)</code>, y suma <code>idx[:n]</code> al test e <code>idx[n:]</code> al train.</details>
<details><summary>🟢 __init__ y normalizar</summary>Primero el <code>if k &lt; 1: raise ValueError(...)</code>; después los cinco atributos. En normalizar: <code>[0.0 if hi == lo else (v - lo) / (hi - lo) for v, lo, hi in zip(x, self.minimos, self.maximos)]</code> (PYTHON.md §15).</details>
<details><summary>🟡 entrenar</summary><code>columnas = list(zip(*X))</code>; <code>self.minimos = [min(c) for c in columnas]</code> y lo mismo con max. Después <code>self.X = [self.normalizar(x) for x in X]</code>, <code>self.y = list(y)</code> y <code>return self</code>.</details>
<details><summary>🔴 vecinos, predecir y puntuacion</summary>Son los de T2-01 con <code>self.X</code> y <code>self.y</code>, normalizando antes <code>x</code>. La puntuación: <code>sum(1 for t in vecinos if t[2] == positiva) / len(vecinos)</code>.</details>
<details><summary>🟡 linea_base</summary>Cuenta las clases del train en un diccionario y elige con <code>min(cuenta, key=lambda c: (-cuenta[c], c))</code>: la más frecuente y, si empatan, la primera alfabéticamente.</details>

## T3_03 · umbral por coste

<details><summary>🟢 errores</summary>Recorre <code>zip(puntuaciones, y_true)</code>. En cada pareja: <code>bloquea = s &gt;= umbral</code>. Si bloquea y no era positiva, suma un FP; si no bloquea y era positiva, suma un FN.</details>
<details><summary>🟢 umbrales_candidatos</summary><code>sorted(set(puntuaciones)) + [float("inf")]</code>. Ninguna puntuación es ≥ infinito: con ese umbral no se bloquea a nadie.</details>
<details><summary>🟡 mejor_umbral</summary>Recorre <code>tabla_costes(...)</code>, que ya va de menor a mayor umbral, y quédate con la fila si su coste es <code>&lt;=</code> que el mejor hasta ahora. Con <code>&lt;=</code>, en un empate gana la última, es decir, el umbral mayor.</details>
<details><summary>🔴 triaje</summary>Un diccionario con los cinco contadores a 0 y, para cada caso, <code>if s &gt;= alto</code> / <code>elif s &gt;= bajo</code> / <code>else</code>. Solo hay FP en la primera rama y solo hay FN en la última.</details>

## T4_03 · llamadas del agente

<details><summary>🟢 motivo</summary>Dos <code>if</code> con la diferencia CON signo: <code>origen - destino &gt; margen</code> es una fuga y <code>destino - origen &gt; margen</code>, una entrada no fiable. Si no, <code>return ""</code>.</details>
<details><summary>🟢 con_cruce</summary><code>[[o, d, abs(o - d)] for o, d in X]</code>: una lista nueva, sin tocar X.</details>
<details><summary>🟡 entrenar_logistica</summary>En cada época, <code>gw = [0.0] * d</code> y <code>gb = 0.0</code>. Para cada (x, t): <code>err = sigmoide(sum(w*xi for w, xi in zip(pesos, x)) + sesgo) - t</code>, <code>gw[j] += err * x[j]</code> y <code>gb += err</code>. Al final: <code>pesos = [w - lr * g / n for w, g in zip(pesos, gw)]</code>.</details>
<details><summary>🔴 explicar</summary><code>c = [(nom, w * xi) for nom, w, xi in zip(nombres, pesos, x)] + [("sesgo", sesgo)]</code> y <code>sorted(c, key=lambda t: (-abs(t[1]), t[0]))</code>.</details>

## T5_03 · disfraces de texto

<details><summary>🟢 quitar_invisibles</summary><code>"".join(c for c in texto if unicodedata.category(c) != "Cf")</code> (PYTHON.md §17).</details>
<details><summary>🟡 juntar_letras_sueltas</summary>Recorre las palabras guardando una <code>racha</code> de palabras de una letra. Cuando llega una palabra larga (o se acaba la lista): si la racha tiene 3 o más, añade <code>"".join(racha)</code>; si no, añade sus letras tal cual. Vacía la racha y añade la palabra larga. Truco: recorre <code>palabras + [None]</code> para no olvidar la última racha.</details>
<details><summary>🟡 normalizar</summary>Ve paso a paso guardando el resultado en la misma variable. Homoglifos: <code>"".join(HOMOGLIFOS.get(c, c) for c in t)</code>. Tildes: <code>nfd = unicodedata.normalize("NFD", t)</code> y quita las <code>"Mn"</code>. Al final, <code>" ".join(juntar_letras_sueltas(re.findall(r"\w+", t)))</code>.</details>
<details><summary>🔴 filtro_significado</summary>Para cada palabra de <code>normalizar(texto).split()</code> que esté en la tabla, y para cada prohibida que esté en la tabla: si <code>coseno(tabla[palabra], tabla[p]) &gt;= umbral</code>, <code>return True</code>. Después de los dos bucles, <code>return False</code>.</details>
<details><summary>🟢 evaluar</summary><code>filtro</code> es una función: llámala con <code>filtro(t)</code>. <code>sum(1 for t in ataques if filtro(t))</code> y lo mismo con los legítimos.</details>

## T6_03 · instrucción escondida

<details><summary>🟢 peso_oculto</summary><code>1.0 / (1.0 + n * math.exp(s_relleno - s_oculta))</code>. Con la resta, el exponente es pequeño aunque las dos puntuaciones sean enormes.</details>
<details><summary>🟡 relleno_para_ahogar</summary>Primero <code>if not 0 &lt; objetivo &lt; 1: raise ValueError(...)</code>. Después <code>n = 0</code> y <code>while peso_oculto(s_oculta, s_relleno, n) &gt;= objetivo: n += 1</code>.</details>
<details><summary>🟢 parecido_necesario</summary>Las comprobaciones y después <code>s_relleno + math.log(objetivo * n / (1 - objetivo))</code>.</details>
<details><summary>🔴 fila_atencion</summary><code>q = tabla[palabras[i]]</code>. Para cada j: <code>float("-inf")</code> si <code>causal and j &gt; i</code>; si no, <code>sum(a * b for a, b in zip(q, tabla[palabras[j]])) / math.sqrt(len(q))</code>. Después, el softmax estable de T6-02.</details>

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
## E2-01 · el trazo que engaña (forja/labs/E2-01_evasion)

<details><summary>🟢 softmax</summary><code>Z = Z - Z.max(axis=1, keepdims=True)</code>, después <code>E = np.exp(Z)</code> y <code>E / E.sum(axis=1, keepdims=True)</code>. <code>keepdims=True</code> deja la forma (n, 1) para que la resta y la división se apliquen fila a fila.</details>
<details><summary>🟡 gradiente_entrada</summary><code>P = softmax(X @ W + b)</code>; resta 1 en la columna correcta de cada fila con <code>P[np.arange(len(y)), y] -= 1.0</code> y devuelve <code>P @ W.T</code>.</details>
<details><summary>🟢 fgsm</summary>Primero el <code>ValueError</code>. Después, una línea: <code>np.clip(X + epsilon * np.sign(gradiente), bajo, alto)</code>, que ya devuelve un array nuevo.</details>
<details><summary>🟢 curva_epsilon</summary>Un bucle sobre <code>epsilons</code>: <code>Xa = fgsm(X, gradiente_entrada(modelo.W, modelo.b, X, y), e)</code> y <code>float(np.mean(modelo.predecir(Xa) == y))</code>.</details>
<details><summary>🟡 gradiente_adversario</summary>Valida <code>alfa</code>. <code>gW, gb = gradiente_pesos(W, b, X, y)</code>; si <code>epsilon == 0</code>, devuélvelos. Si no, genera <code>Xa</code> con <code>fgsm</code>, calcula <code>gW2, gb2 = gradiente_pesos(W, b, Xa, y)</code> y combina: <code>alfa * gW + (1 - alfa) * gW2</code> (y lo mismo con b).</details>
<details><summary>🟢 reducir_bits</summary><code>L = 2 ** bits - 1</code> y <code>np.round(X * L) / L</code>.</details>
<details><summary>🟢 puntuacion_squeezing</summary>Compara <code>P.shape != P_reducida.shape</code> y después <code>np.abs(P - P_reducida).sum(axis=1)</code>.</details>
<details><summary>🟡 umbral_para_fpr</summary>Ordena las puntuaciones de menor a mayor y recórrelas: para cada <code>t</code>, <code>sum(1 for v in s if v &gt; t) / len(s)</code>. Devuelve la primera que cumpla <code>&lt;= fpr</code>. Cuidado con los empates: <code>&gt;</code> estricto.</details>

## E2-02 · la copia por correo (forja/labs/E2-02_extraccion)

<details><summary>🟢 redondear_probabilidades</summary>El <code>ValueError</code> y <code>np.round(np.asarray(P, dtype=float), decimales)</code>.</details>
<details><summary>🟡 permitir_consulta</summary><code>vivos = [t for t in historial.get(clave, []) if ahora - t &lt; ventana]</code> y guárdalos con <code>historial[clave] = vivos</code> antes de decidir. Si <code>len(vivos) + n &gt; maximo</code>, <code>return False</code>; si no, <code>vivos.extend([ahora] * n)</code> y <code>return True</code>.</details>
<details><summary>🟢 etiquetas_de_respuesta</summary>Dos <code>if</code> con <code>in</code>: <code>np.asarray(respuesta["clases"], dtype=int)</code> o <code>np.argmax(np.asarray(respuesta["probabilidades"]), axis=1)</code>. Al final, el <code>raise ValueError</code>.</details>
<details><summary>🟡 resolver_ecuaciones</summary><code>L = np.log(np.clip(P, minimo, 1.0))</code>, <code>R = L - L[:, 0:1]</code> (con <code>0:1</code> la columna conserva la forma (n, 1)), <code>A = np.hstack([Q, np.ones((len(Q), 1))])</code>, <code>S, *_ = np.linalg.lstsq(A, R, rcond=None)</code> y <code>return S[:-1], S[-1]</code>.</details>
<details><summary>🟢 acuerdo</summary>Pasa las dos a <code>list(...)</code>, valida longitudes y <code>sum(1 for a, b in zip(...) if a == b) / len(a)</code>.</details>

## E2-03 · ¿estaba en el registro? (forja/labs/E2-03_privacidad)

<details><summary>🟢 perdida_por_ejemplo</summary><code>-np.log(np.clip(P[np.arange(len(y)), y], minimo, 1.0))</code>.</details>
<details><summary>🟡 curva_roc</summary>Convierte con <code>s = np.asarray(puntuaciones)</code> y <code>m = np.asarray(es_miembro, dtype=bool)</code>; los no miembros son <code>~m</code>. Valida longitudes y que <code>m.sum()</code> y <code>(~m).sum()</code> sean mayores que 0. Después, <code>for t in sorted(set(s.tolist()), reverse=True)</code> y añade <code>(float(np.mean(s[~m] &gt;= t)), float(np.mean(s[m] &gt;= t)))</code> tras el <code>(0.0, 0.0)</code> inicial.</details>
<details><summary>🟢 area_bajo_curva</summary><code>sum((curva[i][0] - curva[i - 1][0]) * (curva[i][1] + curva[i - 1][1]) / 2 for i in range(1, len(curva)))</code>.</details>
<details><summary>🟡 mejor_umbral</summary>Mismo recorrido que <code>curva_roc</code>, de mayor a menor. Guarda el mejor y cámbialo solo si la nueva ventaja es <b>estrictamente</b> mayor: así, en un empate, se queda el umbral más alto.</details>
<details><summary>🟢 media_laplace</summary>Valida, <code>v = np.clip(np.asarray(valores, dtype=float), bajo, alto)</code>, <code>sens = (alto - bajo) / len(v)</code> y <code>float(v.mean() + rng.laplace(0.0, sens / epsilon))</code>.</details>
<details><summary>🟢 media_gaussiana</summary>Igual que Laplace, con <code>sigma = sens * math.sqrt(2 * math.log(1.25 / delta)) / epsilon</code> y <code>rng.normal(0.0, sigma)</code>. Valida <code>0 &lt; epsilon &lt; 1</code> y <code>0 &lt; delta &lt; 1</code>.</details>
<details><summary>🔴 recortar_y_ruido</summary><code>B = gradientes[0].shape[0]</code>. La norma de cada ejemplo: <code>np.sqrt(sum((g.reshape(B, -1) ** 2).sum(axis=1) for g in gradientes))</code>. El factor: <code>np.minimum(1.0, recorte / normas)</code>, con cuidado de no dividir entre 0 (<code>np.where</code>). Para multiplicar un array de forma (B, a, b) por el factor de forma (B,), usa <code>f.reshape((-1,) + (1,) * (g.ndim - 1))</code>. Después, <code>.sum(axis=0)</code>, suma <code>rng.normal(0.0, ruido * recorte, size=s.shape)</code> y divide entre <code>B</code>.</details>
## E3_01 · auditoría en código

<details><summary>🟢 muestreo_por_riesgo</summary>Usa un conjunto <code>muestra</code>: primero los de riesgo alta (comprueba <code>len(muestra) &gt; maximo</code>). Después recorre <code>FUNCIONES</code> y, si una función no tiene ningún control en la muestra, añade uno. Al final, rellena y devuelve <code>sorted(muestra)</code>.</details>
<details><summary>🟡 muestreo_por_riesgo</summary>El mejor de una función: <code>sorted(de_f, key=lambda c: (ORDEN_RIESGO[c["riesgo"]], c["id"]))[0]</code> (PYTHON.md §7). Relleno: <code>restantes = sorted(...)</code>, <code>k = min(maximo - len(muestra), len(restantes))</code> y <code>random.Random(semilla).sample(restantes, k)</code>.</details>
<details><summary>🟢 cobertura</summary>Convierte la muestra en <code>set</code> (PYTHON.md §9). Para cada función, cuenta cuántos de sus controles están en la muestra y divide entre cuántos tiene.</details>
<details><summary>🟡 clasificar_hallazgo</summary>Valida con <code>isinstance(x, int) and x &gt;= 0</code> para muestra y fallos, y <code>fallos &lt;= muestra</code>. Luego cuatro <code>if</code> en el orden del docstring; cuidado con dividir entre 0: comprueba <code>muestra &gt; 0</code> antes de <code>fallos / muestra</code>.</details>
<details><summary>🟡 intervalo_wilson</summary>Calcula <code>p</code> y el denominador <code>d = 1 + z * z / n</code> una vez; <code>math.sqrt</code> para la raíz (PYTHON.md §11). Recorta con <code>max(0.0, …)</code> y <code>min(1.0, …)</code>.</details>
<details><summary>🔴 resumen_auditoria</summary><code>conteo = {s: 0 for s in SEVERIDAD}</code> y suma 1 por cada valor. Orden: <code>sorted(clasificaciones, key=lambda i: (SEVERIDAD.index(clasificaciones[i]), i))</code>. Conclusión: mira <code>conteo["nc-mayor"]</code> y después <code>conteo["nc-menor"]</code>.</details>
## E4-01 · la forja bajo carga (forja/labs/E4-01_carga)

<details><summary>🟢 percentil</summary>Comprueba primero los dos casos del <code>ValueError</code>. <code>v = sorted(valores)</code> crea una lista nueva (no toca la original). Después, <code>pos = (len(v) - 1) * p / 100</code>, <code>i = int(pos)</code> y <code>f = pos - i</code>, y el <code>if i + 1 &lt; len(v)</code> del docstring.</details>
<details><summary>🟢 resumen_latencias</summary>El <code>ValueError</code> va lo primero, antes del caso vacío. Reutiliza <code>percentil</code> y envuelve cada número en <code>round(..., 3)</code>.</details>
<details><summary>🟡 CuboDeTokens</summary>En <code>__init__</code> guarda todo en <code>self</code>, también <code>self.ultimo = reloj()</code> (llamándolo: con paréntesis). En <code>permitir</code>: <code>self.tokens = min(self.capacidad, self.tokens + (ahora - self.ultimo) * self.recarga)</code>; después, el <code>if self.tokens &gt;= coste</code>. Si falla el test del rechazo, mira si restas antes de comprobar.</details>
<details><summary>🟢 normalizar_pregunta</summary>Una sola expresión encadenada: <code>" ".join(unicodedata.normalize("NFKC", texto).casefold().split()).strip(SIGNOS_BORDE)</code>.</details>
<details><summary>🟢 clave_cache</summary>Construye el texto con <code>"\n".join([ambito, modelo, str(float(temperatura)), normalizar_pregunta(pregunta)])</code> y pásalo a <code>hashlib.sha256(t.encode("utf-8")).hexdigest()</code>.</details>
<details><summary>🟡 CacheRespuestas</summary>Guarda tuplas <code>(valor, caduca_en)</code>. En <code>obtener</code>, desempaqueta con <code>valor, caduca = self.datos[clave]</code>. En <code>guardar</code>, un <code>while len(self.datos) &gt; self.max_entradas: self.datos.popitem(last=False)</code>.</details>
<details><summary>🔴 atender</summary>Sigue los pasos con un <code>return</code> temprano en cada rechazo. Para no duplicar código con y sin semáforo: <code>async with (estado.semaforo if estado.semaforo is not None else contextlib.nullcontext()):</code>. La suma a <code>admitidas</code> va justo antes del <code>try</code> y la resta en el <code>finally</code>, las dos solo si hay semáforo. El plazo: <code>await asyncio.wait_for(llamar_modelo(pregunta), timeout)</code> dentro de un <code>try/except TimeoutError</code>. Calcula la clave antes del paso 3 y guárdala en una variable para el paso 5.</details>

## E4-02 · el cuaderno de la forja (forja/labs/E4-02_trazas)

<details><summary>🟡 luhn_valido</summary><code>if not (13 &lt;= len(digitos) &lt;= 19) or not digitos.isdigit(): return False</code>. Después, <code>for i, c in enumerate(reversed(digitos))</code>: los de <code>i</code> impar se duplican (y se les resta 9 si pasan de 9).</details>
<details><summary>🟡 redactar</summary>Cinco <code>texto = re.sub(patron, etiqueta, texto)</code> en orden, con <code>flags=re.IGNORECASE</code> en el IBAN y el DNI. Para la tarjeta, una función <code>def tarjeta(m)</code> que mira <code>re.sub(r"[ -]", "", m.group(0))</code> y devuelve <code>"[TARJETA]"</code> o <code>m.group(0)</code> sin cambios; pásala a <code>re.sub</code> en lugar del texto.</details>
<details><summary>🟡 redactar_valor</summary>Tres <code>isinstance</code>: <code>str</code>, <code>(list, tuple)</code> y <code>dict</code>. En los dos últimos te llamas a ti misma: <code>tuple(redactar_valor(v) for v in valor)</code> y <code>{k: redactar_valor(v) for k, v in valor.items()}</code>. Lo demás se devuelve tal cual.</details>
<details><summary>🟢 atributos_peticion</summary>Un diccionario literal con las seis claves. <code>float(temperatura)</code>: el test pasa un <code>1</code>.</details>
<details><summary>🟢 atributos_respuesta</summary>Empieza con <code>a = {}</code> y añade <code>"gen_ai.response.model"</code> y <code>"gen_ai.response.finish_reasons"</code> solo <code>if "model" in datos</code> y <code>if "done_reason" in datos</code>. Los tokens, con <code>datos.get(..., 0)</code>.</details>
<details><summary>🟢 mensajes</summary>El caso <code>"no"</code> primero; luego <code>"redactado"</code> cambia el texto, y cualquier modo que no sea <code>"crudo"</code> lanza el error. Construye el diccionario del mensaje y añade <code>"finish_reason"</code> solo si no es <code>None</code>. Devuelve una lista con ese mensaje.</details>
<details><summary>🔴 preguntar_con_traza</summary>Todo va dentro del <code>with tracer.start_as_current_span(...) as span:</code>. <code>base = {k: atrs[k] for k in OBLIGATORIOS}</code>. El <code>try/except Exception as e</code> envuelve solo la llamada a <code>pedir_ollama</code>; en el <code>except</code>, tras registrar, un <code>raise</code> a secas vuelve a lanzar la misma excepción. Guarda <code>ra = atributos_respuesta(datos)</code> en una variable: la usas para el span y para las métricas de tokens.</details>

## E4-03 · la puerta de la forja (forja/labs/E4-03_despliegue)

<details><summary>🟢 regla_modelo</summary>Tres <code>if</code> con <code>return</code>: <code>m is None</code>, <code>m["nombre"] not in permitidos</code> y <code>digest_normalizado(m.get("digest")) != digest_normalizado(permitidos[m["nombre"]])</code>.</details>
<details><summary>🟢 regla_usuario</summary>Una lista <code>v = []</code>. <code>str(u).split(":")[0] in ("0", "root")</code> separa el uid del gid. Usa <code>elif</code> entre «sin declarar» y «root»: un usuario vacío no es las dos cosas.</details>
<details><summary>🟢 regla_recursos</summary><code>r = despliegue.get("recursos") or {}</code> cubre a la vez el que falta y el <code>None</code>; <code>if not r.get("cpus")</code> cubre a la vez el que falta y el vacío.</details>
<details><summary>🟡 puerto_expuesto</summary>Primero saca la IP: del diccionario, con <code>.get("host_ip")</code>; del texto, quita el protocolo con <code>.split("/")[0]</code>; si empieza por <code>"["</code>, la IP es <code>s[1:s.index("]")]</code>; si no, <code>partes = s.split(":")</code> y la IP es <code>partes[0]</code> solo si hay exactamente 3 partes. Sin IP → <code>True</code>. Con IP: <code>try: return not ipaddress.ip_address(ip).is_loopback</code> y <code>except ValueError: return True</code>.</details>
<details><summary>🟢 regla_puertos</summary><code>any(puerto_expuesto(p) for p in despliegue.get("puertos", []))</code>.</details>
<details><summary>🟡 regla_imagen</summary><code>if "@sha256:" in img: return []</code>. Después, <code>ultimo = img.split("/")[-1]</code>: está fijada si <code>":" in ultimo</code> y <code>ultimo.split(":")[-1]</code> no es ni <code>""</code> ni <code>"latest"</code>.</details>
<details><summary>🟡 evaluar</summary>Un diccionario de nombre → función; para el modelo, <code>lambda d: regla_modelo(d, permitidos)</code>. Junta las violaciones en un <code>set()</code> con <code>.update(...)</code> y devuelve <code>sorted(...)</code>.</details>
<details><summary>🟢 repartir</summary>El <code>ValueError</code> primero; después, copia la fórmula del docstring.</details>
<details><summary>🟢 decidir_canary</summary>Una función interna <code>tasa(m)</code> que devuelva <code>m["errores"] / m["n"] if m["n"] else 0.0</code>, y los cuatro pasos en orden, cada uno con su <code>return</code>.</details>
## A1-06 · el juez (forja/labs/A1-06_juez)

<details><summary>🟢 plantilla_puntual</summary>Haz una lista con los cinco bloques del docstring y únelos con <code>"\n\n".join(bloques)</code>. La respuesta va con <code>envolver(respuesta, "respuesta")</code>, que ya viene hecha.</details>
<details><summary>🟢 plantilla_comparacion</summary>Igual que la anterior, con seis bloques: <code>envolver(a, "respuesta_a")</code> y <code>envolver(b, "respuesta_b")</code>.</details>
<details><summary>🟡 parsear_puntuacion</summary><code>re.findall(patron, texto, flags=re.IGNORECASE)</code> devuelve todas las capturas; la última es <code>m[-1]</code>. Escribe una función auxiliar que reciba la cadena capturada: si contiene <code>"."</code> o <code>","</code>, devuelve <code>None</code>; si no, <code>int(...)</code> y comprueba el rango. Usa la misma auxiliar en las tres reglas y haz <code>return</code> en cuanto una regla encuentre algo. Para la regla 3: <code>texto.replace(" ", "").replace("*", "").strip().rstrip(".")</code> y <code>re.fullmatch</code>.</details>
<details><summary>🟢 parsear_veredicto</summary>Si hay etiqueta, <code>v = m[-1].lower()</code>; si no, la cadena limpia en minúsculas. Después, <code>{"a": "A", "b": "B", "empate": "empate"}.get(v)</code> devuelve <code>None</code> para todo lo demás.</details>
<details><summary>🟢 veredicto_equilibrado</summary>Traduce con <code>{"A": "B", "B": "A"}.get(v_ba, v_ba)</code>: «empate» se queda igual.</details>
<details><summary>🟡 kappa_cohen</summary>Reutiliza <code>porcentaje_acuerdo</code> para <code>po</code> (y para los <code>ValueError</code>). Las categorías: <code>set(x) | set(y)</code>. Para cada una, <code>(x.count(c) / n) * (y.count(c) / n)</code>.</details>
<details><summary>🟡 intervalo_bootstrap</summary>Sigue el docstring al pie de la letra: crea <code>rng</code> UNA vez, fuera del bucle. Llama a <code>rng.choices(range(n), k=n)</code> en cada repetición y construye las dos listas con los mismos índices.</details>
<details><summary>🟡 comparar_con_referencia</summary>Primero <code>presentes = [i for i in base if actual.get(i) is not None]</code>; casi todo sale de ahí. <code>faltan</code> son los de <code>base</code> que no están en <code>presentes</code>. Para ordenar, <code>sorted(...)</code>.</details>

## A1-07 · el guardián entrenado (forja/labs/A1-07_guardian)

<details><summary>🟢 ngramas</summary>Una comprensión con dos <code>for</code>: <code>[t[i:i + n] for n in range(n_min, n_max + 1) for i in range(len(t) - n + 1)]</code>.</details>
<details><summary>🟡 entrenar</summary>Valida primero (<code>set(etiquetas) != {0, 1}</code> cubre las dos últimas condiciones). Un <code>Counter</code> por clase, con <code>cuentas[e].update(ngramas(t, n_min, n_max))</code>. Vocabulario: <code>set(cuentas[0]) | set(cuentas[1])</code>. Recorre el vocabulario entero para cada clase: <code>Counter</code> devuelve 0 para lo que no ha visto.</details>
<details><summary>🟡 probabilidad</summary>Los n-gramas conocidos son los que están en <code>modelo["log_verosimilitud"][0]</code>, porque las dos clases tienen el mismo vocabulario. La media es <code>sum(...) / len(gs)</code> si <code>gs</code> no está vacía. Al final, <code>1 / (1 + math.exp(-z))</code>.</details>
<details><summary>🟢 matriz_confusion</summary>Con <code>zip</code> y cuatro casos: (1, 1) → vp, (0, 1) → fp, (0, 0) → vn, (1, 0) → fn, siendo (etiqueta, predicción).</details>
<details><summary>🟢 tasas</summary>Una función auxiliar <code>d(a, b)</code> que devuelva <code>a / (a + b)</code>, o <code>0.0</code> si <code>a + b == 0</code>. Las cuatro tasas salen de ella.</details>
<details><summary>🟢 curva_umbral</summary>Para cada umbral: <code>[1 if p &gt;= u else 0 for p in puntuaciones]</code>, después <code>tasas(matriz_confusion(...))</code>. Reutiliza tus funciones.</details>
<details><summary>🟡 elegir_umbral</summary>Filtra los que cumplen <code>c["tfp"] &lt;= tfp_maxima</code>. Si no queda ninguno, <code>None</code>. Si quedan, <code>min(..., key=lambda c: (c["tfn"], -c["umbral"]))</code>: el signo menos hace que, a igual tfn, gane el umbral más alto.</details>
<details><summary>🟢 con_separadores</summary><code>sep.join(palabra)</code> intercala el separador entre las letras de una cadena. Aplícalo solo si <code>len(palabra) &gt; 1</code>.</details>
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

## T7_01 · árboles, bosques y k-means

<details><summary>🟢 gini</summary>Cuenta cada clase con un diccionario; con n = len(etiquetas), resta a 1 la suma de <code>(veces / n) ** 2</code>. Lista vacía: 0.0 antes de dividir.</details>
<details><summary>🟡 mejor_corte</summary><code>d = sorted(set(valores))</code>; los umbrales son <code>(a + b) / 2</code> para <code>a, b in zip(d, d[1:])</code>. Para cada uno, separa las etiquetas en izq (valor &lt;= umbral) y der, y calcula el gini ponderado. Quédate con el primero que mejore <em>estrictamente</em>: así ganan los umbrales pequeños en un empate.</details>
<details><summary>🟢 predecir</summary>Un <code>while "hoja" not in nodo</code> que baja a <code>nodo["izq"]</code> o <code>nodo["der"]</code>.</details>
<details><summary>🟢 muestra_bootstrap</summary>Crea UN solo <code>r = random.Random(semilla)</code> y llama n veces a <code>r.randrange(n)</code>.</details>
<details><summary>🟡 votar</summary>Cuenta votos y ordena las clases con <code>key=lambda c: (-votos[c], c)</code>: más votos primero y, en empate, orden alfabético.</details>
<details><summary>🟡 asignar</summary><code>d = [math.dist(p, c) for c in centros]</code> y <code>d.index(min(d))</code>: index devuelve el primero, que es el de índice menor.</details>
<details><summary>🔴 mover_centros</summary>Para cada k: <code>mios = [p for p, a in zip(puntos, asignacion) if a == k]</code>; si hay puntos, <code>[sum(col) / len(mios) for col in zip(*mios)]</code>; si no, <code>list(centros[k])</code> (una copia).</details>
<details><summary>🟡 mas_raros</summary><code>sorted(range(len(puntos)), key=lambda i: (-math.dist(puntos[i], centro), i))[:n]</code></details>

## T10_01 · equidad

<details><summary>🟢 cargar</summary><code>with open(ruta, encoding="utf-8", newline="") as f: return list(csv.DictReader(f))</code> (PYTHON.md §10).</details>
<details><summary>🟢 tasa_seleccion</summary>Filtra con <code>zip(decisiones, grupos)</code> las del grupo g; si la lista queda vacía, <code>return None</code>; si no, <code>.count(favorable) / len(...)</code>.</details>
<details><summary>🟢 ratio_80</summary><code>min(tasas.values()) / max(tasas.values())</code>, con cuidado si el máximo es 0.</details>
<details><summary>🟡 aprobar</summary>Para cada pareja (p, g): el umbral es <code>umbral1</code> si <code>umbral1 is not None and g == "1"</code>; si no, <code>umbral</code>. Compara con <code>&gt;=</code>.</details>
<details><summary>🟡 de_los_que_devuelven / precision</summary>Son la misma cuenta con el filtro al revés: en una te quedas con las posiciones con <code>real_bueno</code> y cuentas los aprobados; en la otra, con las aprobadas y cuentas los buenos.</details>
<details><summary>🔴 informe_umbral</summary>Convierte primero: <code>p = [float(f[puntuacion]) …]</code>, <code>g = [f[grupo] …]</code>, <code>r = [f[real] == bueno …]</code>, y <code>ap = aprobar(p, g, umbral, umbral1)</code>. Para cada grupo de <code>sorted(set(g))</code>, filtra ap y r y rellena las cinco claves reutilizando tus funciones.</details>

## P1_01 · extractor

<details><summary>🟢 extraer_json</summary>Un <code>try: d = json.loads(texto) except json.JSONDecodeError:</code>; en el except, el trozo es <code>texto[texto.find("{"):texto.rfind("}") + 1]</code> (comprueba antes que haya llaves). Al final, <code>isinstance(d, dict)</code>.</details>
<details><summary>🟡 valida</summary>Cuatro condiciones con <code>and</code>: es un dict, <code>set(salida) == set(CAMPOS)</code>, todos los valores <code>isinstance(..., str)</code> y la urgencia está en URGENCIAS. Comprueba primero que es un dict: si es None, lo demás fallaría.</details>
<details><summary>🟡 con_reintentos</summary><code>for i in range(intentos):</code> llama, extrae y, si <code>valida</code>, <code>return s, i + 1</code>. Después del bucle, <code>return None, intentos</code>.</details>
<details><summary>🔴 delimitar</summary><code>"&lt;correo&gt;\n" + correo.replace("&lt;/correo&gt;", "[/correo]") + "\n&lt;/correo&gt;"</code></details>
<details><summary>🔴 id_valido</summary><code>texto.startswith("P-") and len(texto) == 5 and texto[2:].isdigit()</code></details>
<details><summary>🔴 exactitud</summary>Para cada campo: cuántas parejas (s, o) tienen <code>s is not None and s.get(campo) == o[campo]</code>, dividido entre <code>len(oro)</code>. El total es la media de los tres campos.</details>
