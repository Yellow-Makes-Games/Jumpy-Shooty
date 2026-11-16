class_name BotDifficulty
extends RefCounted
## How good a bot is. Every number that separates Easy from Expert lives here.

enum { EASY, NORMAL, HARD, EXPERT }
const NAMES := ["Easy", "Normal", "Hard", "Expert"]

var reaction_time: float     ## seconds before the bot reacts to where you are now
var aim_error: float         ## degrees of wobble in its aim
var turn_speed: float        ## degrees per second it can turn its view
var fire_gap: float          ## seconds it waits between shots, at least
var lead: float              ## 0..1: how well it aims ahead of a moving target
var head_chance: float       ## 0..1: how often it goes for the head
var strafe: float            ## 0..1: how much it dodges side to side while fighting
var jumpiness: float         ## 0..1: how often it jumps (and bunny-hops) in a fight
var slides: bool             ## slides while chasing
var dodge_chance: float      ## 0..1: chance to dive or flip away when it gets hit
var grapples: bool           ## uses the grapple to close distance or reach high ground
var belly_slides: bool       ## holds its dives into a belly slide (Hard and Expert)
var sprint: bool
## What it can notice. It never sees through walls: it has to look at you, hear you
## or be shot by you, and when it loses you it searches where you were.
var view_angle: float        ## degrees either side of where it looks that it can see
var hear_range: float        ## metres it hears gunfire from (through walls too)
var step_range: float        ## metres it hears someone running from (half that if they walk)
var sound_error: float       ## how far off its guess of where a sound came from is, per metre away
var memory: float            ## seconds it keeps hunting someone after it last saw or heard them
var predict: float           ## seconds ahead it guesses where you were running when you broke sight


static func make(level: int) -> BotDifficulty:
	var d := BotDifficulty.new()
	match level:
		EASY:
			d._fill(0.5, 3.5, 200.0, 0.7, 0.6, 0.0, 0.3, 0.05, false, 0.0, false, false)
		NORMAL:
			d._fill(0.35, 3.2, 320.0, 0.36, 0.65, 0.15, 0.6, 0.15, true, 0.15, false, true)
		HARD:
			d._fill(0.22, 2.2, 520.0, 0.24, 0.85, 0.35, 0.85, 0.3, true, 0.4, true, true)
		_:
			d._fill(0.14, 1.2, 800.0, 0.18, 1.0, 0.55, 1.0, 0.45, true, 0.65, true, true)
	d.belly_slides = level >= HARD
	var i := clampi(level, EASY, EXPERT)
	d.view_angle = [50.0, 60.0, 70.0, 80.0][i]
	d.hear_range = [25.0, 35.0, 50.0, 65.0][i]
	d.step_range = [5.0, 7.0, 10.0, 13.0][i]
	d.sound_error = [0.3, 0.22, 0.14, 0.08][i]
	d.memory = [8.0, 11.0, 15.0, 20.0][i]
	d.predict = [0.0, 0.3, 0.6, 0.9][i]
	return d


func _fill(rt: float, err: float, turn: float, gap: float, ld: float, head: float, st: float,
		jump: float, sl: bool, dodge: float, grap: bool, spr: bool) -> void:
	reaction_time = rt
	aim_error = err
	turn_speed = turn
	fire_gap = gap
	lead = ld
	head_chance = head
	strafe = st
	jumpiness = jump
	slides = sl
	dodge_chance = dodge
	grapples = grap
	sprint = spr
