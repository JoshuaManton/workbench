#version 330 core

// from vbo
layout(location = 0) in vec3 vbo_vertex_position;
layout(location = 1) in vec2 vbo_tex_coord;
layout(location = 2) in vec4 vbo_color;
layout(location = 3) in vec3 vbo_normal;

uniform vec3 position;
uniform vec3 scale;
uniform vec4 mesh_color;

out vec4 vert_color;
out vec3 vert_normal;
out vec2 tex_coord;

void main() {
    gl_Position = vec4(position + (vbo_vertex_position * scale), 1);
    vert_color = vbo_color * mesh_color;
    vert_normal = vbo_normal;
    tex_coord = vbo_tex_coord;
}