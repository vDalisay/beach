// Shared receiver treatment: no emission and no duplicate surface overlay.
float caustic_pattern(vec3 p, vec3 n, float water_y, float phase,
		sampler2D caustic_tex, vec2 thresholds) {
	float depth = water_y - p.y;
	float submerged = smoothstep(0.08, 0.30, depth);
	float fade = 1.0 - smoothstep(2.5, 5.0, depth);
	float upward = smoothstep(0.15, 0.75, n.y);
	float a = texture(caustic_tex, p.xz * 0.35 + phase * vec2(0.015, 0.008)).r;
	float b = texture(caustic_tex, p.xz * 0.43 + phase * vec2(-0.01, 0.013)).r;
	return smoothstep(thresholds.x, thresholds.y, min(a, b)) * submerged * fade * upward;
}
