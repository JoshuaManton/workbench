@vert

@include "default_vert.glsl"



@frag

#version 330 core

in vec3 tex_coord;

uniform sampler2D texture_handle;
uniform bool horizontal;
uniform int bloom_range;
uniform float bloom_weight;

layout(location = 0) out vec4 out_color;

void main() {
    vec2 tex_offset = 1.0 / textureSize(texture_handle, 0); // gets size of single texel
    vec3 result = texture(texture_handle, tex_coord.xy).rgb; // current fragment's contribution
    if (horizontal) {
        for (int i = 1; i < bloom_range; ++i) {
            result += texture(texture_handle, tex_coord.xy + vec2(tex_offset.x * i, 0.0)).rgb * (bloom_weight/pow(i, 2));
            result += texture(texture_handle, tex_coord.xy - vec2(tex_offset.x * i, 0.0)).rgb * (bloom_weight/pow(i, 2));
        }
    }
    else {
        for (int i = 1; i < bloom_range; ++i) {
            result += texture(texture_handle, tex_coord.xy + vec2(0.0, tex_offset.y * i)).rgb * (bloom_weight/pow(i, 2));
            result += texture(texture_handle, tex_coord.xy - vec2(0.0, tex_offset.y * i)).rgb * (bloom_weight/pow(i, 2));
        }
    }
    out_color = vec4(result, 1.0);
}
