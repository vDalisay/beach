shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, shadows_disabled;

// Air bubble: nearly clear in the middle with a bright silvery rim, the way total internal
// reflection makes bubbles read underwater. Instance colour alpha fades each particle.

uniform vec4 tint : source_color = vec4(0.88, 0.97, 1.0, 1.0);
uniform float rim_power = 2.4;
uniform float rim_glow = 0.7;

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - facing, rim_power);
	ALBEDO = tint.rgb;
	ROUGHNESS = 0.06;
	SPECULAR = 0.9;
	EMISSION = tint.rgb * rim * rim_glow;
	ALPHA = clamp(0.18 + rim * 0.82, 0.0, 1.0) * COLOR.a;
}
