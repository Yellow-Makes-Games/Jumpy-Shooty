class_name WeaponState
extends RefCounted
## The local player's copy of a weapon: ammo, fire cooldown and reloading.
## Most guns reload the whole magazine at once. The shotgun loads a shell at a time
## (WeaponData.reload_per_round) and can fire between shells, which stops the reload.

var data: WeaponData
var ammo := 0
var _cooldown := 0.0
var _reload_left := 0.0


func _init(d: WeaponData) -> void:
	data = d
	ammo = d.magazine


func is_reloading() -> bool:
	return _reload_left > 0.0


## How far the reload has got, 0..1: for a shell-by-shell reload, how full the magazine is.
func reload_progress() -> float:
	if not is_reloading():
		return 1.0
	var round_done := 1.0 - _reload_left / data.reload_time
	if data.reload_per_round:
		return clampf((ammo + round_done) / float(data.magazine), 0.0, 1.0)
	return round_done


## The current round (or the whole magazine) being loaded, 0..1: drives the reload animation.
func round_progress() -> float:
	return 1.0 - _reload_left / data.reload_time if is_reloading() else 0.0


func update(delta: float) -> void:
	_cooldown = max(_cooldown - delta, 0.0)
	if _reload_left > 0.0:
		_reload_left -= delta
		if _reload_left <= 0.0:
			if data.reload_per_round:
				ammo += 1
				_reload_left = data.reload_time if ammo < data.magazine else 0.0
			else:
				_reload_left = 0.0
				ammo = data.magazine


## Seconds until the gun can fire again (0 = ready).
func cooldown() -> float:
	return _cooldown


func can_fire() -> bool:
	if data.is_melee():
		return _cooldown <= 0.0   # a blade never runs dry
	if _cooldown > 0.0 or ammo <= 0:
		return false
	return data.reload_per_round or not is_reloading()


## Returns true if a shot was fired. Starts a reload automatically when empty.
func fire() -> bool:
	if not can_fire():
		if ammo <= 0:
			start_reload()
		return false
	if data.is_melee():
		_cooldown = data.fire_interval
		return true
	_reload_left = 0.0   # a shell-by-shell reload stops for the shot
	ammo -= 1
	_cooldown = data.fire_interval
	if ammo <= 0:
		start_reload()
	return true


func start_reload() -> void:
	if data.is_melee() or is_reloading() or ammo >= data.magazine:
		return
	_reload_left = data.reload_time


func reset() -> void:
	ammo = data.magazine
	_cooldown = 0.0
	_reload_left = 0.0
