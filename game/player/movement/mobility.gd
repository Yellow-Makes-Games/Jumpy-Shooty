class_name Mobility
extends RefCounted
## The mobility slot: the tool on your mobility button (right mouse), picked like
## your weapon before a match and while you wait to respawn.
##
##  - grapple: the grappling hook (see Grapple): swing, reel in, hook players.
##  - portal:  the portal gun (see PortalGun and Portal): shoot two portals onto
##             walls, floors or ceilings; walk into one and come out of the other
##             with your speed carried through. Anyone can use anyone's portals.
##  - blink:   a short teleport where you look (see Blink), one charge that
##             comes back a couple of seconds after you use it.
##
## A race always uses the grapple: the courses are built around it.

const GRAPPLE := "grapple"
const PORTAL := "portal"
const BLINK := "blink"
const IDS := [GRAPPLE, PORTAL, BLINK]

const NAMES := {GRAPPLE: "Grappling Hook", PORTAL: "Portal Gun", BLINK: "Blink"}
const SHORT := {GRAPPLE: "Grapple", PORTAL: "Portal Gun", BLINK: "Blink"}
const BLURBS := {
	GRAPPLE: "Hook any surface and swing, or hook a player to reel them in for a flying kick.",
	PORTAL: "Shoot a blue and an orange portal onto any surface. Step in one, fly out the other at full speed.",
	BLINK: "Teleport a few metres where you look, keeping your speed. A trail of sparks follows you there.",
}


static func default_id() -> String:
	return GRAPPLE


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
