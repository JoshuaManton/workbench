#version 330 core

// from vbo
layout(location = 0) in vec2 in_vertex_position;
layout(location = 1) in int sprite_coord_index;

// from bufferdata
layout(location = 2) in vec2 in_center_position;
layout(location = 3) in vec2 in_scale;
layout(location = 4) in int sprite_index;

out vec2 tex_coord;

uniform sampler1D atlas_coords_texture;
uniform float time;
uniform mat4 transform;

void main() {
    gl_Position = transform * vec4(in_center_position + (in_vertex_position * in_scale), 0, 1);

    float x = texelFetch(atlas_coords_texture, sprite_index * 6 + sprite_coord_index, 0).r;
    float y = texelFetch(atlas_coords_texture, sprite_index * 6 + sprite_coord_index, 0).g;
    tex_coord = vec2(x, y);
}
