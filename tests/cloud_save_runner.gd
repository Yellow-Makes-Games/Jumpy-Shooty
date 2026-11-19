extends Node
## The checks for tests/cloud_save_test.gd.

var _fails: Array = []


func run() -> void:
	# The sign-in: RFC 7636's own example, and the browser coming back.
	_expect(Account.pkce_challenge("dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk") == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
		"the PKCE challenge is base64url(SHA-256(verifier)), no padding")
	_expect(Account.parse_callback("GET /callback?code=ab%2Fc&state=1 HTTP/1.1") == {"code": "ab/c", "state": "1"},
		"the code is read from the redirect")
	_expect(Account.parse_callback("GET /callback?error=access_denied&error_description=Nope+then HTTP/1.1").get("error") == "access_denied",
		"so is an error")
	_expect(Account.parse_callback("GET /favicon.ico HTTP/1.1").is_empty(), "anything else is ignored")
	_expect(not Account.available() and not Account.signed_in(), "a headless run never signs in")

	# Progress: nothing earned anywhere is lost, nothing is counted twice.
	var a := {"stats": {"kills": 10, "xp": 900, "wins": 2}, "owned": ["hat:crown"], "sets": {"courses": ["foundry"]},
		"times": {"foundry": 80.0}, "best": {"top_speed": 30.0}, "completed": {"first_blood": 100.0}}
	var b := {"stats": {"kills": 7, "xp": 1500, "deaths": 3}, "owned": ["hat:halo", "hat:crown"], "sets": {"courses": ["sky_ruins"]},
		"times": {"foundry": 75.0, "sky_ruins": 90.0}, "best": {"top_speed": 28.0}, "completed": {"first_blood": 50.0, "win_1": 70.0}}
	var p := CloudSave.merge_progress(a, b)
	_expect(p.stats == {"kills": 10, "xp": 1500, "wins": 2, "deaths": 3, "courses": 2}, "each count keeps the bigger copy (a set's: its size)")
	_expect(p.owned.size() == 2 and "hat:halo" in p.owned, "unlocks are joined")
	_expect(p.sets.courses.size() == 2, "sets are joined")
	_expect(p.times == {"foundry": 75.0, "sky_ruins": 90.0}, "best times keep the quicker")
	_expect(p.best.top_speed == 30.0, "top speed keeps the faster")
	_expect(p.completed == {"first_blood": 50.0, "win_1": 70.0}, "an achievement keeps its earlier date")
	_expect(CloudSave.merge_progress(p, p) == p, "merging a copy with itself changes nothing")

	# The profile: the newer copy wins; custom characters are joined by name.
	var bolt_new := _custom("Sir Bolt", "gold")
	var bolt_old := _custom("Sir Bolt", "red")
	var frog := _custom("Frog Man", "red")
	var old := {"updated_at": 100.0, "player_name": "Old", "custom_characters": [bolt_old, frog], "tracked": ["kills_25"]}
	var new := {"updated_at": 200.0, "player_name": "New", "custom_characters": [bolt_new], "tracked": []}
	var prof := CloudSave.merge_profile(old, new)
	_expect(prof.player_name == "New" and prof.tracked == [], "the newer profile wins")
	_expect(prof.custom_characters == [bolt_new, frog], "custom characters join by name, the newer one's version kept")
	_expect(CloudSave.merge_profile(new, old) == prof, "whichever order they come in")
	_expect(CloudSave.merge({}, {"profile": new}).profile.player_name == "New", "an empty copy (a new account) takes the other")

	# Restoring a cloud copy here.
	var saved := [Settings.player_name, Settings.custom_characters.duplicate(), Settings.character,
		Settings.tracked_achievements.duplicate(), Settings.profile_updated_at, Settings.calling_card, Settings.icon]
	Achievements.reset_for_test()
	Settings.custom_characters.clear()   # (this computer's own characters would join in)
	Settings.adopt_profile(0.0)   # (and its own profile, if changed lately, would be the newer)
	Achievements.add("kills", 3)
	Achievements._toasts.clear()
	var toasts := Achievements._toasts.size()
	var cloud := {"version": 1, "profile": {"updated_at": 5000.0, "player_name": "Cloudy", "character": frog,
		"custom_characters": [frog, "not a character"], "tracked": ["kills_100"], "calling_card": "nope"},
		"progress": {"stats": {"kills": 30, "xp": 2000, "weapons_used": 99}, "sets": {"weapons": ["pistol", "rifle"]},
			"best": {"top_speed": 31.0}, "completed": {"first_blood": 1.0}}}
	var merged := CloudSave.merge(CloudSave.capture(), cloud)
	CloudSave.restore(merged, false)
	_expect(Achievements.stat("kills") == 30 and Achievements.stat("xp") == 2000, "the cloud's bigger counts are taken")
	_expect(Achievements.stat("weapons_used") == 2, "a set's count is its size, whatever the copy says")
	_expect(Achievements.done("kills_25") and Achievements.done("first_blood"), "achievements it reaches are done")
	_expect(Achievements._toasts.size() == toasts, "and not announced again")
	_expect(Achievements.best("top_speed") == 31.0, "top speed comes too")
	_expect(Settings.player_name == "Cloudy" and Settings.character == frog and Settings.custom_characters == [frog],
		"the newer profile is taken, bad characters left out")
	_expect(Settings.calling_card == CallingCard.DEFAULT_CARD, "a card that doesn't exist falls back to the default")
	_expect(Settings.profile_updated_at == 5000.0 and Settings.profile_key() == Settings._profile_key,
		"a profile from the cloud doesn't count as changed here")
	var again := CloudSave.capture()
	_expect(CloudSave.merge(again, merged).progress.stats == again.progress.stats, "a second sync changes nothing")
	Settings.player_name = "Changed"
	_expect(Settings.profile_key() != Settings._profile_key, "changing the name here does count")

	# The Profile page's account panel (drawn by hand: a headless run has no account).
	var page := ProfilePage.new()
	add_child(page)
	page._account = VBoxContainer.new()
	page.add_child(page._account)
	Account._providers = ["google", "discord"]
	page._show_account()
	_expect(page._account.find_child("sign_in_google", true, false) != null and page._account.find_child("sign_in_discord", true, false) != null,
		"signed out: a button for each provider")
	Account.user_id = "u1"
	Account._refresh = "r"
	Account.email = "someone@example.com"
	Account.status = "Synced 12:00"
	page._show_account()
	var who := page._account.find_child("who", true, false) as Label
	_expect(who != null and who.text.ends_with("someone@example.com") and page._account.find_child("sign_out", true, false) != null,
		"signed in: who as, and Sign out")
	Account.user_id = ""
	Account._refresh = ""
	Account.email = ""
	Account.status = ""
	Account._providers = []
	page.queue_free()

	Achievements.reset_for_test()
	Settings.player_name = saved[0]
	Settings.custom_characters.assign(saved[1])
	Settings.character = saved[2]
	Settings.tracked_achievements.assign(saved[3])
	Settings.adopt_profile(saved[4])
	Settings.calling_card = saved[5]
	Settings.icon = saved[6]
	if _fails.is_empty():
		print("PASS: every check passed")
	else:
		print("FAIL:\n  " + "\n  ".join(_fails))
	get_tree().quit(1 if not _fails.is_empty() else 0)


func _custom(char_name: String, paint: String) -> String:
	var c := CustomCharacter.new()
	c.name = char_name
	c.paint = paint
	return Characters.valid(c.to_id())


func _expect(ok: bool, what: String) -> void:
	print("    %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails.append(what)
