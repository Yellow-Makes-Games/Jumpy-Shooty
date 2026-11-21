class_name WorldCompositor
extends RefCounted
## The one Compositor a World3D runs, shared by everything that wants a compositor effect
## on that world's views: CMAA2 (GraphicsQuality.use_cmaa2) and GTAO (Gtao.use) today.
##
## Godot gives each world one compositor slot (RenderingServer.scenario_set_compositor),
## and whoever sets it last wins: two features each setting their own Compositor would
## silently switch each other off. So each feature puts its effects in here under a key
## of its own (add()) and takes only those out again (remove()); this puts them all
## together in one Compositor and keeps that in the world's slot. Once the last effect
## goes the world's slot is cleared (and the Compositor dropped), as if nothing had
## been there.
##
## Order: Godot runs a world's effects by callback type (all pre-opaque ones, then
## post-opaque...), and within a type in the order of the Compositor's list. The list here
## is sorted by each key's `order` (lower first), then by the key, so it is the same
## however and whenever the features came and went.
##
## Kept in the World3D's metadata, so it lives exactly as long as the world: the game
## window's for the whole run, a menu picture's or the results screen killcam's until
## that view goes. (Godot frees the world's scenario with it.)
##
## Not through a WorldEnvironment: a WorldEnvironment's compositor goes on its world
## (Godot 4.7's world_environment.cpp: on entering and leaving the tree, and on
## set_compositor), so a feature that used one would take the slot from this, and
## leaving the tree would clear it. Nothing in the game gives a WorldEnvironment a
## compositor; if one ever does, this notices it coming or going (SceneTree's node_added
## and node_removed, which come after Godot has set the slot), puts its own compositor
## back at the end of the frame, and warns: put the effect in here instead.
##
## Cameras: Godot uses a camera's own compositor, if it has one, in place of its world's
## (even an empty one). A view that should run some of the world's effects but not all
## (a portal's: no CMAA2, the window's goes over it, but its own GTAO) gives its camera
## without(): a second Compositor with the world's effects less one key's, kept in step
## here whenever the world's set changes.

const META := &"world_compositor"

## (Every world that has one, for putting the slot back; see _watch_tree().)
static var _all: Array = []   # of WeakRef
static var _watching := false
static var _reclaim_queued := false

var _scenario := RID()
var _world: WeakRef
var _compositor := Compositor.new()
## key -> {"order": int, "effects": Array[CompositorEffect]}
var _parts := {}
## key left out -> WeakRef to the Compositor handed out for it (the cameras hold it).
var _without := {}


## Puts `effects` on `world` under `key`, in place of whatever was under that key
## (another feature's keys are left alone). `order`: lower runs first within a callback
## type (see above).
static func add(world: World3D, key: StringName, effects: Array[CompositorEffect], order: int = 0) -> void:
	if world == null:
		return
	var wc := _of(world, true)
	wc._parts[key] = {"order": order, "effects": effects.duplicate()}
	wc._update()


## Takes `key`'s effects off `world`. With `only`, only if they are still those (so a
## feature whose key was taken over by a newer copy of itself leaves the newer one).
static func remove(world: World3D, key: StringName, only: Array = []) -> void:
	var wc := _of(world, false)
	if wc == null or not wc._parts.has(key):
		return
	if not only.is_empty() and not _same(wc._parts[key].effects, only):
		return
	wc._parts.erase(key)
	wc._update()


## The effects `world` has under `key` (empty if none).
static func effects_of(world: World3D, key: StringName) -> Array[CompositorEffect]:
	var wc := _of(world, false)
	var out: Array[CompositorEffect] = []
	if wc and wc._parts.has(key):
		out.assign(wc._parts[key].effects)
	return out


## Has `world` effects under `key`?
static func has(world: World3D, key: StringName) -> bool:
	var wc := _of(world, false)
	return wc != null and wc._parts.has(key)


## The Compositor on `world`'s slot now, or null when it has none.
static func compositor_of(world: World3D) -> Compositor:
	var wc := _of(world, false)
	return wc._compositor if wc and not wc._parts.is_empty() else null


## For a camera that draws `world` but should not run `key`'s effects: a Compositor
## holding the world's others, in the same order, kept in step as they change (empty
## when there are none, which still keeps the world's off that camera). The same one
## for every camera that asks, while any of them holds it.
static func without(world: World3D, key: StringName) -> Compositor:
	if world == null:
		return Compositor.new()
	var wc := _of(world, true)
	var held: Compositor = wc._without[key].get_ref() if wc._without.has(key) else null
	if held == null:
		held = Compositor.new()
		wc._without[key] = weakref(held)
		held.compositor_effects = wc._list(key)
	return held


static func _of(world: World3D, make: bool) -> WorldCompositor:
	if world == null:
		return null
	if world.has_meta(META):
		return world.get_meta(META)
	if not make:
		return null
	var wc := WorldCompositor.new()
	wc._scenario = world.scenario
	wc._world = weakref(world)
	# (The world's metadata is all that holds it: dropped by _update() once it is empty, or with the world.)
	world.set_meta(META, wc)
	_all = _all.filter(func(w): return w.get_ref() != null)
	_all.append(weakref(wc))
	_watch_tree()
	return wc


## The effects, less `leave_out`'s, in order.
func _list(leave_out: StringName = &"") -> Array[CompositorEffect]:
	var keys := _parts.keys()
	keys.sort_custom(func(a, b):
		var oa: int = _parts[a].order
		var ob: int = _parts[b].order
		return oa < ob or (oa == ob and String(a) < String(b)))
	var out: Array[CompositorEffect] = []
	for k in keys:
		if k != leave_out:
			out.append_array(_parts[k].effects)
	return out


func _update() -> void:
	_compositor.compositor_effects = _list()
	for k in _without.keys():
		var held: Compositor = _without[k].get_ref()
		if held == null:
			_without.erase(k)
		else:
			held.compositor_effects = _list(k)
	_put()
	if _parts.is_empty() and _without.is_empty():
		var world: World3D = _world.get_ref()
		if world and world.get_meta(META, null) == self:
			world.remove_meta(META)


## Its compositor on the world's slot (none once it is empty).
func _put() -> void:
	RenderingServer.scenario_set_compositor(_scenario, _compositor.get_rid() if not _parts.is_empty() else RID())


## (Once, when the first world has one.) A WorldEnvironment with a compositor of its own
## coming or going has just set the world's slot (see above): put ours back.
static func _watch_tree() -> void:
	if _watching:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	_watching = true
	tree.node_added.connect(WorldCompositor._on_node)
	tree.node_removed.connect(WorldCompositor._on_node)


static func _on_node(node: Node) -> void:
	if node is WorldEnvironment and (node as WorldEnvironment).compositor != null and not _reclaim_queued:
		push_warning("WorldCompositor: %s has a compositor of its own, which Godot puts on its world in place of the shared one; " % node.get_path()
			+ "the shared one is put back. Add effects with WorldCompositor.add() instead.")
		_reclaim_queued = true
		WorldCompositor._reclaim.call_deferred()


static func _reclaim() -> void:
	_reclaim_queued = false
	var live := []
	for w in _all:
		var wc: WorldCompositor = w.get_ref()
		if wc:
			wc._put()
			live.append(w)
	_all = live


## The same effects, in the same order (by identity, whatever the arrays' types).
static func _same(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if a[i] != b[i]:
			return false
	return true
