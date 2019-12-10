@vert

@include "default_vert.glsl"



@frag

#version 330 core

in vec3 tex_coord;

uniform float gamma;
uniform float exposure;

uniform sampler2D texture_handle;

layout(location = 0) out vec4 out_color;

void main() {
    vec3 color = texture(texture_handle, tex_coord.xy).rgb;

    // exposure tone mapping
    color = vec3(1.0) - exp(-color * exposure);

    // gamma correction
    color = pow(color, vec3(1.0 / gamma));

    out_color = vec4(color, 1.0);
}
