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
- Music: none for now. (Sound effects style not decided yet.)

## Weapons

- For now: one semi-automatic pistol (one shot per click).

## Movement

- Feel: between fast-and-grounded and very floaty.
- Skill tricks welcome ("skill tricks galore"): bunny-hopping and air-strafing are intended.
- No fall damage.
- Grapple: short cooldown, attaches to any surface.

## Arena

- Size: about the size of the current test map (80 x 80 m).
- Themes: different arenas can use different themes. Theme of the first arena: not decided.

## Match rules

- The host sets the win condition per lobby: first to N kills, or a time limit.

## Still open

- Health: regeneration, pickups, or neither? Respawn delay (3 s for now)?
- Headshots: extra damage or not?
- Sound effects: punchy and arcade-like, or heavier and realistic?
- Theme of the first arena.
- The end of the cut-off sentence in the original brief ("Networking tradeoffs that affect the...").
