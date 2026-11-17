extends SceneTree
## The lobby lists the addresses friends can join at: home-network ones and Tailscale's.
## Run: godot --headless --path . --script tests/join_address_test.gd

func _initialize() -> void:
	var lobby: GDScript = load("res://game/ui/lobby_menu.gd")
	var ok := true
	var cases := {
		"192.168.1.20": true, "10.0.0.5": true, "172.16.0.1": true, "172.31.9.9": true,
		"172.32.0.1": false, "100.101.102.103": true, "100.63.0.1": false, "100.128.0.1": false,
		"127.0.0.1": false, "8.8.8.8": false, "fe80::1": false,
	}
	for ip in cases:
		if lobby._is_join_address(ip) != cases[ip]:
			print("FAIL: %s should be %s" % [ip, cases[ip]])
			ok = false
	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)
