class_name ReasoningSim
extends RefCounted
## T11 · Post-entrenamiento y razonamiento, de verdad y en GDScript (sin dependencias).
## Una «política» sobre un conjunto de problemas con respuesta verificable: logits por
## (problema, respuesta), softmax, y aprendizaje real por:
##   · GRPO (recompensas verificables): muestrea un grupo, premia lo correcto, ventaja = recompensa − media del grupo.
##   · DPO (preferencias directas): sube la elegida y baja la rechazada, sin modelo de premio.
##   · cómputo en inferencia: best-of-N y autoconsistencia (voto de la mayoría).
##   · destilación: un modelo pequeño aprende a imitar la distribución de uno grande.
## Todo con RNG sembrado: los resultados se repiten.


class Policy:
	extends RefCounted
	var logits: Array = []  # [m][k]
	var problems: Array = []

	func setup(p_problems: Array) -> Policy:
		problems = p_problems
		logits = []
		for p: Dictionary in problems:
			var row := []
			for _k in (p["respuestas"] as Array).size():
				row.append(0.0)
			logits.append(row)
		return self

	func probs(m: int) -> Array:
		return ReasoningSim.softmax(logits[m])

	func argmax(m: int) -> int:
		var best := 0
		for k in logits[m].size():
			if logits[m][k] > logits[m][best]:
				best = k
		return best

	## Accuracy por la respuesta más probable (greedy), medida con la verdad.
	func accuracy() -> float:
		var ok := 0
		for m in problems.size():
			ok += int(argmax(m) == int(problems[m]["correcta"]))
		return float(ok) / maxf(problems.size(), 1)

	func sample(m: int, rng: RandomNumberGenerator) -> int:
		var p := probs(m)
		var r := rng.randf()
		var acc := 0.0
		for k in p.size():
			acc += p[k]
			if r <= acc:
				return k
		return p.size() - 1

	func clone() -> Policy:
		var c := Policy.new()
		c.problems = problems
		for row: Array in logits:
			c.logits.append(row.duplicate())
		return c


static func softmax(xs: Array) -> Array:
	var mx := -INF
	for x: float in xs:
		mx = maxf(mx, x)
	var out := []
	var s := 0.0
	for x: float in xs:
		var e := exp(x - mx)
		out.append(e)
		s += e
	for i in out.size():
		out[i] /= maxf(s, 1e-9)
	return out


## Recompensa de una respuesta. verificable: 1 si es la correcta. amañable (gameable): 1 si la
## respuesta lleva la marca de «segura de sí misma», aunque sea falsa.
static func reward(problem: Dictionary, k: int, verifiable: bool) -> float:
	if verifiable:
		return 1.0 if k == int(problem["correcta"]) else 0.0
	# Recompensa amañable: un juez barato que premia la respuesta que SUENA segura (la «hack»),
	# sin comprobar si es cierta. Optimizarla da respuestas seguras y falsas (reward hacking).
	return 1.0 if k == int(problem.get("hack", -1)) else 0.0


## GRPO: por cada problema, un grupo de muestras; ventaja = recompensa − media del grupo;
## se sube el logit de lo que salió mejor que la media. Devuelve la curva de accuracy (verdad).
static func grpo(policy: Policy, steps: int, group: int, lr: float, seed: int, verifiable: bool) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var curve := [policy.accuracy()]
	for _t in steps:
		for m in policy.problems.size():
			var ks := []
			var rs := []
			var mean := 0.0
			for _g in group:
				var k := policy.sample(m, rng)
				var r := reward(policy.problems[m], k, verifiable)
				ks.append(k)
				rs.append(r)
				mean += r
			mean /= maxf(group, 1)
			for i in ks.size():
				policy.logits[m][ks[i]] += lr * (rs[i] - mean)
		curve.append(policy.accuracy())
	return curve


## Accuracy «real» de una política entrenada con recompensa amañable (mide la verdad, no el amaño).
static func true_accuracy(policy: Policy) -> float:
	return policy.accuracy()


## Fracción de respuestas más probables que son el amaño (respuesta segura pero falsa).
static func hack_rate(policy: Policy) -> float:
	var n := 0
	var hacked := 0
	for m in policy.problems.size():
		var h := int(policy.problems[m].get("hack", -1))
		if h >= 0:
			n += 1
			hacked += int(policy.argmax(m) == h)
	return float(hacked) / maxf(n, 1)


## DPO: pares (elegida, rechazada) por problema; sube la elegida, baja la rechazada. Sin premio.
static func dpo(policy: Policy, steps: int, lr: float) -> Array:
	var curve := [policy.accuracy()]
	for _t in steps:
		for m in policy.problems.size():
			var ch := int(policy.problems[m]["correcta"])
			var rej := int(policy.problems[m].get("hack", (ch + 1) % policy.logits[m].size()))
			policy.logits[m][ch] += lr
			policy.logits[m][rej] -= lr
		curve.append(policy.accuracy())
	return curve


## Cómputo en inferencia: muestrea n respuestas por problema y se queda con la más votada
## (autoconsistencia). Devuelve la accuracy con ese presupuesto de muestras.
static func self_consistency(policy: Policy, n: int, seed: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var ok := 0
	for m in policy.problems.size():
		var votes := {}
		for _i in n:
			var k := policy.sample(m, rng)
			votes[k] = int(votes.get(k, 0)) + 1
		var best := -1
		var best_v := -1
		for k: int in votes:
			if votes[k] > best_v:
				best_v = votes[k]
				best = k
		ok += int(best == int(policy.problems[m]["correcta"]))
	return float(ok) / maxf(policy.problems.size(), 1)


## Destilación: el alumno aprende a imitar la distribución del maestro (minimiza la diferencia
## con las probabilidades del maestro, paso a paso). Devuelve la curva de accuracy del alumno.
static func distill(student: Policy, teacher: Policy, steps: int, lr: float) -> Array:
	var curve := [student.accuracy()]
	for _t in steps:
		for m in student.problems.size():
			var tp := teacher.probs(m)
			var sp := student.probs(m)
			for k in student.logits[m].size():
				student.logits[m][k] += lr * (tp[k] - sp[k])
		curve.append(student.accuracy())
	return curve
