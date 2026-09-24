shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec3 top_color : source_color = vec3(1.0, 0.957, 0.875);
uniform vec3 underside_color : source_color = vec3(0.729, 0.796, 0.875);
uniform vec3 sun_direction = vec3(0.0, 1.0, 0.0);

void fragment() {
	vec3 n_world = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float top = smoothstep(-0.45, 0.65, n_world.y);
	ALBEDO = mix(underside_color, top_color, top) + vec3(0.025) * max(dot(n_world, sun_direction), 0.0);
}
