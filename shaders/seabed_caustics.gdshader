shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;
#include "res://shaders/beach_caustics.gdshaderinc"

uniform sampler2D caustic_texture : repeat_enable, filter_linear_mipmap;
uniform vec3 stone_color : source_color = vec3(0.2, 0.37, 0.35);
uniform float surface_y = 0.08;
uniform float caustic_strength = 0.12;
uniform vec2 caustic_thresholds = vec2(0.16, 0.46);
uniform float debug_time = -1.0;
varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
    float phase = debug_time >= 0.0 ? debug_time : TIME;
    float caustic = 0.0;
    if (caustic_strength > 0.0) {
        caustic = caustic_pattern(world_position, normalize(world_normal), surface_y, phase, caustic_texture, caustic_thresholds);
    }
    ALBEDO = min(stone_color * (1.0 + caustic_strength * caustic), vec3(1.0));
    ROUGHNESS = 0.95;
    SPECULAR = 0.12;
}
