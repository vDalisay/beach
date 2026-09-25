shader_type spatial;
// Native ambient/radiance is replaced by explicit fill and a tinted grazing reflection:
// the pale horizon sky otherwise turns all distant water white-mint. Sun glints stay native.
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert, specular_schlick_ggx, ambient_light_disabled;

#include "res://shaders/beach_swash.gdshaderinc"

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D normal_texture : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D noise_texture : repeat_enable, filter_linear_mipmap;
uniform vec3 shallow_color : source_color = vec3(0.502, 0.796, 0.745);
uniform vec3 deep_color : source_color = vec3(0.176, 0.624, 0.667);
uniform vec3 offshore_color : source_color = vec3(0.137, 0.427, 0.537);
uniform vec3 foam_color : source_color = vec3(0.957, 0.965, 0.871);
uniform vec3 underside_color : source_color = vec3(0.224, 0.498, 0.573);
uniform vec3 underside_window_color : source_color = vec3(0.62, 0.80, 0.93);
uniform vec3 ambient_fill : source_color = vec3(0.722, 0.741, 0.812);
uniform float ambient_fill_energy = 0.32;
uniform vec3 reflection_color : source_color = vec3(0.64, 0.82, 0.92);
uniform float reflection_strength = 0.3;
uniform float absorption_density = 0.20;
uniform float normal_strength = 0.06;
uniform float debug_time = -1.0;
// 0 when the Beach detail graphics setting is Off: no rolling surf, only the edge foam.
uniform int surf_level : hint_range(0, 1) = 1;
varying vec3 world_position;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec3 reconstruct_view(vec2 uv, float raw_depth, mat4 inverse_projection) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
    vec3 ndc = vec3(uv * 2.0 - 1.0, raw_depth * 2.0 - 1.0);
#else
    vec3 ndc = vec3(uv * 2.0 - 1.0, raw_depth);
#endif
    vec4 p = inverse_projection * vec4(ndc, 1.0);
    return p.xyz / max(p.w, 0.00001);
}

void fragment() {
    float phase = debug_time >= 0.0 ? debug_time : TIME;
    float shore_distance = (world_position.z - UV2.x) / sqrt(1.0 + UV2.y * UV2.y);
    float bed_depth = COLOR.r * 8.0;
    vec2 uv_a = world_position.xz * 0.18 + phase * vec2(0.018, 0.006);
    vec2 uv_b = world_position.xz * 0.11 + phase * vec2(-0.009, 0.012);
    vec2 perturb = (texture(normal_texture, uv_a).rg * 2.0 - 1.0
                 + texture(normal_texture, uv_b).rg * 2.0 - 1.0) * normal_strength;
    float distance_fade = 1.0 - smoothstep(45.0, 140.0, length(VERTEX));
    vec3 n_world = normalize(vec3(perturb.x * distance_fade, 1.0, perturb.y * distance_fade));
    if (!FRONT_FACING) n_world = -n_world;
    NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);
    ROUGHNESS = 0.28;
    SPECULAR = 0.25;
    METALLIC = 0.0;

    float raw_depth = texture(depth_texture, SCREEN_UV).r;
    // Godot 4.6 uses reverse Z in all renderers: cleared/far depth is zero.
    bool valid_depth = raw_depth > 0.00001;
    vec3 opaque_view = reconstruct_view(SCREEN_UV, raw_depth, INV_PROJECTION_MATRIX);
    float path_length = valid_depth ? clamp(length(opaque_view - VERTEX), 0.0, 30.0) : 30.0;
    float contact_depth = valid_depth ? max(0.0, -opaque_view.z + VERTEX.z) : 30.0;
    vec3 body_color = mix(shallow_color, deep_color, smoothstep(0.25, 3.2, bed_depth));
    body_color = mix(body_color, offshore_color, smoothstep(55.0, 230.0, shore_distance) * 0.75);
    float facet = texture(noise_texture, world_position.xz * 0.09).r;
    body_color *= 1.0 + (facet - 0.5) * 0.12;
    float absorption = 1.0 - exp(-absorption_density * path_length);
    float fresnel = 0.02 + 0.98 * pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 5.0);
    float opacity = clamp(max(absorption, 0.65 * fresnel), 0.04, 0.92);
    opacity *= smoothstep(0.0, 0.35, shore_distance);

    float noise = texture(noise_texture, world_position.xz * 0.8 + phase * vec2(0.02, -0.01)).r;
    float breakup = smoothstep(0.26, 0.58, noise);
    // The supplied noise is fine grain. A coarse mip supplies metre-scale gaps
    // that survive minification instead of averaging into an unbroken white line.
    float patches = textureLod(noise_texture, world_position.xz * 0.025 + phase * vec2(0.003, -0.001), 3.0).r;
    float patch_mask = mix(0.3, 1.0, smoothstep(0.47, 0.53, patches));
    // White water rolls in from the surf and breaks onto the sand in step with the swash that
    // the sand shader draws (beach_swash.gdshaderinc).
    vec2 surf = vec2(0.0, (1.0 - smoothstep(0.0, 0.8, shore_distance)) * 0.45);
    if (surf_level > 0) {
        surf = swash_water(world_position.x, shore_distance, phase);
    }
    float shore_foam = max(surf.x * smoothstep(0.18, 0.55, noise), surf.y * breakup) * patch_mask;
    float contact_foam = (1.0 - smoothstep(0.02, 0.18, contact_depth)) * breakup * 0.25;
    contact_foam *= (1.0 - smoothstep(15.0, 25.0, length(VERTEX))) * float(valid_depth);
    float foam = max(shore_foam, contact_foam);
    if (FRONT_FACING) {
        ALBEDO = mix(body_color, foam_color, foam);
        ALPHA = max(opacity, foam * 0.9);
        float grazing = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
        EMISSION = ALBEDO * ambient_fill * ambient_fill_energy
                 + reflection_color * reflection_strength * grazing * (1.0 - foam);
    } else {
        // From below, the surface is mostly a bright window overhead and an opaque
        // mirror of the water at grazing angles, so the sky above does not show through.
        float overhead = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
        ALBEDO = vec3(0.0);
        EMISSION = mix(underside_color, underside_window_color, smoothstep(0.55, 0.95, overhead)) * 0.9;
        ALPHA = mix(0.96, 0.82, smoothstep(0.55, 0.95, overhead));
        SPECULAR = 0.0;
    }
}
