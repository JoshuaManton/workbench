package workbench

SHADER_RGBA_2D_VERT ::
`
#version 330 core

// from vbo
layout(location = 0) in vec3 vbo_vertex_position;
layout(location = 1) in vec2 vbo_tex_coord;
layout(location = 2) in vec4 vbo_color;

uniform mat4 model_matrix;
uniform mat4 view_matrix;
uniform mat4 projection_matrix;

out vec4 desired_color;

void main() {
    vec4 result = projection_matrix * view_matrix * model_matrix * vec4(vbo_vertex_position, 1);
    gl_Position = result;
    desired_color = vbo_color;
}
`;

SHADER_RGBA_2D_FRAG ::
`
#version 330 core

in vec4 desired_color;

out vec4 color;

void main() {
    color = desired_color;
}
`;



SHADER_RGBA_3D_VERT ::
`
#version 330 core

layout(location = 0) in vec3 vbo_vertex_position;
layout(location = 1) in vec2 vbo_tex_coord;
layout(location = 2) in vec4 vbo_color;
layout(location = 3) in vec4 vbo_normal;

uniform vec4 mesh_color;

uniform mat4 model_matrix;
uniform mat4 view_matrix;
uniform mat4 projection_matrix;

out vec4 desired_color;

void main() {
    vec4 result = projection_matrix * view_matrix * model_matrix * vec4(vbo_vertex_position, 1);
    gl_Position = result;
    desired_color = vbo_color * mesh_color;
}
`;

SHADER_RGBA_3D_FRAG ::
`
#version 330 core

in vec4 desired_color;

out vec4 color;

void main() {
    color = desired_color;
}
`;



SHADER_TEXTURE_3D_UNLIT_VERT ::
`
#version 330 core

// from vbo
layout(location = 0) in vec3 vbo_vertex_position;
layout(location = 1) in vec2 vbo_tex_coord;

// note(josh): mesh vert colors are broken right now
// layout(location = 2) in vec4 vbo_color;

uniform vec4 mesh_color;

uniform mat4 model_matrix;
uniform mat4 view_matrix;
uniform mat4 projection_matrix;

out vec2 tex_coord;
out vec4 desired_color;

void main() {
    vec4 result = projection_matrix * view_matrix * model_matrix * vec4(vbo_vertex_position, 1);
    gl_Position = result;
    tex_coord = vbo_tex_coord;
    desired_color = mesh_color;
}
`;

SHADER_TEXTURE_3D_UNLIT_FRAG ::
`
#version 330 core

in vec2 tex_coord;
in vec4 desired_color;

uniform sampler2D atlas_texture;

layout(location = 0) out vec4 color;

void main() {
    color = texture(atlas_texture, tex_coord) * desired_color;
}
`;



SHADER_TEXTURE_3D_LIT_VERT ::
`
#version 330 core

layout(location = 0) in vec3 vbo_vertex_position;
layout(location = 1) in vec2 vbo_tex_coord;
// layout(location = 2) in vec4 vbo_color;
layout(location = 3) in vec3 vbo_normal;

uniform mat4 model_matrix;
uniform mat4 view_matrix;
uniform mat4 projection_matrix;

out vec2 tex_coord;
out vec3 normal;
out vec3 frag_position;
// out vec4 vertex_color;

void main() {
    vec4 result = ((projection_matrix * view_matrix) * model_matrix) * vec4(vbo_vertex_position, 1);

    gl_Position = result;
    tex_coord = vbo_tex_coord;
    normal = mat3(transpose(inverse(model_matrix))) * vbo_normal;
    frag_position = vec3(model_matrix * vec4(vbo_vertex_position, 1.0));
    // vertex_color = vbo_color;
}
`;

SHADER_TEXTURE_3D_LIT_FRAG ::
`
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
// in vec4 vertex_color;



uniform vec3 camera_position;

uniform vec4 mesh_color;

uniform sampler2D atlas_texture;
uniform int has_texture;

uniform Material material;

#define MAX_LIGHTS 100

uniform vec3  point_light_positions  [MAX_LIGHTS];
uniform vec4  point_light_colors     [MAX_LIGHTS];
uniform float point_light_intensities[MAX_LIGHTS];
uniform int   num_point_lights;

uniform vec3  directional_light_directions [MAX_LIGHTS];
uniform vec4  directional_light_colors     [MAX_LIGHTS];
uniform float directional_light_intensities[MAX_LIGHTS];
uniform int   num_directional_lights;



out vec4 out_color;



vec4 calculate_point_light(int, vec3, vec4);
vec4 calculate_directional_light(int, vec3, vec4);

void main() {
    vec3 norm = normalize(normal);

    // vec4 unlit_color = material.ambient * vertex_color;
    vec4 unlit_color = material.ambient * mesh_color;
    if (has_texture == 1) {
        unlit_color *= texture(atlas_texture, tex_coord);
    }
    out_color = unlit_color;
    for (int i = 0; i < num_point_lights; i++) {
        out_color += calculate_point_light(i, norm, unlit_color);
    }
    for (int i = 0; i < num_directional_lights; i++) {
        out_color += calculate_directional_light(i, norm, unlit_color);
    }
}

vec4 calculate_point_light(int light_index, vec3 norm, vec4 unlit_color) {
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
    vec3  reflect_dir = reflect(-light_dir, norm);
    float spec        = pow(max(dot(view_dir, reflect_dir), 0.0), material.shine);
    vec4  specular    = color * spec * material.specular;

    float attenuation = 1.0 / distance * intensity;

    diffuse  *= attenuation;
    specular *= attenuation;

    return unlit_color * vec4((diffuse + specular).xyz, 1.0);
}

vec4 calculate_directional_light(int light_index, vec3 norm, vec4 unlit_color) {
    vec3  direction = directional_light_directions [light_index];
    vec4  color     = directional_light_colors     [light_index];
    float intensity = directional_light_intensities[light_index];

    vec3  view_dir  = normalize(camera_position - frag_position);

    // diffuse
    float diff    = max(dot(norm, -direction), 0.0);
    vec4  diffuse = color * diff * material.diffuse;

    diffuse  *= intensity;

    return unlit_color * vec4(diffuse.xyz, 1.0);
}
`;



SHADER_TEXT_VERT ::
`
#version 330 core

// from vbo
layout(location = 0) in vec3 vbo_vertex_position;
layout(location = 1) in vec2 vbo_tex_coord;
layout(location = 2) in vec4 vbo_color;

uniform mat4 model_matrix;
uniform mat4 view_matrix;
uniform mat4 projection_matrix;

out vec2 tex_coord;
out vec4 desired_color;

void main() {
    vec4 result = projection_matrix * view_matrix * model_matrix * vec4(vbo_vertex_position, 1);
    gl_Position = result;
    tex_coord = vbo_tex_coord;
    desired_color = vbo_color;
}
`;

SHADER_TEXT_FRAG ::
`
#version 330 core

in vec2 tex_coord;
in vec4 desired_color;

uniform sampler2D atlas_texture;

out vec4 color;

void main() {
	uvec4 bytes = uvec4(texture(atlas_texture, tex_coord) * 255);
	uvec4 desired = uvec4(desired_color * 255);

	uint old_r = bytes.r;

	bytes.r = desired.r;
	bytes.g = desired.g;
	bytes.b = desired.b;
	bytes.a &= old_r & desired.a;

	color = vec4(bytes.r, bytes.g, bytes.b, bytes.a) / 255;
}
`;