shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha, blend_mix;

uniform vec4 ghost_color : source_color = vec4(0.28, 1.0, 0.62, 0.38);

void fragment() {
	ALBEDO = ghost_color.rgb;
	EMISSION = ghost_color.rgb * 0.35;
	ALPHA = ghost_color.a;
}
