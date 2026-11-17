class_name KillcamOverlay
## What is drawn over a killcam (see KillcamView): thin letterbox bars, whose view it
## is, the weapon and what made the kill special, a bar along the clip with a mark at
## the kill, and "ELIMINATED" as the blow lands. Used by the HUD (the death killcam)
## and the results screen (the match's best kills), in the HUD's style (HudStyle).

const BAR := 0.075   ## letterbox bars, as a share of the height


## r: where the killcam is on screen. view: the KillcamView playing. footer: a hint in
## the bottom right ("SPACE  SKIP"), or "". title: what is shown top left ("KILLCAM").
static func draw(ci: CanvasItem, r: Rect2, view: KillcamView, title: String, footer: String, small: bool = false) -> void:
	if view == null or view.clip == null:
		return
	var clip := view.clip
	var info := clip.info
	var k := 0.8 if small else 1.0   # text sizes on the results screen's smaller screen
	var bar := roundf(r.size.y * BAR)
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, bar)), Color(0, 0, 0, 0.85))
	ci.draw_rect(Rect2(r.position + Vector2(0, r.size.y - bar), Vector2(r.size.x, bar)), Color(0, 0, 0, 0.85))
	var pad := 24.0 * k + 8.0
	var x := r.position.x + pad
	var y := r.position.y + bar + 30.0 * k + 6.0
	var killer := int(clip.killer)
	var track: KillClip.Track = clip.tracks.get(killer)
	var color: Color = track.color if track else Net.player_color(killer)
	var killer_name: String = track.name if track else Net.player_name(killer)
	var victim_track: KillClip.Track = clip.tracks.get(int(clip.victim))
	var victim_name: String = victim_track.name if victim_track else Net.player_name(int(clip.victim))
	var weapon := str(info.get("weapon", ""))
	var with := "%s  ·  on %s" % ["Bare feet" if weapon in ["kick", "none"] else WeaponData.name_of(weapon), victim_name]
	var tags := KillScore.tag_words(int(info.get("tags", 0)), int(info.get("streak", 0)), float(info.get("distance", 0.0)))
	# A dark plate behind the words, so they read over a bright wall or sky.
	var block := maxf(HudStyle.text_width(killer_name, int(32 * k)), HudStyle.text_width(with, int(15 * k), false))
	var chips := 0.0
	for chip in tags:
		chips += HudStyle.text_width(chip, int(12 * k)) + 18.0 * k + 6.0
	var spaced := HudStyle.font_spaced()
	var top := 20.0 * k + spaced.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * k)).x
	if not small:
		top += 14.0 * k + spaced.get_string_size("THROUGH THEIR EYES", HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * k)).x
	block = minf(maxf(maxf(maxf(block, chips), top), 240.0 * k), r.size.x - pad * 2.0)
	var plate_h := (34.0 + 30.0 + 28.0 + (24.0 if not tags.is_empty() else 0.0)) * k + 12.0
	ci.draw_rect(Rect2(x - 14.0 * k, y - 18.0 * k, block + 28.0 * k, plate_h), Color(0.02, 0.03, 0.05, 0.5))
	ci.draw_rect(Rect2(x - 14.0 * k, y - 18.0 * k, 3.0, plate_h), color)
	# A red dot that blinks, like a recording.
	var blink := fmod(Time.get_ticks_msec() / 1000.0, 1.0) < 0.6
	ci.draw_circle(Vector2(x + 6.0 * k, y), 6.0 * k, Color(HudStyle.RED, 1.0 if blink else 0.35))
	var w := HudStyle.label(ci, Vector2(x + 20.0 * k, y), title, int(14 * k), HudStyle.RED)
	if not small:
		HudStyle.label(ci, Vector2(x + 34.0 * k + w, y), "THROUGH THEIR EYES", int(11 * k), Color(1, 1, 1, 0.6))
	y += 34.0 * k
	HudStyle.text(ci, Vector2(x, y), killer_name, int(32 * k), color.lightened(0.3))
	y += 30.0 * k
	HudStyle.text(ci, Vector2(x, y), with, int(15 * k), Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_LEFT, false)
	y += 28.0 * k
	var cx := x
	for chip in tags:
		var size := int(12 * k)
		var cw := HudStyle.text_width(chip, size) + 18.0 * k
		if cx + cw > r.end.x - pad:
			break
		var gold: bool = chip == "HEADSHOT" or chip.ends_with("KILL")
		HudStyle.plate(ci, Rect2(cx, y - 12.0 * k, cw, 24.0 * k), 6.0, Color(1, 1, 1, 0.12) if not gold else Color(HudStyle.YELLOW, 0.2))
		HudStyle.text(ci, Vector2(cx + 9.0 * k, y), chip, size, HudStyle.YELLOW if gold else Color(1, 1, 1, 0.9))
		cx += cw + 6.0
	# The clip's progress, with a mark where the kill is.
	var line := Rect2(r.position.x + pad, r.end.y - bar - 22.0 * k - 6.0, r.size.x - pad * 2.0, 4.0)
	ci.draw_rect(line, Color(1, 1, 1, 0.18))
	ci.draw_rect(Rect2(line.position, Vector2(line.size.x * view.progress(), line.size.y)), HudStyle.ORANGE)
	var at := clampf((clip.kill_time - clip.start) / maxf(clip.end - clip.start, 0.01), 0.0, 1.0)
	ci.draw_rect(Rect2(line.position.x + line.size.x * at - 1.5, line.position.y - 5.0, 3.0, line.size.y + 10.0), HudStyle.RED)
	if footer != "":
		HudStyle.label(ci, Vector2(line.end.x, line.position.y - 16.0 * k), footer, int(12 * k), Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_RIGHT)
	# The blow lands.
	var since := view.time - clip.kill_time
	if since >= 0.0 and since < 1.6:
		var a := clampf((1.6 - since) / 0.4, 0.0, 1.0)
		var c := r.position + r.size * 0.5
		var w1 := HudStyle.text_width("ELIMINATED  ", int(24 * k))
		var total := w1 + HudStyle.text_width(victim_name, int(24 * k))
		HudStyle.text(ci, Vector2(c.x - total * 0.5, c.y + 90.0 * k), "ELIMINATED", int(24 * k), Color(HudStyle.RED, a))
		HudStyle.text(ci, Vector2(c.x - total * 0.5 + w1, c.y + 90.0 * k), victim_name, int(24 * k), Color(1, 1, 1, a))
	# A plain crosshair dot where the killer was aiming.
	if view.time < clip.kill_time + 0.6:
		var mid := r.position + r.size * 0.5
		ci.draw_circle(mid, 2.5, Color(1, 1, 1, 0.85))
		ci.draw_arc(mid, 9.0, 0.0, TAU, 24, Color(1, 1, 1, 0.35), 1.5)
