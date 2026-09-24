shader_type spatial;
render_mode cull_disabled;

// Restoration coral gardens (MultiMesh): the model's vertex shading times a per-instance reef
// colour from INSTANCE_CUSTOM, faded in from bleached grey as the section is restored.
uniform vec3 bleached_color : source_color = vec3(0.251, 0.322, 0.341);
uniform float restored : hint_range(0.0, 1.0) = 0.0;
// Regrowth layers grow each piece up from its base as the section is restored.
uniform float growth : hint_range(0.0, 1.0) = 1.0;

varying vec3 reef_color;

void vertex() {
	reef_color = INSTANCE_CUSTOM.rgb;
	VERTEX *= growth;
}

void fragment() {
	ALBEDO = COLOR.rgb * mix(bleached_color, reef_color, restored);
	ROUGHNESS = 0.85;
}
