# Milestone 1 feature tracker

Status: **not started** · **rough** (exists, placeholder or partial) · **working** (done,
tested by me) · **verified** (also checked by Austin on a real PC / with a friend).

Last updated: phase 1, part 1 (match loop).

## Menus and flow

| Feature | Status | Notes |
| --- | --- | --- |
| Main menu (Play, Multiplayer, Settings, Exit) | working | Placeholder styling |
| Mode select (1v1 Bot, Multiplayer FFA) | rough | Bot button disabled until phase 1; Practice mode added |
| Lobby: create, join, player list, host shown, start, leave | working | Direct IP only for now |
| Settings menu (mouse, camera, audio, graphics) | working | Audio sliders have no sounds to affect yet |
| Pause menu in match | working | Resume, settings, leave; host can end the match early |
| Match results screen | working | Rankings, kills, deaths; return to lobby or main menu |
| Return to lobby and play again | working | Tested: two matches back to back |

## Multiplayer

| Feature | Status | Notes |
| --- | --- | --- |
| Host and join over direct IP | working | Tested with up to 5 copies on one machine |
| Steam lobbies, invites, relay | not started | Next step; needs the GodotSteam plugin |
| Movement sync with smoothing | working | Sync test passes at 100 ms latency, 60 ms jitter, 10% loss |
| Player leaves mid-match | working | Their character disappears for everyone |
| Host leaves: match ends, everyone back to menu | working | Covered by the sync test |
| Rejoin a match in progress | rough | Joining mid-match drops you into the arena; a rejoining player starts at 0 kills |
| Internet play between two PCs | not started | Needs Steam, or router port forwarding for direct IP |
| Hit detection (host decides with rewind) | working | Laggy-network test: 90% of aimed shots hit with rewind vs 37% without |

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
| Health, damage, death, respawn (3 s), kills | working | Host decides; falling out of the arena counts as a death |
| Kill feed, hit marker, damage flash, death screen | working | Placeholder look |
| Match timer and kill target | working | Placeholder rules: first to 15 kills or 8 minutes, until you choose |
| Weapons | rough | One placeholder test gun (hitscan, 20 damage, 20 rounds, reload). Real weapons wait on your design answers |
| Weapon switching | not started | Needs a second weapon |
| Muzzle flash, tracers, impacts | rough | Simple glowing shapes |
| Weapon sounds | not started | |
| Bot | not started | Phase 1 (simple), phase 3 (uses movement) |
| Arena | rough | Greybox test layout; real arena designed in phase 2 |
| Character models and animation | not started | Capsule placeholders; phase 4 |
| Sound | not started | |

## Known issues

- The first-person gun can poke into walls when you stand right against them.
- Name tags show through walls (handy while testing; will be limited to line of sight).
- No LAN address detection on some networks: the lobby may show 127.0.0.1. Use `ipconfig`
  to find your address if so.
