shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;
#include "res://shaders/beach_caustics.gdshaderinc"

uniform sampler2D caustic_texture : repeat_enable, filter_linear_mipmap;
uniform vec3 stone_color : source_color = vec3(0.45, 0.47, 0.76);
uniform vec3 stone_color_alt : source_color = vec3(0.27, 0.32, 0.63);
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
    // One shade per rock instance, so neighbouring boulders separate like the reference.
    vec3 origin = MODEL_MATRIX[3].xyz;
    float pick = fract(sin(dot(origin.xz, vec2(12.9898, 78.233))) * 43758.5453);
    vec3 stone = mix(stone_color, stone_color_alt, step(0.55, pick));
    // Seen through the alpha-blended surface, submerged rock carries the water's absorption.
    if (CAMERA_POSITION_WORLD.y > surface_y) {
        stone *= vec3(0.3, 0.55, 0.66);
    }
    ALBEDO = min(stone * (1.0 + caustic_strength * caustic), vec3(1.0));
    ROUGHNESS = 0.95;
    SPECULAR = 0.12;
}
