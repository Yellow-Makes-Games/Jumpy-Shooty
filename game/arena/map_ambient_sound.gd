class_name MapAmbientSound
extends Node3D
## A quiet sound that belongs to a place and loops for as long as the map is up: a
## room's hum, a crackle, a shimmer (Empyrean Tower's tiers). Put the node where it
## comes from. It is heard within Reach metres, fading with distance, and never over
## the fighting: keep Volume low. The sound is one of the game's own (SfxList), made
## by tools/audio/make_sfx.py as a loop.

## The sound's name in SfxList.
@export var sound := ""
## How far it carries (metres).
@export var reach := 30.0
## Full strength within this many metres.
@export var near := 8.0

var _player: AudioStreamPlayer3D


func _ready() -> void:
	var out := get_node_or_null("/root/Sound")
	if out == null or out.silent or sound == "":
		return
	var stream: AudioStream = out.stream(sound)
	if stream == null:
		return
	stream = stream.duplicate()
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
	_player = AudioStreamPlayer3D.new()
	_player.stream = stream
	_player.bus = out.BUS_SFX
	_player.unit_size = near
	_player.max_distance = reach
	_player.volume_db = SfxList.VOLUME.get(sound, -20.0)
	add_child(_player)
	_player.play(randf() * maxf(stream.get_length() - 0.1, 0.0))
