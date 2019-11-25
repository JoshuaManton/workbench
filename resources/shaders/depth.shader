@vert

@include "default_vert_2d.glsl"



@frag

#version 330 core

in vec2 tex_coord;

uniform sampler2D texture_handle;

out vec4 FragColor;

void main() {
    float depth_value = texture(texture_handle, tex_coord).r;
    FragColor = vec4(vec3(depth_value), 1.0);
}
