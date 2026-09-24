shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, skip_vertex_transform, shadows_disabled, fog_disabled;

// Inverted-hull hover outline with constant screen width. HoverHighlight supplies a
// copy of the mesh with welded normals so low-poly hard edges do not crack.
uniform vec4 outline_color : source_color = vec4(1.0);
uniform float width_px = 2.5;
uniform float max_world_width = 0.03;
uniform float dash_px = 0.0; // > 0: diagonal screen-space dashes (blocked style)

void vertex() {
	vec4 view_position = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 view_normal = normalize(MODELVIEW_NORMAL_MATRIX * NORMAL);
	float view_distance = max(-view_position.z, 0.05);
	// abs(): the Compatibility renderer flips Y in the projection for its render targets.
	float metres_per_pixel = 2.0 * view_distance / (abs(PROJECTION_MATRIX[1][1]) * VIEWPORT_SIZE.y);
	view_position.xyz += view_normal * min(width_px * metres_per_pixel, max_world_width);
	VERTEX = view_position.xyz;
	NORMAL = view_normal;
}

void fragment() {
	if (dash_px > 0.0 && mod(floor((FRAGCOORD.x + FRAGCOORD.y) / dash_px), 2.0) < 1.0) {
		discard;
	}
	ALBEDO = outline_color.rgb;
}
