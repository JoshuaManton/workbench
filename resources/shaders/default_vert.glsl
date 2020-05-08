#version 330 core

layout(location = 0) in vec3 vbo_vertex_position;
layout(location = 1) in vec3 vbo_tex_coord;
layout(location = 2) in vec4 vbo_color;
layout(location = 3) in vec3 vbo_normal;

uniform vec4 mesh_color;
uniform mat4 model_matrix;
uniform mat4 view_matrix;
uniform mat4 projection_matrix;

out vec3 frag_position;
out vec3 tex_coord;
out vec4 vert_color;
out vec3 vert_normal;
out vec3 vertex_pos;

void main() {
    gl_Position = projection_matrix * view_matrix * model_matrix * vec4(vbo_vertex_position, 1);
    tex_coord = vbo_tex_coord;
    vert_normal = mat3(transpose(inverse(model_matrix))) * vbo_normal;
    frag_position = vec3(model_matrix * vec4(vbo_vertex_position, 1.0));
    vert_color = vbo_color * mesh_color;
    vertex_pos = vbo_vertex_position;
}