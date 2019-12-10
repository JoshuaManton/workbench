@vert

@include "default_vert.glsl"



@frag

#version 330 core

in vec4 vert_color;
in vec3 vert_normal;
in vec3 tex_coord;

uniform float slice_z;

uniform sampler3D texture_handle;
uniform int has_texture;

out vec4 out_color;

void main() {
    vec4 tex_color = vec4(1, 1, 1, 1);
    if (has_texture == 1) {
        tex_color = texture(texture_handle, vec3(tex_coord.xy, slice_z));
    }
    out_color = vert_color * tex_color;
}
