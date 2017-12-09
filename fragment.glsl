#version 330 core

in vec2 tex_coord;

uniform sampler2D atlas_texture;
uniform sampler1D atlas_coords_texture;

out vec4 color;

void main() {
    color = texture(atlas_texture, tex_coord);
}
