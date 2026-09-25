shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

// Expanding "life returns" light wall (open cylinder). Brightest at its base.
uniform vec4 wave_color : source_color = vec4(1.0, 0.945, 0.788, 1.0);
uniform float intensity = 1.0;
uniform float wall_height = 1.2;
uniform float shimmer = 0.35;
// How fast the light fades with height: steep for the wall, gentle for the beacon column.
uniform float fade_power = 2.2;

varying vec3 local_position;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	float height = clamp(local_position.y / wall_height + 0.5, 0.0, 1.0);
	float fade = pow(1.0 - height, fade_power);
	float angle = atan(local_position.z, local_position.x);
	float streak = hash12(vec2(floor(angle * 40.0), floor(TIME * 8.0)));
	ALBEDO = wave_color.rgb * fade * (1.0 - shimmer + shimmer * streak) * intensity;
}
