shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

#include "res://shaders/beach_caustics.gdshaderinc"

uniform sampler2D sand_texture : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D macro_noise : repeat_enable, filter_linear_mipmap;
uniform sampler2D caustic_texture : repeat_enable, filter_linear_mipmap;
uniform vec3 dry_color : source_color = vec3(0.902, 0.769, 0.545);
uniform vec3 wet_color : source_color = vec3(0.678, 0.600, 0.435);
uniform vec3 bed_color : source_color = vec3(0.66, 0.6, 0.76);
// Alpha-blended water cannot absorb red light from the sand behind it, so sand seen
// from above the surface carries the transmission tint instead of turning mint.
uniform vec3 transmission_tint : source_color = vec3(0.6, 0.88, 0.92);
uniform bool use_shore_data = true;
uniform bool use_vertex_tint = false;
uniform float surface_y = 0.08;
uniform float caustic_strength = 0.22;
uniform vec2 caustic_thresholds = vec2(0.16, 0.46);
// Negative means live animation; captures set the same phase on all receivers.
uniform float debug_time = -1.0;
varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	float shore_distance = (world_position.z - UV2.x) / sqrt(1.0 + UV2.y * UV2.y);
	float detail = dot(texture(sand_texture, world_position.xz * 0.18).rgb, vec3(0.2126, 0.7152, 0.0722));
	float macro = texture(macro_noise, world_position.xz * 0.035).r;
	float variation = 1.0 + (detail - 0.5) * 0.12 + (macro - 0.5) * 0.06;
	float wet = use_shore_data ? smoothstep(-1.2, 0.35, shore_distance) : 0.0;
	vec3 sand = mix(dry_color, wet_color, wet) * variation;
	if (use_vertex_tint) sand *= COLOR.rgb;
	float depth = max(surface_y - world_position.y, 0.0);
	if (use_shore_data) {
		if (CAMERA_POSITION_WORLD.y > surface_y) {
			sand *= mix(vec3(1.0), transmission_tint, smoothstep(0.0, 1.4, depth));
		} else {
			sand = mix(sand, bed_color, smoothstep(0.0, 3.0, depth) * 0.45) * (1.0 - 0.2 * smoothstep(0.5, 3.0, depth));
		}
	}
	float phase = debug_time >= 0.0 ? debug_time : TIME;
	float caustic = 0.0;
	if (use_shore_data && caustic_strength > 0.0) {
		caustic = caustic_pattern(world_position, normalize(world_normal), surface_y, phase, caustic_texture, caustic_thresholds);
	}
	ALBEDO = min(sand * (1.0 + caustic_strength * caustic), vec3(1.0));
	ROUGHNESS = mix(0.96, 0.65, wet);
	SPECULAR = mix(0.12, 0.25, wet);
}
