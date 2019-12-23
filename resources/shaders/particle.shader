@vert
#version 330 core

layout(location = 0) in vec3 vbo_vertex_position;
layout(location = 1) in vec2 vbo_uv;

layout(location = 2) in vec4 instance_colour;
layout(location = 3) in mat4 instance_offset;

uniform mat4 view_matrix;
uniform mat4 projection_matrix;

out vec4 vert_color;
out vec2 uv;

void main() {

    mat4 vp = view_matrix * instance_offset;

    float xx = vp[0][0];
    float yx = vp[1][0];
    float zx = vp[2][0];
    float d = sqrt(xx * xx + yx * yx + zx * zx);

    vp[0][0] = d;
    vp[0][1] = 0.0;
    vp[0][2] = 0.0;

    vp[1][0] = 0.0;
    vp[1][1] = d;
    vp[1][2] = 0.0;

    vp[2][0] = 0.0;
    vp[2][1] = 0.0;
    vp[2][2] = d;
    vp *= d;

    gl_Position = projection_matrix * vp * vec4(vbo_vertex_position, 1.0);
    vert_color = instance_colour;
    uv = vbo_uv;
}

@frag
#version 330 core

uniform sampler2D texture_sampler;

in vec2 uv;
in vec4 vert_color;
out vec4 out_color;

void main() {

    vec4 o = texture(texture_sampler, uv) * vert_color;

    if (o.a == 0) {
        discard;
    }

    out_color = o;
}