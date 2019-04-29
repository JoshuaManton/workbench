package gpu

using import "core:math"

using import "../types"
using import "../logging"

      import odingl "../external/gl"

/*

--- GPU

=> create_mesh   :: proc(vertices: []$Vertex_Type, indicies: []u32, name: string) -> MeshID
=> release_mesh  :: proc(id: MeshID)
=> update_mesh   :: proc(id: MeshID, vertices: []$Vertex_Type, indicies: []u32)
=> draw_mesh     :: proc(id: MeshID, mode: Draw_Mode, shader: Shader_Program, texture: Texture, color: Colorf, mvp_matrix: ^Mat4, depth_test: bool)
=> get_mesh_info :: proc(id: MeshID) -> (Mesh_Info, bool)

*/

init_gpu_opengl :: proc(version_major, version_minor: int, set_proc_address: odingl.Set_Proc_Address_Type) {
	odingl.load_up_to(version_major, version_minor, set_proc_address);
}

// todo(josh): this probably should be something faster than a map
all_meshes: map[MeshID]Mesh_Info;

create_mesh :: proc(vertices: []$Vertex_Type, indicies: []u32, name: string) -> MeshID {
	@static last_mesh_id: int;
	last_mesh_id += 1;
	id := cast(MeshID)last_mesh_id;

	vao := gen_vao();
	vbo := gen_vbo();
	ibo := gen_ebo();

	mesh := Mesh_Info{name, vao, vbo, ibo, type_info_of(Vertex_Type), len(indicies), len(vertices)};
	all_meshes[id] = mesh;

	update_mesh(id, vertices, indicies);

	return id;
}

update_mesh :: proc(id: MeshID, vertices: []$Vertex_Type, indicies: []u32) {
	mesh, ok := get_mesh_info(id);
	assert(ok);

	bind_vao(mesh.vao);

	bind_vbo(mesh.vbo);
	buffer_vertices(vertices);

	bind_ibo(mesh.ibo);
	buffer_elements(indicies);

	set_vertex_format(Vertex_Type);

	bind_vao(cast(VAO)0);

	mesh.vertex_type  = type_info_of(Vertex_Type);
	mesh.index_count  = len(indicies);
	mesh.vertex_count = len(vertices);
	all_meshes[id] = mesh;
}

draw_mesh :: proc(id: MeshID, mode: Draw_Mode, shader: Shader_Program, texture: Texture, color: Colorf, mvp_matrix: ^Mat4, depth_test: bool) {
	mesh, ok := get_mesh_info(id);
	assert(ok);

	bind_vao(mesh.vao);
	bind_vbo(mesh.vbo);
	bind_ibo(mesh.ibo);
	use_program(shader);
	bind_texture2d(texture);

	program := get_current_shader();

	uniform4f(program, "mesh_color", color.r, color.g, color.b, color.a);
	uniform_matrix4fv(program, "mvp_matrix", 1, false, &mvp_matrix[0][0]);

	old_depth_test := odingl.IsEnabled(odingl.DEPTH_TEST);
	defer if old_depth_test == odingl.TRUE {
		odingl.Enable(odingl.DEPTH_TEST);
	}

	if depth_test {
		odingl.Enable(odingl.DEPTH_TEST);
	}
	else {
		odingl.Disable(odingl.DEPTH_TEST);
	}

	if mesh.index_count > 0 {
		odingl.DrawElements(cast(u32)mode, i32(mesh.index_count), odingl.UNSIGNED_INT, nil);
	}
	else {
		odingl.DrawArrays(cast(u32)mode, 0, cast(i32)mesh.vertex_count);
	}
}

release_mesh :: proc(id: MeshID) {
	mesh, ok := all_meshes[id];
	assert(ok);
	delete_vao(mesh.vao);
	delete_buffer(mesh.vbo);
	delete_buffer(mesh.ibo);
	delete_key(&all_meshes, id);
}

get_mesh_info :: inline proc(id: MeshID) -> (Mesh_Info, bool) {
	mesh, ok := all_meshes[id];
	return mesh, ok;
}




all_framebuffers: map[FramebufferID]Framebuffer_Data;

create_framebuffer :: proc(width, height: int) -> FramebufferID {
	@static last_fbo_id: int;
	last_fbo_id += 1;
	id := cast(FramebufferID)last_fbo_id;

	fbo := gen_framebuffer();
	bind_fbo(fbo);

	texture := gen_texture();
	bind_texture2d(texture);

	tex_image2d(Texture_Target.Texture2D, 0, Internal_Color_Format.RGBA32F, cast(i32)width, cast(i32)height, 0, Pixel_Data_Format.RGB, Texture2D_Data_Type.Unsigned_Byte, nil);
	tex_parameteri(Texture_Target.Texture2D, Texture_Parameter.Mag_Filter, Texture_Parameter_Value.Nearest);
	tex_parameteri(Texture_Target.Texture2D, Texture_Parameter.Min_Filter, Texture_Parameter_Value.Nearest);

	framebuffer_texture2d(Framebuffer_Attachment.Color0, texture);

	rbo := gen_renderbuffer();
	bind_rbo(rbo);

	renderbuffer_storage(Renderbuffer_Storage.Depth24_Stencil8, cast(i32)width, cast(i32)height);
	framebuffer_renderbuffer(Framebuffer_Attachment.Depth_Stencil, rbo);

	assert_framebuffer_complete();

	fbo_data := Framebuffer_Data{fbo, texture, rbo, width, height};
	all_framebuffers[id] = fbo_data;

	bind_texture2d(0);
	bind_rbo(0);
	bind_fbo(0);

	return id;
}

get_framebuffer_data :: proc(id: FramebufferID) -> (Framebuffer_Data, bool) {
	data, ok := all_framebuffers[id];
	return data, ok;
}

update_framebuffer_data :: proc(id: FramebufferID, data: Framebuffer_Data) {
	all_framebuffers[id] = data;
}

bind_framebuffer :: proc(id: FramebufferID) {
	data, ok := all_framebuffers[id];
	assert(ok);

	bind_fbo(data.fbo);
	viewport(0, 0, cast(int)data.width, cast(int)data.height);
	set_clear_color(Colorf{.1, .5, .6, 1});
	clear(Clear_Flags.Color_Buffer | Clear_Flags.Depth_Buffer);
}

unbind_framebuffer :: proc() {
	bind_fbo(0);
}

delete_framebuffer :: proc(id: FramebufferID) {
	data, ok := all_framebuffers[id];
	assert(ok);
	delete_rbo(data.rbo);
	delete_texture(data.texture);
	delete_fbo(data.fbo);
	delete_key(&all_framebuffers, id);
}