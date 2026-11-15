class_name WeaponState
extends RefCounted
## The local player's copy of a weapon: ammo, fire cooldown and reloading.

var data: WeaponData
var ammo := 0
var _cooldown := 0.0
var _reload_left := 0.0


func _init(d: WeaponData) -> void:
	data = d
	ammo = d.magazine


func is_reloading() -> bool:
	return _reload_left > 0.0


func reload_progress() -> float:
	return 1.0 - _reload_left / data.reload_time if is_reloading() else 1.0


func update(delta: float) -> void:
	_cooldown = max(_cooldown - delta, 0.0)
	if _reload_left > 0.0:
		_reload_left -= delta
		if _reload_left <= 0.0:
			_reload_left = 0.0
			ammo = data.magazine


func can_fire() -> bool:
	return _cooldown <= 0.0 and ammo > 0 and not is_reloading()


## Returns true if a shot was fired. Starts a reload automatically when empty.
func fire() -> bool:
	if not can_fire():
		if ammo <= 0:
			start_reload()
		return false
	ammo -= 1
	_cooldown = data.fire_interval
	if ammo <= 0:
		start_reload()
	return true


func start_reload() -> void:
	if is_reloading() or ammo >= data.magazine:
		return
	_reload_left = data.reload_time


func reset() -> void:
	ammo = data.magazine
	_cooldown = 0.0
	_reload_left = 0.0
