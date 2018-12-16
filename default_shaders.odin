package workbench

SHADER_RGBA_VERT ::
`
#version 330 core

// from vbo
layout(location = 0) in vec3 vbo_vertex_position;
layout(location = 1) in vec2 vbo_tex_coord;
layout(location = 2) in vec4 vbo_color;

uniform mat4 mvp_matrix;

out vec4 desired_color;

void main() {
    vec4 result = mvp_matrix * vec4(vbo_vertex_position.x, vbo_vertex_position.y, vbo_vertex_position.z, 1);
    if (result.w > 0) { result /= result.w; }
    gl_Position = result;
    desired_color = vbo_color;
}
`;

SHADER_RGBA_FRAG ::
`
#version 330 core

in vec4 desired_color;

layout(location = 0) out vec4 color;

void main() {
    color = desired_color;
}
`;

SHADER_TEXTURE_VERT ::
`
#version 330 core

// from vbo
layout(location = 0) in vec3 vbo_vertex_position;
layout(location = 1) in vec2 vbo_tex_coord;

// note(josh): mesh vert colors are broken right now
// layout(location = 2) in vec4 vbo_color;

uniform vec4 mesh_color;
uniform mat4 mvp_matrix;

out vec2 tex_coord;
out vec4 desired_color;

void main() {
    vec4 result = mvp_matrix * vec4(vbo_vertex_position.x, vbo_vertex_position.y, vbo_vertex_position.z, 1);
    if (result.w > 0) { result /= result.w; }
    gl_Position = result;
    tex_coord = vbo_tex_coord;
    desired_color = mesh_color;
}
`;

SHADER_TEXTURE_FRAG ::
`
#version 330 core

in vec2 tex_coord;
in vec4 desired_color;

uniform sampler2D atlas_texture;

layout(location = 0) out vec4 color;

void main() {
    color = texture(atlas_texture, tex_coord) * desired_color;
}
`;

SHADER_TEXT_VERT ::
`
#version 330 core

// from vbo
layout(location = 0) in vec3 vbo_vertex_position;
layout(location = 1) in vec2 vbo_tex_coord;
layout(location = 2) in vec4 vbo_color;

uniform mat4 mvp_matrix;

out vec2 tex_coord;
out vec4 desired_color;

void main() {
    vec4 result = mvp_matrix * vec4(vbo_vertex_position.x, vbo_vertex_position.y, vbo_vertex_position.z, 1);
    if (result.w > 0) { result /= result.w; }
    gl_Position = result;
    tex_coord = vbo_tex_coord;
    desired_color = vbo_color;
}
`;

SHADER_TEXT_FRAG ::
`
#version 330 core

in vec2 tex_coord;
in vec4 desired_color;

uniform sampler2D atlas_texture;

out vec4 color;

void main() {
	uvec4 bytes = uvec4(texture(atlas_texture, tex_coord) * 255);
	uvec4 desired = uvec4(desired_color * 255);

	uint old_r = bytes.r;

	bytes.r = desired.r;
	bytes.g = desired.g;
	bytes.b = desired.b;
	bytes.a &= old_r & desired.a;

	color = vec4(bytes.r, bytes.g, bytes.b, bytes.a) / 255f;
}
`;

SHADER_RGBA_3D_VERT ::
`
#version 330 core

layout(location = 0) in vec3 vbo_vertex_position;
layout(location = 1) in vec2 vbo_tex_coord;
layout(location = 2) in vec4 vbo_color;
layout(location = 3) in vec4 vbo_normal;

uniform vec4 mesh_color;
uniform mat4 mvp_matrix;

out vec4 desired_color;

void main() {
    vec4 result = mvp_matrix * vec4(vbo_vertex_position.x, vbo_vertex_position.y, vbo_vertex_position.z, 1);
    if (result.w > 0) { result /= result.w; }
    gl_Position = result;
    desired_color = vbo_color * mesh_color;
}
`;

SHADER_RGBA_3D_FRAG ::
`
#version 330 core

in vec4 desired_color;

out vec4 color;

void main() {
    color = desired_color;
}
`;

SHADER_CUBEMAP_VERT ::
`
#version 330 core
layout (location = 0) in vec3 vbo_vertex_position;

out vec3 TexCoords;

uniform mat4 mvp_matrix;

void main()
{
    TexCoords = vbo_vertex_position;
    gl_Position = mvp_matrix * vec4(vbo_vertex_position, 1.0);
} 
`;

SHADER_CUBEMAP_FRAG :: 
`
#version 330 core
out vec4 color;

in vec3 TexCoords;

uniform samplerCube skybox;

void main()
{    
    color = texture(skybox, TexCoords);
}
`;