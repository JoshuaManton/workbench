#version 330 core

in vec2 tex_coord;

uniform sampler2D atlas_texture;

out vec4 color;

void main() {
    //color = vec4(tex_coord, 0, 1);
    color = texture(atlas_texture, tex_coord);
}
