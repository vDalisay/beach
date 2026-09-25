shader_type canvas_item;
// Sticker rim for model-rendered and 3D-sprite icons drawn over the world: a navy outline of
// `width` screen pixels around the icon's silhouette and a small drop underneath, so an icon of a
// beach chair still reads in front of real beach chairs. Width is in screen pixels (via fwidth),
// so the rim is the same at every icon size, UI scale and resolution.

uniform vec4 outline_color : source_color = vec4(0.043, 0.165, 0.267, 1.0);
uniform float width = 2.0;
uniform float drop = 1.5;

void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;
	vec2 step_uv = fwidth(UV) * width;
	float rim = 0.0;
	for (int i = 0; i < 12; i++) {
		float angle = float(i) * 0.5235988;
		rim = max(rim, texture(TEXTURE, UV + vec2(cos(angle), sin(angle)) * step_uv).a);
	}
	rim = max(rim, texture(TEXTURE, UV - vec2(0.0, fwidth(UV).y * (width + drop))).a * 0.75);
	float rim_alpha = rim * outline_color.a * COLOR.a;
	float alpha = base.a + rim_alpha * (1.0 - base.a);
	vec3 rgb = (base.rgb * base.a + outline_color.rgb * rim_alpha * (1.0 - base.a)) / max(alpha, 0.0001);
	COLOR = vec4(rgb, alpha);
}
