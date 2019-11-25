@vert

@include "default_vert_2d.glsl"



@frag

#version 330 core

in vec3 tex_coord;

uniform sampler2D texture_handle;
uniform sampler2D bloom_texture;

layout(location = 0) out vec4 out_color;

void main() {
    vec3 color = texture(texture_handle, tex_coord.xy).rgb;
    vec3 bloom_color = texture(bloom_texture, tex_coord.xy).rgb;
    color += bloom_color;

    out_color = vec4(color, 1.0);
}
