@vert

@include "default_vert.glsl"




@frag

#version 330 core

in vec2 tex_coord;
in vec3 normal;
in vec3 frag_position;
in vec4 vertex_color;



struct Material {
    vec4  ambient;
    vec4  diffuse;
    vec4  specular;
    float shine;
};

uniform vec3 camera_position;

uniform Material material;

uniform sampler2D texture_handle;
uniform int has_texture;

#define NUM_SHADOW_MAPS 4
uniform sampler2D shadow_maps[NUM_SHADOW_MAPS];
uniform sampler2D shadow_map;

uniform float cascade_distances[NUM_SHADOW_MAPS];
uniform mat4 cascade_light_space_matrices[NUM_SHADOW_MAPS];

#define MAX_LIGHTS 100

uniform vec3  point_light_positions  [MAX_LIGHTS];
uniform vec4  point_light_colors     [MAX_LIGHTS];
uniform float point_light_intensities[MAX_LIGHTS];
uniform int   num_point_lights;

uniform vec3  sun_direction;
uniform vec4  sun_color;
uniform float sun_intensity;

uniform float bloom_threshhold;


out vec4 out_color;
out vec4 bloom_color;



vec3 calculate_point_light(Material, int, vec3);
vec3 calculate_sun_light(Material, vec3);
float calculate_shadow(int);

void main() {
    vec3 norm = normalize(normal);

    // base color
    vec4 result_color = vertex_color;

    // texture color
    if (has_texture == 1) {
        float gamma = 2.2; // todo(josh): dont hardcode this. not sure if it needs to change per texture?
        vec3 tex_sample = pow(texture(texture_handle, tex_coord).rgb, vec3(gamma));
        result_color *= vec4(tex_sample, 1.0);
    }

    // material color
    result_color *= material.ambient;
    for (int i = 0; i < num_point_lights; i++) {
        result_color.rgb *= 1 + calculate_point_light(material, i, norm);
    }

    // shadow color
    float dist = length(camera_position - frag_position);
    int shadow_map_index = 0;
    for (int cascade_idx = 0; cascade_idx < NUM_SHADOW_MAPS; cascade_idx++) {
        shadow_map_index = cascade_idx;
        if (dist < cascade_distances[cascade_idx]) {
            break;
        }
    }

    float shadow = (1.0 - calculate_shadow(shadow_map_index));
    result_color.rgb *= 1 + calculate_sun_light(material, norm) * shadow;

    // visualize cascades
    // if (shadow_map_index == 0) {
    //     out_color.rgb += vec3(1, 0, 0) * 0.2;
    // }
    // else if (shadow_map_index == 1) {
    //     out_color.rgb += vec3(0, 1, 0) * 0.2;
    // }
    // else if (shadow_map_index == 2) {
    //     out_color.rgb += vec3(0, 0, 1) * 0.2;
    // }
    // else if (shadow_map_index == 3) {
    //     out_color.rgb += vec3(1, 0, 1) * 0.2;
    // }
    // out_color = vec4(dist, dist, dist, 1);



    out_color = result_color;

    // bloom color
    float brightness = dot(out_color.rgb, vec3(0.2126, 0.7152, 0.0722)); // todo(josh): make configurable
    if (brightness > bloom_threshhold) {
        bloom_color = vec4(out_color.rgb * ((brightness / bloom_threshhold) - 1), 1.0);
    }
    else {
        bloom_color = vec4(0.0, 0.0, 0.0, 1.0);
    }
}

vec3 calculate_point_light(Material material, int light_index, vec3 norm) {
    vec3  position  = point_light_positions  [light_index];
    vec4  color     = point_light_colors     [light_index];
    float intensity = point_light_intensities[light_index];

    float distance = length(position - frag_position);
    vec3  light_dir = normalize(position - frag_position);
    vec3  view_dir  = normalize(camera_position - frag_position);

    // diffuse
    float diff    = max(dot(norm, light_dir), 0.0);
    vec4  diffuse = color * diff * material.diffuse;

    // specular
    // todo(josh): blinn-phong specularity?
    vec3  reflect_dir = reflect(-light_dir, norm);
    float spec        = pow(max(dot(view_dir, reflect_dir), 0.0), material.shine);
    vec4  specular    = color * spec * material.specular;

    float attenuation = (1.0 / (distance)) * intensity; // todo(josh): should this be distance-squared?

    diffuse  *= attenuation;
    specular *= attenuation;

    return (diffuse + specular).xyz;
}

vec3 calculate_sun_light(Material material, vec3 norm) {
    vec3  view_dir  = normalize(camera_position - frag_position);

    // diffuse
    float diff    = max(dot(norm, -sun_direction), 0.0);
    vec4  diffuse = sun_color * diff * material.diffuse;

    diffuse *= sun_intensity;
    return diffuse.xyz;
}

float calculate_shadow(int shadow_map_idx) {
    vec4 frag_position_light_space = cascade_light_space_matrices[shadow_map_idx] * vec4(frag_position, 1.0);
    vec3 proj_coords = frag_position_light_space.xyz / frag_position_light_space.w; // todo(josh): check for divide by zero?
    proj_coords = proj_coords * 0.5 + 0.5;
    if (proj_coords.z > 1.0) {
        proj_coords.z = 1.0;
    }

    float bias = max(0.05 * (1.0 - dot(normal, -sun_direction)), 0.005);

#if 0
    float depth = texture(shadow_maps[shadow_map_idx], proj_coords.xy).r;
    float shadow = depth + bias < proj_coords.z ? 1.0 : 0.0;
    return shadow;
#else
    float shadow = 0.0;
    vec2 texel_size = 1.0 / textureSize(shadow_maps[shadow_map_idx], 0);
    for (int x = -2; x <= 2; x += 1) {
        for (int y = -2; y <= 2; y += 1) {
            float pcf_depth = texture(shadow_maps[shadow_map_idx], proj_coords.xy + vec2(x, y) * texel_size).r;
            shadow += pcf_depth + bias < proj_coords.z ? 1.0 : 0.0;
        }
    }
    return shadow / 25.0;
#endif
}
