shader_type spatial;

// Backdrop city buildings (MultiMesh). Vertex alpha marks the surface: 1 painted wall, which takes
// the per-instance paint colour from INSTANCE_CUSTOM; 0.5 matte trim, roof and tiles; 0 glass.
varying vec3 paint;

void vertex() {
	paint = INSTANCE_CUSTOM.rgb;
}

void fragment() {
	float painted = step(0.75, COLOR.a);
	float glass = 1.0 - step(0.25, COLOR.a);
	ALBEDO = COLOR.rgb * mix(vec3(1.0), paint, painted);
	ROUGHNESS = mix(0.9, 0.3, glass);
	SPECULAR = mix(0.2, 0.5, glass);
}
