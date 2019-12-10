@vert

@include "default_vert.glsl"



@frag

#version 330 core

in vec3 tex_coord;

uniform sampler2D texture_handle;
uniform bool horizontal;
uniform float weight[5] = float[] (0.227027, 0.1945946, 0.1216216, 0.054054, 0.016216);

layout(location = 0) out vec4 out_color;

void main() {
    vec2 tex_offset = 1.0 / textureSize(texture_handle, 0); // gets size of single texel
    vec3 result = texture(texture_handle, tex_coord.xy).rgb * weight[0]; // current fragment's contribution
    if (horizontal) {
        for (int i = 1; i < 5; ++i) {
            result += texture(texture_handle, tex_coord.xy + vec2(tex_offset.x * i, 0.0)).rgb * weight[i];
            result += texture(texture_handle, tex_coord.xy - vec2(tex_offset.x * i, 0.0)).rgb * weight[i];
        }
    }
    else {
        for (int i = 1; i < 5; ++i) {
            result += texture(texture_handle, tex_coord.xy + vec2(0.0, tex_offset.y * i)).rgb * weight[i];
            result += texture(texture_handle, tex_coord.xy - vec2(0.0, tex_offset.y * i)).rgb * weight[i];
        }
    }
    out_color = vec4(result, 1.0);
}
