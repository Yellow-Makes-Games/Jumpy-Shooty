# Milestone 1 feature tracker

Status: **not started** · **rough** (exists, placeholder or partial) · **working** (done,
tested by me) · **verified** (also checked by Austin on a real PC / with a friend).

Last updated: phase 1, part 2 (design answers applied). Decisions are in [DESIGN.md](DESIGN.md).

## Menus and flow

| Feature | Status | Notes |
| --- | --- | --- |
| Main menu (Play, Multiplayer, Settings, Exit) | working | Placeholder styling |
| Mode select (1v1 Bot, Multiplayer FFA) | rough | Bot button disabled until phase 1; Practice mode added |
| Lobby: create, join, player list, host shown, start, leave | working | Direct IP only for now |
| Lobby win condition (first to N kills, or time limit) | working | Host picks; everyone sees it |
| Settings menu (mouse, camera, audio, graphics) | working | Audio sliders have no sounds to affect yet |
| Pause menu in match | working | Resume, settings, leave; host can end the match early |
| Match results screen | working | Rankings, kills, deaths; return to lobby or main menu |
| Return to lobby and play again | working | Tested: two matches back to back |

## Multiplayer

| Feature | Status | Notes |
| --- | --- | --- |
| Host and join over direct IP | working | Tested with up to 5 copies on one machine |
| Steam lobbies, invites, relay | not started | Next step; needs the GodotSteam plugin |
| Movement sync with smoothing | working | Sync test passes at 100 ms latency, 60 ms jitter, 10% loss. ENet throttling switched off so movement updates are not dropped |
| Player leaves mid-match | working | Their character disappears for everyone |
| Host leaves: match ends, everyone back to menu | working | Covered by the sync test |
| Rejoin a match in progress | rough | Joining mid-match drops you into the arena; a rejoining player starts at 0 kills |
| Internet play between two PCs | not started | Needs Steam, or router port forwarding for direct IP |
| Hit detection (host decides with rewind) | working | Laggy-network test: 90% of aimed shots hit with rewind vs 37% without |
| Headshots | working | 1.5x damage above the shoulders (lower when crouched). Yellow hit marker |

## Movement

| Feature | Status | Notes |
| --- | --- | --- |
| Walk, sprint, acceleration, friction | working | Numbers in movement_tuning.gd |
| Jump, coyote time, jump buffering | working | |
| Air control, momentum preservation | working | Air steering never slows you down |
| Bunny-hopping and air-strafing | working | A jump timed on landing keeps all speed; strafe+turn in the air gains speed |
| No fall damage | working | By design |
| Crouch | working | Ctrl or C. Lower and slower, fits under 1.4 m gaps, smaller hitbox. In the air it tucks your legs up |
| Slide | working | Crouch while moving fast: speed boost (once per 1.2 s), keeps momentum, speeds up downhill, jump out of it |
| Grapple (momentum-based) | working | Right mouse. Rope swing, not a pull: swing, pump with WASD, let go to launch, jump to let go with a kick. 45 m range, 0.6 s cooldown, any surface |
| Wall-run, wall-jump | working | Hold forward along a wall in the air. Low gravity for 1.6 s, camera leans. Jump to kick off. Same wall can't be reused until you land |
| Vault, ledge climb | working | Run into anything 0.45 to 1.25 m high and you vault it, keeping speed. Jump at a ledge up to 2.3 m and you climb up |
| Dive and roll | working | Q (or Alt): lunge toward where you look (+4 m/s, low hitbox), from the ground or once per jump, 1 s cooldown. Landing from a dive rolls you forward keeping your speed; hold crouch to roll into a slide |
| Flips (air flip dodge) | working | Press jump again in mid-air: flip toward your WASD direction with a small burst, once per jump (refreshed by wall runs and the grapple). A jump pressed just above the floor still counts as a bunny-hop |

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
| Match timer and kill target | working | Set per lobby by the host |
| Weapons | working | Semi-automatic pistol: 25 damage, 12 rounds, 1.3 s reload. Numbers to tune by playtesting |
| Weapon switching | not started | Only one weapon for now, by choice |
| Muzzle flash, tracers, impacts | rough | Simple glowing shapes |
| Weapon sounds | not started | |
| Bot | not started | Phase 1 (simple), phase 3 (uses movement) |
| Testing Grounds (test map) | working | Greybox combat arena plus a training yard with practice lanes: grapple beams, wall-run zigzag and wall-jump chimney, slide hill and bars, vault blocks and ledges at marked heights, gap jumps of 6, 10 and 13 m (jump / jump + dive / jump + flip + dive). An automated test runs each course |
| Construction site (first real arena) | not started | |
| Character models and animation | not started | Capsule placeholders; phase 4 |
| Sound | not started | |

## Known issues

- The first-person gun can poke into walls when you stand right against them.
- Name tags show through walls (handy while testing; will be limited to line of sight).
- No LAN address detection on some networks: the lobby may show 127.0.0.1. Use `ipconfig`
  to find your address if so.
