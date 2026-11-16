class_name MapScenery
extends RefCounted
## Turns a MapLayout into what you see: sky and sun, materials and meshes.
## Used by the arena and by tools/map_preview.gd, so both show the same thing.

const DEFAULT_LOOK := {
	"sky_top": Color(0.22, 0.38, 0.62),
	"sky_horizon": Color(0.70, 0.74, 0.80),
	"ground_horizon": Color(0.45, 0.47, 0.50),
	"ground_bottom": Color(0.20, 0.17, 0.13),
	"ambient_energy": 0.35,
	"sun_angles": Vector3(-52, -35, 0),   # degrees
	"sun_energy": 1.1,
	"sun_color": Color(1, 1, 1),
	"shadow_distance": 120.0,
	"roughness": 0.85,
	# Optional extras (leave out for none):
	#   "ambient_color": Color   fill light of this colour instead of the sky's
	#   "shadow_opacity": float  below 1 softens the sun's shadows
	#   "fog_color": Color, "fog_density": float   haze that thickens with distance
	#   "tonemap": "filmic", "white": float   punchier colours than the default (AgX)
	#   "lamps": true            switch on the map's lamps (MapLayout.lights)
	#   "glow": {kind: energy}   kinds that shine (lamp faces, signs)
}


static func build_environment(parent: Node, layout: MapLayout) -> void:
	var look := DEFAULT_LOOK.duplicate()
	look.merge(layout.look(), true)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = look.sky_top
	sky_mat.sky_horizon_color = look.sky_horizon
	sky_mat.ground_horizon_color = look.ground_horizon
	sky_mat.ground_bottom_color = look.ground_bottom
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = look.ambient_energy
	if look.has("ambient_color"):
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = look.ambient_color
	if look.get("fog_density", 0.0) > 0.0:
		env.fog_enabled = true
		env.fog_light_color = look.fog_color
		env.fog_density = look.fog_density
		env.fog_sky_affect = 0.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC if look.get("tonemap", "") == "filmic" else Environment.TONE_MAPPER_AGX
	env.tonemap_white = look.get("white", 1.0)
	env.ssao_enabled = true
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = look.sun_angles
	sun.light_energy = look.sun_energy
	sun.light_color = look.sun_color
	sun.shadow_enabled = true
	sun.shadow_opacity = look.get("shadow_opacity", 1.0)
	sun.directional_shadow_max_distance = look.shadow_distance
	parent.add_child(sun)


## Adds a "Level" node holding the map's collision and meshes. Returns it.
static func build_level(parent: Node, layout: MapLayout) -> Node3D:
	var level := Node3D.new()
	level.name = "Level"
	parent.add_child(level)
	layout.instantiate(level, materials(layout))
	if layout.look().get("lamps", false):
		for l in layout.lights:
			var lamp: Light3D
			if l.toward == null:
				var omni := OmniLight3D.new()
				omni.omni_range = l.range
				omni.omni_attenuation = 0.7
				lamp = omni
			else:
				var spot := SpotLight3D.new()
				spot.spot_range = l.range
				spot.spot_angle = l.angle
				spot.spot_attenuation = 0.5
				lamp = spot
			lamp.light_color = l.color
			lamp.light_energy = l.energy
			level.add_child(lamp)
			lamp.position = l.pos
			if l.toward != null:
				lamp.look_at(l.toward)
	return level


## Bots find their way around with a navigation mesh: a map of every walkable
## floor, ramp and deck, worked out from the level's collision shapes. Returns the
## region to add to the scene.
static func bake_navigation(level: Node3D) -> NavigationRegion3D:
	var started := Time.get_ticks_msec()
	var nav := NavigationMesh.new()
	nav.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav.geometry_collision_mask = 1
	nav.cell_size = 0.25
	nav.cell_height = 0.25
	nav.agent_radius = 0.5
	nav.agent_height = 1.75
	nav.agent_max_climb = 0.25   # the body cannot walk up a kerb, so paths must not cross one
	nav.agent_max_slope = 46.0
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nav, source, level)
	NavigationServer3D.bake_from_source_geometry_data(nav, source)
	var region := NavigationRegion3D.new()
	region.name = "Navigation"
	region.navigation_mesh = nav
	print("Navigation mesh: %d polygons in %d ms" % [nav.get_polygon_count(), Time.get_ticks_msec() - started])
	return region


static func materials(layout: MapLayout) -> Dictionary:
	var look := DEFAULT_LOOK.duplicate()
	look.merge(layout.look(), true)
	var grid: ImageTexture = _grid_texture() if layout.grid_texture() else null
	var colors := layout.kind_colors()
	var result := {}
	for kind in colors:
		var m := StandardMaterial3D.new()
		m.albedo_color = colors[kind]
		if grid:
			m.albedo_texture = grid
			m.uv1_triplanar = true
			m.uv1_world_triplanar = true
			m.uv1_scale = Vector3(0.25, 0.25, 0.25)  # one grid square per 4 m (sub-lines every 1 m)
		m.roughness = look.roughness
		m.vertex_color_use_as_albedo = true
		var shine: float = look.get("glow", {}).get(kind, 0.0)
		if shine > 0.0:
			m.emission_enabled = true
			m.emission = colors[kind]
			m.emission_energy_multiplier = shine
		result[kind] = m
	return result


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
