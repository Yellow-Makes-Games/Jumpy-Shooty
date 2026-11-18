# Development guide

## One-time setup (about 10 minutes)

1. **Install Godot 4.7.2**, the standard version (not ".NET"), from
   https://godotengine.org/download. On Windows it is a single .exe; put it somewhere
   permanent such as `C:\Godot\`.
2. **Get the project.** Clone this repository (GitHub Desktop is the easiest way), or
   download it as a ZIP from GitHub and unzip it.
3. **Open it in Godot.** Start Godot, click **Import**, choose `project.godot` in this
   folder, then **Import & Edit**. The first import takes a minute.
4. Press **F5** to play.

## Running several copies on one PC

This is the quickest way to test multiplayer. From the project folder:

- **Windows:** first tell the script where Godot is (once per Command Prompt window):
  ```
  set GODOT=C:\Godot\Godot_v4.7.2-stable_win64.exe
  tools\run_local.bat 3
  ```
  The number is how many copies (2 to 5). The first copy hosts and the rest join it
  automatically, in a grid of windows.
- **Linux/macOS:** `GODOT=/path/to/godot tools/run_local.sh 3`

Click inside a window to control that copy. Esc frees the mouse.

You can also do it by hand: run the game twice, choose **Multiplayer → Create lobby** in
one and **Multiplayer → Join lobby** with address `127.0.0.1` in the other.

## Playing with a friend

**Until Steam is wired in**, connecting is direct (no server). The host's lobby shows a
**lobby code** (like `ABCD-EFGH`) that stands for the host's address; friends type it into
the Join box on the Multiplayer page. An IP address works there too.

- **Same home network:** host with **Create lobby**. If the router can't be opened, the
  lobby's code stands for your local address (for example `192.168.1.20`, shown beside it).
  Your friend types the code (or that address) into **Join lobby**.
- **Over the internet:** when you create a lobby, the game asks your router to open
  UDP port 24680 (UPnP) and the lobby shows a code for your public address with a **Copy code**
  button. Send that to friends; they type it into **Join lobby**. If the lobby says the
  router would not open the port, forward UDP 24680 to your PC by hand in the router's
  settings (or UPnP is switched off there, or your provider shares one address between
  homes, which no router setting fixes).

Windows may ask whether to allow Godot through the firewall the first time you host.
Allow it on private networks.

**With Steam (coming next):** create a lobby and invite friends through Steam; no
addresses or router settings. Everyone needs Steam running.

## Automated tests

`tests/run_all.sh` runs everything in about 4 minutes on a 4-core machine (needs bash
and python3, so on Windows use Git Bash or WSL; I run these on every change anyway).
The quick checks run side by side (`JOBS=8 tests/run_all.sh` for more at once), and the
ones that only step physics run on a fixed game clock (Godot's `--fixed-fps 60`), so
they play out as fast as the machine allows instead of in real time. Their logs go to
`tests/out/check_<name>.log`.

Quick checks:

- movement (`tests/movement_test.gd`): speeds, stopping, jump height, momentum in the air;
- robots (`tests/robot_test.gd`), for every character: the model files hold every bone
  and clip, the skeletons match, each movement state plays the right animation, the
  poses fit the hitbox, and every gun has its muzzle bone and its own clips;
- weapons (`tests/weapon_test.gd`): damage and falloff, magazine and shell-by-shell
  reloads, melee wind-ups and shoves;
- sounds (`tests/audio_test.gd`): every sound file loads and every sound the code asks
  for exists;
- map scenes (`tests/map_scene_test.gd`): every map loads and builds, blocks, resize
  handles, race gates, bot routes, hazards, and the map lists keep race and arena maps apart;
- the Testing Grounds courses and the Construction Site and Office routes: a scripted
  player runs each one (`tests/course_test.gd`, `tests/site_test.gd`,
  `tests/office_test.gd`), plus spawn points and bot navigation; the other arenas'
  spawns and navigation (`tests/arena_maps_test.gd`). To run one route and print what
  the player did: `COURSE_ONLY="fence" COURSE_DEBUG="fence" godot --headless --fixed-fps 60
  --path . --script tests/site_test.gd`;
- breakable walls and floors (`tests/destruction_test.gd`);
- flicker (`tests/map_flicker_test.gd`), on the Castle, Castle 2, Rail Yard, Lost Temple and Neon
  Arcade: no two surfaces of different colours share a plane where both can be seen,
  and no sign lies in the wall behind it. `FLICKER_MAPS=all` tries every map,
  `FLICKER_LIST=40` prints more of what it found;
- Halcyon (`tests/halcyon_test.gd`): spawn points, pickups, the terminal on its dais,
  bot navigation through every room and level, the hull stays sealed, the reactor pit
  kills;
- Cirrus (`tests/cirrus_test.gd`, with `--fixed-fps 60`): spawn points and pickups, the
  pool of arrangements, the clock's timing and sounds, no writing, what crosses the gap,
  a move (riders on an island that stays are carried, those on one that goes die), the
  glass, bots' routes and crossings;
- the map terminal (`tests/terminal_test.gd`): a 2 s hold in range fires its event,
  what cancels a hold, no use during the event or cooldown, one player at a time;
- low gravity (`tests/gravity_test.gd`): the multiplier's schedule, jump heights,
  rockets and grenades fly the same path, the centrifuge slows, and gravity always
  comes back to 1.0;
- menu layout (`tests/ui_layout_test.gd`): builds every menu page (main menu and its
  pages, the four Settings tabs, lobby, results, pause, loadout) at 18 window sizes
  and shapes (960x540 to 4K, 16:10, 21:9, 32:9, 4:3, 5:4, tall and tiny windows) and
  fails if any button, text box or slider is off screen, if a robot or weapon button
  cuts its name short, or if the death screen's two columns do not fit;
- controls rebinding (`tests/controls_check.gd`), the main menu's mode switch
  (`tests/menu_mode_test.gd`), Deathmatch maps, pickups and inventory
  (`tests/deathmatch_test.gd`), and the debug menu and target dummies in a real
  Practice match (`tests/debug_test.gd`);
- killcams (`tests/killcam_test.gd`): the kill scores, their breakdown into parts that
  add up to them, and the pick of the best three,
  what travels with a death, recording and blending frames, a replay from the killer's
  eyes (camera, arms, the victim, the shot, slow motion), the best kills playing
  fullscreen after a match (counting down to the best), the results page with
  them listed still fits 1600x900, and a killcam saved as a video is a Motion JPEG
  AVI with every frame and an index, as long as the clip plays;
- spectating (`tests/spectator_test.gd`): in a Vs Bots match you switch to spectating and
  back; a spectator has no robot, score or scoreboard row, the bots play on, and the free
  camera flies through the floor, faster with Sprint, the way it looks;
- the game boots into practice mode on every map without script errors.

Networked and bot runs (real time):

- sync (`tests/run_sync_test.sh`): 3 copies on a simulated bad network (100 ms latency,
  60 ms jitter, 10% loss) move on their own; every copy must draw every other player
  within 15 cm of where they really were (95% of frames), with no visible pops, show
  the move they were really doing (`tests/check_anim.py`) as the robot they picked,
  and notice when the host leaves. `SYNC_DEBUG=1 python3 tests/check_sync.py
  tests/out/sync_*.log` prints where and when each pop happened;
- match (`tests/run_match_test.sh`): 3 copies on a laggy network play two matches back
  to back, aiming and shooting on their own: hits land, the match ends at the kill
  target, every copy agrees on the results and on broken walls, new robot and gun
  picks show in the second match, and every copy hears its own gun and the others'
  shots and footsteps;
- bots (`tests/run_bot_test.sh`): a bot of every difficulty finds you and shoots, Expert
  beats Easy on accuracy, the hard bots use the movement set, Rematch works, a
  5-player free-for-all against 4 bots, a sword bot, and your and the bots' sounds;
- spectating online (`tests/run_spectator_test.sh`): a client joins mid-match to spectate;
  it sees both players move, nobody sees it, and it is never on the player list;
- ground slam (`tests/run_slam_test.sh`): a hammer slam from a drop in Practice hits
  the target dummy, and online a client's slam is ruled on by the host, hits the host's
  player and is heard by both;
- Halcyon online and with bots (`tests/run_gravity_test.sh`): a client fires the
  terminal on the host, a client across the room cannot, a late joiner is told how far
  along the event is, and bots use the terminal and keep moving in low gravity;
- killcams (`tests/run_killcam_test.sh`): Vs Bots (in game time), the killcam plays each
  time the bot gets you and runs until you respawn, Jump skips it (not in its first 0.75 s),
  with `--manual-respawn` Jump brings you back (and nothing else does), and the results
  screen plays the best kills and saves the best as a video; online, a host and a client on a laggy network each
  watch their killcams, score every kill the same, show each killer their kill's points
  (adding up to its score), pick the same best three and have a clip of each;
- Killcam mode (`tests/run_killcam_mode_test.sh`): Vs Bots and online, everyone has the
  sniper rifle (even a client who picked another gun), each player's points are their
  kills' killcam scores plus the #1 killcam bonus, the match ends at the kill that
  reaches the target, the rankings go by points, and host and client agree;
- races (`tests/run_race_test.sh`, in game time): you and 4 bots finish Rooftop Run in
  time order and "Race again" starts another, Easy bots finish, and a hazard, a fall and
  R each send you back. After changing a course, run it on that map:
  `MAPS="foundry" tests/run_race_test.sh`.

The sync, match and bot tests take a map and a player count, for example
`MAP=testing_grounds tests/run_bot_test.sh` or `MAP=office tests/run_sync_test.sh 5 "100,60,10"`.
- breakable walls and floors (`tests/destruction_test.gd`): the arena maps have them and
  race maps none, no spawn stands on floor that can break, an intact wall still collides
  as one box, damage cracks then breaks a piece and a shot then goes through the hole;
  online (`tests/run_break_test.sh`, laggy network) the host shoots the floor out from
  under itself and falls through, a client breaks a wall, a player joining mid-match is
  shown what is broken and every copy agrees; the match test also checks every copy
  ends each match with the same broken pieces;
- Halcyon (`tests/halcyon_test.gd`): 16 or more spawn points, each clear, none in the
  Control Room or in sight of the terminal's dais; the pickups (the heavy weapons up
  high, none in the Control Room); the terminal on its dais and its event; on the bots'
  navigation mesh, every room and level reached from the dais and back, both decks
  joined, and the Control Room entered by each of its six doorways; the dome and the
  floor glass cannot break and nothing gets out of the hull; no lit strip hangs across
  a doorway or in mid-air; no two floors or floor markings of different colours share a
  height where they overlap (that flickers); the reactor pit kills;
- the map terminal (`tests/terminal_test.gd`): one press in range fires its event; a
  press from out of range, or during the event or the cooldown, does nothing, and a key
  kept down does not fire it again; and for a terminal set to need a hold: a 2 s hold
  fires it, letting go, leaving the range and dying cancel and taking damage does not,
  one player at a time;
- low gravity (`tests/gravity_test.gd`): the multiplier reaches 0.3 and returns to 1.0
  on schedule, a jump reaches about 4 m against about 1.2 m, rockets and grenades fly
  the same path, the centrifuge slows to half speed, and gravity is back at 1.0 when a
  match ends mid-event, when the next starts and when the map is unloaded; online and
  with bots (`tests/run_gravity_test.sh`): a client fires the terminal on the host, a
  client across the room cannot, a late joiner is told how far along the event is, and
  bots use the terminal and keep moving through the low gravity;
- the debug menu and target dummies, in a real Practice match on the Testing Grounds:
  body shots and headshots on a dummy, it goes down and gets back up, god mode, infinite
  ammo, adding and removing bots, changing robot and gun, game speed, and that no cheat
  works online (`tests/debug_test.gd`);
- map scenes: every map loads and builds, every block has a colour, and the resize
  handles move the right face; race maps have gates numbered in order ending in one
  finish, a bot route, hazards and moving parts that move, and the map lists keep race
  maps and arena maps apart (`tests/map_scene_test.gd`);
- races (`tests/run_race_test.sh`, in game time so it plays out the same on a slow
  machine): on every race map you (on autopilot) and 4 Normal bots all finish, in time
  order, and "Race again" starts another; Easy bots finish every map too; a hazard, a
  fall and R each send you back; an online race between a host and a client finishes
  for both and both see the same finishers;
- the game boots into practice mode on every map without script errors;
- bots climb the Construction Site tower to a player standing on a high floor
  (`tests/run_bot_climb_test.sh`);
- a bot of every difficulty finds you and shoots, even Easy hits a player standing still, harder bots hit a moving player more often, the hard bots slide, dive, belly-slide, flip and grapple (and the easier ones never belly-slide), and Rematch starts a new match; a 5-player free-for-all against 4 bots, where every bot shoots, bots fight each other as well as you, the robots alternate, and the rematch keeps all 4 bots (`tests/run_bot_test.sh`);
- a match test: 3 copies on a laggy network play two matches back to back, aiming
  and shooting on their own; checks that hits land, the match ends at the kill target,
  every copy agrees on the results, and "return to lobby, play again" works;
- a sync test: 2 copies on a clean network, then 5 copies on a simulated bad network
  (100 ms latency, 60 ms jitter, 10% packet loss). Each copy moves on its own, and the test
  checks that every copy draws every other player within 15 cm of where they really were
  (95% of frames), with no visible pops, and that everyone notices when the host leaves.
  The 5-copy run fails now and then on a small test machine (five copies sharing four
  processor cores); `SYNC_DEBUG=1 python3 tests/check_sync.py tests/out/sync_*.log` prints
  where and when each pop happened;
- the sync, match and bot tests take a map: `MAP=testing_grounds tests/run_bot_test.sh`.
  `run_all.sh` spreads them over both maps;
- animation sync (`tests/check_anim.py`, part of the sync and match tests): every copy
  shows each other player doing the move they were really doing at that moment, shows
  each held move, and kicks their gun on every shot. The bot test checks the bot's body
  the same way.
- sound effects (`tests/run_audio_test.sh`): every sound file loads and every sound the
  code asks for exists (`tests/audio_test.gd`); in a bot match your own gun, reloads,
  steps and hit markers play, and the bots' shots, impacts and steps play placed in the
  world; online, each copy hears the other's shots and footsteps in the world.
- character sync (same checker): the copies play different robots, and every copy must
  show each player as the robot they picked. In the match test everyone picks again in
  the lobby between matches, and the new picks must show in the next match. The bot
  test checks the bot plays the robot you did not pick, and that with several bots they take turns through the robots starting with the other one.

## Debug menu

Press **F1** (or **`**) in Practice or Vs Bots for testing cheats: god mode, infinite
ammo, no cooldowns, noclip, game speed, teleports, changing robot and gun, adding and
freezing bots, and an FPS readout. It lives in `game/dev/debug_menu.gd`; the switches
are in `game/dev/cheats.gd`, whose checks all answer "off" in an online match, so a new
cheat should go through one of them.

## Developer command-line options

Pass these after `--`, for example `godot --path . -- --practice`. The full list is at the
top of `game/dev/dev_args.gd`. The useful ones:

| Option | What it does |
| --- | --- |
| `--practice` | Go straight into the arena alone |
| `--map=ID` | Which map: `construction_site` (the default), `office`, `kilnworks`, `castle`, `halcyon`, `cirrus`, `testing_grounds`, a race map (`rooftop_run`, `foundry`, `sky_ruins`, `summit_plunge`), or a map scene's path (`res://game/maps/my_map.tscn`). Works with `--practice`, `--bot` and `--host` |
| `--host` / `--join=ADDRESS` | Host or join straight away |
| `--name=NAME` | Player name for this copy |
| `--autostart=N` | Host starts the match when N players are in the lobby |
| `--net-sim=L,J,P` | Pretend the connection is bad: L ms latency, J ms jitter, P% loss |
| `--third-person` | Start in third person |
| `--spawn=X,Y,Z,YAW[,PITCH]` | Start at a given spot, facing YAW (degrees). Pick a spot that is clear on the map you use: start inside something and you fall out of the map |
| `--bot=LEVEL` | Go straight into a 1v1 against a bot (0 Easy, 1 Normal, 2 Hard, 3 Expert) |
| `--bots=N` | With `--bot`: play a free-for-all against N bots (1 to 4) instead of one |
| `--menu=PAGE` | Open the main menu on a page: `play`, `practice`, `bot`, `multiplayer`, `settings` |
| `--settings-tab=N` | Open Settings on a tab: 0 Controls, 1 Camera & HUD, 2 Audio, 3 Graphics (with `--menu=settings`, or in the pause menu) |
| `--pause-page=PAGE` | The pause menu opens on `loadout` or `settings` (pair with `--press=SEC:pause`) |
| `--hud=STYLE` | Use the `arcs` or `clean` HUD in both views for this run |
| `--manual-respawn` | Respawn only on a Jump or Fire press, as in a real game, even headless or with `--scripted-input` (which otherwise ask to respawn as soon as the wait is over) |
| `--save-killcam=N` | On the results screen, save best kill #N as a video straight away, into the game's own data folder (`user://killcams`) instead of Videos (tests) |
| `--fall=SEC` | Your player falls out of the arena after SEC seconds, to show the death screen |
| `--character=ID` | Play as `needle`, `vanguard`, `kestrel`, `bulwark`, `rivet`, `specter`, `orbit` or `templar` without changing your saved choice |
| `--weapon=ID` | Play with `pistol`, `shotgun`, `rifle` or `sniper` without changing your saved choice |
| `--bot-weapon=ID` | Give every bot this gun (normally each bot picks one at random) |
| `--switch-weapon` | With `--auto-return`: pick the next gun in the lobby between matches (for the match test) |
| `--press=SEC:ACTION` | Press an input action after SEC seconds, e.g. `--press=10:toggle_camera` (pairs with `--screenshot`) |
| `--hold=SEC:ACTION:DURATION` | Hold an input action down, e.g. `--hold=5:move_forward:3` |
| `--look=SEC:YAW,PITCH` | Turn your view by YAW and to PITCH (degrees) after SEC seconds, e.g. `--look=3:0,-60` to look down |
| `--speed=X` | Game speed, e.g. `0.25` for quarter speed (to film a move in slow motion) |
| `--game-clock` | Count the SEC of `--press`, `--hold`, `--look`, `--screenshot` and `--quit-after` in game time. With Godot's own `--fixed-fps 60` (before the `--`) a scripted run plays out the same however slowly the machine renders, so screenshots land on the right frame |
| `--kill-target=N` / `--time-limit=S` | Host: shorter matches for testing |
| `--rules=killcam` / `--points=N` | Host or `--bot`: a Killcam-mode match; `--points` sets the points to win (a lobby setting, so clients play to it too; default 5,000) |
| `--race` | With `--practice`, `--bot` or `--host` and no `--map`: race on the first race map (a race map in `--map` makes it a race anyway) |
| `--game=dm` | With `--practice`, `--bot` or `--host`: a Deathmatch (an arena map: `construction_site`, `office`, `kilnworks`, `castle`, `halcyon`, `cirrus`...) |
| `--map-event=SEC` | Start the map's events (Halcyon's low gravity) after SEC seconds, as if a terminal had fired them: for tests and screenshots |
| `--eager-terminal` | Bots go for a map terminal whenever one is ready and they have nobody to fight (normally they only try now and then) |
| `--autopilot` | Your own racer runs the course the way a bot does (race tests and screenshots) |
| `--bot-level=LEVEL` | With `--autopilot`: at this bot difficulty (default 3, Expert) |

## Maps

Maps are scenes you edit in the Godot editor: `game/maps/construction_site.tscn`,
`game/maps/office.tscn`, `game/maps/kilnworks.tscn`, `game/maps/rail_yard.tscn`,
`game/maps/lost_temple.tscn`, `game/maps/neon_arcade.tscn`, `game/maps/castle.tscn`, `game/maps/halcyon.tscn`, `game/maps/cirrus.tscn` and `game/maps/testing_grounds.tscn`. Double-click one in the FileSystem dock to open it.

The Castle is a good small example of a map with several height levels: a curtain
wall with a battlement walk at 6 m, four round corner towers at 12 m reached by
stone ramps laid along the wall walks, a gatehouse with a gate tunnel, and a
central keep whose upper floor (6 m) is reached from a terrace ramp and from the
west wall walk over a timber bridge, and whose roof deck (12 m) the keep stair
climbs to. Its palette (`palettes/castle.tres`) shows a breakable kind (the wooden
hoardings in the bailey). Its small dressing (a coping on every merlon, pilasters and
torches along the walls, door and window surrounds, the great hall's fittings, market
goods, ivy, weeds, and the lake and mountains outside) is the scene's `Dressing` branch,
about 2,000 drawn-only blocks written by `python3 tools/arena/castle_dressing.py`. The
script reads where the merlons, barrels, crates, carts and hoardings are, so run it
again after moving them; it replaces only the `Dressing` branch and leaves the rest of
the scene as it is.

`game/maps/castle_v2.tscn` (test map `castle_v2`, "Castle 2") is a refreshed Castle:
72 m across instead of 60, a wall walk that runs all
the way round over flush corner bastions, a stair up each wall with a landing from
its head into the bastion, a keep with doors on
every side and ramps inside, four bridges from the keep to the walls, and in each
quarter a climb chain (2.2 m, then 4.2 m) up to a bridge. Two scripts first wrote it. The
layout (everything solid, the spawns and pickups) comes from
`godot --headless --path . --script tools/arena/castle_v2_blockout.gd` (the numbers are
at the top). The detail on top comes from
`godot --headless --path . --script tools/arena/castle_v2_dressing.gd`: about 1,500
blocks (copings, pilasters, torches, door frames, the hall's fittings, a
canopy and its goods in each quarter, paint on the ground, a jetty outside). Nearly
all are drawn only. About 100 are solid (the ones the script wraps in `hard()`): the
canopy roofs with their beams and brackets, the counters, racks, troughs and basins
under them, the well head, the market booth's awning, the crane jib, the hall's
benches and fireplace, and the gatehouse winch. A canopy roof slopes 33 degrees from
4.3 m at the wall to 3.45 m, so you can stand on it and ledge-climb from its top to
the wall walk. The spawns and pickups are where the block-out put them. Each quarter has a colour (stables gold,
training yard red, well court blue, market green) that its bastion flag, the keep's
banners and the pennants under the bridges repeat, so you can tell which way you face
in a map that is the same on all four sides. The dressing script removes its own
earlier pieces first (they carry the meta `dressing`), so it can be run again; the
block-out script starts over from the old Castle. The scene is edited by hand now
(blocks were moved in the editor), so both scripts refuse to run unless
`CASTLE_V2_REBUILD=1` is set: a run would throw the hand edits away. Try the map with
`--map=castle_v2 --practice`.

**What a map is made of.** The root node is a `MapRoot`. Under it:

- **MapBlock** nodes: every floor, wall, crate and girder. A block is a box, cylinder,
  tube or cone with a **Kind** (its colour from the map's palette). A cone's Size is the
  diameter of its foot and its height; **Top** is the diameter at the top (0 comes to a
  point), and it collides as the same flat-sided shape you see. Its inspector also has
  **Size**, **Solid** (off = drawn only, like paint on the floor), **Drawn** (off = an
  invisible wall, shown in the editor as a faint blue box), **Tint** (to make one block
  a little lighter or darker), **Material Type** (what it is made of: its footsteps and
  how it breaks; see below) and a **Breaking** section (see "Breakable walls and floors").
- Plain **Node3D** groups. Each object (a container, a staircase, the crane) is a group
  grouped the Godot way (the group icon beside it in the Scene tree), so a click in the
  3D view selects the whole object. To change one part, pick the part in the Scene
  tree, or select the object and press Ungroup in the 3D toolbar (next to the lock).
- **MapSpawn** nodes (under `Spawns`): where players appear. The green figure shows
  which way they face. Keep at least 8 (5 on a race map: they are the start line).
- **MapDummy** nodes (under `TargetRange` in the Testing Grounds): target dummies. The
  orange figure shows which way the dummy faces; the inspector picks its robot, its gun
  and the caption over its head (the Testing Grounds ones give the distance).
- **MapWeaponSpawn** nodes (under `WeaponSpawns`, on the Construction Site, the
  Office, the Kilnworks and the Castle): Deathmatch weapon pickups. Stand one on a floor and pick its **Weapon** in the
  inspector; in a Deathmatch that weapon floats a metre above it, bobbing and turning,
  until someone walks through it, and is back 10 s after (`Match.PICKUP_RESPAWN`). Other
  games leave the spot empty. The orange ghost and label are editor-only.
- **MapTerminal**, **GravityEvent** and **MapSpinner** nodes (Halcyon): a console players
  press Interact at, the event it sets off, and scenery that turns. See "Terminals and
  map events" below.
- **MapIsland**, **LayoutEvent** and **MapJumpLink** nodes (Cirrus): a group of blocks
  that flies, the clock that rearranges the islands, and a crossing bots are told how
  to make. See "Maps of flying islands" below.
- **Label3D** nodes: signs and painted floor numbers.
- **Environment** (sky, ambient light) and **Sun**: ordinary Godot nodes, so the editor
  shows the map lit the way the game does.

**Editing.** Move, turn and duplicate (Ctrl+D) blocks like any node. To resize a block,
drag one of the red handles on its faces: that face moves and the opposite one stays
put. Sizes snap to 0.1 m, or whole metres while you hold Ctrl. You can also type the
Size in the inspector, or use the scale tool (scale is folded into the size in the
game). A block or group you hide with the eye icon is left out of the game.

Colours live in the palette (`game/maps/palettes/*.tres`): change one there and every
block of that kind changes. To add a kind, add an entry to the palette's Colors, then
type its name into a block's Kind. A colour whose alpha is below 1 makes the kind
see-through (Halcyon's dome and windows): you look through it, but it is as solid as
any block. The palette's **Surface** list gives a kind a pattern drawn on every surface
of that kind with no extra blocks (Halcyon): `panels` (seams on walls, now and then a
hatch or vent slots), `panels_plain`, `tiles`, `plates` (rivets), `grating`, `slats`
(a vent), `hazard` (slanted stripes), `treads` (grip lines across a ramp),
`corrugated` (shipping containers), and for buildings and the outdoors: `checker`,
`pavers` and `slabs` (floors), `bricks`, `blocks` and `blocks_small` (dressed stone; on a
floor, flagstones), `cobbles`, `planks` and `planks_upright`, `shingles` and `thatch`
(roofs), `grass`, `dirt`, `gravel` and `tarmac` (soft blotches), `clumps` (leaves),
`bark`, `strata` (a cliff), `water` (ripples that move), `confetti` (an arcade carpet)
and `windows` / `windows_lit` (rows of windows on far-off buildings). The patterns are settings of one shader,
`game/arena/map_surface.gdshader`, listed in `MapScenery.SURFACES`; they are measured
in metres from where the surface is in the map, so they line up from block to block. A
kind that glows or is see-through takes no pattern. The MapRoot's inspector also has the map's rules:
**Bounds** (leave it and you are out; drawn as a red rectangle), **Kill Height** and the
**Swing Point** the test player hooks.

**Breakable walls and floors.** A palette's **Breakable** list names the kinds that can
be broken and how much damage a piece of each takes (a pistol shot is 25; below 50 a
whole pane shatters at once, for glass). Blocks break only in arena matches, never races.
Each block's **Breaking** section decides for that block:

- **Breakable**: *Default* follows the palette, *Yes* breaks even if the kind is not in
  the list, *No* never breaks (a landing or a floor a route needs). Maps saved with the
  old **Unbreakable** tick load as *No*.
- **Break Settings** (a `BlockBreakable` resource; empty = the palette's numbers, per
  cell). **Block Health**: the damage it takes (0 = the kind's toughness, or 100 if the
  palette has none). **Break Mode**: *Per Cell* cuts a thin wall or floor (at most 0.6 m
  thick, at least 7 m² of face, box-shaped) into about 2 m pieces that each have that
  health; thicker blocks set to Yes warn in the editor and stay whole. *Whole Block* gives
  the block (any size or shape: a crate, a pillar) one pool of health and breaks it all
  at once; what rests on it stays where it is. Save the resource as a `.tres` to share
  it between blocks. New break settings belong in `game/arena/block_breakable.gd`.

Per cell, pieces near a spawn, and pieces that something else rests on, hangs from or
passes through, never break; thin drawn-only blocks lying flat on a breakable one (a
ceiling under a floor, a rug, a lamp strip, frosting on glass) break along with it. A
whole block only keeps the spawn rule. The bots' navigation mesh is not rebuilt when
something breaks. The code is `game/arena/map_destruction.gd`.

**Materials.** A block's **Material Type** (concrete, metal, wood, glass, dirt, rubber)
sets the footsteps on it and the crash, rubble and dust when it breaks. Left blank, it
comes from the palette's **Material** list (kind -> material), else from the kind's name
(`glass`, `plank`/`crate` -> wood, `steel`/`girder` -> metal...). The table is
`game/arena/block_materials.gd`: for now most materials reuse the step and break sounds
at another pitch, so real sounds can drop in there later without touching any map.

**Trying it.** With a map scene open, press **F6** (run current scene): the game starts in
practice mode on that map. In the game, all blocks of one kind are merged into a single
mesh and the bots' navigation mesh is worked out from the solid blocks, so moving
things needs no extra step.

**Checking it.** After moving things on the Construction Site, run `tests/site_test.gd`:
it tells you if a route no longer works or a bot can no longer reach a floor. The test
keeps its own note of where the routes are (at the top of `tests/site_test.gd`), so if
you move the lift shaft or a climbing crate on purpose, change its numbers there too.
The same goes for the Office and `tests/office_test.gd`, and the Testing Grounds courses
and `tests/course_test.gd`.
`tests/map_scene_test.gd` checks that every map loads, has a colour for every block and
has enough spawn points.

**A new map.** Make a scene with a MapRoot root (or duplicate an existing map and strip
it down), give it a palette, add blocks, spawns, a WorldEnvironment and a sun. F6 plays
it straight away. To put it in the menus, add a line to `LIST` in `game/arena/maps.gd`.
To offer an arena for Deathmatch too, give it `"also": ["dm"]` there and add
MapWeaponSpawn nodes; `tests/deathmatch_test.gd` checks every Deathmatch map has at
least 8 pickups of 10 or more different weapons, each over a floor with room to stand,
and that all the Deathmatch maps together offer every weapon.

The scripts behind this:

| File | What it holds |
| --- | --- |
| `game/arena/maps.gd` | The list of maps (id, name, scene). Add a map here and it shows up in the menus |
| `game/arena/map_root.gd`, `map_block.gd`, `map_spawn.gd`, `map_palette.gd` | The node types above; `MapRoot.build()` turns the blocks into collision and meshes |
| `game/arena/map_mesher.gd`, `map_scenery.gd` | One merged mesh per kind, the materials, the navigation mesh |
| `game/arena/map_destruction.gd` | Breakable walls and floors: which pieces break, their collision and cracks, rubble |
| `game/arena/map_terminal.gd`, `map_event.gd`, `gravity_event.gd`, `world_gravity.gd` | The console players press Interact at, the event it fires, and the one gravity multiplier all movement reads |
| `game/arena/map_spinner.gd` | Scenery that turns (never solid) |
| `game/arena/map_surface.gdshader` | The patterns a palette's Surface list draws on a kind (panel seams, tiles, grating, hazard stripes...) |
| `addons/map_tools/` | The editor plugin: resize handles, click-to-select, the bounds outline |

To render pictures of a map without opening the game:

```
tools/map_preview.sh construction_site OUT_DIR --shots="sw;top;cut7.5;-24,1.7,35:0,13,0:75"
```

Shots are corners (`sw`, `ne`, ...), `top` (a plan), `cutY` (a plan with everything above
height Y sliced off, to see one floor) or a camera `x,y,z:look-x,y,z:fov`. The map can
also be a scene path (`res://game/maps/my_map.tscn`). A plan shows 92 m from top to
bottom; `--span=150` fits a map the size of Halcyon (`--shots="cut5.9;cut-0.6"` are its
main and lower decks). On a map with a LayoutEvent every island is shown at its
home; `--layout=SET,KIND,VARIANT,LOOK` shows one of its arrangements instead (SET 1..:
which islands are up; KIND 0 Swap, 1 Drift, 2 Close, 3 Far, 4 Split; LOOK 1 = sunset),
`--layout=A:B:0.5` half way through the move from arrangement A to B, and
`--layout=A:B:warn` the end of the warning before it.

### Rail Yard, Lost Temple and Neon Arcade

These three arenas were laid out by `tools/arena/build_arena_maps.py` (one file per map
in `tools/arena/`, the scene writer in `tools/arena/arena_builder.py`). They are ordinary
map scenes, grouped one object per group like the others, so edit them in the editor.
Running the script again (`python3 tools/arena/build_arena_maps.py rail_yard`) rebuilds a
map and its palette from scratch and overwrites hand edits. After moving things,
`godot --headless --path . --script tests/arena_maps_test.gd` checks that every spawn is
clear, walls and floors still break, and a bot can walk between every spawn point and to
each map's floors (the goals are at the top of the test).

Each map file ends with a `details(m)` function: the small things (window frames, lamps,
signs, pipes, weeds, vines, the street outside the arcade). They are all drawn only, so
they change neither collision nor the bots' navigation. The builder has helpers for them:
`strip` (a box), `on_wall` (a piece that stands proud of a wall face), `rod` and `pipe`
(bars at any angle), `sign`, and `stairs(..., cheek_stop=)` for stair sides that stop
short of a landing. The rules they keep, which `tests/map_flicker_test.gd` checks:

- Two surfaces of different colours never share a plane. A detail stands proud of the
  surface behind it, and one laid over another is both a different depth (2 cm or more)
  and a different outline, so their fronts and their edges are in different planes.
- Paint on a floor is 2 cm thick or more, and each kind of paint has its own height.
- A box that wraps a post (a collar, a cap) ends below the post's top.
- On a wall or floor that breaks, a detail is a thin skin (0.15 m or less) lying
  inside one panel's outline, so it breaks with the panel. Anything bigger, or
  anything that spans two panels, would hold the wall up: stand it on its own posts.

### Halcyon

`game/maps/halcyon.tscn` is the inside of a colony ship, the biggest arena (140 x 140 m,
up to 16 players) and the only one that is sealed all round: a round Control Room in the
middle under a glass dome, four spoke corridors to four tall rooms (Hangar north,
Hydroponics east, Engineering south, Cargo Bay west), an outer ring corridor joining
them through three corner sections and the Cryo zone, and a lower maintenance deck (-6 m)
under the spokes and the ring. The tall rooms run from the lower deck's floor up to
26-30 m, with decks about every 7 m and plenty to hook. The reactor pit in Engineering
is the only hazard: it drops below the map's Kill Height (-16 m).

It was laid out by `python3 tools/arena/build_arena_maps.py halcyon` (the layout is
`tools/arena/halcyon.py`: the four spokes are one spoke turned, three ring corners one
corner mirrored). Like the other generated arenas the scene is an ordinary map scene and
is what you edit from here on; running the script again rebuilds it from scratch and
**overwrites hand edits**. After moving things, `godot --headless --path . --script
tests/halcyon_test.gd` checks the spawns, the routes and that the hull is still sealed
(the places it walks to are at the top of the test).

Things to keep true when editing it:

- The dome, the floor glass and the hull windows are the kind `glass_hull`, which is not
  in the palette's Breakable list (and they are ticked Unbreakable too). The glass
  that breaks is `glass_pane`; a pane only breaks if nothing rests on it, so they stop
  a little short of the lintel above.
- In low gravity a jump reaches 4 m. Every room has a ceiling and the hull has no gaps,
  so nobody gets out; keep it that way when you open a wall.
- Wall and floor details (each place's "Details" group: ribs, vents, wall displays,
  conduits, ceiling beams, floor lines, grates, hazard stripes) are drawn only: Solid
  is off on every one, and none stands more than 0.3 m off its surface, so nothing
  snags a wall run, a slide or a swing. Keep new ones the same. Panel seams, tiles,
  grating and stripes are not blocks at all: the palette's Surface list draws them.
- A light bar or colour band along a wall stops at every doorway and window (in a
  round room it is made of straight pieces, one per wall piece, for that reason). The
  Halcyon test fails if one hangs across an opening.
- Two surfaces of different kinds (or tints) in exactly the same plane flicker. So a
  room's floor stops at its wall under a doorway (the doorway's threshold is the floor
  there), a wall has no sill under an opening that starts at the floor, and corridor
  walls end inside a room's wall, not flush with its face. Paint on a floor goes in
  layers so no two share a height: grates 12 mm thick, lines 20 to 24 mm, hole rims
  30 mm, hazard stripes 40 mm, words 60 mm up. Wall pieces differ in how far they stand
  off the wall. The Halcyon test checks the floors.
- Words on a floor are Label3D nodes lying flat with Shaded on, so they take the
  room's light (and go blue with it in low gravity).
- No spawn point or weapon in the Control Room, and no spawn point that can see the dais.
- Lighting is the ambient light, a soft shadowless "sun" and the glowing kinds (each
  room has its own accent kind: `accent_cyan` and so on). There are no light nodes, so
  it looks the same on every renderer. The sky is `game/maps/sky/halcyon_sky.gdshader`.

### Cirrus

`game/maps/cirrus.tscn` is a university campus on floating islands, open to the sky, for
up to 16 players: the quad in the middle (a round lawn about 29 m across, with the
clock tower on it: nine flights of stairs up to the belfry at 26 m, under a tall slate
spire), five building islands round it (Observatory, Labs, Lecture Hall, Cafeteria,
Library), five stepping stones just off the quad's rim, and nothing underneath: the
Kill Height is -45 m. There are **no walkways**: an island's tip is 24.4 m (80 ft) of open
sky from the quad's rim, and neighbours are as far apart. That is beyond a jump with a
dive or a flip, within reach of the whole chain (flip, dive and glide: 26 m), and easy
for the grapple or the rocket boots. A banner mast on each island's tip and five on the
quad's rim are grapple points. Floors are 5.5 m apart and the main halls are two floors
high. There is no writing anywhere on it: each building is told by its colour and its
shape (the Observatory's copper dome, the Labs' glass wall and roof stacks, the Lecture
Hall's shell roof, the Cafeteria's striped awning, the Library's columned porch).

The scene has all five islands at their homes (about 135 m across), and that is what
you edit. **In a match only two are up at a time**, and the clock changes which, every
60 s for the whole match:

- A clock ticks quietly the whole time, and the clock faces' long hands count the
  minute down.
- At 60 s the bell tolls and there are 8 s of warning. The islands that are about to
  go are doomed: their engines and lamps turn red and sputter, they sag, and anyone
  standing on one feels it shake. Nothing else moves yet: the time to get off.
- Then, for 4 s, the doomed islands fall away below the map (whoever is still on one
  goes under the Kill Height with it: a fall, nobody's kill), an island that is in
  both pairs glides to its new place carrying its riders, and new ones rise out of the
  clouds. A clunk when they have arrived. Afternoon and sunset change places each time.
- What comes next is drawn at random a turn ahead: never the same pair twice running
  (so at least one island comes up fresh) and never the same kind twice running.
  The kinds: **Swap** (each at its home), **Drift** (each 36 degrees round the quad),
  **Close** (each 12.2 m nearer: a jump from the quad), **Far** (each 9.1 m further
  out, and both 7 m up or both 9 m down) and **Split** (one 8 m up, one 8 m down).

Players are only put on islands that are up and staying; when there is none (both are
on the move) on the quad, which has five spawn points of its own. Pickups go down with
their island and come back with it. In the team modes (Search and Destroy, Capture
the Flag) the clock does not run and all five islands stay up, because their bomb
sites and flag stands are fixed spots. How it works is under "Maps of flying islands"
below.

It was laid out by `python3 tools/arena/build_arena_maps.py cirrus` (the layout is
`tools/arena/cirrus.py`; one island function, five building functions). Like the other
generated arenas the scene is what you edit from here on, and running the script again
**overwrites hand edits**. After moving things, `godot --headless --path . --fixed-fps 60
--script tests/cirrus_test.gd` checks it.

Things to keep true when editing it:

- Nothing stepped, stacked or cube-shaped where a slope or a curve belongs: roofs are
  wedges, cones and domes; trims, furniture and posts are bevelled; trees are round
  clumps; stairs are closed in by sloping sides over an invisible ramp, so the zigzag of
  the steps never shows. The game's surface patterns are drawn twice the size and under
  half as strong here (the palette's **Surface Scale** and **Surface Strength**).
- Everything on a building island goes inside that island's MapIsland node (blocks,
  spawn points, pickups, its mast and its two crossings), or it is left behind when
  the island moves.
- **Decor**: each building has a Decor group and each plaza and the quad a Garden
  group (about 2,500 of the map's 5,283 blocks). Small things are drawn only, so you
  walk and shoot straight through them: chairs, stools, armchairs, rugs, pot plants,
  shrubs, flower beds, hanging baskets, ivy, books, pictures, screens, glassware and
  every light. Big things are solid cover: shelves, counters, workbenches, desks,
  cabinets, benches, the planter boxes and tree tubs. Keep it that way, and keep
  solid pieces out of the walking lanes, off spawn points and pickups, and off the
  middle of each island's tip, where people land, and at least 4 m from the quad's
  masts (a lamp post 2 m from one knocked a player landing off the grapple right off
  the lawn). Ivy is round clumps lying on the
  wall, never flat rectangles. Lights are the kind `lamp`, so they come on at sunset
  with the windows and go red on a doomed island.
- Spawn points are on the building islands, plus the five on the quad's lawn for when no
  island has room. None on the tower or a stone.
- An island's line from the quad (and the line 36 degrees either side of it, where it
  stands when it has drifted) is kept clear on the quad's rim: bots set off along it.
  The quad's masts are 18 degrees to one side of each island's line, the stepping
  stones 18 degrees to the other.
- Nothing may stand above the fog (-34 m) under an island at its lowest (9 m down), and
  the Kill Height must stay below that and far above a parked island (-120 m).
- Stairs the bots must use: 2 m wide or more, no steeper than 31 degrees (5.5 m up in
  9.2 m), steps of 0.25 m or less, 2 m of clear floor before the foot and beyond the
  head, nothing narrower than 2 m on the way, and the hole in the floor above starting
  only where the stair still has 2.4 m of headroom. A stair that breaks one of these is
  walkable for a person and missing from the navigation mesh.
- The clock tower's stair winds up over itself, so the MapRoot has **Winding Floors**
  ticked: the navigation mesh is then cut up a way that keeps such a stair (leave it
  off on other maps: the usual way makes tidier paths in the open).
- Bots cannot get round this map without the grapple, so the MapRoot has **Bots
  Grapple** ticked: every bot carries it here, whatever it was dealt.
- Only the Labs' glass (`glass_lab`) breaks. Its panes ride the island like the walls.
- The sky, the cloud sea and the ringed planet are `game/maps/sky/cirrus_sky.gdshader`;
  the LayoutEvent turns its `sunset` and `swirl` up and down. The Environment's fog is
  height fog only (nothing above -34 m is touched): it is what a falling island
  vanishes into.

### Terminals and map events

A **MapTerminal** is a console players use by pressing **Interact** (`interact` in
`Settings.ACTIONS`; G by default, rebindable like any key). Halcyon's stands on the dais
in the Control Room. The rules, which the host decides:

- stand within its **Range** (2 m) and press Interact: one press sets it off;
- it cannot be used while its event is running or cooling down, and a press made then
  does not count later: it takes a new press once it is ready.

A terminal can ask for a hold instead: give its **Channel Time** some seconds (it is 0
by default). Then Interact must be held that long; letting go cancels, and so does
leaving the range (walking off, or being knocked out of it) or dying, while taking
damage does not; and it belongs to one player at a time.

Nothing about it is on the HUD. A ring of light over the console pulses gently when it
is ready, flashes full when someone sets it off (through a hold it fills round in blue,
for everyone to see), and sits dim while it is locked; a hum winds down as it goes off.

Its **Event** points at a **MapEvent** node in the same scene. The one kind a terminal
sets off is **GravityEvent** (Halcyon's `LowGravity`): gravity eases down to **Gravity Scale** (0.3)
over **Ease Time** (2 s), stays there for **Duration** (30 s), eases back, and the
terminal stays locked for **Cooldown** (60 s) more. While it runs every light in the map
fades to a deep blue, a soft chord swells in, motes of light drift through the boxes
listed in **Mote Volumes**, and the map's MapSpinners turn at **Spinner Speed** (half).
All of that follows the same curve as the gravity.

How it works underneath:

- `WorldGravity.scale` is the one gravity multiplier. `MovementController` and
  `Grapple` multiply by it wherever they use gravity (falling, swinging, slides
  downhill, and the wall run's and glide's own gravity, scaled the same), so the
  tuning resource's `gravity` (22) is never changed. Rockets and grenades do not read
  it. The arena puts it back to 1.0 when a match starts and when the map is unloaded.
- The host owns the terminal and the event. A player's copy only says when its player
  presses and lets go of Interact there (`Net.terminal_hold`); the host checks the range (and
  the timing, for a hold) and tells everyone the terminal's state and the event's clock
  (`Net.send_terminal_state`, `Net.send_map_event_state`), again every few seconds, and
  to anyone who joins mid-match (`Net.request_map_state`).
- Bots press at a terminal through the same `PlayerInput.interact` a person does.

**To put a terminal on another map:** add a GravityEvent node (a plain Node with
`game/arena/gravity_event.gd`) to the map scene and set its numbers; add a Node3D with
`game/arena/map_terminal.gd` where the console stands (on a floor; build the console
itself from MapBlocks round it) and point its Event at the GravityEvent; fill in Mote
Volumes if you want motes. Nothing else needs changing: the arena, the network and the
bots find them in the scene. A different kind of event is a script that extends
`MapEvent` and fills in `length()` and `_update()`. An event that leaves something
changed after it ends (a LayoutEvent's layout) keeps it in `state`, which the host
sends along with the clock; `_on_match_started()` is where it puts things back.

A **MapSpinner** is a group of MapBlocks that turns round its own y axis (tip the node
over for another axis): Halcyon's centrifuge ring, outside the hull. It is decoration
only: drawn, never solid, and each copy of the game turns it by its own clock. That is
why it is not a MapMover (a mover is solid, carries riders and runs off the race clock,
so plain movers are for race maps; in an arena the one kind of mover is a MapIsland,
below, which runs off its LayoutEvent's clock). MapHazard is race-only too, so
Halcyon's pit uses the Kill Height and its decks are joined by fixed ramps.

### Maps of flying islands

Three node kinds, all in `game/arena/`, none of them tied to Cirrus:

- **MapIsland** (`map_island.gd`, a MapMover): a group that flies. Where it sits in the
  scene is its home; a LayoutEvent can stand it anywhere round **Pivot** (so many
  degrees round, so many metres up, so many metres out) or park it far below the map,
  hidden and with nothing to bump into. In the game it is one moving body, whatever is
  in it: blocks, spawn points, weapon and power-up spots, grapple points, jump links
  and breakable glass all ride along. `up` says people can be on it, `doomed` that it
  goes down at the next move.
- **LayoutEvent** (`layout_event.gd`, a MapEvent, no terminal needed): a clock that runs
  for as long as a match does. Each turn: **Hold Time** (60 s), a tick or a tock every
  second (quiet everywhere, a little louder near **Tick From**); then the bell and
  **Windup Time** (8 s) of warning, in which the doomed islands' engines and **Doom
  Kinds** (lamps) turn **Doom Color** and sputter and they sag by **Doom Dip**; then
  **Move Time** (4 s): doomed islands fall **Down** metres, staying ones glide, new ones
  rise. **Up Count** (2) islands are up at a time. The pool it draws from is under
  **Arrangements**: Drift's turns, how far Close comes in and Far goes out, Far's
  heights, Split's height. It also blends the look (the second look's sun, ambient
  light, fog colour and **Lit Kinds**), and during the warning and the move the camera
  rumbles, the **Flare Kinds** (engines) burn bright, the clouds swirl and scraps of
  paper blow through the **Scraps** box. Nothing is on the HUD. MapSpinners with
  **Driven** set to Countdown are clock hands it turns (once round per turn, at twelve
  when the bell goes); one set to Swing is the bell, which it rocks.
- **MapJumpLink** (`map_jump_link.gd`): tells bots how to cross where the navigation
  mesh has no way. **How** is Grapple (hook, ride the rope, let go) or Leap (run off
  toward the landing). **Hook** names what to hook, or **Hook Group** says "the nearest
  node of this group" (a hook found that way may have a child called Land: the
  landing). **Landing** is where it comes down (empty: the link itself). With **Round
  From** and **Round Radius** the takeoff is worked out: on a round floor, facing
  wherever the landing is just now. **Leaves** marks a crossing that leads off its
  island: the only kind bots may take from a doomed island. A link on an island that is
  down or on its way cannot be used. Bots use one only when walking will not get them
  where they are going, and will take two in a row (island to quad, quad to island).

(**MapSpan**, a walkway that runs out and draws in, is still in `game/arena/` from the
first version of Cirrus. No map uses it now.)

How it works underneath:

- The host owns the LayoutEvent: it starts the clock when a match starts, keeps it, and
  decides every arrangement a whole turn ahead (`pick_first`, `pick_after`). An
  arrangement is one small number (`LayoutEvent.pack`: which set of islands, which
  kind, a throw of the dice, the look), and `state` holds the present one and the next
  one together. Every copy places the islands from the clock and that number alone, so
  they are in the same place for everyone, also for someone who joins part-way
  (`Net._map_state_request`), and everyone knows which islands are doomed. With the
  clock stopped every island is up at its home. It never runs in a team mode.
- `MapRoot.update_movers()` moves each island's body in the physics step, and its node
  with it, so everything inside rides. Each copy of the game moves its own player, so
  riders are carried by the engine's moving-platform handling; the player's view turns
  with the island. Other players are drawn a little in the past, so their positions
  are carried through `MapRoot.carried()` to where the island is now. Pickups follow
  through `move_to()`. A grapple hook stays on the body it hit (`Grapple.carrier`).
- Someone on a doomed island is not killed by the event: the island carries them under
  the Kill Height, and the arena's ordinary falling-out-of-the-map check does the rest.
- `MapRoot.open_spawns()` is what the arena picks a spawn point from: those on islands
  that are up and not doomed, else those on ground that never moves. When the clock
  first starts, anyone standing on an island that is not in the first pair is put back
  at a spawn point (`LayoutEvent._rescue`).
- Breakable pieces inside an island are built as children of its body
  (`MapDestruction.add_riding`), so they break as usual wherever the island is.
- The bots' navigation mesh is baked once per arrangement: again when a move settles
  (well under a second), kept, and thrown away when something breaks. Parked islands
  are left out of it. While the map moves or the new mesh is not ready
  (`MapRoot.shifting`, `nav_pending`), bots stand where they are and keep fighting.
  During the warning a bot on a doomed island (`MapRoot.doomed_at`) drops everything
  and makes for the crossing that leads off it. On a map with drops bots also check
  for floor ahead before a dash, a hop or a dodge.

**To make another map of flying islands:** put each part that flies in a MapIsland at
its home; add a LayoutEvent and set its times, its pool and the second look; give every
island a MapJumpLink off it (Leaves ticked) and one onto it, with grapple points to
hook; put a few spawn points on ground that never moves; tick Bots Grapple. Then check,
as the Cirrus test does, that the grapple crosses in every arrangement and that
nobody who stays on a staying island ends up inside geometry.

### Race maps

`game/maps/rooftop_run.tscn`, `foundry.tscn`, `sky_ruins.tscn` and `summit_plunge.tscn` are ordinary maps
(MapBlocks in groups, so one click picks a whole piece and F6 plays it as a race) with
four more node types:

- **MapCheckpoint** (under `Checkpoints`): a gate. **Number** says the order (1, 2, 3...),
  **Finish** marks the last one, **Opening** is its width and height. Racers must pass
  them in order; the one before is where you come back to.
- **MapHazard**: a MapBlock that sends you back to your checkpoint when you touch it
  (molten metal, live wires, the presses). Same Size, Kind and Solid as any block.
- **MapMover**: a group that moves. Its blocks ride along (and carry whoever stands on
  them). **Travel** is how far it goes and comes back, **Period** how long the round
  trip takes, **Hold** how long it rests at each end, **Spin** turns it (degrees a
  second, for the sweeper arms) and **Phase** staggers it against its neighbours.
  Everyone sees them in the same place: they run off the race clock.
- **MapRoutePoint** (under `BotRoute`, in running order): the line the bots take, and
  what they do at each point (run, jump, long jump, dive jump, flip dive, slide, crawl,
  wall run, wall jump, chimney, grapple to the point plus Aim, wait for ground, wait for a
  clear path, boost jump, boost up, glide jump). **Boost** on a grapple or glide-jump point
  also fires the rocket boots toward the next point (as it lets go of the rope, or in
  the glide). If you move an obstacle, move its route points with it.

Falling below **Kill Height** sends you back too. A map counts as a race map when it has
checkpoints; `game/arena/maps.gd` lists each map with its game, `ffa` or `race`, and the
menus only offer a map for its own game.

The four courses were laid out by `tools/race/build_race_maps.py` (the sections are in
`tools/race/sections.py`: gaps, vaults, climbs, wall runs, chimneys, grapples, pistons,
presses, sweepers, and the ones built for the newer moves: rocket gaps, boost-up walls,
glide gaps, ski jumps, grapple swings and belly-slide chutes, with the distances each
move covers at the top of that part of the file). Edit a map in the editor and the
change is yours to keep; running the script again rebuilds them all from scratch and
overwrites hand edits. To try a section on its own, build the test strip
`race_lab` (`LAB='[["boost_gap", {"d": 20}]]' python3 tools/race/build_race_maps.py race_lab`,
any sections and arguments) and race it with `--map=res://game/maps/race_lab.tscn --autopilot`.
After changing a course, `MAPS=<map id> tests/run_race_test.sh` checks that bots still get round.
`game/match/race_state.gd` (the `Race` autoload) runs the race rules and
`game/bot/race_brain.gd` the race bots.

## Tuning movement

All movement numbers are in `game/player/movement/movement_tuning.gd`, each with a comment
saying what it does. Change a number, press F5, and feel the difference. Tell me what
feels off and I will tune it with you.

## The robot models and their animations

The player robots are built by code, not drawn in a modelling program, so they can be
changed by editing numbers and rebuilding. Every character shares one skeleton and one
set of animations; only the shape differs. Everything is in `tools/robot/` (needs
python3 with numpy):

| File | What it holds |
| --- | --- |
| `designs.py` | Each robot's shape, and the materials. `PLAYABLE` lists the ones built for the game (Needle, Vanguard, Kestrel, Bulwark, Rivet, Specter, Orbit, Templar); the unused draft, Brick, is kept |
| `rig.py` | The skeleton (bone names and positions) and the pose solver |
| `animations.py` | Every animation, written as key poses: body clips and first-person arm clips |
| `weapons.py` | The four guns' shapes and materials (pistol, shotgun, rifle, sniper), and where the left hand holds each long gun |
| `weapon_anims.py` | The long guns' own clips: how each is held, carried when sprinting, fired (pump, bolt), reloaded, and the first-person arm poses for each |
| `build.py` | Writes, for each playable robot, `game/player/robot/NAME.glb` (full body) and `NAME_arms.glb` (first-person arms and guns) |

After changing any of them:

```
python3 tools/robot/build.py
godot --headless --path . --import
```

To look at the result without opening the game (these render on a machine with no
graphics card, so I can check poses myself):

- `python3 tools/robot/sheet.py OUT_DIR run sprint:8 death:6:0:1.3` renders side and
  front contact sheets of clips (name, frames, start and end time). Add
  `--glb game/player/robot/vanguard.glb` to look at another character.
- `tools/robot/preview.sh JOB.json` renders any set of robots, poses and camera angles
  described in a job file; the format is at the top of `tools/robot/preview.gd`. It can
  also drive a robot with the game's real animator from made-up movement.

In the game, `game/player/robot/` holds the code: `robot_animator.gd` decides what the
body shows from the movement state (the same way for you, other players and the bot),
and `view_model.gd` does the first-person arms.

**Guns.** Every model file holds all four guns; `RobotModel` keeps only the picked one's
mesh parts (the materials are named `GUN.KIND`, e.g. `rifle.accent`). A long gun's clips
are the base name plus the gun (`aim_rifle`, `fp_reload_shotgun`, `fire_sniper`); the
game falls back to the plain (pistol) clip when a gun has no version of one. Each gun's
shots leave from its own marker bone (`muzzle_shotgun`, ...). The numbers for every gun
are in `game/combat/weapon_data.gd`. The akimbo pistols are the one weapon in two hands:
the left gun rides on its own bones in the left fist (`pistol_l`, `pistol_l_slide`,
`pistol_l_mag`, `muzzle_akimbo_l`; pose specs move them with `pistol_l`, `slide_l` and
`mag_l`), the shots alternate between `muzzle_akimbo` and `muzzle_akimbo_l`
(`WeaponData.muzzle_bone_left`), and `fire(left)` kicks only the arm that fired. A model made in Blender later can
replace the .glb files as long as it keeps the same bone and clip names.

**Your own body in first person.** The arms and gun you see are the separate arms
model on the camera (`view_model.gd`). The legs and torso are your real body: the same
skeleton and the same animator everyone else sees, drawn for your camera by a second
mesh with the head and arms left out (`RobotModel.add_view_mesh`; the full mesh stays
hidden from your camera and only casts your shadow). Three things make it look right
from inside, all in `robot_animator.gd` and switched by `first_person`:

- The torso stays upright under the camera instead of leaning with your aim or with
  the run, and `place_for_view` keeps the neck just below and behind your eyes, sliding
  the body back as you look straight down so you see your legs and not the inside of
  your chest.
- A move whose normal animation would look wrong from inside has a second version
  made for the camera, named `view_` plus the clip's name (`view_flip_back`,
  `view_slide`, `view_roll`...). When one exists it is played for you instead; everyone
  else still sees the normal clip, and `animator.source` reports the normal name. The
  flips are the main case: the body does not turn over in front of a level camera, the
  legs tuck and sweep through the view instead.
- To add one, write the function next to the others under "The body as you see it in
  first person" in `animations.py` using `_seen(lean, left leg, right leg)`, list it in
  `view_clips()`, rebuild, and look at it with a first-person puppet shot in
  `preview.sh` (`"first_person": {"pitch": -30, "eye": 1.6}`) before trying it in the game.

To photograph a move in the real game, script it, for example a backflip:

```
godot --fixed-fps 60 --path . -- --practice --game-clock --hold=2.0:jump:0.1 \
    --hold=2.4:jump:0.1 --screenshot=2.6:/tmp/flip.png --quit-after=3
```

Use the Vulkan renderer for this; the compatibility renderer draws the first-person
arms wrongly.

**Adding a character:** write its shape as a new function in `designs.py` (model it
around the shared skeleton in `rig.py`), add its name to `DESIGNS` and `PLAYABLE`,
rebuild, then list it in `game/player/robot/characters.gd` with a display name and a
one-line description. The menus, the lobby, the network and the tests pick it up from
that list. If its forearms are bulky, give it an entry in `FP_SLIM` so the
first-person arms do not fill the view.

**Melee weapons** are not in the model files: `game/combat/melee_model.gd` builds each one
from faceted shapes (`game/combat/melee_kit.gd`: plates cut from an outline, bars, lofted
blades), in weapon space with the grip at the origin and the blade up +Y. To look at one
on its own: `tools/combat/melee_preview.sh hammer OUT_DIR` (side, three-quarter and face
on, then close up). How far each rests lower in first person is `MELEE_REST_VIEW` in
`view_model.gd`.

**Melee swings** have no clips either: `game/combat/melee_swing.gd` animates the weapon
(where the grip is, which way the blade points, how far the body turns and leans) and
bends the arms to hold it. Each weapon's blows are keys in its `MOVES` table: a ready
stance, two taps that take turns and a heavy blow, each with where it winds up to,
where it lands and where it ends; a key named `fp_...` is used instead in first person.
A weapon's `"air"` entry is its move off the ground: the same three keys, with `axis` and
`turns` (the body goes round that axis that many times, from the start of the wind-up to
the hit), `wind` (how much of that a full wind-up covers), `after` (turns it carries
on round after the hit) or `dive` (no turn: the body tips back, then over into the blow), and `legs` (the
legs' own pose wound up and as it lands: the superman punch's knee and kick back). The ground slam's pose is `SLAM_FALL` and `SLAM_HIT` in the same file.
Change a number and film it:

```
tools/combat/swing_preview.sh hammer OUT_DIR            # front, side and behind, quarter speed, OUT_DIR/swing.mp4
tools/combat/swing_preview.sh hammer OUT_DIR --step=0.0166667 --blows=heavy   # full speed, the heavy blow only
tools/combat/swing_preview.sh hammer OUT_DIR --step=0.0083333 --blows=air,slam   # half speed: the mid-air move, then a ground slam
```

For first person, film the real game: `godot --fixed-fps 60 --write-movie OUT/m.png --path .
-- --practice --map=testing_grounds --game-clock --weapon=hammer --spawn=47,0,2,-90
--hold=1.0:fire:0.13 --hold=2.5:fire:1.3 --quit-after=4.5` stands you in front of a target
dummy, taps once and then lets go a full wind-up (add `--speed=0.25` for slow motion).
`tests/weapon_test.gd` checks every blow: the left hand stays on the handle, the blow
ends back at ready, the taps take turns, a mid-air move's turn ends as it lands, and what a
ground slam does at each distance. `tests/movement_test.gd` checks the hang and the slam's fall.

## Sound effects

Every sound is made by code, like the robots: `tools/audio/make_sfx.py` (python3 with
numpy) builds all of them from noise, sine waves, filters and envelopes and writes
`game/audio/sfx/*.wav`. Nothing is recorded or downloaded, so they are ours to ship
(see `game/audio/LICENSE.md`). The style is crisp but realistic: a clean attack,
real weight in the low end, gun actions and armour that sound like dull steel rather
than ringing bells, and room tails. The players are robots, so their feet and hits are
metal, but nothing beeps. Each recipe is a short function near the sound's name; change its
numbers and rebuild:

```
python3 tools/audio/make_sfx.py            # every sound (a few seconds)
python3 tools/audio/make_sfx.py fire_      # only the ones whose names start with fire_
godot --headless --path . --import
```

Cirrus's clock has six sounds of its own (`clock_tick`, `clock_tock`, `bell_toll`,
`layout_rise`, `island_move`, `bridge_lock`), played by its LayoutEvent. The tick is the
quietest sound in the game on purpose.

Two of the sounds loop (`terminal_hum` and `gravity_pad`, for Halcyon's terminal and low
gravity): every frequency in them fits a whole number of times into the file, so the end
runs into the start, and the nodes that play them (MapTerminal, GravityEvent) set the
loop and fade them in and out.

In the game, `game/audio/` holds the code:

| File | What it does |
| --- | --- |
| `sound.gd` | The `Sound` autoload. Plays your own sounds in your head and everyone else's placed in the world (3D, quieter and duller with distance; far gunshots add a distant echo layer). Sets up the Effects and Music buses for the Audio sliders, with a limiter on Master. Hooks every menu button and slider by itself, and plays hit markers, kill and hurt sounds from the match events |
| `player_sounds.gd` | One per player: footsteps, jumps, landings, slides, wall runs, vaults, the grapple, reload steps, the pump and the bolt. It watches the same movement facts the animation uses, so it works the same for you, bots and other players |
| `sfx_list.gd` | The tables to tune: how loud each sound plays, and when each reload and pump/bolt sound plays (matched to the animations in `tools/robot/weapon_anims.py`) |

A menu button picks its click with `button.set_meta("sfx", "back")` (or `"confirm"`,
`"select"`, `"none"`); buttons labelled Back, Resume, Leave lobby, Leave match and Main
menu play the back sound already, and the orange main buttons play the confirm sound.
`--sound-log` prints every sound as it plays. The Music bus is ready for music but
nothing plays on it yet.
