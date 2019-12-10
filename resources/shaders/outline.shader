@vert

@include "default_vert.glsl"



@frag

#version 330 core

in vec4 vert_color;
in vec3 vert_normal;
in vec3 tex_coord;

uniform sampler2D texture_handle;
uniform int has_texture;

out vec4 out_color;

void main() {
    vec4 tex_color = vec4(1, 1, 1, 1);
    if (has_texture == 1) {
        tex_color = texture(texture_handle, vec2(tex_coord));
    }
    vec4 color = vert_color * tex_color;
    vec2 texel_size = 1.0 / textureSize(texture_handle, 0);
    vec4 adjacent_color = texture(texture_handle, vec2(tex_coord) + texel_size*3);

    if (length(color - adjacent_color) > 0.5) {
        out_color = vec4(0, 0, 0, 1);
    }
    else {
        out_color = color;
    }
}
