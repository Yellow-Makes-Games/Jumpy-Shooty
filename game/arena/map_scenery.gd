class_name MapScenery
extends RefCounted
## Shared map helpers: the materials blocks are drawn with (in the game and in the
## editor) and the bots' navigation mesh.

## Bots find their way around with a navigation mesh: a map of every walkable
## floor, ramp and deck, worked out from the level's collision shapes. Returns the
## region to add to the scene.
static func bake_navigation(level: Node3D) -> NavigationRegion3D:
	var started := Time.get_ticks_msec()
	var nav := _nav_settings(level)
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nav, source, level)
	NavigationServer3D.bake_from_source_geometry_data(nav, source)
	var region := NavigationRegion3D.new()
	region.name = "Navigation"
	region.navigation_mesh = nav
	print("Navigation mesh: %d polygons in %d ms" % [nav.get_polygon_count(), Time.get_ticks_msec() - started])
	return region


## Redoes the navigation mesh after the level changed (walls or floors broke), baking
## on a background thread so the game does not stall; `done` is called (with a line
## saying how long it took) when it is in.
static func rebake_navigation(region: NavigationRegion3D, level: Node3D, done: Callable) -> void:
	var started := Time.get_ticks_msec()
	var nav := _nav_settings(level)
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nav, source, level)
	var parsed := Time.get_ticks_msec() - started
	NavigationServer3D.bake_from_source_geometry_data_async(nav, source, func():
		# (May run on the baking thread: hand the result back to the main one.)
		if is_instance_valid(region):
			region.set_deferred("navigation_mesh", nav)
		done.call_deferred("%d polygons, parsed in %d ms, %d ms in all" % [nav.get_polygon_count(), parsed, Time.get_ticks_msec() - started]))


static func _nav_settings(level: Node3D = null) -> NavigationMesh:
	var nav := NavigationMesh.new()
	if level is MapRoot and (level as MapRoot).winding_floors:
		# A floor that winds up over itself (a spiral stair) is lost by the usual way of
		# cutting the mesh into regions; this way keeps it.
		nav.sample_partition_type = NavigationMesh.SAMPLE_PARTITION_MONOTONE
	nav.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav.geometry_collision_mask = 1
	nav.cell_size = 0.25
	nav.cell_height = 0.25
	nav.agent_radius = 0.5
	nav.agent_height = 1.75
	nav.agent_max_climb = 0.25   # the body cannot walk up a kerb, so paths must not cross one
	nav.agent_max_slope = 46.0
	return nav


## The patterns a palette can give a kind (MapPalette.surface), as settings of
## map_surface.gdshader. Cells are in metres: a wall panel's (width, height) and a floor
## or ceiling tile's (x, z).
const SURFACE_SHADER := preload("res://game/arena/map_surface.gdshader")
const SURFACES := {
	# Wall panels 3 m wide and 2 m high, now and then one with a hatch or vent slots.
	"panels": {"style": 0, "wall_cell": Vector2(3, 2), "floor_cell": Vector2(3, 3), "seam_shade": 0.66, "vary": 0.03, "detail": 0.18},
	# The same, quieter: for bright walls and for things that are not walls.
	"panels_plain": {"style": 0, "wall_cell": Vector2(2, 2), "floor_cell": Vector2(2, 2), "seam_shade": 0.78, "vary": 0.02},
	# Floor tiles 2 m square.
	"tiles": {"style": 1, "wall_cell": Vector2(2, 1), "floor_cell": Vector2(2, 2), "seam_shade": 0.7, "vary": 0.035},
	# Riveted plates (maintenance decks).
	"plates": {"style": 2, "wall_cell": Vector2(2, 1.5), "floor_cell": Vector2(1.5, 1.5), "seam_shade": 0.62, "vary": 0.05},
	# A fine mesh in 1 m frames (catwalks, floor grates).
	"grating": {"style": 3, "wall_cell": Vector2(1, 1), "floor_cell": Vector2(1, 1), "seam_shade": 0.55},
	# Louvres (vents).
	"slats": {"style": 4},
	# Slanted dark stripes (the edge of a drop).
	"hazard": {"style": 5},
	# Grip lines across a ramp.
	"treads": {"style": 6, "seam_shade": 0.66},
	# Upright ridges (shipping containers).
	"corrugated": {"style": 7, "wall_cell": Vector2(1000, 1000), "floor_cell": Vector2(1000, 1000)},
	# Floor tiles 1 m square, every other one a shade darker.
	"checker": {"style": 1, "wall_cell": Vector2(1, 1), "floor_cell": Vector2(1, 1), "seam_shade": 0.8, "vary": 0.02, "checker": 0.16},
	# Paving slabs 1 m square (pavements, platforms), and concrete laid in 3 m bays.
	"pavers": {"style": 1, "wall_cell": Vector2(1, 0.5), "floor_cell": Vector2(1, 1), "seam_shade": 0.8, "vary": 0.045},
	"slabs": {"style": 1, "wall_cell": Vector2(3, 1.5), "floor_cell": Vector2(3, 3), "seam_shade": 0.78, "vary": 0.03},
	# Brickwork with pale mortar.
	"bricks": {"style": 8, "wall_cell": Vector2(0.62, 0.24), "floor_cell": Vector2(0.62, 0.31), "seam": 0.015, "seam_shade": 1.22, "vary": 0.08},
	# Dressed stone in level courses (castle and temple walls; on a floor, flagstones).
	"blocks": {"style": 9, "wall_cell": Vector2(1.3, 0.6), "floor_cell": Vector2(1.5, 1.1), "seam": 0.016, "seam_shade": 0.7, "vary": 0.055},
	"blocks_small": {"style": 9, "wall_cell": Vector2(0.8, 0.4), "floor_cell": Vector2(0.9, 0.7), "seam": 0.013, "seam_shade": 0.72, "vary": 0.05},
	# Round stones with dark gaps.
	"cobbles": {"style": 10, "wall_cell": Vector2(0.42, 0.42), "floor_cell": Vector2(0.42, 0.42), "seam": 0.02, "seam_shade": 0.72, "vary": 0.09},
	# Clumps of leaves (tree tops, hedges, bushes).
	"clumps": {"style": 10, "wall_cell": Vector2(1.1, 1.1), "floor_cell": Vector2(1.1, 1.1), "seam": 0.0, "seam_shade": 1.0, "vary": 0.12},
	# Boards: level on a wall and along x on a floor, or ("_upright") upright and along z.
	"planks": {"style": 11, "wall_cell": Vector2(3.2, 0.28), "floor_cell": Vector2(3.2, 0.28), "seam": 0.011, "seam_shade": 0.64, "vary": 0.075},
	"planks_upright": {"style": 11, "wall_cell": Vector2(3.2, 0.28), "floor_cell": Vector2(3.2, 0.28), "seam": 0.011, "seam_shade": 0.64, "vary": 0.075, "turn": true},
	# Soft blotches: grass, bare earth, loose stones, tarmac.
	"grass": {"style": 12, "wall_cell": Vector2(3.5, 3.5), "floor_cell": Vector2(3.5, 3.5), "vary": 0.075, "detail": 0.09},
	"dirt": {"style": 12, "wall_cell": Vector2(2.4, 2.4), "floor_cell": Vector2(2.4, 2.4), "vary": 0.06, "detail": 0.1},
	"gravel": {"style": 12, "wall_cell": Vector2(2.2, 2.2), "floor_cell": Vector2(2.2, 2.2), "vary": 0.04, "detail": 0.2},
	"tarmac": {"style": 12, "wall_cell": Vector2(4, 4), "floor_cell": Vector2(4, 4), "vary": 0.035, "detail": 0.1},
	# Rows of windows on the walls of far-off buildings; "_lit" has lights on in some.
	"windows": {"style": 13, "wall_cell": Vector2(3, 3.4), "seam_shade": 0.62, "detail": 0.0},
	"windows_lit": {"style": 13, "wall_cell": Vector2(3, 3.4), "seam_shade": 0.55, "detail": 0.36, "lit": Color(1.0, 0.82, 0.5), "lit_power": 1.3},
	# A cliff: level beds of rock with cracks.
	"strata": {"style": 14, "wall_cell": Vector2(5, 1.5), "seam": 0.035, "seam_shade": 0.74, "vary": 0.06},
	# An arcade carpet: small bright shapes scattered over it.
	"confetti": {"style": 15, "wall_cell": Vector2(0.8, 0.8), "floor_cell": Vector2(0.8, 0.8), "vary": 0.03, "lit_power": 0.3},
	# Ripples on a pool, streaks down a waterfall (they move).
	"water": {"style": 16},
	# Roof tiles in rows down the slope, and thatch.
	"shingles": {"style": 17, "wall_cell": Vector2(0.6, 0.45), "floor_cell": Vector2(0.6, 0.45), "seam": 0.012, "seam_shade": 0.7, "vary": 0.07, "detail": 1.0},
	"thatch": {"style": 17, "wall_cell": Vector2(1, 0.6), "floor_cell": Vector2(1, 0.6), "seam_shade": 0.8, "vary": 0.08, "detail": 0.0},
	# Tree trunks and rough posts.
	"bark": {"style": 18, "seam_shade": 0.72, "vary": 0.06},
}


## kind -> material, for every kind in the palette.
static func materials(palette: MapPalette, grid: bool) -> Dictionary:
	var result := {}
	if palette == null:
		return result
	var grid_tex: ImageTexture = _grid_texture() if grid else null
	for kind in palette.colors:
		var pattern: String = palette.surface.get(kind, "")
		if pattern != "" and not grid and SURFACES.has(pattern) and palette.colors[kind].a >= 0.999 and palette.glow.get(kind, 0.0) <= 0.0:
			# A patterned kind: the same colour and roughness, drawn by the surface shader.
			var sm := ShaderMaterial.new()
			sm.shader = SURFACE_SHADER
			sm.set_shader_parameter("albedo", palette.colors[kind])
			sm.set_shader_parameter("roughness", palette.roughness)
			for key in SURFACES[pattern]:
				sm.set_shader_parameter(key, SURFACES[pattern][key])
			result[kind] = sm
			continue
		var m := StandardMaterial3D.new()
		m.albedo_color = palette.colors[kind]
		if grid_tex:
			m.albedo_texture = grid_tex
			m.uv1_triplanar = true
			m.uv1_world_triplanar = true
			m.uv1_scale = Vector3(0.25, 0.25, 0.25)  # one grid square per 4 m (sub-lines every 1 m)
		m.roughness = palette.roughness
		m.vertex_color_use_as_albedo = true
		if palette.colors[kind].a < 0.999:
			# A colour with alpha below 1 is see-through (glass). No shine: a glancing
			# reflection would turn the pane white and hide what is behind it.
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
			m.metallic_specular = 0.0
		var shine: float = palette.glow.get(kind, 0.0)
		if shine > 0.0:
			m.emission_enabled = true
			m.emission = palette.colors[kind]
			m.emission_energy_multiplier = shine
		result[kind] = m
	return result


## Bright magenta, for a block whose kind is not in the palette.
static func missing_material() -> Material:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1, 0, 1)
	return m


## A greybox grid so you can judge distance and speed. Not final art.
static func _grid_texture() -> ImageTexture:
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	img.fill(Color(1, 1, 1))
	for i in size:
		for j in size:
			var major := i < 3 or j < 3
			var minor := (i % 64) < 1 or (j % 64) < 1
			if major:
				img.set_pixel(i, j, Color(0.62, 0.62, 0.62))
			elif minor:
				img.set_pixel(i, j, Color(0.85, 0.85, 0.85))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
