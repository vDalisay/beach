shader_type spatial;
render_mode cull_disabled;
#include "res://shaders/beach_caustics.gdshaderinc"

// Sea turtle body. The head and tail are part of the body mesh, so they turn here around
// their joints; TurtleAnimator sets the angles per turtle. Flippers use the same shader
// with neck_enabled off. Model space of art/models/turtle.glb: head faces -Z, shell top +Y;
// the neck leaves the carapace under its front margin (z -0.37) and the tail behind it (z 0.4).

uniform bool neck_enabled = false;
uniform float head_yaw = 0.0;
uniform float head_pitch = 0.0;
uniform float tail_yaw = 0.0;
uniform vec3 neck_pivot = vec3(0.0, 0.068, -0.36);
// Head influence ramps in between these z values, only near the midline, so the neck bends
// out from under the shell while the carapace margin stays put.
uniform vec2 neck_blend = vec2(-0.38, -0.45);
uniform float neck_half_width = 0.09;
uniform vec3 tail_pivot = vec3(0.0, 0.036, 0.36);
uniform vec2 tail_blend = vec2(0.41, 0.46);
uniform float skin_roughness = 0.55;
uniform sampler2D caustic_texture : repeat_enable, filter_linear_mipmap;
uniform float surface_y = 0.08;
uniform float caustic_strength = 0.3;
uniform vec2 caustic_thresholds = vec2(0.16, 0.46);

varying vec3 world_position;
varying vec3 world_normal;

mat3 rotation_y(float angle) {
	float c = cos(angle);
	float s = sin(angle);
	return mat3(vec3(c, 0.0, -s), vec3(0.0, 1.0, 0.0), vec3(s, 0.0, c));
}

mat3 rotation_x(float angle) {
	float c = cos(angle);
	float s = sin(angle);
	return mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, c, s), vec3(0.0, -s, c));
}

void vertex() {
	if (neck_enabled) {
		float midline = 1.0 - smoothstep(neck_half_width, neck_half_width + 0.02, abs(VERTEX.x));
		float head_weight = (1.0 - smoothstep(neck_blend.y, neck_blend.x, VERTEX.z)) * midline;
		if (head_weight > 0.0) {
			mat3 head_rotation = rotation_y(head_yaw) * rotation_x(head_pitch);
			VERTEX = mix(VERTEX, neck_pivot + head_rotation * (VERTEX - neck_pivot), head_weight);
			NORMAL = normalize(mix(NORMAL, head_rotation * NORMAL, head_weight));
		}
		float tail_weight = smoothstep(tail_blend.x, tail_blend.y, VERTEX.z) * midline;
		if (tail_weight > 0.0) {
			mat3 tail_rotation = rotation_y(tail_yaw);
			VERTEX = mix(VERTEX, tail_pivot + tail_rotation * (VERTEX - tail_pivot), tail_weight);
			NORMAL = normalize(mix(NORMAL, tail_rotation * NORMAL, tail_weight));
		}
	}
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float caustic = 0.0;
	if (caustic_strength > 0.0) {
		caustic = caustic_pattern(world_position, normalize(world_normal), surface_y, TIME, caustic_texture, caustic_thresholds);
	}
	ALBEDO = min(COLOR.rgb * (1.0 + caustic_strength * caustic), vec3(1.0));
	ROUGHNESS = skin_roughness;
	SPECULAR = 0.5;
}
