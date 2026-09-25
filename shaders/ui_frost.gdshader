shader_type canvas_item;
// Frosted shade: blurs and tints whatever is behind it (the live game behind pause, settings,
// the booklet and results; the beach behind the title menu). It samples the screen's mipmaps
// (these exist in the Compatibility renderer too) with a small ring of taps to smooth the mip
// blocks. `amount` (0..1) fades both the blur and the tint in and out; the rect's own colour alpha
// scales it too, so a ColorRect whose `color.a` is tweened fades the frost the same way.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float blur_lod = 3.0;
uniform vec4 tint : source_color = vec4(0.027, 0.102, 0.173, 0.5);
uniform float vignette = 0.3;
uniform float amount = 1.0;

void fragment() {
	float strength = amount * COLOR.a;
	float lod = blur_lod * strength;
	vec2 texel = SCREEN_PIXEL_SIZE * exp2(lod) * 0.75;
	vec3 sum = textureLod(screen_texture, SCREEN_UV, lod).rgb * 2.0;
	float weight = 2.0;
	for (int i = 0; i < 8; i++) {
		float angle = float(i) * 0.7853982 + 0.3927;
		sum += textureLod(screen_texture, SCREEN_UV + vec2(cos(angle), sin(angle)) * texel, lod).rgb;
		weight += 1.0;
	}
	vec3 color = mix(sum / weight, tint.rgb, tint.a * strength);
	float edge = smoothstep(0.4, 0.95, length((SCREEN_UV - 0.5) * vec2(1.2, 1.0)));
	color *= 1.0 - edge * vignette * strength;
	COLOR = vec4(color, 1.0);
}
