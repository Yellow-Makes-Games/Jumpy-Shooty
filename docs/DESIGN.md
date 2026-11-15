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
- UI: minimal and clean.
- Music: none for now.
- Sound effects: heavier and realistic.

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

## Arena

- Size: about the size of the current test map (80 x 80 m).
- Themes: different arenas can use different themes.
- First arena: a construction site.

## Match rules

- The host sets the win condition per lobby: first to N kills, or a time limit.

## Still open

- Respawn delay (3 s for now).
- The end of the cut-off sentence in the original brief ("Networking tradeoffs that affect the...").
