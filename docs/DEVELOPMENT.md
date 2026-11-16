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
- robot checks: the model files hold every bone and clip, each movement state plays the
  right animation, and the poses fit the hitbox (`tests/robot_test.gd`);
- the Testing Grounds practice courses and the Construction Site routes: a scripted
  player runs each one (`tests/course_test.gd`, `tests/site_test.gd`). The site test also
  checks the spawn points and that a bot can walk to every level. To run one route and
  print what the player did: `COURSE_ONLY="fence" COURSE_DEBUG="fence" godot --headless
  --path . --script tests/site_test.gd`;
- the game boots into practice mode on every map without script errors;
- bots climb the Construction Site tower to a player standing on a high floor
  (`tests/run_bot_climb_test.sh`);
- a bot of every difficulty finds you and shoots, even Easy hits a player standing still, harder bots hit a moving player more often, the hard bots slide, dive, flip and grapple, and Rematch starts a new match (`tests/run_bot_test.sh`);
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

## Developer command-line options

Pass these after `--`, for example `godot --path . -- --practice`. The full list is at the
top of `game/dev/dev_args.gd`. The useful ones:

| Option | What it does |
| --- | --- |
| `--practice` | Go straight into the arena alone |
| `--map=ID` | Which map: `construction_site` (the default) or `testing_grounds`. Works with `--practice`, `--bot` and `--host` |
| `--host` / `--join=ADDRESS` | Host or join straight away |
| `--name=NAME` | Player name for this copy |
| `--autostart=N` | Host starts the match when N players are in the lobby |
| `--net-sim=L,J,P` | Pretend the connection is bad: L ms latency, J ms jitter, P% loss |
| `--third-person` | Start in third person |
| `--spawn=X,Y,Z,YAW[,PITCH]` | Start at a given spot (degrees). Example: `--practice --spawn=45,0,10,-90` puts you at the start of the slide lane |
| `--bot=LEVEL` | Go straight into a 1v1 against a bot (0 Easy, 1 Normal, 2 Hard, 3 Expert) |
| `--menu=PAGE` | Open the main menu on a page: `play`, `practice`, `bot`, `multiplayer`, `settings` |
| `--press=SEC:ACTION` | Press an input action after SEC seconds, e.g. `--press=10:toggle_camera` (pairs with `--screenshot`) |
| `--hold=SEC:ACTION:DURATION` | Hold an input action down, e.g. `--hold=5:move_forward:3` |
| `--kill-target=N` / `--time-limit=S` | Host: shorter matches for testing |

## Maps

A map is a script, not a scene: it lists its pieces (boxes, ramps, cylinders), spawn
points and signs, and the game builds the collision, the meshes and the bots' navigation
mesh from that list. Everything is in `game/arena/`:

| File | What it holds |
| --- | --- |
| `maps.gd` | The list of maps (id, name, script). Add a map here and it shows up in the menus |
| `map_layout.gd` | The base every map extends: piece helpers (`_box`, `_span`, `_ramp`, ...), spawns, signs |
| `map_scenery.gd`, `map_mesher.gd` | Sky and sun from the map's look, one merged mesh per colour, the navigation mesh |
| `site_kit.gd` | Building blocks for construction sites: floor plates with holes, stairs, girders, scaffolding, containers, the crane, vehicles, the fence, signs. Also the colours and the looks (time of day) |
| `construction_site.gd` | The Construction Site map: where everything goes. Positions are metres; x runs west to east, z north to south, y up |
| `testing_grounds.gd` | The test map |

To look at a map without opening the game:

```
tools/map_preview.sh res://game/arena/construction_site.gd OUT_DIR --shots="sw;top;cut7.5;-24,1.7,35:0,13,0:75"
```

Shots are corners (`sw`, `ne`, ...), `top` (a plan), `cutY` (a plan with everything above
height Y sliced off, to see one floor) or a camera `x,y,z:look-x,y,z:fov`. `--look=NAME`
renders one of the other looks kept in `site_kit.gd` (`golden`, `dusk`, `mist`).

After moving things on the Construction Site, run `tests/site_test.gd`: it tells you if a
route no longer works or a bot can no longer reach a floor.

## Tuning movement

All movement numbers are in `game/player/movement/movement_tuning.gd`, each with a comment
saying what it does. Change a number, press F5, and feel the difference. Tell me what
feels off and I will tune it with you.

## The robot model and its animations

The player robot is built by code, not drawn in a modelling program, so it can be changed
by editing numbers and rebuilding. Everything is in `tools/robot/` (needs python3 with
numpy):

| File | What it holds |
| --- | --- |
| `designs.py` | The robot's shape and materials. `CHOSEN` picks the look ("needle"); the two other drafts are kept |
| `rig.py` | The skeleton (bone names and positions) and the pose solver |
| `animations.py` | Every animation, written as key poses: body clips and first-person arm clips |
| `build.py` | Writes `game/player/robot/robot.glb` (full body) and `robot_arms.glb` (first-person arms and pistol) |

After changing any of them:

```
python3 tools/robot/build.py
godot --headless --path . --import
```

To look at the result without opening the game (these render on a machine with no
graphics card, so I can check poses myself):

- `python3 tools/robot/sheet.py OUT_DIR run sprint:8 death:6:0:1.3` renders side and
  front contact sheets of clips (name, frames, start and end time).
- `tools/robot/preview.sh JOB.json` renders any set of robots, poses and camera angles
  described in a job file; the format is at the top of `tools/robot/preview.gd`. It can
  also drive a robot with the game's real animator from made-up movement.

In the game, `game/player/robot/` holds the code: `robot_animator.gd` decides what the
body shows from the movement state (the same way for you, other players and the bot),
and `view_model.gd` does the first-person arms. A model made in Blender later can
replace the .glb files as long as it keeps the same bone and clip names.
