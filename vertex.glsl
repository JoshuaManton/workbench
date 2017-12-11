#version 330 core

// from vbo
layout(location = 0) in vec2 in_vertex_position;

// from bufferdata
layout(location = 2) in vec2 in_center_position;
layout(location = 3) in vec2 in_scale;
layout(location = 4) in int sprite_index;
layout(location = 5) in int sprite_width;
layout(location = 6) in int sprite_height;

out vec2 tex_coord;

uniform sampler1D metadata_texture;
uniform float time;
uniform mat4 transform;
uniform vec2 camera_position;

void main() {
    gl_Position = transform * vec4((in_center_position + (in_vertex_position * vec2(sprite_width, sprite_height)) / 2 * in_scale - camera_position), 0, 1);

    float x = texelFetch(metadata_texture, sprite_index * 6 + gl_VertexID, 0).r;
    float y = texelFetch(metadata_texture, sprite_index * 6 + gl_VertexID, 0).g;
    tex_coord = vec2(x, y);
}
