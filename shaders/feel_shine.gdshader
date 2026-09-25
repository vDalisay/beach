shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled, fog_disabled;

// "Done" gleam applied as a per-effect material_overlay. A diagonal band crosses the
// object set; a rim flash and sparse glints ride with it. Additive: output is light only.
uniform vec3 sweep_origin;
uniform vec3 sweep_direction = vec3(1.0, 0.0, 0.0);
uniform float sweep_distance = 1.0;
uniform float progress = 0.0;       // -0.15 .. 1.15 animated by FeelShine
uniform float band_width = 0.22;    // fraction of sweep_distance
uniform vec4 core_color : source_color = vec4(1.0, 0.973, 0.902, 1.0);
uniform vec4 fringe_color : source_color = vec4(0.561, 0.953, 0.878, 1.0);
uniform float intensity = 1.0;
uniform float rim_strength = 0.45;
uniform float glint_density = 18.0;

varying vec3 world_position;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float along = dot(world_position - sweep_origin, sweep_direction) / max(sweep_distance, 0.01);
	float d = along - progress;
	float core = 1.0 - smoothstep(0.0, band_width * 0.35, abs(d));
	float fringe = 1.0 - smoothstep(band_width * 0.2, band_width, abs(d));
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - facing, 2.5) * rim_strength * (1.0 - smoothstep(0.0, 0.6, abs(d)));
	float glint = step(0.93, hash13(floor(world_position * glint_density))) * fringe;
	vec3 light = core_color.rgb * (core * 1.2 + glint * 0.8) + fringe_color.rgb * (fringe * 0.35 + rim);
	ALBEDO = light * intensity;
}
