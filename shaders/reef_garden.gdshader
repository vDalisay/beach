shader_type spatial;
render_mode cull_disabled;

// Restoration coral gardens (MultiMesh): the model's vertex shading times a per-instance reef
// colour from INSTANCE_CUSTOM, faded in from bleached grey as the section is restored.
uniform vec3 bleached_color : source_color = vec3(0.251, 0.322, 0.341);
uniform float restored : hint_range(0.0, 1.0) = 0.0;
// Regrowth layers grow each piece up from its base as the section is restored.
uniform float growth : hint_range(0.0, 1.0) = 1.0;
// Restoration wave (presentation): pieces within wave_front metres of wave_origin (on the ground
// plane) are reached; each warms, and grows when grow_with_wave is 1, as the front passes it.
// The default front reaches everything, so the garden looks as it always did.
uniform vec3 wave_origin = vec3(0.0);
uniform float wave_front = 100000.0;
uniform float wave_feather = 4.0;
uniform float grow_with_wave : hint_range(0.0, 1.0) = 0.0;

varying vec3 reef_color;
varying float reached;

void vertex() {
	reef_color = INSTANCE_CUSTOM.rgb;
	vec3 piece = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	reached = 1.0 - smoothstep(wave_front - wave_feather, wave_front, distance(piece.xz, wave_origin.xz));
	VERTEX *= growth * mix(1.0, reached, grow_with_wave);
}

void fragment() {
	ALBEDO = COLOR.rgb * mix(bleached_color, reef_color, restored * reached);
	ROUGHNESS = 0.85;
}
