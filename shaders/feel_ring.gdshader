shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// Flat additive ring on a unit plane (FeelRing, sand-cleaner area preview).
uniform vec4 ring_color : source_color = vec4(1.0);
uniform float thickness = 0.04;   // UV units of the unit plane (0..0.5)
uniform float intensity = 1.0;
uniform float dashes = 0.0;       // 0 = solid ring
uniform float dash_phase = 0.0;

void fragment() {
	vec2 p = UV - vec2(0.5);
	float r = length(p);
	float t = max(thickness, 0.001);
	float band = 1.0 - smoothstep(0.0, t, abs(r - (0.5 - t)));
	if (dashes > 0.0) {
		float a = atan(p.y, p.x) / 6.2831853 + 0.5;
		band *= step(0.45, fract(a * dashes + dash_phase));
	}
	ALBEDO = ring_color.rgb * band * intensity;
}
