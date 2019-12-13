@vert

#version 330 core

layout(location = 0) in vec3 vbo_vertex_position;
layout(location = 1) in vec4 vbo_color;
layout(location = 2) in mat4 vbo_offset;

uniform mat4 view_matrix;
uniform mat4 projection_matrix;

out vec4 vert_color;

void main() {
    gl_Position = projection_matrix * view_matrix * vbo_offset * vec4(vbo_vertex_position, 1.0); 
    vert_color = vbo_color;
}

@frag

#version 330 core

in vec4 vert_color;

out vec4 out_color;

void main() {
    out_color = vert_color;
}