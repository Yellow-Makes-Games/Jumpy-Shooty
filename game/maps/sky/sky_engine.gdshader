shader_type sky;
// The sky engine's still picture, used as the Environment's sky (see sky_engine.gdshaderinc).
// It never uses TIME or POSITION: either would make Godot capture the map's lighting
// from the sky again every frame. What moves is drawn by sky_dome.gdshader instead.

#include "res://game/maps/sky/sky_engine.gdshaderinc"

// Where the cloud sea is seen from (the middle of the map at head height).
uniform vec3 eye_origin = vec3(0.0, 2.0, 0.0);
// The moment the still picture shows (moving layers stand still at it).
uniform float still_time = 40.0;

void sky() {
	COLOR = sky_engine(normalize(EYEDIR), eye_origin, still_time, !AT_CUBEMAP_PASS);
}
