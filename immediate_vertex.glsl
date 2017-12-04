#version 330 core

layout(location = 0) in vec2 in_vertex_position;
layout(location = 1) in vec2 in_tex_coord;

out vec2 tex_coord;

uniform float time;
uniform mat4 transform;

void main() {
    gl_Position = transform * vec4(in_vertex_position, 0, 1);
    tex_coord = in_tex_coord;
}
