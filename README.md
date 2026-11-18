# Jumpy Shooty

A fast, high-mobility 3D multiplayer arena shooter: grapple, wall-run, slide, dive and
fight in free-for-all matches of up to 16 players, or offline against 1 to 4 bots. Play a
**Deathmatch** where everyone starts unarmed and grabs weapons floating around the map. Or put
the guns away and **race**: run an obstacle course against friends or bots, from
checkpoint to checkpoint, to the finish.

Built with **Godot 4.7** (GDScript). Multiplayer is player-hosted: one player hosts and
up to 15 friends connect to them. Today that works over direct IP; Steam invites and
relays are next.

**Status:** Milestone 1 in progress: match loop, full movement set, the Construction Site, Office, Kilnworks, Rail Yard, Lost Temple and Neon Arcade maps, four race courses (Rooftop Run, Foundry, Sky Ruins, Summit Plunge), the Testing Grounds test map and offline bot matches (1v1, or a free-for-all against up to 4 bots) work, with sound effects for every gun, hit, move and menu; Steam is next. See [docs/FEATURES.md](docs/FEATURES.md)
for what works and what does not yet.

## Quick start

1. Install Godot 4.7.2 (standard version, not .NET) from https://godotengine.org/download.
2. Open Godot, click **Import**, and pick this folder's `project.godot`.
3. Press **F5** (or the ▶ button) to play.

More detail, including how to play with a friend and run several copies on one PC, is in
[docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).

## Controls

| Action | Key |
| --- | --- |
| Move | W A S D |
| Sprint | Shift |
| Glide (hold in mid-air: you carry on the way you were going, slowing and sinking gently, free to look and aim, and guns scatter less; let go to stop) | Shift |
| Jump | Space |
| Shoot (melee: hold to wind a swing up, let go to swing; the longer the wind-up, the harder the hit) | Left mouse |
| Change weapon (while waiting to respawn) | 1-7 or mouse wheel |
| Deathmatch: take out the weapon in slot 1 or 2 (you carry two) | 1 / 2 or mouse wheel |
| Kick (any weapon; with a player on your grapple: flying kick) | F |
| Rocket boots (a burst toward WASD as you look; hold Space to tip it up; while gliding, turns the glide that way) | E |
| Interact (press at the terminal in Halcyon's Control Room: low gravity) | G |
| Reload (in a race: back to your last checkpoint) | R |
| Switch first / third person | V |
| Scoreboard | Tab (hold) |
| Menu (Loadout: change robot or weapon for your next respawn) | Esc |
| Debug menu (Practice and Vs Bots only) | F1 |

Right mouse is your **mobility** tool, picked before a match, in the pause menu's Loadout or
by pressing right mouse while you wait to respawn: the **grappling hook**, the **portal gun**
(each press puts up your next portal, blue then orange; walk into one and come out of the other
with your speed carried through; anyone can use anyone's portals, and yours go when you die) or
**blink** (a short teleport where you look, one charge that recharges, with a trail of sparks to where you land). A race always has the grapple.
Grapple is right mouse, crouch / slide is Ctrl or C, dive is Q or Alt. Every key except Esc can be
rebound under **Settings > Controls** (two bindings per action, keys or mouse buttons); a key
you give to one action is taken off any other that had it, and **Reset controls to defaults**
puts them all back.

## Project layout

```
game/
  core/      settings, screen changes
  net/       multiplayer: hosting, joining, lobby, movement smoothing
  player/    player, movement (movement/), camera (camera/)
  match/     match rules run by the host: health, hits, kills, respawns, timer, races
  combat/    weapons and shot effects
  audio/     sound effects (sfx/) and the code that plays them
  arena/     the arena and the map system (see docs/DEVELOPMENT.md)
  maps/      the maps: scenes you edit in the Godot editor, and their palettes
  ui/        menus, lobby, HUD, pause menu
  dev/       developer command-line options
addons/      map_tools: the editor plugin for editing maps
tools/       launch several copies, take screenshots, render map previews, build the robots, sounds and race maps
tests/       automated tests (tests/run_all.sh)
docs/        setup guide, feature tracker
```
