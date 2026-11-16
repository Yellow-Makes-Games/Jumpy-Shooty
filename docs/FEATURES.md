# Milestone 1 feature tracker

Status: **not started** · **rough** (exists, placeholder or partial) · **working** (done,
tested by me) · **verified** (also checked by Austin on a real PC / with a friend).

Last updated: no name tags over players, and bots no longer see through walls. Decisions are in [DESIGN.md](DESIGN.md).

## Menus and flow

| Feature | Status | Notes |
| --- | --- | --- |
| Main menu (Play, Multiplayer, Settings, Exit) | working | Styled to match the HUD (Chakra Petch, dark panels, orange accent, drifting grid backdrop). Front page shows every robot side by side, idling; Play has cards for Vs Bots, Practice and Multiplayer |
| Mode select (Vs Bots, Practice, Multiplayer FFA) | working | Vs Bots page: pick how many bots (1 for a 1v1, up to 4 for a 5-player free-for-all), difficulty and kills to win; Rematch on the results screen |
| Lobby: create, join, player list, host shown, start, leave | working | Direct IP only for now |
| Character select | working | Seven robots (Needle, Vanguard, Kestrel, Bulwark, Rivet, Specter, Orbit), with a live preview. On the Practice and Vs Bots pages and in the lobby (each player picks their own; the list shows everyone's pick). Remembered between sessions. Looks only |
| Lobby win condition (first to N kills, or time limit) | working | Host picks; everyone sees it |
| Settings menu (mouse, camera, HUD, audio, graphics) | working | Tabs: Controls (with the key list), Camera & HUD, Audio, Graphics. Switches and sliders apply at once. Audio: Master, Music (nothing plays on it yet) and Effects |
| Pause menu in match | working | Resume, settings, leave, controls list; host can end the match early |
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
| Character sync | working | Every copy shows each player as the robot they picked, including a new pick made in the lobby between matches. Checked by the sync and match tests |
| Animation sync | working | Other players show the move they are really doing (run, slide, wall run side, flip direction, vault or climb, reload, shots, death). Checked by the sync and match tests, also on the laggy network |

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
| Belly slide | working | Keep holding dive as you land and you slide along on your front instead of rolling (+1 m/s on impact, a little less friction than a slide, weak steering, speeds up downhill). Lowest hitbox in the game (0.8 m) and you can shoot the whole way. Let go (or jump) to get up; let go while holding crouch to go straight into a slide. If the slide runs out while you are still holding dive you crawl (2 m/s). Under a gap too low to crouch in you stay down until you crawl out |
| Flips (air flip dodge) | working | Press jump again in mid-air: flip toward your WASD direction with a small burst, once per jump (refreshed by wall runs and the grapple). A jump pressed just above the floor still counts as a bunny-hop |

## Camera

| Feature | Status | Notes |
| --- | --- | --- |
| First person | working | Your robot's arms and gun, with poses for sprint, slide, wall run, vault, dive, grapple and reload. Drawn so they never cut into walls |
| Your body in first person | working | Look down and you see your own torso and legs, running, crouching, hanging from the rope, casting your shadow. Sliding puts your legs out in front of you. In a flip the camera stays level so you can keep aiming, and your knees and feet sweep through the view (over the top for a backflip, round the edge for a side flip); a landing roll tucks them through and plants them. On your belly you see only your arms, as you would |
| Third person with wall collision | working | V to switch; smooth blend between them. Shows your full robot |

## Combat, bot, arena, art, audio

| Feature | Status | Notes |
| --- | --- | --- |
| Health, damage, death, respawn (3 s), kills | working | Host decides; falling out of the arena counts as a death |
| HUD | working | Two layouts, chosen separately for first and third person in Settings: Twin arcs (health and ammo as arcs round the crosshair, move cooldowns under it; first-person default) and Clean (corners; third-person default). Both have the score bar, kill feed with headshots, hit markers, damage numbers, arrows toward whoever hit you, a red screen edge at low health, kill confirmation, a death screen (the robot that got you, its HP left, headshot, distance, respawn bar) and the Tab scoreboard (also shown while dead). Font: Chakra Petch |
| Match timer and kill target | working | Set per lobby by the host |
| Weapons | working | Four guns, picked before the match (lobby, Practice and Vs Bots pages, beside the robot) and kept for the whole match. Pistol: semi-auto, 25 damage, 12 rounds. Shotgun: pump-action, 10 pellets of 11, one-shot kill up close, falls off from 9 to 22 m, 6 shells loaded one at a time (shooting stops the reload). Assault rifle: full auto, 10 shots a second, 13 damage, 30 rounds. Sniper rifle: bolt-action, 75 damage, 2x headshots (a headshot kills, two body shots do), no wobble, 5 rounds. Each has its own model, crosshair, HUD ammo display, kill-feed icon, muzzle flash and tracer, and its own animations in first and third person (hold, sprint carry, fire with pump or bolt, reload). Bots pick a gun at random and fight to suit it. Numbers to tune by playtesting |
| Weapon switching | not started | One gun per match, by choice; change it in the lobby between matches |
| Muzzle flash, tracers, impacts | rough | Simple glowing shapes |
| Weapon sounds | working | Each gun has its own shot (a wide version for your own gun, a placed one for others, and a distant echo layer when far away), every reload step timed to the animation, the shotgun's pump and the sniper's bolt after each shot, an empty click, and a sound for bringing the gun up (on spawn and when picking it in a menu). Made by code; not yet heard on a real PC |
| Bot | working | Offline: 1v1, or a free-for-all against up to 4 bots (you plus 4 is a full 5). Bots fight each other too: each goes for the nearest player it knows about, favouring one it can see, whoever just shot it and whoever it is already fighting. No seeing through walls: a bot sees you only when you are in front of it with nothing in the way; it hears gunfire, bullets going past and someone running close by (a rough spot, not your exact position), and knows roughly where a shot that hits it came from. It goes to where it last saw or heard you, searches round there, and otherwise roams the map. Harder bots see wider, hear further, place sounds better, guess where you ran and keep hunting for longer. Bots are named (Gizmo, Sprocket, Bolt, Piston) and take turns through the robots, starting with the one after yours, so no bot plays your robot. One difficulty for every bot. Easy / Normal / Hard / Expert change reaction time, aim wobble, turn speed, fire rate, leading, headshots and which moves it uses. Gets round the map on the navigation mesh, takes the stairs to your floor, keeps its tricks away from drops, strafes and jumps in fights; Normal+ slides; Hard+ bunny-hops, dives (usually holding it into a belly slide), grapples, flip-dodges when hit. Same movement and gun rules as you. Numbers to tune by playtesting |
| Testing Grounds (test map) | working | Greybox combat arena plus a training yard with practice lanes: grapple beams, wall-run zigzag and wall-jump chimney, slide hill and bars, vault blocks and ledges at marked heights, gap jumps of 6, 10 and 13 m (jump / jump + dive / jump + flip + dive). An automated test runs each course. A target range down the middle of the yard: five robot target dummies at 5, 10, 20, 35 and 60 m from a firing line |
| Construction Site (first real map) | working | "The Tower": a half-built six-floor tower in an 80 x 80 m yard, with a crane, scaffolding, a hoist tower, containers, a pit and a fence to wall-run. 12 spawn points. An automated test runs a player over 18 movement routes and checks that bots can walk to every level. Needs a playtest for balance (the top may be too strong) |
| Office (second real map) | working | "Atrium tower": a smaller interior map, a 48 x 36 m office building with three floors (0, 5 and 10 m) round a three-storey atrium. Bridge across the atrium at 10 m, skylight beams to swing from, a service lift shaft to wall-jump, a shelf and a filing stack to climb a floor, stairs either side, desks and dividers to vault, a half-shut server room shutter to slide under, long window walls to wall-run. 12 spawn points. An automated test runs 8 movement routes and checks that bots can walk everywhere. Needs a playtest for balance |
| Target dummies | working | Robots that stand still to be shot (MapDummy in a map; the Testing Grounds range has five). Same hitbox and hit check as a player, so the same hit markers, damage numbers, headshots and kill marker. A readout over each shows its health, the last hit and distance, hits and headshots so far, total damage and how long the kill took. Brought to 0 it falls over and gets back up 2 s later; left alone 3 s it heals. Works online too (the host decides hits) |
| Debug menu | working | F1 (or `) in Practice and Vs Bots: god mode, infinite ammo, no cooldowns, noclip flying, game speed (0.1x to 2x), full health, kill self, teleport (crosshair, saved spot, spawn points, each target dummy), change robot and gun on the spot, add / remove / freeze bots, FPS and position readout. Never opens online, and every cheat is off there, even for the host |
| Map choice | working | The host picks the map in the lobby; practice and the bot menu have a picker. Testing Grounds is listed as a test map |
| Map editing | working | Maps are scenes: open one in the Godot editor, click a piece to select it, drag its face handles to resize it, F6 to play it. See DEVELOPMENT.md |
| Character models | working | Seven robots: Needle, Vanguard, Kestrel, Bulwark, Rivet, Specter and Orbit, all with white armour, player colour on the trim and visor. Same skeleton, hitbox and animations. Built by code in `tools/robot/` (see DEVELOPMENT.md) |
| Character animation | working | Idle, run, sprint, crouch, slide, jump and fall, landing, wall run (both sides), wall jump, vault, ledge climb, grapple swing, dive, landing roll, belly slide and crawl, four flips, shooting, reload, death, respawn. The body aims where the player looks; legs follow the direction of travel. Same animator for you, other players and the bot. The vault is the least polished clip |
| Sound | working | Crisp, realistic sound effects (low and weighty, not arcade), all generated by `tools/audio/make_sfx.py` (no recordings; see `game/audio/LICENSE.md`). Bullet impacts on walls (with the odd ricochet) and on robots, near-miss whizzes, hit markers (brighter for headshots), kill confirms, hurt and death sounds. Robot footsteps and sounds for every move (jump, landing, roll, slide, belly slide and crawl, wall run, wall jump, vault, ledge climb, grapple fire/attach/release/miss, dive, flip, crouch). Menu hover, click, confirm, back, toggles and sliders; match start and end. Other players' sounds are placed in 3D. No music yet. Levels need a listen on a real PC |

## Known issues

- Animations have only been judged from rendered still frames so far, not in motion on a
  real PC. Timing and feel will need a playtest pass.
- The muzzle flashes are still simple placeholders.
- The sound effects have only been checked by measurement and automated tests, not
  listened to on a real PC yet: expect to tune levels in `game/audio/sfx_list.gd`.
- The sniper rifle has no scope or zoom: right mouse is the grapple. It can be added
  with a new key if wanted.
- No LAN address detection on some networks: the lobby may show 127.0.0.1. Use `ipconfig`
  to find your address if so.
