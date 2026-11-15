# Milestone 1 feature tracker

Status: **not started** · **rough** (exists, placeholder or partial) · **working** (done,
tested by me) · **verified** (also checked by Austin on a real PC / with a friend).

Last updated: phase 0.

## Menus and flow

| Feature | Status | Notes |
| --- | --- | --- |
| Main menu (Play, Multiplayer, Settings, Exit) | working | Placeholder styling |
| Mode select (1v1 Bot, Multiplayer FFA) | rough | Bot button disabled until phase 1; Practice mode added |
| Lobby: create, join, player list, host shown, start, leave | working | Direct IP only for now |
| Settings menu (mouse, camera, audio, graphics) | working | Audio sliders have no sounds to affect yet |
| Pause menu in match | working | Resume, settings, leave, host can end match |
| Match results screen | not started | Phase 1 |
| Return to lobby and play again | rough | Host can end the match; results come in phase 1 |

## Multiplayer

| Feature | Status | Notes |
| --- | --- | --- |
| Host and join over direct IP | working | Tested with up to 5 copies on one machine |
| Steam lobbies, invites, relay | not started | Next step; needs the GodotSteam plugin |
| Movement sync with smoothing | working | Sync test passes at 100 ms latency, 60 ms jitter, 10% loss |
| Player leaves mid-match | working | Their character disappears for everyone |
| Host leaves: match ends, everyone back to menu | working | Covered by the sync test |
| Rejoin a match in progress | rough | Joining mid-match drops you into the arena; scores not kept yet |
| Internet play between two PCs | not started | Needs Steam, or router port forwarding for direct IP |
| Hit detection (host decides with rewind) | not started | Phase 1 |

## Movement

| Feature | Status | Notes |
| --- | --- | --- |
| Walk, sprint, acceleration, friction | working | Numbers in movement_tuning.gd |
| Jump, coyote time, jump buffering | working | |
| Air control, momentum preservation | working | Air steering never slows you down |
| Slide | not started | Phase 1 (basic), phase 2 (full) |
| Grapple (momentum-based) | not started | Phase 2 |
| Wall-run, wall-jump | not started | Phase 2 |
| Dive, roll, flips, vault, ledges | not started | Phase 2 |

## Camera

| Feature | Status | Notes |
| --- | --- | --- |
| First person | working | |
| Third person with wall collision | working | V to switch; smooth blend between them |

## Combat, bot, arena, art, audio

| Feature | Status | Notes |
| --- | --- | --- |
| Weapons, health, death, respawn, kills | not started | Phase 1 |
| Bot | not started | Phase 1 (simple), phase 3 (uses movement) |
| Arena | rough | Greybox test layout; real arena designed in phase 2 |
| Character models and animation | not started | Capsule placeholders; phase 4 |
| Sound | not started | |

## Known issues

- Name tags show through walls (handy while testing; will be limited to line of sight).
- No LAN address detection on some networks: the lobby may show 127.0.0.1. Use `ipconfig`
  to find your address if so.
