shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix, shadows_disabled, fog_disabled;

// Placement hologram: soft fill, bright fresnel rim, rising scan lines, gentle breath.
uniform vec4 ghost_color : source_color = vec4(0.5, 0.96, 0.78, 1.0);
uniform float fill_alpha = 0.16;
uniform float rim_alpha = 0.85;
uniform float rim_power = 2.0;
uniform float scan_density = 14.0;  // lines per metre
uniform float scan_speed = 0.35;    // metres per second
uniform float breath_amount = 0.12; // 0 under reduced motion
uniform float appear = 1.0;         // script animates 0 -> 1 on show, 1 -> 0 on fade

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - facing, rim_power);
	float line = 1.0 - smoothstep(0.0, 0.08, fract(world_position.y * scan_density - TIME * scan_speed * scan_density));
	float breath = 1.0 + breath_amount * sin(TIME * 6.2831853 * 1.2);
	float alpha = (fill_alpha + line * 0.08 + rim * rim_alpha) * breath;
	ALBEDO = mix(ghost_color.rgb, vec3(1.0), rim * 0.5 + line * 0.3);
	ALPHA = clamp(alpha, 0.0, 1.0) * appear;
}
