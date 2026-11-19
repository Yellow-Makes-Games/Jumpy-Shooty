class_name Mobility
extends RefCounted
## The mobility slot: the tool on your mobility button (right mouse), picked like
## your weapon before a match and while you wait to respawn.
##
##  - grapple: the grappling hook (see Grapple): swing, reel in, hook players.
##  - grapple2: Grappling Hook 2 (see HookShot): the same rope, but the hook is
##             shot out and takes a moment to fly there, trailing a slack line that
##             pulls tight once it has bitten. You have to lead what you aim at.
##  - portal:  the portal gun (see PortalGun and Portal): shoot two portals onto
##             walls, floors or ceilings; walk into one and come out of the other
##             with your speed carried through. Anyone can use anyone's portals.
##  - blink:   a short teleport where you look (see Blink), one charge that
##             comes back a couple of seconds after you use it.
##  - jetpack: hold to fly (see Jetpack), on fuel that refills when you let go.
##
## A race always uses the grapple: the courses are built around it.

const GRAPPLE := "grapple"
const GRAPPLE2 := "grapple2"
const PORTAL := "portal"
const BLINK := "blink"
const JETPACK := "jetpack"
const IDS := [GRAPPLE, GRAPPLE2, PORTAL, BLINK, JETPACK]

const NAMES := {GRAPPLE: "Grappling Hook", GRAPPLE2: "Grappling Hook 2", PORTAL: "Portal Gun", BLINK: "Blink", JETPACK: "Jetpack"}
const SHORT := {GRAPPLE: "Grapple", GRAPPLE2: "Grapple 2", PORTAL: "Portal Gun", BLINK: "Blink", JETPACK: "Jetpack"}
const BLURBS := {
	GRAPPLE: "Hook any surface and swing, or hook a player to reel them in for a flying kick.",
	GRAPPLE2: "Shoot the hook out: it flies there trailing a slack line, bites, then the rope snaps tight and yanks you in harder. Lead your target.",
	PORTAL: "Shoot a blue and an orange portal onto any surface. Step in one, fly out the other at full speed. Up to 45 m apart.",
	BLINK: "Teleport a few metres where you look, keeping your speed. A trail of sparks follows you there.",
	JETPACK: "Hold to fly up and steer with WASD. Fuel refills when you let go, fastest on the ground.",
}


static func default_id() -> String:
	return GRAPPLE


## Is this tool a rope (either grappling hook)? The others take the mobility button
## for themselves.
static func is_grapple(id: String) -> bool:
	return id == GRAPPLE or id == GRAPPLE2


## What the HUD calls it, under the crosshair.
static func hud_label(id: String) -> String:
	return "GRAPPLE 2" if id == GRAPPLE2 else valid(id).to_upper()


static func has(id: String) -> bool:
	return id in IDS


static func valid(id: String) -> String:
	return id if has(id) else default_id()


static func name_of(id: String) -> String:
	return NAMES[valid(id)]


static func short_name(id: String) -> String:
	return SHORT[valid(id)]


static func blurb(id: String) -> String:
	return BLURBS[valid(id)]


static func next(id: String) -> String:
	return IDS[(IDS.find(valid(id)) + 1) % IDS.size()]
