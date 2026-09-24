shader_type spatial;
render_mode cull_disabled;
#include "res://shaders/beach_caustics.gdshaderinc"

// Reef fish swimming for MultiMesh schools. The model's head faces -Z; each instance's
// INSTANCE_CUSTOM carries (tail-beat phase, tail amplitude as a fraction of body length,
// C-bend curvature), written every frame by FishSchool. Instance colour shades each fish.

uniform float head_z = -0.15;
uniform float tail_z = 0.18;
// Radians of travelling wave between nose and tail tip (about one body wavelength).
uniform float wave_number = 5.4;
uniform float fish_roughness = 0.45;
uniform sampler2D caustic_texture : repeat_enable, filter_linear_mipmap;
uniform float surface_y = 0.08;
uniform float caustic_strength = 0.3;
uniform vec2 caustic_thresholds = vec2(0.16, 0.46);

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	float body_length = tail_z - head_z;
	float s = clamp((VERTEX.z - head_z) / body_length, 0.0, 1.0);
	float phase = INSTANCE_CUSTOM.x;
	float amplitude = INSTANCE_CUSTOM.y * body_length;
	float bend = INSTANCE_CUSTOM.z;
	// Subcarangiform wave: the head recoils a little, the rear third and tail sweep widely.
	float envelope = amplitude * (0.08 + 0.92 * s * s);
	float wave = phase - s * wave_number;
	// A turning or startled fish curls into a C, head and tail toward the inside.
	float lateral = envelope * sin(wave) + bend * body_length * s * s;
	// Slope of the displaced midline along the body keeps the faceted shading attached.
	float slope = (amplitude * 1.84 * s * sin(wave) - envelope * wave_number * cos(wave)) / body_length + bend * 2.0 * s;
	VERTEX.x += lateral;
	float angle = atan(slope);
	float c = cos(angle);
	float sn = sin(angle);
	NORMAL = vec3(c * NORMAL.x + sn * NORMAL.z, NORMAL.y, -sn * NORMAL.x + c * NORMAL.z);
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float caustic = 0.0;
	if (caustic_strength > 0.0) {
		caustic = caustic_pattern(world_position, normalize(world_normal), surface_y, TIME, caustic_texture, caustic_thresholds);
	}
	ALBEDO = min(COLOR.rgb * (1.0 + caustic_strength * caustic), vec3(1.0));
	ROUGHNESS = fish_roughness;
	SPECULAR = 0.55;
}
