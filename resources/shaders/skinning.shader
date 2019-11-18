@vert

#version 330

const int MAX_BONES = 100;
const int MAX_WEIGHTS = 4;

layout(location = 0) in vec3 vbo_vertex_position;
layout(location = 1) in vec2 vbo_tex_coord;
layout(location = 2) in vec4 vbo_color;
layout(location = 3) in vec3 vbo_normal;
layout(location = 4) in int vbo_bone_ids[MAX_WEIGHTS];
layout(location = 5) in float vbo_weights[MAX_WEIGHTS];

out vec2 tex_coord;
out vec3 normal;
out vec3 frag_position;
out vec4 frag_position_light_space;
out vec4 vert_color;

uniform mat4 model_matrix;
uniform mat4 view_matrix;
uniform mat4 projection_matrix;
uniform mat4 light_space_matrix;
uniform mat4 bones[MAX_BONES];

void main()
{
    vec4 skinned_pos = vec4(0);
    vec4 skinned_norm = vec4(0);
    for (int i = 0; i < MAX_WEIGHTS; i++) {
        float weight = vbo_weights[i];

        if (weight > 0) {
            mat4 bone_transform = bones[vbo_bone_ids[i]];

            skinned_pos += (bone_transform * vec4(vbo_vertex_position, 1)) * weight;
            skinned_norm += (bone_transform * vec4(vbo_normal, 0)) * weight;
        }
    }

    gl_Position = (projection_matrix * view_matrix * model_matrix) * skinned_pos;
    normal = mat3(transpose(inverse(model_matrix))) * skinned_norm.xyz;

    frag_position = (view_matrix * skinned_pos).xyz;
    frag_position_light_space = light_space_matrix * vec4(frag_position, 1.0);

    vert_color = vbo_color;
    tex_coord = vbo_tex_coord;
}



@frag

#version 330 core

in vec4 vert_color;
in vec3 vert_normal;
in vec2 tex_coord;

uniform sampler2D texture_handle;
uniform int has_texture;

out vec4 out_color;

void main() {
    vec4 tex_color = vec4(1, 1, 1, 1);
    if (has_texture == 1) {
        tex_color = texture(texture_handle, tex_coord);
    }
    out_color = vert_color * tex_color;
}
