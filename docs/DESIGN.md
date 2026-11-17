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
- Low gravity (2026-11-17, Halcyon's event) changes players only: jumps, falls, swings, slides, wall runs and glides all go light together. Bullets, rockets and grenades do not change, so weapons stay predictable.
- Flips (2026-11-16): an air flip dodge. Press jump again in mid-air to flip toward your WASD direction with a small burst, once per jump.
- Float (2026-11-17, since replaced by the glide below): Shift in mid-air cancels your up-and-down speed and glides you in a straight line the way you face, at the speed you had, sinking slowly, for about a second (2.5 s was tried and was far too long). It pairs with every other move (they take over from it), so it doubles as a vertical cancel, and it is a steadier way to shoot from the air. Rocket boots are the exception: used while floating they turn the float the way you press, so it can change direction. Legs out to the sides, whirling like a helicopter's rotor (the first try, half a flip's speed, was too slow), and they hurt and shove anyone they touch. (A rocket booster out of the seat was tried and dropped: it looked goofy.)
- Glide (2026-11-17) replaces the float, modelled on Warframe's Aim Glide: hold Shift in the air, keep your own heading with free look, speed bleeding to a drift, the fall starting nearly stopped and growing, a 1.5 s budget per time in the air spent in pieces, and half the weapon spread while gliding. The spinning legs and their damage went with the float. Speed bleeds fully (a lighter bleed that kept the race gaps was offered and turned down), so the glide is for hanging and shooting, not for distance: at slide speed a flip carries further than a glide does. The race maps were rebuilt to suit: the ski jumps are a flip and a dive over 21 m (were a float over 24 m), and the 40 m float-and-boost leaps are 20 m glide-and-boost leaps.
- Grapple pulls you in: a yank when it catches, then a steady reel toward the hook that only adds speed along the rope (sideways speed is kept, so pulls turn into swings). The rope takes up its own slack, so it is always tight, and letting go keeps every bit of speed.

## Maps

- **Halcyon** (2026-11-17): the colony ship *Halcyon*, whose gravity comes from a huge centrifuge ring turning round its hull. The biggest and most vertical arena (140 x 140 m, up to 16 players), for free-for-all, Deathmatch and Gun Game.
  - Tone: the inside of a capital ship in a classic sci-fi shooter (clean, cold corridors, big viewports onto space) but brighter and more hopeful, because this ship carries colonists. The feel only: nothing named or copied.
  - Layout: hub, four spokes and an outer ring. The round Control Room in the middle (30 m across, a glass dome above and a ring of glass in the floor, the centrifuge sweeping past both), a spoke corridor to each of four tall rooms, an outer ring corridor so no room is a dead end, and a tighter lower maintenance deck under the spokes and the ring with two stairwells up into the Control Room.
  - Rooms, one accent colour each: Hangar (cyan; the biggest volume, two shuttles, a viewport onto a planet), Hydroponics (green; terraces of planting beds, grow lights), Engineering (orange; the reactor core, ringed catwalks, and the reactor pit under it, the map's only hazard), Cargo Bay (yellow; container stacks and a gantry crane) and the Cryo/Habitat zone in the ring (pale blue; the one tight part, on purpose). Every tall room is a grapple playground, 32 to 36 m from floor to ceiling.
  - The low gravity event, the game's first interactive map object: press Interact (G) at the terminal on the Control Room's dais and the centrifuge slows to half speed. Gravity eases to 30% for 30 s (a jump reaches about 4 m), then a 60 s cooldown. One press is enough (first built as a 2 s hold that a knock off the dais interrupted; changed the same day, 2026-11-17, to a press, and the gravity from 40% to 30%, for a stronger effect that is simpler to set off). No weapon in the Control Room: going for the event is a risk with no item reward.
  - Its feel is blissful, not an alarm: the lights fade to a deep blue, a soft sustained chord swells in, slow motes of light drift through the big rooms. Shown, never told: nothing on the HUD, no red, no flashing.
  - Surfaces (2026-11-17): bare walls and floors read as empty at this size, so the hull is panelled and the floors tiled by a surface shader (no blocks), and each place carries drawn-only details: ribs, vents, wall displays in the room's colour, conduits and ceiling beams; on the floors a line of each room's colour to follow to it, grates, hazard stripes at every drop hole, railing gap and the reactor pit, and names and deck numbers stencilled. None of it is solid, so movement is unchanged.
  - Power weapons sit up high where only the grapple takes you (the top reactor catwalk, the six-high container stack, the hangar gantry, the top terrace); the rest are in the corridors, the ring and the lower deck.
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
