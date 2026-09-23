shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform sampler2D noise_texture : source_color, repeat_enable;
uniform vec3 sand_color : source_color = vec3(0.18, 0.36, 0.34);

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 drift = vec2(TIME * 0.013, -TIME * 0.009);
	float noise = texture(noise_texture, world_position.xz * 0.055 + drift).r;
	float caustic = smoothstep(0.64, 0.8, noise) * 0.1;
	ALBEDO = sand_color + vec3(caustic * 0.7, caustic, caustic * 0.88);
	ROUGHNESS = 0.95;
}
