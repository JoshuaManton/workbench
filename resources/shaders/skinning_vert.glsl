#version 330

const int MAX_BONES = 100;
const int MAX_WEIGHTS = 4;

layout(location = 0) in vec3 vbo_vertex_position;
layout(location = 1) in vec3 vbo_tex_coord;
layout(location = 2) in vec4 vbo_color;
layout(location = 3) in vec3 vbo_normal;
layout(location = 4) in int vbo_bone_ids[MAX_WEIGHTS];
layout(location = 5) in float vbo_weights[MAX_WEIGHTS];

out vec3 tex_coord;
out vec3 vert_normal;
out vec3 frag_position;
out vec4 vert_color;

uniform vec4 mesh_color;
uniform mat4 model_matrix;
uniform mat4 view_matrix;
uniform mat4 projection_matrix;
uniform mat4 bones[MAX_BONES];
uniform int  do_animation;

void main() {
    vec4 skinned_pos = vec4(0);
    vec4 skinned_norm = vec4(0);
    if (do_animation == 1) {
        for (int i = 0; i < MAX_WEIGHTS; i++) {
            skinned_pos += (bones[vbo_bone_ids[i]] * vec4(vbo_vertex_position, 1)) * vbo_weights[i];
            skinned_norm += (bones[vbo_bone_ids[i]] * vec4(vbo_normal, 0)) * vbo_weights[i];
        }
    }
    else {
        skinned_pos = vec4(vbo_vertex_position, 1);
        skinned_norm = vec4(vbo_normal, 0);
    }

    gl_Position = projection_matrix * view_matrix * model_matrix * skinned_pos;
    tex_coord = vbo_tex_coord;
    vert_normal = mat3(transpose(inverse(model_matrix))) * normalize(skinned_norm.xyz);
    frag_position = vec3(model_matrix * skinned_pos);
    vert_color = vbo_color * mesh_color;
}