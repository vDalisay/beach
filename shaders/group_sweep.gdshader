shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec3 sweep_origin;
uniform vec3 sweep_direction;
uniform float sweep_distance = 1.0;
uniform float sweep_progress : hint_range(0.0, 1.0) = 0.0;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float along = dot(world_position - sweep_origin, sweep_direction) / max(sweep_distance, 0.01);
	float band = 1.0 - smoothstep(0.0, 0.3, abs(along - sweep_progress));
	ALBEDO = vec3(0.62, 0.95, 0.82);
	EMISSION = vec3(0.32, 1.0, 0.74) * band * 1.5;
	ALPHA = band * 0.9;
}
