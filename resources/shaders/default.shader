@vert

@include "default_vert.glsl"



@frag

#version 330 core

in vec4 vert_color;
in vec3 tex_coord;

uniform sampler2D texture_handle;
uniform int has_texture_handle;

layout (location=0) out vec4 out_color;

void main() {
    vec4 tex_color = vec4(1, 1, 1, 1);
    if (has_texture_handle == 1) {
        tex_color = texture(texture_handle, vec2(tex_coord));
    }
    out_color = vert_color * tex_color;
}
