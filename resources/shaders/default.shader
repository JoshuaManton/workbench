@vert

#version 330 core

// from vbo
layout(location = 0) in vec3 vbo_vertex_position;
layout(location = 1) in vec2 vbo_tex_coord;
layout(location = 2) in vec4 vbo_color;
layout(location = 3) in vec3 vbo_normal;

uniform vec4 mesh_color;

uniform mat4 model_matrix;
uniform mat4 view_matrix;
uniform mat4 projection_matrix;

out vec4 vert_color;
out vec3 vert_normal;
out vec2 tex_coord;

void main() {
    vec4 result = projection_matrix * view_matrix * model_matrix * vec4(vbo_vertex_position, 1);
    gl_Position = result;
    vert_color = vbo_color * mesh_color;
    vert_normal = vbo_normal;
    tex_coord = vbo_tex_coord;
}



@frag

#version 330 core

in vec4 vert_color;
in vec3 vert_normal;
in vec2 tex_coord;

uniform sampler2D texture_handle;
uniform int has_texture;

out vec4 out_color;

void main() {
    vec4 tex_color = vec4(1, 1, 1, 1);
    if (has_texture == 1) {
        tex_color = texture(texture_handle, tex_coord);
    }
    out_color = vert_color * tex_color;
}
