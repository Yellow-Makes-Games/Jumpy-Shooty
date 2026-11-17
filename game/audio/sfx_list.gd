class_name SfxList
## Tables for the sound effects, kept apart from the code that plays them so they are
## easy to tune (and the tests can read them without the game running).
## The sounds themselves: game/audio/sfx/, made by tools/audio/make_sfx.py.

## How loud each sound plays, in dB (every file is normalised to the same peak).
const VOLUME := {
	"fire_pistol": -5.0, "fire_rifle": -6.5, "fire_shotgun": -3.5, "fire_sniper": -2.5,
	"far_pistol": -9.0, "far_rifle": -10.0, "far_shotgun": -7.0, "far_sniper": -5.0,
	"equip_pistol": -10.0, "equip_rifle": -10.0, "equip_shotgun": -10.0, "equip_sniper": -10.0,
	"fire_pistol_fp": -5.0, "fire_rifle_fp": -6.5, "fire_shotgun_fp": -3.5, "fire_sniper_fp": -2.5, "dry_click": -10.0,
	"mag_out": -12.0, "mag_in": -11.0, "mag_out_rifle": -12.0, "mag_in_rifle": -11.0,
	"slide_back": -12.0, "slide_fwd": -10.0, "charge_back": -12.0, "charge_fwd": -10.0,
	"pump_back": -9.0, "pump_fwd": -8.0, "shell_in": -11.0,
	"bolt_up": -12.0, "bolt_back": -11.0, "bolt_fwd": -10.0, "bolt_down": -11.0,
	"impact_wall": -11.0, "ricochet": -16.0, "impact_body": -8.0, "whiz": -9.0,
	"hitmarker": -9.0, "hitmarker_head": -7.0, "kill": -5.0, "kill_head": -4.0,
	"hurt": -6.0, "hurt_head": -5.0, "death": -6.0, "respawn": -11.0,
	"step": -15.0, "crawl": -17.0, "jump": -13.0, "land": -11.0, "land_hard": -8.0,
	"flip": -12.0, "dive": -11.0, "roll": -11.0, "slide": -11.0, "belly_slide": -10.0,
	"wall_run": -12.0, "wall_jump": -10.0, "vault": -12.0, "ledge_climb": -11.0,
	"crouch": -18.0, "stand": -18.0,
	"grapple_fire": -10.0, "grapple_attach": -10.0, "grapple_release": -12.0, "grapple_miss": -12.0,
	"ui_hover": -20.0, "ui_click": -12.0, "ui_confirm": -10.0, "ui_back": -12.0,
	"ui_toggle": -13.0, "ui_tick": -20.0, "ui_select": -12.0,
	"match_start": -6.0, "match_end": -6.0,
	"swing_sword": -8.0, "swing_hammer": -7.0, "swing_dagger": -10.0,
	"equip_sword": -10.0, "equip_hammer": -10.0, "equip_dagger": -10.0,
	"melee_hit": -5.0, "hammer_hit": -4.0, "slam": -5.0,
	"kick": -9.0, "flying_kick": -6.0, "rocket_boost": -7.0,
	"break_concrete": -4.0, "break_wood": -5.0, "break_glass": -6.0,
	# The newer weapons
	"fire_revolver": -3.5, "fire_machine_pistol": -6.5, "fire_break_action": -3.0, "fire_smg": -7.0,
	"fire_burst_rifle": -6.0, "fire_lmg": -6.0, "fire_lever_action": -3.5, "fire_bolt_action": -3.0,
	"fire_railgun": -3.0, "fire_rocket_launcher": -3.0, "fire_grenade_launcher": -4.0,
	"far_revolver": -7.0, "far_machine_pistol": -10.0, "far_break_action": -6.5, "far_smg": -10.5,
	"far_burst_rifle": -9.5, "far_lmg": -9.0, "far_lever_action": -6.5, "far_bolt_action": -5.5,
	"far_railgun": -6.0, "far_rocket_launcher": -6.0, "far_grenade_launcher": -8.0,
	"fire_revolver_fp": -3.5, "fire_machine_pistol_fp": -6.5, "fire_break_action_fp": -3.0, "fire_smg_fp": -7.0,
	"fire_burst_rifle_fp": -6.0, "fire_lmg_fp": -6.0, "fire_lever_action_fp": -3.5, "fire_bolt_action_fp": -3.0,
	"fire_railgun_fp": -3.0, "fire_rocket_launcher_fp": -3.0, "fire_grenade_launcher_fp": -4.0,
	"equip_revolver": -10.0, "equip_machine_pistol": -10.0, "equip_break_action": -10.0, "equip_smg": -10.0,
	"equip_burst_rifle": -10.0, "equip_lmg": -10.0, "equip_lever_action": -10.0, "equip_bolt_action": -10.0,
	"equip_railgun": -10.0, "equip_rocket_launcher": -10.0, "equip_grenade_launcher": -10.0,
	"equip_brass_knuckles": -10.0, "equip_spear": -10.0, "equip_axe": -10.0, "equip_bat": -10.0,
	"swing_brass_knuckles": -10.0, "swing_spear": -9.0, "swing_axe": -7.5, "swing_bat": -7.0,
	"bat_hit": -4.0, "punch_hit": -5.0, "explosion": -1.0, "explosion_far": -4.0,
	"cylinder_open": -12.0, "cylinder_close": -10.0, "empties_out": -14.0, "speedloader": -11.0,
	"break_open": -10.0, "break_close": -9.0, "shells_in": -11.0, "lever_down": -10.0, "lever_up": -9.0,
	"cover_open": -11.0, "cover_close": -9.0, "box_out": -11.0, "box_in": -10.0, "cell_out": -11.0,
	"cell_in": -10.0, "rocket_in": -9.0, "drum_turn": -11.0, "grenade_in": -11.0, "rail_vent": -11.0,
}

## Gun handling, in seconds from the start of the clip, matched to the animations
## in tools/robot/weapon_anims.py (each sound's own click lands on the key frame).
const RELOAD_STEPS := {
	"pistol": [[0.24, "mag_out"], [0.785, "mag_in"], [1.0, "slide_back"], [1.095, "slide_fwd"]],
	"rifle": [[0.28, "mag_out_rifle"], [0.945, "mag_in_rifle"], [1.37, "charge_back"], [1.495, "charge_fwd"]],
	"sniper": [[0.28, "mag_out_rifle"], [0.945, "mag_in_rifle"], [1.55, "bolt_up"], [1.63, "bolt_back"],
		[1.82, "bolt_fwd"], [2.02, "bolt_down"]],
	"shotgun": [[0.255, "shell_in"]],   # one shell; repeats until the tube is full
	"revolver": [[0.33, "cylinder_open"], [0.52, "empties_out"], [1.2, "speedloader"], [1.42, "cylinder_close"]],
	"machine_pistol": [[0.26, "mag_out"], [0.845, "mag_in"], [1.077, "slide_back"], [1.18, "slide_fwd"]],
	"break_action": [[0.32, "break_open"], [0.93, "shells_in"], [1.35, "break_close"]],
	"smg": [[0.236, "mag_out_rifle"], [0.796, "mag_in_rifle"], [1.153, "charge_back"], [1.259, "charge_fwd"]],
	"burst_rifle": [[0.295, "mag_out_rifle"], [0.995, "mag_in_rifle"], [1.442, "charge_back"], [1.574, "charge_fwd"]],
	"lmg": [[0.45, "cover_open"], [1.0, "box_out"], [2.15, "box_in"], [2.82, "cover_close"]],
	"lever_action": [[0.26, "shell_in"]],
	"bolt_action": [[0.27, "shell_in"]],
	"railgun": [[0.5, "cell_out"], [1.72, "cell_in"]],
	"rocket_launcher": [[0.8, "rocket_in"]],
	"grenade_launcher": [[0.27, "grenade_in"], [0.42, "drum_turn"]],
}
## After each shot: the shotgun's pump and the sniper's bolt.
const FIRE_STEPS := {
	"shotgun": [[0.17, "pump_back"], [0.315, "pump_fwd"]],
	"sniper": [[0.40, "bolt_up"], [0.44, "bolt_back"], [0.60, "bolt_fwd"], [0.77, "bolt_down"]],
	"lever_action": [[0.10, "lever_down"], [0.30, "lever_up"]],
	"bolt_action": [[0.345, "bolt_up"], [0.38, "bolt_back"], [0.518, "bolt_fwd"], [0.665, "bolt_down"]],
	"railgun": [[0.05, "rail_vent"]],
}
