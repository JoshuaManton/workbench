package workbench

SHADER_RGBA_VERT ::
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
    if (result.w > 0) { result /= result.w; }
    gl_Position = result;
    desired_color = vbo_color;
}
`;

SHADER_RGBA_FRAG ::
`
#version 330 core

in vec4 desired_color;

layout(location = 0) out vec4 color;

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
    if (result.w > 0) { result /= result.w; }
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

SHADER_TEXTURE_UNLIT_VERT ::
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
    if (result.w > 0) { result /= result.w; }
    gl_Position = result;
    tex_coord = vbo_tex_coord;
    desired_color = mesh_color;
}
`;

SHADER_TEXTURE_UNLIT_FRAG ::
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

SHADER_TEXTURE_LIT_VERT ::
`
#version 330 core

layout(location = 0) in vec3 vbo_vertex_position;
layout(location = 1) in vec2 vbo_tex_coord;
// todo(josh): mesh vert colors
// layout(location = 2) in vec4 vbo_color;
layout(location = 3) in vec3 vbo_normal;

uniform vec4 mesh_color;
uniform mat4 model_matrix;
uniform mat4 view_matrix;
uniform mat4 projection_matrix;

out vec2 tex_coord;
out vec3 normal;
out vec3 frag_position;
out vec4 desired_color;

void main() {
    vec4 result = projection_matrix * view_matrix * model_matrix * vec4(vbo_vertex_position, 1);

    // commenting this out fixes specularity, hopefully it wasn't here for a reason :DDDDDDDD
    // https://i.imgur.com/UqXbIMe.png
    // if (result.w > 0) { result /= result.w; }

    gl_Position = result;
    tex_coord = vbo_tex_coord;
    normal = mat3(transpose(inverse(model_matrix))) * vbo_normal;
    frag_position = vec3(model_matrix * vec4(vbo_vertex_position, 1.0));
    desired_color = mesh_color;
}
`;

SHADER_TEXTURE_LIT_FRAG ::
`
#version 330 core

in vec2 tex_coord;
in vec3 normal;
in vec3 frag_position;
in vec4 desired_color;

uniform sampler2D atlas_texture;
uniform int has_texture;

#define MAX_LIGHTS 100
uniform vec3  light_positions         [MAX_LIGHTS];
uniform vec4  light_colors            [MAX_LIGHTS];
uniform float light_ambient_strengths [MAX_LIGHTS];
uniform float light_diffuse_strengths [MAX_LIGHTS];
uniform float light_specular_strengths[MAX_LIGHTS];
uniform int   num_lights;

uniform vec3 camera_position;

out vec4 out_color;

vec4 calculate_point_light(int, vec3, vec4);

void main() {
    vec3 norm = normalize(normal);

    vec4 unlit_color = desired_color;
    if (has_texture == 1) {
        unlit_color *= texture(atlas_texture, tex_coord);
    }
    out_color = vec4(0, 0, 0, 0);
    for (int i = 0; i < num_lights; i++) {
        out_color += calculate_point_light(i, norm, unlit_color);
    }
}

vec4 calculate_point_light(int light_index, vec3 norm, vec4 unlit_color) {
    vec3  position          = light_positions         [light_index];
    vec4  color             = light_colors            [light_index];
    float ambient_strength  = light_ambient_strengths [light_index];
    float diffuse_strength  = light_diffuse_strengths [light_index];
    float specular_strength = light_specular_strengths[light_index];

    float distance = length(position - frag_position);
    vec3  light_dir = normalize(position - frag_position);
    vec3  view_dir  = normalize(camera_position - frag_position);

    // ambient
    vec4 ambient = color * ambient_strength;

    // diffuse
    float diff    = max(dot(norm, light_dir), 0.0);
    vec4  diffuse = color * diff * diffuse_strength;

    // specular
    vec3  reflect_dir = reflect(-light_dir, norm);
    float spec        = pow(max(dot(view_dir, reflect_dir), 0.0), 32);
    vec4  specular    = color * spec * specular_strength;

    float attenuation = 1.0 / distance;

    ambient  *= attenuation;
    diffuse  *= attenuation;
    specular *= attenuation;

    return unlit_color * vec4((ambient + diffuse + specular).xyz, 1.0);
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
    if (result.w > 0) { result /= result.w; }
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