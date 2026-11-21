class_name Mobility
extends RefCounted
## The mobility slot: the tool on your mobility button (right mouse), picked like
## your weapon before a match and while you wait to respawn.
##
##  - grapple: the grappling hook (see Grapple): the hook is shot out and takes a
##             moment to fly there, trailing a slack line that pulls tight once it
##             has bitten. Swing, reel in, hook players (lead what you aim at).
##  - portal:  the portal gun (see PortalGun and Portal): shoot two portals onto
##             walls, floors or ceilings; walk into one and come out of the other
##             with your speed carried through. Anyone can use anyone's portals.
##  - blink:   a short teleport where you look (see Blink), through walls, three
##             charges that come back one at a time; quick blinks go shorter.
##  - jetpack: hold to fly (see Jetpack), on fuel that refills when you let go.
##
## A race always uses the grapple: the courses are built around it.

const GRAPPLE := "grapple"
const PORTAL := "portal"
const BLINK := "blink"
const JETPACK := "jetpack"
const IDS := [GRAPPLE, PORTAL, BLINK, JETPACK]
## Ids that are no longer tools, and the tool a saved choice of one becomes: the
## projectile hook was "grapple2" (Grappling Hook 2) until it replaced the first
## grappling hook.
const RENAMED := {"grapple2": GRAPPLE}

const NAMES := {GRAPPLE: "Grappling Hook", PORTAL: "Portal Gun", BLINK: "Blink", JETPACK: "Jetpack"}
const SHORT := {GRAPPLE: "Grapple", PORTAL: "Portal Gun", BLINK: "Blink", JETPACK: "Jetpack"}
const BLURBS := {
	GRAPPLE: "Shoot the hook out: it bites, the slack snaps tight and you swing. Hook a player to kick.",
	PORTAL: "Shoot a blue and an orange portal onto any surface. Step in one, fly out the other at full speed. Up to 45 m apart.",
	BLINK: "Teleport where you look, even through walls, keeping your speed. Three charges: quick ones go shorter.",
	JETPACK: "Hold to fly up and steer with WASD. Fuel refills when you let go, fastest on the ground.",
}


static func default_id() -> String:
	return GRAPPLE


## Is this tool the rope? The others take the mobility button for themselves.
static func is_grapple(id: String) -> bool:
	return canonical(id) == GRAPPLE


## What the HUD calls it, under the crosshair.
static func hud_label(id: String) -> String:
	return valid(id).to_upper()


## A stored id as it is called today (see RENAMED); anything else as it is.
static func canonical(id: String) -> String:
	return RENAMED.get(id, id)


static func has(id: String) -> bool:
	return id in IDS


static func valid(id: String) -> String:
	id = canonical(id)
	return id if has(id) else default_id()


static func name_of(id: String) -> String:
	return NAMES[valid(id)]


static func short_name(id: String) -> String:
	return SHORT[valid(id)]


static func blurb(id: String) -> String:
	return BLURBS[valid(id)]


static func next(id: String) -> String:
	return IDS[(IDS.find(valid(id)) + 1) % IDS.size()]
