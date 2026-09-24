shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// Soft round puff for ParticlePool.DUST. Instance colour alpha fades it.
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float soft = 1.0 - smoothstep(0.15, 1.0, dot(p, p));
	ALBEDO = COLOR.rgb;
	ALPHA = soft * COLOR.a * 0.8;
}
