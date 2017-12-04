#version 330 core

layout(location = 0) in vec2 in_vertex_position;
layout(location = 1) in vec2 in_tex_coord;
layout(location = 2) in vec2 in_center_position;
layout(location = 3) in vec2 in_scale;

out vec2 tex_coord;

uniform float time;
uniform mat4 transform;

void main() {
    gl_Position = transform * vec4(in_center_position + (in_vertex_position * in_scale), 0, 1);
    tex_coord = in_tex_coord;
}
