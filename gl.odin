package workbench

using import "core:runtime"
      import "core:fmt"
      import "core:os"
using import "core:math"

      import        "external/glfw"
      import odingl "external/gl"

vao: VAO;
vbo: VBO;

shader_rgba:    Shader_Program;
shader_text:    Shader_Program;
shader_texture: Shader_Program;

shader_rgba_3d:    Shader_Program;
shader_cubemap:    Shader_Program;

_init_opengl :: proc(opengl_version_major, opengl_version_minor: int) {
	odingl.load_up_to(opengl_version_major, opengl_version_minor,
		proc(p: rawptr, name: cstring) {
			(cast(^rawptr)p)^ = rawptr(glfw.GetProcAddress(name));
		});

	vao = gen_vao();
	vbo = gen_vbo();

	ok: bool;
	shader_rgba, ok    = load_shader_text(SHADER_RGBA_VERT, SHADER_RGBA_FRAG);
	assert(ok);
	shader_texture, ok = load_shader_text(SHADER_TEXTURE_VERT, SHADER_TEXTURE_FRAG);
	assert(ok);
	shader_text, ok    = load_shader_text(SHADER_TEXT_VERT, SHADER_TEXT_FRAG);
	assert(ok);
	shader_rgba_3d, ok = load_shader_text(SHADER_RGBA_3D_VERT, SHADER_RGBA_3D_FRAG);
	assert(ok);
	shader_cubemap, ok = load_shader_text(SHADER_CUBEMAP_VERT, SHADER_CUBEMAP_FRAG);

	assert(ok);
}