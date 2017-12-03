#version 330 core

in vec2 tex_coord;

uniform sampler2D texture_data;

out vec4 color;

void main() {
    color = texture(texture_data, tex_coord);
}
