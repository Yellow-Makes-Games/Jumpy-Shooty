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

**Until Steam is wired in**, connecting works over direct IP:

- **Same home network:** host with **Create lobby**. The lobby shows your local address
  (for example `192.168.1.20`). Your friend types that into **Join lobby**.
- **Over the internet:** direct IP needs the host's router to forward **UDP port 24680**
  to the host's PC, and your friend joins using your public IP address. This is fiddly
  and is exactly what Steam will remove. If you want to try it before Steam is ready,
  ask me and I will walk you through your router.

Windows may ask whether to allow Godot through the firewall the first time you host.
Allow it on private networks.

**With Steam (coming next):** create a lobby and invite friends through Steam; no
addresses or router settings. Everyone needs Steam running.

## Automated tests

`tests/run_all.sh` runs everything (needs bash and python3, so on Windows use Git Bash
or WSL; I run these on every change anyway):

- movement checks (speeds, stopping, jump height, momentum in the air);
- robot checks, for every character: the model files hold every bone and clip, the
  skeletons match, each movement state plays the right animation, and the poses fit
  the hitbox (`tests/robot_test.gd`); every gun has its muzzle bone and its own aim,
  carry, reload and first-person clips;
- weapons: damage and falloff (a close shotgun blast and a sniper headshot kill, the
  rifle never one-shots), whole-magazine and shell-by-shell reloads (`tests/weapon_test.gd`);
- the Testing Grounds practice courses and the Construction Site routes: a scripted
  player runs each one (`tests/course_test.gd`, `tests/site_test.gd`). The site test also
  checks the spawn points and that a bot can walk to every level. To run one route and
- robot checks: the model files hold every bone and clip, each movement state plays the
  right animation, and the poses fit the hitbox (`tests/robot_test.gd`);
- the Testing Grounds practice courses and the Construction Site and Office routes: a
  scripted player runs each one (`tests/course_test.gd`, `tests/site_test.gd`,
  `tests/office_test.gd`). The site and office tests also check the spawn points and that
  a bot can walk to every level. To run one route and
  print what the player did: `COURSE_ONLY="fence" COURSE_DEBUG="fence" godot --headless
  --path . --script tests/site_test.gd`;
- map scenes: every map loads and builds, every block has a colour, and the resize
  handles move the right face (`tests/map_scene_test.gd`);
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

## Developer command-line options

Pass these after `--`, for example `godot --path . -- --practice`. The full list is at the
top of `game/dev/dev_args.gd`. The useful ones:

| Option | What it does |
| --- | --- |
| `--practice` | Go straight into the arena alone |
| `--map=ID` | Which map: `construction_site` (the default), `office`, `testing_grounds`, or a map scene's path (`res://game/maps/my_map.tscn`). Works with `--practice`, `--bot` and `--host` |
| `--host` / `--join=ADDRESS` | Host or join straight away |
| `--name=NAME` | Player name for this copy |
| `--autostart=N` | Host starts the match when N players are in the lobby |
| `--net-sim=L,J,P` | Pretend the connection is bad: L ms latency, J ms jitter, P% loss |
| `--third-person` | Start in third person |
| `--spawn=X,Y,Z,YAW[,PITCH]` | Start at a given spot, facing YAW (degrees). Pick a spot that is clear on the map you use: start inside something and you fall out of the map |
| `--bot=LEVEL` | Go straight into a 1v1 against a bot (0 Easy, 1 Normal, 2 Hard, 3 Expert) |
| `--bots=N` | With `--bot`: play a free-for-all against N bots (1 to 4) instead of one |
| `--menu=PAGE` | Open the main menu on a page: `play`, `practice`, `bot`, `multiplayer`, `settings` |
| `--character=ID` | Play as `needle`, `vanguard`, `kestrel`, `bulwark`, `rivet`, `specter` or `orbit` without changing your saved choice |
| `--weapon=ID` | Play with `pistol`, `shotgun`, `rifle` or `sniper` without changing your saved choice |
| `--bot-weapon=ID` | Give every bot this gun (normally each bot picks one at random) |
| `--switch-weapon` | With `--auto-return`: pick the next gun in the lobby between matches (for the match test) |
| `--press=SEC:ACTION` | Press an input action after SEC seconds, e.g. `--press=10:toggle_camera` (pairs with `--screenshot`) |
| `--hold=SEC:ACTION:DURATION` | Hold an input action down, e.g. `--hold=5:move_forward:3` |
| `--look=SEC:YAW,PITCH` | Turn your view by YAW and to PITCH (degrees) after SEC seconds, e.g. `--look=3:0,-60` to look down |
| `--game-clock` | Count the SEC of `--press`, `--hold`, `--look`, `--screenshot` and `--quit-after` in game time. With Godot's own `--fixed-fps 60` (before the `--`) a scripted run plays out the same however slowly the machine renders, so screenshots land on the right frame |
| `--kill-target=N` / `--time-limit=S` | Host: shorter matches for testing |

## Maps

Maps are scenes you edit in the Godot editor: `game/maps/construction_site.tscn`,
`game/maps/office.tscn` and `game/maps/testing_grounds.tscn`. Double-click one in the FileSystem dock to open it.

**What a map is made of.** The root node is a `MapRoot`. Under it:

- **MapBlock** nodes: every floor, wall, crate and girder. A block is a box, cylinder or
  tube with a **Kind** (its colour from the map's palette). Its inspector also has
  **Size**, **Solid** (off = drawn only, like paint on the floor), **Drawn** (off = an
  invisible wall, shown in the editor as a faint blue box) and **Tint** (to make one block
  a little lighter or darker).
- Plain **Node3D** groups. Each object (a container, a staircase, the crane) is a group
  grouped the Godot way (the group icon beside it in the Scene tree), so a click in the
  3D view selects the whole object. To change one part, pick the part in the Scene
  tree, or select the object and press Ungroup in the 3D toolbar (next to the lock).
- **MapSpawn** nodes (under `Spawns`): where players appear. The green figure shows
  which way they face. Keep at least 8.
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
type its name into a block's Kind. The MapRoot's inspector also has the map's rules:
**Bounds** (leave it and you are out; drawn as a red rectangle), **Kill Height** and the
**Swing Point** the test player hooks.

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

The scripts behind this:

| File | What it holds |
| --- | --- |
| `game/arena/maps.gd` | The list of maps (id, name, scene). Add a map here and it shows up in the menus |
| `game/arena/map_root.gd`, `map_block.gd`, `map_spawn.gd`, `map_palette.gd` | The node types above; `MapRoot.build()` turns the blocks into collision and meshes |
| `game/arena/map_mesher.gd`, `map_scenery.gd` | One merged mesh per kind, the materials, the navigation mesh |
| `addons/map_tools/` | The editor plugin: resize handles, click-to-select, the bounds outline |

To render pictures of a map without opening the game:

```
tools/map_preview.sh construction_site OUT_DIR --shots="sw;top;cut7.5;-24,1.7,35:0,13,0:75"
```

Shots are corners (`sw`, `ne`, ...), `top` (a plan), `cutY` (a plan with everything above
height Y sliced off, to see one floor) or a camera `x,y,z:look-x,y,z:fov`. The map can
also be a scene path (`res://game/maps/my_map.tscn`).

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
| `designs.py` | Each robot's shape, and the materials. `PLAYABLE` lists the ones built for the game (Needle, Vanguard, Kestrel, Bulwark, Rivet, Specter, Orbit); the unused draft, Brick, is kept |
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
are in `game/combat/weapon_data.gd`. A model made in Blender later can
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
