# Design decisions

Decisions Austin has made, so nobody has to ask again. Newest at the top of each section.

## Technology (2026-11-15)

- Engine: Godot 4 (4.7.2).
- Networking: Steam (lobbies, invites, relay) plus direct IP for development and LAN.
- One player hosts; no dedicated servers. If the host leaves, the match ends (no host migration yet).
- Hits: the host decides, with rewind to what the shooter saw.

## Look and feel (2026-11-15)

- Art style: clean, stylized low-poly.
- Characters: robots.
- Player robots (2026-11-16): two characters to choose from. **Needle**: slim, one
  glowing eye, thin struts and blade limbs. **Vanguard**: an athletic armoured frame
  with broad shoulders and a helmet with a visor band. White armour for everyone; each
  player's colour shows on the trim panels and the glowing visor.
- Five more robots (2026-11-16), picked from mockups in the same style: **Kestrel** (scout:
  wedge helmet with crest fins, back thrusters, talon feet), **Bulwark** (heavy: low
  three-eyed head in a high collar, dome shoulders, piston legs), **Rivet** (site worker:
  hard hat, camera-lens eye, hazard stripes, tank backpack), **Specter** (stealth: hood
  with a V visor, trailing scarf, blade fins) and **Orbit** (glowing orb head in gimbal
  rings, glowing chest core). The bot named Rivet became Gizmo so names do not clash.
- Characters are looks only (2026-11-16): same hitbox, same movement, same animations.
  You pick yours before the round: on the Practice and Vs Bots pages, or in the lobby.
  The choice is remembered. In a 1v1 the bot plays the robot after yours in the list, never your own.
- The grapple fires from the robot's left wrist; the pistol is in the right hand.
- A robot that dies powers down (visor goes dark) and collapses; a respawn boots it back up.
- First person shows your own body (2026-11-16): legs and torso when you look down, and
  in the moves that bring them into view. Flips keep the camera steady (chosen over a
  camera that tumbles with the flip, so aiming still works mid-flip); the legs tuck and
  sweep through the view instead.
- UI: minimal and clean.
- Music: none for now (Austin will add it later; the Music slider and bus are ready).
- Sound effects: crisp and realistic, not high-pitched or arcade-like. Other players' sounds are positional (3D) so fights read clearly.

## Weapons

- For now: one semi-automatic pistol (one shot per click).
- Headshots do 1.5x damage.

## Health

- No health regeneration and no health pickups.

## Movement

- Feel: between fast-and-grounded and very floaty.
- Skill tricks welcome ("skill tricks galore"): bunny-hopping and air-strafing are intended.
- No fall damage.
- Grapple: short cooldown, attaches to any surface.
- Flips (2026-11-16): an air flip dodge. Press jump again in mid-air to flip toward your WASD direction with a small burst, once per jump.
- Grapple rope takes up its own slack (always tight, never pulls you in), so swings keep their momentum.

## Maps

- **Testing Grounds** (2026-11-16): the starting test map, kept long-term for testing. It is not a player-facing map.
  - The arena part (80 x 80 m) is the original combat test area.
  - The training yard (through the doorway on the east side) has practice lanes for the grapple, wall run and wall jump, slide, and vault and ledge climb.
- **Construction Site:** the first playable, player-facing map.
  - Layout (2026-11-16): "The Tower", picked from three concepts (the others were "The Yard", two structures facing each other, and "The Dig", a deep excavation). One half-built tower in the middle, king of the hill: floors every 4 m up to 20 m, stepping back as they rise, with a crow's nest at 24 m on the lift shaft and the crane's jib at 34 m.
  - Lots of verticality, and a route for every move: stairs, a lift shaft to wall-jump, tall crates to climb a floor at a time, scaffolding and a hoist tower to jump and climb, walls and the fence to wall-run, girders, the crane and floodlight masts to swing from, a conveyor and an earth ramp to slide, pipes to run through.
  - Look (2026-11-16): "Clear midday", picked from four (the others were golden hour, dusk under floodlights, and a misty morning with a muted palette; they were dropped when maps became scenes). Clean, stylized, low-poly; bright sun, blue sky, primary colours.
- **Office:** the second player-facing map, a smaller interior one.
  - Layout (2026-11-16): "Atrium tower", picked from three (the others were "Stacked open-plan floors" and "Split-level lobby"). A 48 x 36 m office building, three floors at 0, 5 and 10 m wrapped round an open atrium under a skylight. A bridge crosses the atrium at 10 m; the 10 m floor's north balcony steps back 2 m so the 5 m floor below has a strip open to the skylight.
  - Rooms: lobby with reception, café and lounges; open-plan desks, meeting rooms and a kitchen at 5 m; corner offices, a server room and a boardroom at 10 m. City backdrop outside the windows (the windows are invisible walls, so you cannot leave).
  - Same look as the Construction Site: same sky and sun, same face shading, its own palette (game/maps/palettes/office.tres).
- Arena size: about the size of the Testing Grounds arena part (80 x 80 m).
- The host picks the map in the lobby; practice and the bot menu have a map picker too.
- Maps are scenes edited in the Godot editor (2026-11-15): every piece is a node you can select, move and resize, and the game merges them into a few meshes when a match starts. Decided before making more maps.
- Themes: different arenas can use different themes.

## Match rules

- The host sets the win condition per lobby: first to N kills, or a time limit.

## Still open

- Respawn delay (3 s for now).
- The end of the cut-off sentence in the original brief ("Networking tradeoffs that affect the...").
