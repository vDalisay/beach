shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// Four-point star for ParticlePool.SPARKLE. Instance colour alpha fades it.
uniform float ray_sharpness = 9.0;
uniform float core_tightness = 14.0;
uniform float brightness = 1.4;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float core = exp(-dot(p, p) * core_tightness);
	float ray_x = max(0.0, 1.0 - abs(p.y) * ray_sharpness) * (1.0 - abs(p.x));
	float ray_y = max(0.0, 1.0 - abs(p.x) * ray_sharpness) * (1.0 - abs(p.y));
	float star = clamp(core + (ray_x + ray_y) * 0.7, 0.0, 1.0);
	ALBEDO = COLOR.rgb * star * COLOR.a * brightness;
}
