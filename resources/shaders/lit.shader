@vert

#version 330 core

layout(location = 0) in vec3 vbo_vertex_position;
layout(location = 1) in vec2 vbo_tex_coord;
layout(location = 2) in vec4 vbo_color;
layout(location = 3) in vec3 vbo_normal;

uniform mat4 model_matrix;
uniform mat4 view_matrix;
uniform mat4 projection_matrix;
uniform mat4 light_space_matrix;

out vec2 tex_coord;
out vec3 normal;
out vec3 frag_position;
out vec4 frag_position_light_space;
out vec4 vertex_color;

void main() {
    vec4 result = projection_matrix * view_matrix * model_matrix * vec4(vbo_vertex_position, 1);

    gl_Position = result;
    tex_coord = vbo_tex_coord;
    normal = mat3(transpose(inverse(model_matrix))) * vbo_normal;
    frag_position = vec3(model_matrix * vec4(vbo_vertex_position, 1.0));
    frag_position_light_space = light_space_matrix * vec4(frag_position, 1.0);
    vertex_color = vbo_color;
}



@frag

#version 330 core

struct Material {
    vec4  ambient;
    vec4  diffuse;
    vec4  specular;
    float shine;
};



in vec2 tex_coord;
in vec3 normal;
in vec3 frag_position;
in vec4 frag_position_light_space;
in vec4 vertex_color;



uniform vec3 camera_position;

uniform vec4 mesh_color;
uniform Material material;

uniform sampler2D texture_handle;
uniform int has_texture;

#define NUM_SHADOW_MAPS 4
uniform sampler2D shadow_maps[NUM_SHADOW_MAPS];
uniform sampler2D shadow_map;

#define MAX_LIGHTS 100

uniform vec3  point_light_positions  [MAX_LIGHTS];
uniform vec4  point_light_colors     [MAX_LIGHTS];
uniform float point_light_intensities[MAX_LIGHTS];
uniform int   num_point_lights;

uniform vec3  directional_light_directions [MAX_LIGHTS];
uniform vec4  directional_light_colors     [MAX_LIGHTS];
uniform float directional_light_intensities[MAX_LIGHTS];
uniform int   num_directional_lights;

uniform float bloom_threshhold;


out vec4 out_color;
out vec4 bloom_color;



vec3 calculate_point_light(int, vec3);
vec3 calculate_directional_light(int, vec3);
float calculate_shadow(vec3, int);

void main() {
    vec3 norm = normalize(normal);

    // vec4 unlit_color = material.ambient * vertex_color;
    vec4 unlit_color = material.ambient * vertex_color * mesh_color;
    if (has_texture == 1) {
        float gamma = 2.2; // todo(josh): dont hardcode this. not sure if it needs to change per texture?
        vec3 tex_sample = pow(texture(texture_handle, tex_coord).rgb, vec3(gamma));
        unlit_color *= vec4(tex_sample, 1.0);
    }
    out_color = unlit_color;
    for (int i = 0; i < num_point_lights; i++) {
        out_color.xyz += unlit_color.xyz * calculate_point_light(i, norm);
    }
    for (int i = 0; i < num_directional_lights; i++) {
        float shadow = (1.0 - calculate_shadow(directional_light_directions[i], 0));
        out_color.xyz += unlit_color.xyz * calculate_directional_light(i, norm) * shadow;
    }

    float brightness = dot(out_color.rgb, vec3(0.2126, 0.7152, 0.0722)); // todo(josh): make configurable
    if (brightness > bloom_threshhold) {
        bloom_color = vec4(out_color.rgb, 1.0);
    }
    else {
        bloom_color = vec4(0.0, 0.0, 0.0, 1.0);
    }
}

vec3 calculate_point_light(int light_index, vec3 norm) {
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

    float attenuation = (1.0 / (distance * distance)) * intensity;

    diffuse  *= attenuation;
    specular *= attenuation;

    return (diffuse + specular).xyz;
}

vec3 calculate_directional_light(int light_index, vec3 norm) {
    vec3  direction = directional_light_directions [light_index];
    vec4  color     = directional_light_colors     [light_index];
    float intensity = directional_light_intensities[light_index];

    vec3  view_dir  = normalize(camera_position - frag_position);

    // diffuse
    float diff    = max(dot(norm, -direction), 0.0);
    vec4  diffuse = color * diff * material.diffuse;

    diffuse *= intensity;
    return diffuse.xyz;
}

float calculate_shadow(vec3 light_direction, int shadow_map_idx) {
    vec3 proj_coords = frag_position_light_space.xyz / frag_position_light_space.w; // todo(josh): check for divide by zero?
    proj_coords = proj_coords * 0.5 + 0.5;
    if (proj_coords.z > 1.0) {
        proj_coords.z = 1.0;
    }
    float closest_depth = texture(shadow_maps[shadow_map_idx], proj_coords.xy).r;
    float current_depth = proj_coords.z;
    float bias = max(0.005 * (1.0 - dot(normal, -light_direction)), 0.0025);
    float pcf_depth = texture(shadow_maps[shadow_map_idx], proj_coords.xy).r;
    float shadow = pcf_depth + bias < proj_coords.z ? 1.0 : 0.0;
    return shadow;

    // float shadow = 0.0;
    // vec2 texel_size = 1.0 / textureSize(shadow_maps[shadow_map_idx], 0);
    // for (int x = -1; x <= 1; x += 1) {
    //     for (int y = -1; y <= 1; y += 1) {
    //         float pcf_depth = texture(shadow_maps[shadow_map_idx], proj_coords.xy + vec2(x, y) * texel_size).r;
    //         shadow += pcf_depth + bias < proj_coords.z ? 1.0 : 0.0;
    //     }
    // }
    // return shadow / 9.0;
}
