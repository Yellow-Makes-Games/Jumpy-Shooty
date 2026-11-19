extends Node
## Your optional online account (Supabase): sign in with Google, Discord or another
## provider, and your profile and progress (see CloudSave) are kept in the cloud and
## follow you to any computer. Signed out, everything works exactly as before, saved
## on this computer only. Setting it up: docs/ACCOUNTS.md.
##
##   Account.available()       is there a Supabase project to sign in to (this build)?
##   Account.signed_in()
##   Account.sign_in("google") opens the browser; `changed` fires when it is done
##   Account.sign_out()
##   Account.sync_now()        put this computer's data and the cloud's together
##
## Signing in (OAuth with PKCE, for a desktop game): the browser opens Supabase's sign-in
## page, which sends you back to a small web server this opens on 127.0.0.1 (REDIRECT
## port) with a one-time code; that and a secret only this copy knows are traded for
## your session. The refresh token is kept in user://account.cfg (never the repo), so
## you stay signed in.
##
## Syncing: on sign-in, when the game starts signed in, at the end of every match, and
## a little after your profile or progress changes. Each sync reads the cloud copy,
## merges it with this one (CloudSave.merge), takes the result here and writes it back,
## so two computers never undo each other. Offline, it tries again later.

signal changed            ## signed in or out, or a sync finished: the UI redraws
signal sign_in_failed(why: String)

const CONFIG_FILES := ["user://supabase.cfg", "res://game/online/supabase.cfg"]
const SESSION_FILE := "user://account.cfg"
const TABLE := "player_data"
const REDIRECT_PORT := 47811
const REDIRECT_PATH := "/callback"
const SIGN_IN_TIMEOUT := 180.0   ## seconds to finish signing in in the browser
const SYNC_DELAY := 20.0         ## after a change, wait this long (more changes join in)
const RETRY := 60.0              ## after a failed sync
const PROVIDER_NAMES := {"google": "Google", "discord": "Discord", "github": "GitHub", "apple": "Apple",
	"twitch": "Twitch", "azure": "Microsoft", "gitlab": "GitLab", "steam": "Steam"}

## "", "signing_in", "syncing"
var busy := ""
var status := ""          ## a line for the UI: the last thing that went wrong, or when it last synced
var email := ""
var user_id := ""
var provider := ""

var _url := ""
var _key := ""
var _providers: Array = []
var _access := ""
var _refresh := ""
var _expires_at := 0.0
var _verifier := ""
var _server: TCPServer
var _peers: Array = []
var _sign_in_left := 0.0
var _sync_in := -1.0       ## seconds to the next sync; -1 none due
var _restoring := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_read_config()
	if not available():
		return
	_load_session()
	Settings.saved.connect(_on_local_change)
	Achievements.progressed.connect(_on_local_change)
	Match.match_over.connect(func(_r): if signed_in(): sync_now())
	if _refresh != "":
		_start_session.call_deferred()


## There is a Supabase project to sign in to: a config file with its URL and public
## (anon) key (docs/ACCOUNTS.md), and this is not a headless test run.
func available() -> bool:
	return _url != "" and _key != "" and DisplayServer.get_name() != "headless" and not DevArgs.scripted_input


func signed_in() -> bool:
	return user_id != "" and _refresh != ""


## The sign-in providers this project has turned on: [[id, name]].
func providers() -> Array:
	var out := []
	for p in _providers:
		out.append([p, PROVIDER_NAMES.get(p, str(p).capitalize())])
	return out


# ---------------------------------------------------------------------------
# Signing in and out

func sign_in(with: String) -> void:
	if not available() or busy == "signing_in":
		return
	_stop_server()
	_server = TCPServer.new()
	if _server.listen(REDIRECT_PORT, "127.0.0.1") != OK:
		_server = null
		_fail("Could not listen on port %d for the sign-in. Is another copy of the game signing in?" % REDIRECT_PORT)
		return
	_verifier = _random_string(64)
	var query := {
		"provider": with,
		"redirect_to": redirect_url(),
		"code_challenge": pkce_challenge(_verifier),
		"code_challenge_method": "s256",
	}
	provider = with
	busy = "signing_in"
	status = "Finish signing in in your browser..."
	_sign_in_left = SIGN_IN_TIMEOUT
	OS.shell_open("%s/auth/v1/authorize?%s" % [_url, _query_string(query)])
	changed.emit()


func cancel_sign_in() -> void:
	if busy == "signing_in":
		_stop_server()
		busy = ""
		status = ""
		changed.emit()


## Sign out: the session is ended on the server and forgotten here. What you have on
## this computer stays.
func sign_out() -> void:
	if _access != "":
		_request(HTTPClient.METHOD_POST, "/auth/v1/logout", "", true)   # (not waited on)
	_access = ""
	_refresh = ""
	user_id = ""
	email = ""
	_sync_in = -1.0
	status = ""
	_save_session()
	changed.emit()


static func redirect_url() -> String:
	return "http://127.0.0.1:%d%s" % [REDIRECT_PORT, REDIRECT_PATH]


## PKCE: the challenge sent with the sign-in is the SHA-256 of a secret (the verifier),
## base64url without padding. Only this copy knows the verifier, so only it can trade
## the code the browser brings back for a session.
static func pkce_challenge(verifier: String) -> String:
	return base64url(verifier.sha256_buffer())


static func base64url(bytes: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(bytes).replace("+", "-").replace("/", "_").trim_suffix("=").trim_suffix("=")


## The code (or error) in the first line of a request to the redirect server:
## "GET /callback?code=abc HTTP/1.1" -> {"code": "abc"}.
static func parse_callback(request_line: String) -> Dictionary:
	var parts := request_line.split(" ")
	if parts.size() < 2 or not parts[1].begins_with(REDIRECT_PATH):
		return {}
	var out := {}
	var q := parts[1].get_slice("?", 1) if "?" in parts[1] else ""
	for pair in q.split("&", false):
		out[pair.get_slice("=", 0).uri_decode()] = pair.get_slice("=", 1).uri_decode() if "=" in pair else ""
	return out


func _process(delta: float) -> void:
	if _server:
		_sign_in_left -= delta
		if _sign_in_left <= 0.0:
			_stop_server()
			_fail("Signing in took too long. Try again.")
		else:
			_poll_server()
	if _sync_in >= 0.0 and busy == "":
		_sync_in -= delta
		if _sync_in < 0.0:
			sync_now()


func _poll_server() -> void:
	while _server and _server.is_connection_available():
		_peers.append({"peer": _server.take_connection(), "text": ""})
	for p in _peers.duplicate():
		var peer: StreamPeerTCP = p.peer
		peer.poll()
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			_peers.erase(p)
			continue
		var n := peer.get_available_bytes()
		if n > 0:
			p.text += peer.get_utf8_string(n)
		if not "\r\n\r\n" in p.text:
			continue
		var got := parse_callback(p.text.get_slice("\r\n", 0))
		_peers.erase(p)
		if not got.has("code") and not got.has("error"):
			_reply(peer, 404, "Not here.")   # (a browser asking for the favicon, say)
			continue
		if got.has("error"):
			_reply(peer, 200, "Sign-in was cancelled. You can close this tab and go back to Jumpy Shooty.")
			_stop_server()
			_fail(str(got.get("error_description", got.error)).replace("+", " "))
			return
		_reply(peer, 200, "Signed in! You can close this tab and go back to Jumpy Shooty.")
		_stop_server()
		_exchange(str(got.code))
		return


func _reply(peer: StreamPeerTCP, code: int, text: String) -> void:
	var body := ("<!doctype html><meta charset=utf-8><title>Jumpy Shooty</title>"
		+ "<body style='background:#0b1220;color:#fff;font:20px sans-serif;display:grid;place-items:center;height:90vh'>"
		+ "<p>%s</p>" % text)
	var head := "HTTP/1.1 %d %s\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % [
		code, "OK" if code == 200 else "Not Found", body.to_utf8_buffer().size()]
	peer.put_data((head + body).to_utf8_buffer())
	peer.disconnect_from_host()


func _stop_server() -> void:
	if _server:
		_server.stop()
		_server = null
	_peers.clear()


func _exchange(code: String) -> void:
	busy = "signing_in"
	status = "Signing in..."
	changed.emit()
	var r := await _request(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=pkce",
		JSON.stringify({"auth_code": code, "code_verifier": _verifier}), false)
	_verifier = ""
	if r.code != 200 or not r.data is Dictionary:
		_fail("Sign-in failed (%s)." % _error_text(r))
		return
	_take_session(r.data)
	busy = ""
	await sync_now()


## Starting the game signed in: trade the saved refresh token for a fresh session.
func _start_session() -> void:
	if await _refresh_session():
		await sync_now()


func _refresh_session() -> bool:
	var r := await _request(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=refresh_token",
		JSON.stringify({"refresh_token": _refresh}), false)
	if r.code == 200 and r.data is Dictionary:
		_take_session(r.data)
		return true
	if r.code >= 400 and r.code < 500:   # the session was ended (signed out elsewhere, or too old)
		status = "Your session ran out. Sign in again."
		sign_out()
		status = "Your session ran out. Sign in again."
		changed.emit()
	else:
		status = "Offline: your progress is saved here and will sync later."
		_sync_in = RETRY
		changed.emit()
	return false


func _take_session(d: Dictionary) -> void:
	_access = str(d.get("access_token", ""))
	_refresh = str(d.get("refresh_token", _refresh))
	_expires_at = Time.get_unix_time_from_system() + float(d.get("expires_in", 3600))
	var user: Dictionary = d.get("user", {}) if d.get("user") is Dictionary else {}
	user_id = str(user.get("id", user_id))
	email = str(user.get("email", email))
	var app: Dictionary = user.get("app_metadata", {}) if user.get("app_metadata") is Dictionary else {}
	provider = str(app.get("provider", provider))
	_save_session()
	changed.emit()


func _fail(why: String) -> void:
	busy = ""
	status = why
	push_warning("[account] " + why)
	sign_in_failed.emit(why)
	changed.emit()


# ---------------------------------------------------------------------------
# Syncing

func _on_local_change(_a = null) -> void:
	if signed_in() and not _restoring and _sync_in < 0.0:
		_sync_in = SYNC_DELAY


## Read the cloud copy, merge it with this computer's, take the result here and write
## it back. True if it all went through.
func sync_now() -> bool:
	if not signed_in() or busy != "":
		return false
	busy = "syncing"
	_sync_in = -1.0
	changed.emit()
	var ok := await _sync()
	busy = ""
	if ok:
		status = "Synced " + Time.get_time_string_from_system().left(5)
	else:
		_sync_in = RETRY
	changed.emit()
	return ok


func _sync() -> bool:
	if Time.get_unix_time_from_system() > _expires_at - 60.0 and not await _refresh_session():
		return false
	var r := await _request(HTTPClient.METHOD_GET, "/rest/v1/%s?select=data&user_id=eq.%s" % [TABLE, user_id], "", true)
	if r.code != 200 or not r.data is Array:
		status = "Couldn't reach your account (%s). Will try again." % _error_text(r)
		return false
	var cloud: Dictionary = {}
	if not r.data.is_empty() and r.data[0] is Dictionary and r.data[0].get("data") is Dictionary:
		cloud = r.data[0].data
	var merged := CloudSave.merge(CloudSave.capture(), cloud)
	_restoring = true
	CloudSave.restore(merged)
	_restoring = false
	var w := await _request(HTTPClient.METHOD_POST, "/rest/v1/%s?on_conflict=user_id" % TABLE,
		JSON.stringify({"user_id": user_id, "data": CloudSave.capture()}), true,
		["Prefer: resolution=merge-duplicates,return=minimal"])
	if w.code < 200 or w.code >= 300:
		status = "Couldn't save to your account (%s). Will try again." % _error_text(w)
		return false
	return true


# ---------------------------------------------------------------------------
# HTTP

## One request to Supabase. {code, data}: code 0 if it never got there.
func _request(method: int, path: String, body: String, authed: bool, extra: Array = []) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 20.0
	add_child(http)
	var headers := ["apikey: " + _key, "Content-Type: application/json"]
	if authed and _access != "":
		headers.append("Authorization: Bearer " + _access)
	headers.append_array(extra)
	if http.request(_url + path, PackedStringArray(headers), method, body) != OK:
		http.queue_free()
		return {"code": 0, "data": null}
	var res: Array = await http.request_completed
	http.queue_free()
	var text := (res[3] as PackedByteArray).get_string_from_utf8()
	return {"code": int(res[1]) if int(res[0]) == HTTPRequest.RESULT_SUCCESS else 0,
		"data": JSON.parse_string(text) if text != "" else null}


static func _error_text(r: Dictionary) -> String:
	if int(r.code) == 0:
		return "no connection"
	if r.data is Dictionary:
		for k in ["error_description", "msg", "message", "error"]:
			if r.data.has(k):
				return "%d: %s" % [r.code, r.data[k]]
	return "error %d" % r.code


static func _query_string(q: Dictionary) -> String:
	var parts := []
	for k in q:
		parts.append("%s=%s" % [str(k).uri_encode(), str(q[k]).uri_encode()])
	return "&".join(parts)


static func _random_string(n: int) -> String:
	const CHARS := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
	var crypto := Crypto.new()
	var bytes := crypto.generate_random_bytes(n)
	var out := ""
	for b in bytes:
		out += CHARS[b % CHARS.length()]
	return out


# ---------------------------------------------------------------------------
# Files

func _read_config() -> void:
	for path in CONFIG_FILES:
		var cfg := ConfigFile.new()
		if cfg.load(path) == OK:
			_url = str(cfg.get_value("supabase", "url", "")).strip_edges().trim_suffix("/")
			_key = str(cfg.get_value("supabase", "anon_key", "")).strip_edges()
			var list = cfg.get_value("supabase", "providers", ["google"])
			_providers = list if list is Array else ["google"]
			if _url != "" and _key != "":
				return
	_url = ""
	_key = ""


func _load_session() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SESSION_FILE) != OK:
		return
	if str(cfg.get_value("account", "url", "")) != _url:   # another project's session
		return
	_refresh = str(cfg.get_value("account", "refresh_token", ""))
	user_id = str(cfg.get_value("account", "user_id", ""))
	email = str(cfg.get_value("account", "email", ""))
	provider = str(cfg.get_value("account", "provider", ""))


func _save_session() -> void:
	if _refresh == "":
		if FileAccess.file_exists(SESSION_FILE):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_FILE))
		return
	var cfg := ConfigFile.new()
	cfg.set_value("account", "url", _url)
	cfg.set_value("account", "refresh_token", _refresh)
	cfg.set_value("account", "user_id", user_id)
	cfg.set_value("account", "email", email)
	cfg.set_value("account", "provider", provider)
	cfg.save(SESSION_FILE)
