extends SceneTree
## Lobby codes (LobbyCode): what friends type to join instead of the host's IP.
## Run: godot --headless --path . --script tests/lobby_code_test.gd
##
## Codes round-trip (address and port) for many addresses and ports; the usual port
## gives 8 characters and others 12; codes never use 0, O, 1 or I; any case, spaces
## and dashes are fine; every single mistyped character is caught, and every swap
## of two neighbours too; wrong lengths and characters get a clear
## message; and an address (with or without a port, or localhost) still works.

var _ok := true


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 24680
	var cases: Array = [["127.0.0.1", 24680], ["192.168.1.20", 24680], ["0.0.0.0", 24680],
		["255.255.255.255", 24680], ["203.0.113.7", 24681], ["10.0.0.5", 1], ["8.8.8.8", 65535]]
	for i in 300:
		var ip := "%d.%d.%d.%d" % [rng.randi_range(0, 255), rng.randi_range(0, 255), rng.randi_range(0, 255), rng.randi_range(0, 255)]
		cases.append([ip, 24680 if i % 2 == 0 else rng.randi_range(1, 65535)])
	var round_trip := true
	var shape := true
	var clean := true
	for c in cases:
		var code := LobbyCode.encode(c[0], c[1])
		var back := LobbyCode.parse(code)
		round_trip = round_trip and back.error == "" and back.host == c[0] and back.port == c[1]
		var want := 9 if c[1] == 24680 else 14   # with the dashes
		shape = shape and code.length() == want and code.replace("-", "").length() == want - want / 5
		for ch in "0O1I":
			clean = clean and not ch in code
	_check(round_trip, "every code gives back its address and port")
	_check(shape, "the usual port gives ABCD-EFGH, others ABCD-EFGH-JKLM")
	_check(clean, "codes never use 0, O, 1 or I")

	var code := LobbyCode.encode("192.168.1.20")
	_check(LobbyCode.parse(code.to_lower()).host == "192.168.1.20", "lower case works")
	_check(LobbyCode.parse(" " + code.replace("-", " ") + " ").host == "192.168.1.20", "spaces instead of dashes work")
	_check(LobbyCode.parse(code.replace("-", "")).host == "192.168.1.20", "no dash works")

	# Every single wrong character, in short and long codes, is caught.
	var caught := true
	for c in [["192.168.1.20", 24680], ["203.0.113.7", 24680], ["203.0.113.7", 30000], ["10.0.0.5", 1]]:
		var raw := LobbyCode.encode(c[0], c[1]).replace("-", "")
		for pos in raw.length():
			for ch in LobbyCode.ALPHABET:
				if ch == raw[pos]:
					continue
				var typo := raw.substr(0, pos) + ch + raw.substr(pos + 1)
				if LobbyCode.decode(typo).error == "":
					caught = false
					print("  missed typo %s -> %s" % [raw, typo])
	_check(caught, "every single mistyped character is caught")
	var swaps := true
	var tried := 0
	for c in cases:
		var raw := LobbyCode.encode(c[0], c[1]).replace("-", "")
		for pos in raw.length() - 1:
			if raw[pos] == raw[pos + 1]:
				continue
			var swapped := raw.substr(0, pos) + raw[pos + 1] + raw[pos] + raw.substr(pos + 2)
			tried += 1
			if LobbyCode.decode(swapped).error == "":
				swaps = false
				print("  missed swap %s -> %s" % [raw, swapped])
	_check(swaps and tried > 2000, "every swap of two neighbours is caught (%d tried)" % tried)

	_check("0, O, 1 or I" in LobbyCode.parse("ABCD-EFG0").error, "a 0 gets its own message")
	_check("8 characters" in LobbyCode.parse("ABCD-EFG").error, "a short code says how long codes are")
	_check("8 characters" in LobbyCode.parse(code + "A").error, "a code too long says so")
	_check("is not in lobby codes" in LobbyCode.parse("ABCD-EF#H").error, "a stray symbol is named")
	_check(LobbyCode.parse("").error != "", "an empty box asks for a code")
	_check(LobbyCode.encode("not-an-ip") == "" and LobbyCode.encode("::1") == "" and LobbyCode.encode("1.2.3.4", 0) == "", "no code for a bad address or port")

	# Addresses still work (LAN, development, the networked tests' --join=127.0.0.1:PORT).
	var a := LobbyCode.parse("127.0.0.1:24681")
	_check(a.error == "" and a.host == "127.0.0.1" and a.port == 24681, "an address with a port works")
	a = LobbyCode.parse("192.168.1.20")
	_check(a.error == "" and a.host == "192.168.1.20" and a.port == 24680, "an address alone uses the usual port")
	a = LobbyCode.parse("localhost")
	_check(a.error == "" and a.host == "localhost" and a.port == 24680, "localhost works")
	a = LobbyCode.parse(":24690")
	_check(a.error == "" and a.host == "127.0.0.1" and a.port == 24690, "a port alone means this PC")
	_check(LobbyCode.parse("127.0.0.1:abc").error != "", "a bad port is refused")

	print("LOBBY CODE TEST: %s" % ("PASS" if _ok else "FAIL"))
	quit(0 if _ok else 1)


func _check(cond: bool, what: String) -> void:
	print("  %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		_ok = false
