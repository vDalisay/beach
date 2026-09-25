shader_type canvas_item;

// Diagonal highlight band for HUD bars and banners. `progress` sweeps -0.3 -> 1.3.
uniform float progress = -1.0;
uniform float width = 0.18;
uniform float strength = 0.6;
uniform vec2 rect_size = vec2(100.0, 10.0);

varying vec2 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;
	float diagonal = (local_position.x + local_position.y * 0.35) / max(rect_size.x, 1.0);
	float band = 1.0 - smoothstep(0.0, width, abs(diagonal - progress));
	COLOR = vec4(base.rgb + vec3(band * strength) * base.a, base.a);
}
