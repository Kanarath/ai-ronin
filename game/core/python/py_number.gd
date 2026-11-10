class_name PyNumber
extends RefCounted
## Números del intérprete de Python del Dojo: conversión exacta entre floats y texto.
##
## - float_repr(x): la representación más corta que vuelve al mismo float, con el formato
##   de CPython (0.1 + 0.2 → "0.30000000000000004", 1e16 → "1e+16", 2.0 → "2.0").
## - format_fixed / format_sci / format_general: ".2f", ".3e", "g" redondeando el valor
##   binario EXACTO con mitad-al-par, como CPython (f"{2.675:.2f}" → "2.67").
## - parse_float(texto): lectura correctamente redondeada (el lector del motor se equivoca
##   en el último bit con literales largos, así que lo corregimos con aritmética exacta).
##
## La aritmética exacta usa enteros grandes mínimos (base 10^9) solo para formatear.

const INT_MAX := 9223372036854775807
const INT_MIN := -9223372036854775807 - 1
const _BASE := 1000000000
const _FRAC_MASK := 4503599627370495  # 2^52 - 1
const _HIDDEN_BIT := 4503599627370496  # 2^52
const _ABS_MASK := 9223372036854775807

static var _p10: Array[float] = []


# ── Bits de un double ────────────────────────────────────────────────────────

static func bits_of(x: float) -> int:
	var b := PackedByteArray()
	b.resize(8)
	b.encode_double(0, x)
	return b.decode_s64(0)


static func from_bits(i: int) -> float:
	var b := PackedByteArray()
	b.resize(8)
	b.encode_s64(0, i)
	return b.decode_double(0)


static func is_negative(x: float) -> bool:
	return bits_of(x) < 0


static func copysign(magnitude: float, sign_of: float) -> float:
	var m := absf(magnitude)
	return -m if is_negative(sign_of) else m


## [mantisa, exponente2] de los bits de un double positivo: valor = m * 2^e2.
static func _decompose_bits(bits: int) -> Array[int]:
	var expf := (bits >> 52) & 2047
	var frac := bits & _FRAC_MASK
	if expf == 0:
		return [frac, -1074]
	return [frac | _HIDDEN_BIT, expf - 1075]


# ── Enteros grandes mínimos ──────────────────────────────────────────────────

static func _big_from_int(m: int) -> PackedInt64Array:
	var a := PackedInt64Array()
	if m == 0:
		a.append(0)
	while m > 0:
		a.append(m % _BASE)
		m = m / _BASE
	return a


static func _big_mul_small(a: PackedInt64Array, k: int) -> void:
	var carry := 0
	for i in a.size():
		var v := a[i] * k + carry
		a[i] = v % _BASE
		carry = v / _BASE
	while carry > 0:
		a.append(carry % _BASE)
		carry = carry / _BASE


static func _big_to_str(a: PackedInt64Array) -> String:
	var parts := PackedStringArray()
	var i := a.size() - 1
	parts.append(str(a[i]))
	i -= 1
	while i >= 0:
		parts.append(str(a[i]).lpad(9, "0"))
		i -= 1
	return "".join(parts)


## Valor exacto de m * 2^e2 como [dígitos: String, exp10: int] (valor = dígitos * 10^exp10).
static func exact_decimal(m: int, e2: int) -> Array:
	if m == 0:
		return ["0", 0]
	while m % 2 == 0:
		m = m >> 1
		e2 += 1
	var a := _big_from_int(m)
	if e2 >= 0:
		var e := e2
		while e >= 30:
			_big_mul_small(a, 1 << 30)
			e -= 30
		if e > 0:
			_big_mul_small(a, 1 << e)
		return [_big_to_str(a), 0]
	var n := -e2
	while n >= 13:
		_big_mul_small(a, 1220703125)  # 5^13
		n -= 13
	if n > 0:
		var p := 1
		for _i in n:
			p *= 5
		_big_mul_small(a, p)
	return [_big_to_str(a), e2]


static func exact_of(x: float) -> Array:
	var d := _decompose_bits(bits_of(absf(x)))
	return exact_decimal(d[0], d[1])


# ── Redondeo decimal (mitad al par sobre el valor exacto) ────────────────────

static func _inc_digits(s: String) -> String:
	if s.is_empty():
		return "1"
	var chars := s.to_utf8_buffer()
	var i := chars.size() - 1
	while i >= 0:
		if chars[i] == 57:  # '9'
			chars[i] = 48
			i -= 1
		else:
			chars[i] += 1
			return chars.get_string_from_utf8()
	return "1" + chars.get_string_from_utf8()


## Conserva los `keep` primeros dígitos de `digits` redondeando el resto (mitad al par).
## Devuelve "" si el resultado es cero.
static func round_digits(digits: String, keep: int) -> String:
	if keep >= digits.length():
		return digits + "0".repeat(keep - digits.length())
	if keep < 0:
		return ""
	var head := digits.substr(0, keep)
	var rd := digits.unicode_at(keep) - 48
	var up := false
	if rd > 5:
		up = true
	elif rd == 5:
		var rest_nonzero := false
		for i in range(keep + 1, digits.length()):
			if digits.unicode_at(i) != 48:
				rest_nonzero = true
				break
		if rest_nonzero:
			up = true
		elif not head.is_empty() and (head.unicode_at(head.length() - 1) - 48) % 2 == 1:
			up = true
	if up:
		head = _inc_digits(head)
	return head


# ── Formatos ─────────────────────────────────────────────────────────────────

static func _special(x: float) -> String:
	if is_nan(x):
		return "nan"
	if is_inf(x):
		return "-inf" if x < 0 else "inf"
	return ""


## repr() de un float, idéntico a CPython.
static func float_repr(x: float) -> String:
	var sp := _special(x)
	if not sp.is_empty():
		return sp
	if x == 0.0:
		return "-0.0" if is_negative(x) else "0.0"
	var s := String.num_scientific(absf(x))
	var ex := 0
	var e_pos := s.find("e")
	var mant := s
	if e_pos >= 0:
		mant = s.substr(0, e_pos)
		ex = s.substr(e_pos + 1).to_int()
	var dot := mant.find(".")
	var digits := mant
	var intlen := mant.length()
	if dot >= 0:
		digits = mant.substr(0, dot) + mant.substr(dot + 1)
		intlen = dot
	var pos := intlen + ex
	while digits.length() > 1 and digits.begins_with("0"):
		digits = digits.substr(1)
		pos -= 1
	while digits.length() > 1 and digits.ends_with("0"):
		digits = digits.substr(0, digits.length() - 1)
	if digits.length() >= 16:
		digits = _shortest_digits(absf(x), digits)
		var full := _sig_digits(absf(x), digits.length())
		pos = int(full[1]) + 1
	var out := _place_point(digits, pos, true)
	return ("-" if x < 0 else "") + out


## El motor da casi siempre los dígitos más cortos; con 16-17 cifras comprobamos si
## sobra alguna, redondeando el valor exacto y releyéndolo.
static func _shortest_digits(ax: float, digits: String) -> String:
	var best := digits
	var ok_given := _roundtrips(ax, digits)
	if not ok_given:
		best = _sig_digits(ax, 17)[0]
	for k in range(maxi(1, digits.length() - 2), best.length()):
		var cand: Array = _sig_digits(ax, k)
		if _roundtrips_exp(ax, cand[0], cand[1]):
			best = cand[0]
			break
	while best.length() > 1 and best.ends_with("0"):
		best = best.substr(0, best.length() - 1)
	return best


static func _roundtrips(ax: float, digits: String) -> bool:
	var sd := _sig_digits(ax, digits.length())
	return sd[0] == digits and _roundtrips_exp(ax, sd[0], sd[1])


static func _roundtrips_exp(ax: float, digits: String, exp_first: int) -> bool:
	return _decimal_to_float(digits, exp_first - digits.length() + 1) == ax


## Dígitos significativos + posición del punto → texto estilo repr.
static func _place_point(digits: String, pos: int, repr_style: bool) -> String:
	var x10 := pos - 1
	if not repr_style or (x10 >= -4 and x10 < 16):
		if pos <= 0:
			return "0." + "0".repeat(-pos) + digits
		if pos >= digits.length():
			return digits + "0".repeat(pos - digits.length()) + ".0"
		return digits.substr(0, pos) + "." + digits.substr(pos)
	var m := digits.substr(0, 1)
	if digits.length() > 1:
		m += "." + digits.substr(1)
	return m + _exp_suffix(x10)


static func _exp_suffix(e: int) -> String:
	return "e" + ("-" if e < 0 else "+") + str(absi(e)).lpad(2, "0")


## Formato ".Nf" (sin signo si `with_sign` es false; el llamador lo añade).
static func format_fixed(x: float, prec: int, with_sign: bool = true) -> String:
	var sp := _special(x)
	if not sp.is_empty():
		return sp if with_sign else sp.trim_prefix("-")
	var sign := "-" if (with_sign and is_negative(x)) else ""
	var n := "0"
	if x != 0.0:
		var ex := exact_of(x)
		var d: String = ex[0]
		var shift: int = ex[1] + prec
		if shift >= 0:
			n = d + "0".repeat(shift)
		else:
			n = round_digits(d, d.length() + shift)
			if n.is_empty():
				n = "0"
	if n.length() < prec + 1:
		n = "0".repeat(prec + 1 - n.length()) + n
	var int_part := n.substr(0, n.length() - prec)
	if prec == 0:
		return sign + int_part
	return sign + int_part + "." + n.substr(n.length() - prec)


## [dígitos redondeados a `sig` cifras significativas, exponente decimal del primero].
static func _sig_digits(x: float, sig: int) -> Array:
	if x == 0.0:
		return ["0".repeat(sig), 0]
	var ex := exact_of(x)
	var d: String = ex[0]
	var exp10: int = d.length() - 1 + int(ex[1])
	var n := round_digits(d, sig)
	if n.length() > sig:
		n = n.substr(0, sig)
		exp10 += 1
	return [n, exp10]


## Formato ".Ne".
static func format_sci(x: float, prec: int, with_sign: bool = true) -> String:
	var sp := _special(x)
	if not sp.is_empty():
		return sp if with_sign else sp.trim_prefix("-")
	var sign := "-" if (with_sign and is_negative(x)) else ""
	var sd := _sig_digits(x, prec + 1)
	var n: String = sd[0]
	var m := n.substr(0, 1)
	if prec > 0:
		m += "." + n.substr(1)
	return sign + m + _exp_suffix(sd[1])


## Formato "g" (y el formato sin tipo con precisión si `no_type` es true).
static func format_general(x: float, prec: int, alt: bool = false, with_sign: bool = true, no_type: bool = false) -> String:
	var sp := _special(x)
	if not sp.is_empty():
		return sp if with_sign else sp.trim_prefix("-")
	if prec == 0:
		prec = 1
	var exp10 := 0
	if x != 0.0:
		exp10 = _sig_digits(x, prec)[1]
	var s := ""
	if exp10 >= -4 and exp10 < prec:
		s = format_fixed(x, prec - 1 - exp10, with_sign)
		if not alt and s.contains("."):
			s = s.rstrip("0").trim_suffix(".")
		if no_type and not s.contains("."):
			s += ".0"
	else:
		s = format_sci(x, prec - 1, with_sign)
		if not alt:
			var e_pos := s.find("e")
			var mant := s.substr(0, e_pos)
			if mant.contains("."):
				mant = mant.rstrip("0").trim_suffix(".")
			s = mant + s.substr(e_pos)
	return s


# ── Lectura de floats ────────────────────────────────────────────────────────

static func _pow10_table() -> Array[float]:
	if _p10.is_empty():
		var v := 1.0
		for _i in 23:
			_p10.append(v)
			v *= 10.0
	return _p10


## Lee un float con la sintaxis de float() de Python. Devuelve [ok: bool, valor: float].
static func parse_float(text: String) -> Array:
	var s := text.strip_edges().to_lower()
	var neg := false
	if s.begins_with("+") or s.begins_with("-"):
		neg = s.begins_with("-")
		s = s.substr(1)
	if s in ["inf", "infinity"]:
		return [true, -INF if neg else INF]
	if s == "nan":
		return [true, NAN]
	# mantisa[.frac][e[+-]exp], con '_' entre dígitos
	var digits := ""
	var exp10 := 0
	var i := 0
	var n := s.length()
	var seen_digit := false
	var seen_dot := false
	var prev_digit := false
	while i < n:
		var c := s.unicode_at(i)
		if c >= 48 and c <= 57:
			if seen_dot:
				exp10 -= 1
			digits += s[i]
			seen_digit = true
			prev_digit = true
		elif c == 95:  # '_'
			if not prev_digit or i + 1 >= n or s.unicode_at(i + 1) < 48 or s.unicode_at(i + 1) > 57:
				return [false, 0.0]
			prev_digit = false
		elif c == 46 and not seen_dot:  # '.'
			seen_dot = true
			prev_digit = false
		else:
			break
		i += 1
	if not seen_digit:
		return [false, 0.0]
	if i < n:
		if s[i] != "e":
			return [false, 0.0]
		i += 1
		var eneg := false
		if i < n and (s[i] == "+" or s[i] == "-"):
			eneg = s[i] == "-"
			i += 1
		var edigits := ""
		while i < n and s.unicode_at(i) >= 48 and s.unicode_at(i) <= 57:
			edigits += s[i]
			i += 1
		if edigits.is_empty() or i < n:
			return [false, 0.0]
		var ev := 0
		if edigits.length() > 6:
			ev = 9999999
		else:
			ev = edigits.to_int()
		exp10 += -ev if eneg else ev
	var v := _decimal_to_float(digits, exp10)
	return [true, -v if neg else v]


static func _decimal_to_float(digits: String, exp10: int) -> float:
	# normalizar: sin ceros a la izquierda ni a la derecha
	var a := 0
	while a < digits.length() - 1 and digits.unicode_at(a) == 48:
		a += 1
	digits = digits.substr(a)
	while digits.length() > 1 and digits.ends_with("0"):
		digits = digits.substr(0, digits.length() - 1)
		exp10 += 1
	if digits == "0":
		return 0.0
	var adjusted := digits.length() + exp10
	if adjusted > 310:
		return INF
	if adjusted < -330:
		return 0.0
	var p10 := _pow10_table()
	if digits.length() <= 15:
		var m := float(digits.to_int())
		if exp10 >= 0 and exp10 <= 22:
			return m * p10[exp10]
		if exp10 < 0 and exp10 >= -22:
			return m / p10[-exp10]
		if exp10 > 22 and digits.length() + exp10 - 22 <= 15:
			var mi := digits.to_int()
			for _i in exp10 - 22:
				mi *= 10
			return float(mi) * p10[22]
	# Camino lento: estimación del motor + corrección exacta por puntos medios.
	var lead := digits.substr(0, 1) + "." + digits.substr(1, 19)
	# El lector del motor falla con números diminutos: leemos escalado y corregimos.
	var guess := 0.0
	if adjusted < -250:
		guess = (lead + "e" + str(adjusted - 1 + 300)).to_float() * pow(10.0, -300.0)
	elif adjusted > 250:
		guess = (lead + "e" + str(adjusted - 1 - 300)).to_float() * pow(10.0, 300.0)
	else:
		guess = (lead + "e" + str(adjusted - 1)).to_float()
	var cb := bits_of(absf(guess))
	for _iter in 16:
		if cb >= 9218868437227405312:  # infinito
			var lim := _midpoint(cb - 1, cb)
			if _cmp_dec(digits, exp10, lim[0], lim[1]) >= 0:
				return INF
			cb -= 1
			continue
		var up := _midpoint(cb, cb + 1)
		var c := _cmp_dec(digits, exp10, up[0], up[1])
		if c > 0 or (c == 0 and cb % 2 == 1):
			cb += 1
			continue
		if cb > 0:
			var down := _midpoint(cb - 1, cb)
			c = _cmp_dec(digits, exp10, down[0], down[1])
			if c < 0 or (c == 0 and cb % 2 == 1):
				cb -= 1
				continue
		break
	return from_bits(cb)


static func _midpoint(b1: int, b2: int) -> Array:
	var d1 := _decompose_bits(b1)
	var d2 := _decompose_bits(b2)
	var emin := mini(d1[1], d2[1])
	var total := (d1[0] << (d1[1] - emin)) + (d2[0] << (d2[1] - emin))
	return exact_decimal(total, emin - 1)


static func _cmp_dec(d1: String, e1: int, d2: String, e2: int) -> int:
	while d1.length() > 1 and d1.ends_with("0"):
		d1 = d1.substr(0, d1.length() - 1)
		e1 += 1
	while d2.length() > 1 and d2.ends_with("0"):
		d2 = d2.substr(0, d2.length() - 1)
		e2 += 1
	var z1 := d1 == "0"
	var z2 := d2 == "0"
	if z1 or z2:
		if z1 and z2:
			return 0
		return -1 if z1 else 1
	var a1 := d1.length() + e1
	var a2 := d2.length() + e2
	if a1 != a2:
		return 1 if a1 > a2 else -1
	var n := maxi(d1.length(), d2.length())
	d1 = d1.rpad(n, "0")
	d2 = d2.rpad(n, "0")
	if d1 == d2:
		return 0
	return 1 if d1 > d2 else -1


# ── Enteros ──────────────────────────────────────────────────────────────────

## Lee un entero estilo int(texto, base). Devuelve [estado, valor]:
## estado 0 = ok, 1 = texto no válido, 2 = desbordamiento.
static func parse_int(text: String, base: int = 10) -> Array:
	var s := text.strip_edges().to_lower()
	var neg := false
	if s.begins_with("+") or s.begins_with("-"):
		neg = s.begins_with("-")
		s = s.substr(1)
	if base == 0:
		base = 10
		if s.begins_with("0x"):
			base = 16
		elif s.begins_with("0o"):
			base = 8
		elif s.begins_with("0b"):
			base = 2
		elif s.length() > 1 and s.begins_with("0") and s.replace("0", "").replace("_", "") != "":
			return [1, 0]
	if (base == 16 and s.begins_with("0x")) or (base == 8 and s.begins_with("0o")) or (base == 2 and s.begins_with("0b")):
		s = s.substr(2)
		if s.begins_with("_"):
			s = s.substr(1)
	if s.is_empty() or s.begins_with("_") or s.ends_with("_") or s.contains("__"):
		return [1, 0]
	var r := 0
	for i in s.length():
		var c := s.unicode_at(i)
		if c == 95:
			continue
		var d := -1
		if c >= 48 and c <= 57:
			d = c - 48
		elif c >= 97 and c <= 122:
			d = c - 87
		if d < 0 or d >= base:
			return [1, 0]
		if r > (INT_MAX - d) / base:
			if neg and r == (INT_MAX - d + 1) / base and (INT_MAX - d + 1) % base == 0 and i == s.length() - 1:
				return [0, INT_MIN]
			return [2, 0]
		r = r * base + d
	return [0, -r if neg else r]


## Redondeo de Python: round(x) con mitad al par sobre el valor exacto.
static func round_half_even(x: float) -> float:
	var f := floorf(x)
	var diff := x - f
	if diff > 0.5:
		return f + 1.0
	if diff < 0.5:
		return f
	return f if fmod(f, 2.0) == 0.0 else f + 1.0


## round(x, n) para floats: redondeo exacto a n decimales (n puede ser negativo).
static func round_ndigits(x: float, n: int) -> float:
	if not is_finite(x) or x == 0.0:
		return x
	if n > 330:
		return x
	var ex := exact_of(x)
	var d: String = ex[0]
	var shift: int = int(ex[1]) + n
	var digits := ""
	if shift >= 0:
		return x
	digits = round_digits(d, d.length() + shift)
	if digits.is_empty():
		return copysign(0.0, x)
	var v := _decimal_to_float(digits, -n)
	return -v if x < 0 else v


# ── Potencias ────────────────────────────────────────────────────────────────

## x ** y. Con exponente entero, el pow() del motor se equivoca a menudo en el último bit;
## lo calculamos en doble-double (error ~2^-100) para coincidir con CPython.
static func pow_float(x: float, y: float) -> float:
	var r0 := pow(x, y)
	if y != floorf(y) or absf(y) > 1024.0 or not is_finite(r0) or r0 == 0.0 or absf(r0) > 1e300 			or absf(r0) < 1e-290 or not is_finite(x) or absf(x) > 1e150 or absf(x) < 1e-150:
		return r0
	var n := int(absf(y))
	var hi := 1.0
	var lo := 0.0
	var bh := x
	var bl := 0.0
	while n > 0:
		if n & 1:
			var m := _dd_mul(hi, lo, bh, bl)
			hi = m[0]
			lo = m[1]
		n = n >> 1
		if n > 0:
			var sq := _dd_mul(bh, bl, bh, bl)
			bh = sq[0]
			bl = sq[1]
	if y < 0.0:
		var q1 := 1.0 / hi
		var pe := _two_prod(q1, hi)
		var rem := ((1.0 - pe[0]) - pe[1]) - q1 * lo
		return q1 + rem / hi
	return hi + lo


static func _split(a: float) -> Array[float]:
	var t := 134217729.0 * a
	var hi := t - (t - a)
	return [hi, a - hi]


static func _two_prod(a: float, b: float) -> Array[float]:
	var p := a * b
	var sa := _split(a)
	var sb := _split(b)
	var err := ((sa[0] * sb[0] - p) + sa[0] * sb[1] + sa[1] * sb[0]) + sa[1] * sb[1]
	return [p, err]


static func _dd_mul(ah: float, al: float, bh: float, bl: float) -> Array[float]:
	var pe := _two_prod(ah, bh)
	var e := pe[1] + (ah * bl + al * bh)
	var s := pe[0] + e
	return [s, e - (s - pe[0])]
