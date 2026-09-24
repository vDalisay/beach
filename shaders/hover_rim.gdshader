shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled, fog_disabled;

// Soft additive rim for hovered objects; the only highlight on see-through (glass) meshes.
uniform vec4 rim_color : source_color = vec4(1.0, 0.98, 0.92, 1.0);
uniform float rim_strength = 0.3;
uniform float fill_strength = 0.04;
uniform float rim_power = 2.5;
uniform float breath_amount = 0.2;
uniform float breath_hz = 1.4;
uniform float push = 0.002;

void vertex() {
	VERTEX += NORMAL * push;
}

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - facing, rim_power);
	float pulse = 1.0 + breath_amount * sin(TIME * 6.2831853 * breath_hz);
	ALBEDO = rim_color.rgb * (rim * rim_strength + fill_strength) * pulse;
}
