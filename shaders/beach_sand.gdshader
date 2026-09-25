shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

#include "res://shaders/beach_caustics.gdshaderinc"
#include "res://shaders/beach_swash.gdshaderinc"

uniform sampler2D sand_texture : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D macro_noise : repeat_enable, filter_linear_mipmap;
uniform sampler2D caustic_texture : repeat_enable, filter_linear_mipmap;
// Project sand detail (tools/build_sand_detail.gd), tileable over 2 m: grain, ripple height, grit
// and sparkle; ripple and grain slopes; and an atlas of shells, pebbles and seaweed scraps.
uniform sampler2D detail_texture : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D detail_normals : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D shell_atlas : source_color, repeat_disable, filter_linear_mipmap;
uniform vec3 dry_color : source_color = vec3(0.902, 0.769, 0.545);
uniform vec3 wet_color : source_color = vec3(0.678, 0.600, 0.435);
uniform vec3 bed_color : source_color = vec3(0.66, 0.6, 0.76);
// Alpha-blended water cannot absorb red light from the sand behind it, so sand seen
// from above the surface carries the transmission tint instead of turning mint.
uniform vec3 transmission_tint : source_color = vec3(0.6, 0.88, 0.92);
uniform bool use_shore_data = true;
uniform bool use_vertex_tint = false;
// Grain, grit, ripples and shells; off for the inland city ground that reuses this material.
uniform bool beach_detail = true;
uniform float surface_y = 0.08;
uniform float caustic_strength = 0.22;
uniform vec2 caustic_thresholds = vec2(0.16, 0.46);
// Negative means live animation; captures set the same phase on all receivers.
uniform float debug_time = -1.0;
// Dry crests read a touch paler and warmer than the hollows, so dunes and mounds read at a glance.
uniform vec3 crest_tint : source_color = vec3(1.0, 0.97, 0.9);
uniform vec2 crest_heights = vec2(0.08, 1.6);
// The old high-tide line: a faint band of darker, dried seaweed-coloured sand where the tideline
// litter lies (LitterLayout.TIDELINE), broken into lengths by the macro noise.
uniform vec3 wrack_color : source_color = vec3(0.62, 0.52, 0.36);
uniform vec3 wrack_band = vec3(-6.2, 0.9, 0.55);
// Detail: texture tiles per metre, how strongly grain and grit show, wind-ripple depth, shells per
// cell, and the distance over which fine detail fades out.
uniform float detail_scale = 0.5;
uniform float grain_strength = 1.0;
uniform float ripple_strength = 0.9;
uniform float shell_density = 1.0;
uniform float detail_distance = 32.0;
// The Beach detail graphics setting (RenderQuality.apply_beach_detail):
//   0 Off     plain sand and a still wet band at the waterline, no waves on the sand;
//   1 Low     waves run up the sand and leave it wet; one layer of sand grain and grit;
//   2 Medium  adds a second grain layer, wind ripples and grain relief, shells and lacy foam;
//   3 High    adds glinting grains.
// Every branch on it is uniform across the screen, so texture reads inside stay well defined.
uniform int detail_level : hint_range(0, 3) = 3;
// The swash sheet and its foam.
uniform vec3 film_color : source_color = vec3(0.55, 0.8, 0.82);
uniform vec3 foam_color : source_color = vec3(0.97, 0.98, 0.95);
varying vec3 world_position;
varying vec3 world_normal;

const float SHELL_CELL = 0.7;

vec4 cell_hash(vec2 cell) {
	vec4 p = fract(vec4(cell.xyxy) * vec4(0.1031, 0.1030, 0.0973, 0.1099));
	p += dot(p, p.wzxy + 33.33);
	return fract((p.xxyz + p.yzzw) * p.zywx);
}

// A shell, pebble or seaweed scrap lying in this cell, if any: rgb and coverage. `ddx`/`ddy` are
// the screen derivatives of xz, taken outside any branch.
vec4 shell_at(vec2 xz, vec2 ddx, vec2 ddy, float density) {
	vec2 cell = floor(xz / SHELL_CELL);
	vec4 h = cell_hash(cell);
	if (h.x >= density) {
		return vec4(0.0);
	}
	float kind = floor(h.w * 16.0);
	float size = mix(0.06, 0.11, fract(h.y * 13.7 + h.z * 3.1));
	// Pebbles and grit-sized shards are smaller; the starfish and seaweed a little larger.
	if (kind >= 12.0 && kind < 15.0) size *= 0.75;
	if (kind == 11.0 || kind == 15.0) size *= 1.25;
	float footprint = max(length(ddx), length(ddy));
	float fade = 1.0 - smoothstep(size * 0.35, size * 0.9, footprint);
	if (fade <= 0.0) {
		return vec4(0.0);
	}
	vec2 centre = (cell + 0.24 + 0.52 * h.yz) * SHELL_CELL;
	float angle = fract(h.z * 9.31 + h.y * 2.7) * 6.2831853;
	mat2 turn = mat2(vec2(cos(angle), -sin(angle)), vec2(sin(angle), cos(angle)));
	float span = 2.0 * size * 1.12;
	vec2 local = turn * (xz - centre) / span + 0.5;
	if (any(lessThan(local, vec2(0.0))) || any(greaterThan(local, vec2(1.0)))) {
		return vec4(0.0);
	}
	vec2 tile = vec2(mod(kind, 4.0), floor(kind / 4.0));
	vec4 texel = textureGrad(shell_atlas, (tile + local) * 0.25, turn * ddx / span * 0.25, turn * ddy / span * 0.25);
	return vec4(texel.rgb, texel.a * fade);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	float phase = debug_time >= 0.0 ? debug_time : TIME;
	float shore_distance = (world_position.z - UV2.x) / sqrt(1.0 + UV2.y * UV2.y);
	vec2 xz = world_position.xz;
	bool grain_on = beach_detail && detail_level >= 1;
	bool relief_on = beach_detail && detail_level >= 2;
	float near = relief_on ? 1.0 - smoothstep(detail_distance * 0.45, detail_distance, length(VERTEX)) : 0.0;
	float detail = dot(texture(sand_texture, xz * 0.18).rgb, vec3(0.2126, 0.7152, 0.0722));
	float macro = texture(macro_noise, xz * 0.035).r;
	float variation = 1.0 + (detail - 0.5) * 0.12 + (macro - 0.5) * 0.06;

	// Wetness: underwater sand, the swash band that never quite dries, and each wave's fresh wet.
	float p = -shore_distance;
	vec4 swash = vec4(0.0);
	float wet = 0.0;
	if (use_shore_data) {
		wet = 1.0 - smoothstep(-0.6, 0.35, p);
		if (detail_level == 0) {
			// No waves: a still strip of wet sand along the water.
			wet = max(wet, (1.0 - smoothstep(0.0, 1.6, p)) * 0.85);
		} else if (p > 0.0 && p < SWASH_REACH + 0.5) {
			swash = swash_sand(world_position.x, p, phase);
			float reach = swash_reach_max(world_position.x);
			float damp = 1.0 - smoothstep(reach * 0.55, reach * 1.1, p);
			wet = max(wet, max(damp * 0.55, swash.z));
		}
	}

	// Grain and grit (Low and up), and a second, larger grain scale that hides the tiling (Medium).
	vec4 grain_a = vec4(0.5, 0.5, 0.5, 0.0);
	vec4 grain_b = vec4(0.5);
	if (grain_on) {
		grain_a = texture(detail_texture, xz * detail_scale);
	}
	if (relief_on) {
		grain_b = texture(detail_texture, xz * detail_scale * 0.37 + vec2(0.31, 0.77));
	}
	float fine = grain_on ? grain_strength : 0.0;
	variation *= 1.0 + ((grain_a.r - 0.5) * 0.16 + (grain_b.r - 0.5) * 0.1) * fine;
	vec3 sand = mix(dry_color, wet_color, wet) * variation;
	if (use_vertex_tint) sand *= COLOR.rgb;
	float grit_dark = 1.0 - smoothstep(0.12, 0.42, grain_a.b);
	float grit_pale = smoothstep(0.58, 0.9, grain_a.b);
	float grit_fade = mix(0.35, 1.0, relief_on ? near : 1.0) * fine;
	sand = mix(sand, sand * 0.62, grit_dark * 0.45 * grit_fade);
	sand = mix(sand, mix(vec3(0.97, 0.94, 0.88), vec3(0.95, 0.8, 0.76), grain_b.g), grit_pale * 0.7 * grit_fade * (1.0 - wet * 0.4));
	float wrack = 0.0;
	if (use_shore_data) {
		sand = mix(sand, sand * crest_tint * 1.08, smoothstep(crest_heights.x, crest_heights.y, world_position.y) * (1.0 - wet));
		wrack = (1.0 - smoothstep(0.0, wrack_band.y, abs(shore_distance - wrack_band.x))) * smoothstep(0.42, 0.62, texture(macro_noise, xz * 0.06).r);
		sand = mix(sand, wrack_color * variation, wrack * wrack_band.z);
	}

	// Wind ripples on dry, open sand (in patches, never on wet sand) and fine grain relief (Medium).
	vec3 n_world = normalize(world_normal);
	if (relief_on) {
		vec4 slopes = texture(detail_normals, xz * detail_scale);
		float ripple_patch = texture(macro_noise, xz * 0.013 + vec2(0.4, 0.1)).r;
		float ripple_mask = (1.0 - wet) * smoothstep(0.38, 0.62, ripple_patch) * ripple_strength * near * (1.0 - wrack * 0.6);
		sand *= 1.0 + (grain_a.g - 0.5) * 0.08 * ripple_mask;
		vec2 slope = (slopes.rg * 2.0 - 1.0) * ripple_mask * 0.55 + (slopes.ba * 2.0 - 1.0) * 0.22 * near * (1.0 - swash.x);
		n_world = normalize(n_world + vec3(-slope.x, 0.0, -slope.y));
	}

	// Shells and pebbles (Medium): a few everywhere, more along the tideline and where waves wash.
	float shell_cover = 0.0;
	if (relief_on && shell_density > 0.0) {
		vec2 ddx = dFdx(xz);
		vec2 ddy = dFdy(xz);
		if (near > 0.0) {
			float zone = 1.0;
			if (use_shore_data) {
				zone += 2.6 * (1.0 - smoothstep(0.0, 2.2, abs(shore_distance - wrack_band.x)));
				zone += 1.6 * (1.0 - smoothstep(0.0, 4.5, abs(p - 1.2)));
			}
			vec4 shell = shell_at(xz, ddx, ddy, 0.1 * shell_density * zone);
			shell_cover = shell.a * near;
			sand = mix(sand, shell.rgb * mix(1.0, 0.82, wet), shell_cover);
		}
	}

	// The swash sheet: a glossy film tinted by the water, with foam riding its front; the foam is
	// broken into lace from Medium up.
	float film = swash.x;
	// Low breaks the foam up with the grain it has already read; Medium adds a moving lace texture.
	float lace = grain_on ? smoothstep(0.3, 0.62, grain_a.r) * 0.85 + 0.15 : 0.75;
	if (relief_on) {
		float lace_grain = texture(detail_texture, xz * 0.9 + vec2(phase * 0.05, -phase * 0.21)).r;
		lace = smoothstep(0.35, 0.75, lace_grain * 0.6 + grain_b.r * 0.6);
	}
	sand = mix(sand, sand * film_color * 1.18, film * mix(0.45, 0.7, swash.w));
	sand = mix(sand, foam_color, clamp(swash.y * lace * 1.3, 0.0, 0.95));

	float depth = max(surface_y - world_position.y, 0.0);
	if (use_shore_data) {
		if (CAMERA_POSITION_WORLD.y > surface_y) {
			sand *= mix(vec3(1.0), transmission_tint, smoothstep(0.0, 1.4, depth));
		} else {
			sand = mix(sand, bed_color, smoothstep(0.0, 3.0, depth) * 0.45) * (1.0 - 0.2 * smoothstep(0.5, 3.0, depth));
		}
	}
	float caustic = 0.0;
	if (use_shore_data && caustic_strength > 0.0) {
		caustic = caustic_pattern(world_position, normalize(world_normal), surface_y, phase, caustic_texture, caustic_thresholds);
	}
	// Faint glints from dry grains that catch the light as the view moves across them (High).
	float glint = 0.0;
	if (relief_on && detail_level >= 3) {
		float glint_grain = texture(detail_texture, xz * detail_scale * 1.7 + VIEW.xy * 0.02).a;
		glint = glint_grain * grain_a.a * (1.0 - wet) * near * 0.6 * fine;
	}
	ALBEDO = min(sand * (1.0 + caustic_strength * caustic), vec3(1.0));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);
	ROUGHNESS = mix(mix(0.96, 0.32, wet), 0.06, film) * mix(1.0, 0.8, shell_cover);
	SPECULAR = mix(mix(0.12, 0.32, wet), 0.55, film);
	EMISSION = vec3(glint);
}
