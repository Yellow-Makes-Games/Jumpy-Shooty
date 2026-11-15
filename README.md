# Jumpy Shooty

A fast, high-mobility 3D multiplayer arena shooter: grapple, wall-run, slide, dive and
fight in free-for-all matches of up to 5 players, or against a bot.

Built with **Godot 4.7** (GDScript). Multiplayer is player-hosted: one player hosts and
up to 4 friends connect to them. Today that works over direct IP; Steam invites and
relays are next.

**Status:** Phase 0 of the Milestone 1 roadmap. See [docs/FEATURES.md](docs/FEATURES.md)
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
| Switch first / third person | V |
| Menu | Esc |

Grapple (right mouse), slide (Ctrl or C), dive (Alt or Q), shooting and weapons arrive in
later phases.

## Project layout

```
game/
  core/      settings, screen changes
  net/       multiplayer: hosting, joining, lobby, movement smoothing
  player/    player, movement (movement/), camera (camera/)
  arena/     the arena and its layout
  ui/        menus, lobby, HUD, pause menu
  dev/       developer command-line options
tools/       launch several copies, take screenshots
tests/       automated tests (tests/run_all.sh)
docs/        setup guide, feature tracker
```
