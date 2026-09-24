shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

// Palm City character atlas with the character skin mask applied; the converted polygon
// shader carries the mask parameters but never samples them.
uniform sampler2D base_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D skin_mask : filter_linear_mipmap, repeat_enable;
uniform vec4 skin_color : source_color = vec4(0.8, 0.58, 0.44, 1.0);
uniform float smoothness : hint_range(0.0, 1.0) = 0.2;

void fragment() {
	vec3 base = texture(base_texture, UV).rgb;
	float skin = texture(skin_mask, UV).r;
	ALBEDO = mix(base, skin_color.rgb, skin);
	ROUGHNESS = 1.0 - smoothness;
}
