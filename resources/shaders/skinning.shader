@vert

#version 330

const int MAX_BONES = 100;
const int MAX_WEIGHTS = 4;

layout(location = 0) in vec3 vbo_vertex_position;
layout(location = 1) in vec3 vbo_tex_coord;
layout(location = 2) in vec4 vbo_color;
layout(location = 3) in vec3 vbo_normal;
layout(location = 4) in int vbo_bone_ids[MAX_WEIGHTS];
layout(location = 5) in float vbo_weights[MAX_WEIGHTS];

out vec3 tex_coord;
out vec3 vert_normal;
out vec3 frag_position;
out vec4 frag_position_light_space;
out vec4 vert_color;

uniform vec4 mesh_color;
uniform mat4 model_matrix;
uniform mat4 view_matrix;
uniform mat4 projection_matrix;
uniform mat4 bones[MAX_BONES];

void main()
{
    vec4 skinned_pos = vec4(0);
    vec4 skinned_norm = vec4(0);
    for (int i = 0; i < MAX_WEIGHTS; i++) {
        skinned_pos += (bones[vbo_bone_ids[i]] * vec4(vbo_vertex_position, 1)) * vbo_weights[i];
        skinned_norm += (bones[vbo_bone_ids[i]] * vec4(vbo_normal, 1)) * vbo_weights[i];
    }
    
    mat4 mvp = projection_matrix * view_matrix * model_matrix;

    gl_Position = mvp * skinned_pos;
    vert_normal = mat3(transpose(inverse(model_matrix))) * skinned_norm.xyz;

    frag_position = (model_matrix * skinned_pos).xyz;

    vert_color = mesh_color * vbo_color;
    tex_coord = vec3(vbo_tex_coord.xy, 0);
}

@frag

#version 330 core

in vec3 tex_coord;
in vec3 vert_normal;
in vec3 frag_position;
in vec4 vert_color;



struct Material {
    vec4  ambient;
    vec4  diffuse;
    vec4  specular;
    float shine;
};

uniform vec3 camera_position;

uniform Material material;

uniform sampler2D texture_handle;
uniform int has_texture_handle;

#define NUM_SHADOW_MAPS 4
uniform sampler2D shadow_maps[NUM_SHADOW_MAPS];

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


layout (location=0) out vec4 out_color;
layout (location=1) out vec4 bloom_color;



vec3 calculate_point_light(Material, int, vec3);
vec3 calculate_sun_light(Material, vec3);
float calculate_shadow(int);

void main() {
    vec3 norm = normalize(vert_normal);

    // base color
    vec4 result_color = vert_color;

    // texture color
    if (has_texture_handle == 1) {
        float gamma = 2.2; // todo(josh): dont hardcode this. not sure if it needs to change per texture?
        vec3 tex_sample = pow(texture(texture_handle, tex_coord.xy).rgb, vec3(gamma));
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
    out_color = result_color;

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

    // bloom color
    float brightness = dot(out_color.rgb, vec3(0.2126, 0.7152, 0.0722)); // todo(josh): make configurable
    if (brightness > bloom_threshhold) {
        bloom_color = vec4(out_color.rgb * ((brightness / bloom_threshhold) - 1), 1.0);
    }
    else {
        bloom_color = vec4(0.0, 0.0, 0.0, 1.0);
    }
}

vec3 calculate_point_light(Material material, int light_index, vec3 frag_normal) {
    vec3  light_position  = point_light_positions  [light_index];
    vec4  light_color     = point_light_colors     [light_index];
    float light_intensity = point_light_intensities[light_index];

    float distance = length(light_position - frag_position);
    vec3  light_dir = normalize(light_position - frag_position);
    vec3  view_dir  = normalize(camera_position - frag_position);

    // diffuse
    float diff    = max(dot(frag_normal, light_dir), 0.0);
    vec4  diffuse = light_color * diff * material.diffuse;

    // specular
    // todo(josh): blinn-phong specularity?
    vec3  reflect_dir = reflect(-light_dir, frag_normal);
    float spec        = pow(max(dot(view_dir, reflect_dir), 0.0), material.shine);
    vec4  specular    = light_color * spec * material.specular;

    float attenuation = (1.0 / (distance)) * light_intensity; // todo(josh): should this be distance-squared?

    diffuse  *= attenuation;
    specular *= attenuation;

    return (diffuse + specular).xyz;
}

vec3 calculate_sun_light(Material material, vec3 frag_normal) {
    // diffuse
    float diff    = max(dot(frag_normal, -sun_direction), 0.0);
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

    float bias = max(0.05 * (1.0 - clamp(dot(vert_normal, -sun_direction), 0, 1)), 0.005);
    // float bias = 0.005 * clamp(dot(vert_normal, -sun_direction), 0, 1);

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
