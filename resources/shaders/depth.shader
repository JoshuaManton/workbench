@vert

@include "default_vert.glsl"



@frag

#version 330 core

in vec3 tex_coord;

uniform sampler2D texture_handle;

out vec4 FragColor;

void main() {
    float depth_value = texture(texture_handle, tex_coord.xy).r;
    FragColor = vec4(vec3(depth_value), 1.0);
}
