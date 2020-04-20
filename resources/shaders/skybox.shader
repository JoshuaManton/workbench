@vert

#version 330 core

layout(location = 0) in vec3 vbo_vertex_position;
// layout(location = 1) in vec3 vbo_tex_coord;
// layout(location = 2) in vec4 vbo_color;
// layout(location = 3) in vec3 vbo_normal;

// uniform vec4 mesh_color;
// uniform mat4 model_matrix;
uniform mat4 view_matrix;
uniform mat4 projection_matrix;

// out vec3 frag_position;
// out vec3 tex_coord;
// out vec4 vert_color;
// out vec3 vert_normal;

out vec3 tex_coord;

void main() {
	tex_coord = vbo_vertex_position;
    gl_Position = projection_matrix * view_matrix * vec4(vbo_vertex_position, 1);
}

@frag

#version 330 core

in vec3 tex_coord;

uniform samplerCube skybox_texture;

layout (location=0) out vec4 out_color;

void main() {
    out_color = texture(skybox_texture, normalize(tex_coord)); // todo(josh): should we normalize tex_coord here?
    out_color = pow(out_color, vec4(2.2));
}