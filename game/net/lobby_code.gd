class_name LobbyCode
## Lobby codes: what friends type to join a lobby, instead of the host's IP address.
##
## There is no server that hands out codes. The code IS the host's address: its IPv4
## address and port, written in 32 letters and digits that are easy to read aloud
## (no 0, O, 1 or I), with a check on the end so a typo is caught instead of
## connecting somewhere wrong.
##
##   On the usual port (24680): 8 characters, shown as ABCD-EFGH.
##     1 bit "long" flag (0), 32 bits address, 7 bits check (CRC-7).
##   On any other port: 12 characters, shown as ABCD-EFGH-JKLM.
##     1 bit "long" flag (1), 32 bits address, 16 bits port, 11 bits check (CRC-11).
##
## A CRC of n bits catches every run of up to n wrong bits, and one mistyped
## character is a run of at most 5, so any single wrong character is always caught.
## Two neighbours swapped are caught too (checked by tests/lobby_code_test.gd). Other
## mistakes slip through only 1 time in 128 (short) or 2048 (long).
##
## Typing an address (with a dot or colon, or "localhost") still works, for LAN and
## development use; parse() tells the two apart.

const ALPHABET := "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"
const DEFAULT_PORT := 24680   # Net.DEFAULT_PORT (Net is an autoload; this file stands alone)
const SHORT_LEN := 8
const LONG_LEN := 12
const _CRC7 := 0x09     # x^7 + x^3 + 1
const _CRC11 := 0x385   # x^11 + x^9 + x^8 + x^7 + x^2 + 1


## The code for a host at `ip` (IPv4, like "203.0.113.7") on `port`, with dashes every
## four characters. "" if `ip` isn't an IPv4 address or `port` is out of range.
static func encode(ip: String, port: int = DEFAULT_PORT) -> String:
	var addr := _ip_to_int(ip)
	if addr < 0 or port < 1 or port > 65535:
		return ""
	var raw := ""
	if port == DEFAULT_PORT:
		raw = _to_chars((addr << 7) | _crc(addr, 33, _CRC7, 7), SHORT_LEN)
	else:
		var payload := (1 << 48) | (addr << 16) | port
		raw = _to_chars((payload << 11) | _crc(payload, 49, _CRC11, 11), LONG_LEN)
	return _with_dashes(raw)


## What the player typed in the Join box (or --join=), read as a lobby code or, failing
## that, an address. Returns {"host": String, "port": int, "error": String}: when
## "error" isn't "", it says what is wrong in words for the player.
static func parse(text: String) -> Dictionary:
	var t := text.strip_edges()
	if t == "":
		return _fail("Type the lobby code the host's lobby shows.")
	if "." in t or ":" in t or t.to_lower() == "localhost":
		return _parse_address(t)
	return decode(t)


## Reads a lobby code (any case; spaces and dashes are ignored).
static func decode(code: String) -> Dictionary:
	var t := code.to_upper().replace("-", "").replace(" ", "").replace("_", "")
	for c in t:
		if c in "0O1I":
			return _fail("Lobby codes never use 0, O, 1 or I. Check the code with the host.")
		if not c in ALPHABET:
			return _fail("\"%s\" is not in lobby codes. Check the code with the host." % c)
	if t.length() != SHORT_LEN and t.length() != LONG_LEN:
		return _fail("A lobby code has %d characters (or %d); that one has %d." % [SHORT_LEN, LONG_LEN, t.length()])
	var v := 0
	for c in t:
		v = (v << 5) | ALPHABET.find(c)
	var long := t.length() == LONG_LEN
	if (v >> (t.length() * 5 - 1)) != int(long):
		return _fail("That lobby code has a typo. Check it with the host.")
	var host := ""
	var port := DEFAULT_PORT
	if long:
		var payload := v >> 11
		if _crc(payload, 49, _CRC11, 11) != v & 0x7FF:
			return _fail("That lobby code has a typo. Check it with the host.")
		host = _int_to_ip((payload >> 16) & 0xFFFFFFFF)
		port = payload & 0xFFFF
	else:
		var addr := v >> 7
		if _crc(addr, 33, _CRC7, 7) != v & 0x7F:
			return _fail("That lobby code has a typo. Check it with the host.")
		host = _int_to_ip(addr)
	if port == 0:
		return _fail("That lobby code has a typo. Check it with the host.")
	return {"host": host, "port": port, "error": ""}


static func _parse_address(t: String) -> Dictionary:
	var host := t
	var port := DEFAULT_PORT
	if t.count(":") == 1:   # host:port (more colons would be IPv6, passed on as it is)
		host = t.get_slice(":", 0)
		var p := t.get_slice(":", 1)
		if not p.is_valid_int() or int(p) < 1 or int(p) > 65535:
			return _fail("\"%s\" is not a port. An address looks like 192.168.1.20 or 192.168.1.20:24680." % p)
		port = int(p)
	if host == "":
		host = "127.0.0.1"
	return {"host": host, "port": port, "error": ""}


static func _fail(why: String) -> Dictionary:
	return {"host": "", "port": 0, "error": why}


## The remainder of `value` (`bits` long) times x^r, divided by the polynomial x^r + poly.
static func _crc(value: int, bits: int, poly: int, r: int) -> int:
	var reg := value << r
	var full := (1 << r) | poly
	for i in range(bits + r - 1, r - 1, -1):
		if reg & (1 << i):
			reg ^= full << (i - r)
	return reg & ((1 << r) - 1)


static func _to_chars(v: int, length: int) -> String:
	var s := ""
	for i in range(length - 1, -1, -1):
		s += ALPHABET[(v >> (i * 5)) & 31]
	return s


static func _with_dashes(raw: String) -> String:
	var parts: PackedStringArray = []
	for i in range(0, raw.length(), 4):
		parts.append(raw.substr(i, 4))
	return "-".join(parts)


static func _ip_to_int(ip: String) -> int:
	var p := ip.strip_edges().split(".")
	if p.size() != 4:
		return -1
	var v := 0
	for part in p:
		if not part.is_valid_int() or int(part) < 0 or int(part) > 255:
			return -1
		v = (v << 8) | int(part)
	return v


static func _int_to_ip(v: int) -> String:
	return "%d.%d.%d.%d" % [(v >> 24) & 255, (v >> 16) & 255, (v >> 8) & 255, v & 255]
