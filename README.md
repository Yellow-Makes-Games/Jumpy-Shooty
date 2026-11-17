# Jumpy Shooty

A fast, high-mobility 3D multiplayer arena shooter: grapple, wall-run, slide, dive and
fight in free-for-all matches of up to 5 players, or offline against 1 to 4 bots. Or put
the guns away and **race**: run an obstacle course against friends or bots, from
checkpoint to checkpoint, to the finish.

Built with **Godot 4.7** (GDScript). Multiplayer is player-hosted: one player hosts and
up to 4 friends connect to them. Today that works by address (direct IP, or over the
internet through a free tunnel: see [docs/ONLINE_PLAY.md](docs/ONLINE_PLAY.md)); Steam
invites and relays are next.

**Status:** Milestone 1 in progress: match loop, full movement set, the Construction Site and Office maps, the Testing Grounds test map and offline bot matches (1v1, or a free-for-all against up to 4 bots) work, with sound effects for every gun, hit, move and menu; Steam is next. See [docs/FEATURES.md](docs/FEATURES.md)
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
| Jump | Space |
| Shoot | Left mouse |
| Reload (in a race: back to your last checkpoint) | R |
| Switch first / third person | V |
| Scoreboard | Tab (hold) |
| Menu | Esc |
| Debug menu (Practice and Vs Bots only) | F1 |

Grapple (right mouse), slide (Ctrl or C) and dive (Alt or Q) arrive in later phases.

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
