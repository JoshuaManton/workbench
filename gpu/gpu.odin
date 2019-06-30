package gpu

using import "core:math"

using import "../types"
using import "../basic"
using import "../logging"
using import wbm "../math"

      import odingl "../external/gl"

/*

--- GPU

=> create_mesh   :: proc(vertices: []$Vertex_Type, indicies: []u32, name: string) -> MeshID
=> release_mesh  :: proc(id: MeshID)
=> update_mesh   :: proc(id: MeshID, vertices: []$Vertex_Type, indicies: []u32)
=> draw_mesh     :: proc(mesh: ^Mesh, camera: ^Camera, position: Vec3, scale: Vec3, rotation: Quat, texture: Texture, color: Colorf, depth_test: bool)
=> get_mesh_info :: proc(id: MeshID) -> (Mesh_Info, bool)

*/

init_gpu_opengl :: proc(version_major, version_minor: int, set_proc_address: odingl.Set_Proc_Address_Type) {
	odingl.load_up_to(version_major, version_minor, set_proc_address);
}



add_mesh_to_model :: proc(model: ^Model, name: string, vertices: []$Vertex_Type, indicies: []u32) {
	vao := gen_vao();
	vbo := gen_vbo();
	ibo := gen_ebo();

	mesh := Mesh{name, vao, vbo, ibo, type_info_of(Vertex_Type), len(indicies), len(vertices)};
	append(&model.meshes, mesh);

	update_mesh(model, len(model.meshes)-1, vertices, indicies);
}

update_mesh :: proc(model: ^Model, mesh_index: int, vertices: []$Vertex_Type, indicies: []u32) {
	info := &model.meshes[mesh_index];
	bind_vao(info.vao);

	bind_vbo(info.vbo);
	buffer_vertices(vertices);

	bind_ibo(info.ibo);
	buffer_elements(indicies);

	bind_vao(cast(VAO)0);

	info.vertex_type  = type_info_of(Vertex_Type);
	info.index_count  = len(indicies);
	info.vertex_count = len(vertices);
}

draw_model :: proc(model: ^Model, camera: ^Camera, position: Vec3, scale: Vec3, rotation: Quat, color: Colorf, depth_test: bool) {
	// view matrix
	view_matrix := identity(Mat4);
	view_matrix = translate(view_matrix, Vec3{-camera.position.x, -camera.position.y, -camera.position.z});
	rotation_matrix := quat_to_mat4(inverse(camera.rotation));
	view_matrix = mul(rotation_matrix, view_matrix);

	// model_matrix
	model_matrix := translate(identity(Mat4), position);
	model_matrix = math.scale(model_matrix, scale);
	model_matrix = math.mul(model_matrix, quat_to_mat4(rotation));

	for mesh in model.meshes {
		bind_vao(mesh.vao);
		bind_vbo(mesh.vbo);
		bind_ibo(mesh.ibo);
		bind_texture2d(model.texture);

		set_vertex_format(mesh.vertex_type);

		program := get_current_shader();

		uniform3f(program, "camera_position", expand_to_tuple(camera.position));

		uniform1i(program, "has_texture", model.texture != 0 ? 1 : 0);
		uniform4f(program, "mesh_color", color.r, color.g, color.b, color.a);

		uniform_matrix4fv(program, "model_matrix",      1, false, &model_matrix[0][0]);
		uniform_matrix4fv(program, "view_matrix",       1, false, &view_matrix[0][0]);
		uniform_matrix4fv(program, "projection_matrix", 1, false, &camera.projection_matrix[0][0]);

		// todo(josh): remove all this depth test stuff? since we take it as a parameter we can just set it every time I think

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
			odingl.DrawElements(cast(u32)camera.draw_mode, i32(mesh.index_count), odingl.UNSIGNED_INT, nil);
		}
		else {
			odingl.DrawArrays(cast(u32)camera.draw_mode, 0, cast(i32)mesh.vertex_count);
		}
	}
}

delete_mesh :: proc(model: ^Model) {
	for mesh in model.meshes {
		delete_vao(mesh.vao);
		delete_buffer(mesh.vbo);
		delete_buffer(mesh.ibo);
	}
	delete(model.meshes);
}





update_camera :: proc(camera: ^Camera, pixel_width: f32, pixel_height: f32) {
	camera.pixel_width = pixel_width;
	camera.pixel_height = pixel_height;
	camera.aspect = camera.pixel_width / camera.pixel_height;

	// perspective
	{
		camera.perspective_matrix = perspective(to_radians(camera.size), camera.aspect, 0.01, 1000);
	}

	// ortho
	{
		top    : f32 =  1 * camera.size + camera.position.y;
		bottom : f32 = -1 * camera.size + camera.position.y;
		left   : f32 = -1 * camera.aspect * camera.size + camera.position.x;
		right  : f32 =  1 * camera.aspect * camera.size + camera.position.x;
		camera.orthographic_matrix = ortho3d(left, right, bottom, top, -1, 1);
	}

	// Unit space
	{
		camera.unit_to_viewport_matrix = translate(identity(Mat4), Vec3{-1, -1, 0});
		camera.unit_to_viewport_matrix = scale(camera.unit_to_viewport_matrix, 2);
		camera.unit_to_pixel_matrix = scale(identity(Mat4), Vec3{camera.pixel_width, camera.pixel_height, 0});
	}

	// Pixel space
	{
		camera.pixel_to_viewport_matrix = scale(identity(Mat4), Vec3{1.0 / camera.pixel_width, 1.0 / camera.pixel_height, 0});
		camera.pixel_to_viewport_matrix = translate(camera.pixel_to_viewport_matrix, Vec3{-1, -1, 0});
		camera.pixel_to_viewport_matrix = scale(camera.pixel_to_viewport_matrix, 2);
	}

	// Viewport space
	{
		camera.viewport_to_pixel_matrix = identity(Mat4);
		camera.viewport_to_pixel_matrix = translate(camera.viewport_to_pixel_matrix, Vec3{1, 1, 0});
		camera.viewport_to_pixel_matrix = scale(camera.viewport_to_pixel_matrix, Vec3{camera.pixel_width/2, camera.pixel_height/2, 0});

		camera.viewport_to_unit_matrix = identity(Mat4);
		camera.viewport_to_unit_matrix = translate(camera.viewport_to_unit_matrix, Vec3{1, 1, 0});
		camera.viewport_to_unit_matrix = scale(camera.viewport_to_unit_matrix, 0.5);
	}
}

Rendermode_Proc :: #type proc(^Camera);

rendermode_world :: proc(camera: ^Camera) {
	if camera.is_perspective {
		camera.projection_matrix = camera.perspective_matrix;
	}
	else {
		camera.projection_matrix = camera.orthographic_matrix;
	}
}
rendermode_unit :: proc(camera: ^Camera) {
	camera.projection_matrix = camera.unit_to_viewport_matrix;
}
rendermode_pixel :: proc(camera: ^Camera) {
	camera.projection_matrix = camera.pixel_to_viewport_matrix;
}

camera_up      :: inline proc(using camera: ^Camera) -> Vec3 do return quaternion_up     (rotation);
camera_down    :: inline proc(using camera: ^Camera) -> Vec3 do return quaternion_down   (rotation);
camera_left    :: inline proc(using camera: ^Camera) -> Vec3 do return quaternion_left   (rotation);
camera_right   :: inline proc(using camera: ^Camera) -> Vec3 do return quaternion_right  (rotation);
camera_forward :: inline proc(using camera: ^Camera) -> Vec3 do return quaternion_forward(rotation);
camera_back    :: inline proc(using camera: ^Camera) -> Vec3 do return quaternion_back   (rotation);

get_cursor_world_position :: proc(camera: ^Camera, cursor_unit_position: Vec2) -> Vec3 {
	cursor_viewport_position := to_vec4((cursor_unit_position * 2) - Vec2{1, 1});
	cursor_viewport_position.w = 1;

	// todo(josh): should probably make this 0.5 because I think directx is 0-1 instead of -1-1 like opengl
	cursor_viewport_position.z = 0; // just some way down the frustum

	inv: Mat4;
	inv = mat4_inverse_(mul(camera.projection_matrix, camera.view_matrix));

	cursor_world_position4 := mul(inv, cursor_viewport_position);
	if cursor_world_position4.w != 0 do cursor_world_position4 /= cursor_world_position4.w;
	cursor_world_position := to_vec3(cursor_world_position4) - camera.position;

	return cursor_world_position;
}

get_cursor_direction_from_camera :: proc(camera: ^Camera, cursor_unit_position: Vec2) -> Vec3 {
	if !camera.is_perspective {
		return camera_forward(camera);
	}

	cursor_world_position := get_cursor_world_position(camera, cursor_unit_position);
	cursor_direction := norm(cursor_world_position);
	return cursor_direction;
}

// normalize_camera_rotation :: proc(using camera: ^Camera) {
// 	for _, i in rotation {
// 		element := &rotation[i];
// 		for element^ < 0   do element^ += 360;
// 		for element^ > 360 do element^ -= 360;
// 	}
// }

world_to_viewport :: inline proc(position: Vec3, camera: ^Camera) -> Vec3 {
	if camera.is_perspective {
		mv := mul(camera.projection_matrix, camera.view_matrix);
		result := mul(mv, Vec4{position.x, position.y, position.z, 1});
		if result.w > 0 do result /= result.w;
		new_result := Vec3{result.x, result.y, result.z};
		return new_result;
	}

	result := mul(camera.projection_matrix, Vec4{position.x, position.y, position.z, 1});
	return Vec3{result.x, result.y, result.z};
}
world_to_pixel :: inline proc(a: Vec3, camera: ^Camera, pixel_width: f32, pixel_height: f32) -> Vec3 {
	result := world_to_viewport(a, camera);
	result = viewport_to_pixel(result, pixel_width, pixel_height);
	return result;
}
world_to_unit :: inline proc(a: Vec3, camera: ^Camera) -> Vec3 {
	result := world_to_viewport(a, camera);
	result = viewport_to_unit(result);
	return result;
}

unit_to_pixel :: inline proc(a: Vec3, pixel_width: f32, pixel_height: f32) -> Vec3 {
	result := a * Vec3{pixel_width, pixel_height, 1};
	return result;
}
unit_to_viewport :: inline proc(a: Vec3) -> Vec3 {
	result := (a * 2) - Vec3{1, 1, 0};
	return result;
}

pixel_to_viewport :: inline proc(a: Vec3, pixel_width: f32, pixel_height: f32) -> Vec3 {
	a /= Vec3{pixel_width/2, pixel_height/2, 1};
	a -= Vec3{1, 1, 0};
	return a;
}
pixel_to_unit :: inline proc(a: Vec3, pixel_width: f32, pixel_height: f32) -> Vec3 {
	a /= Vec3{pixel_width, pixel_height, 1};
	return a;
}

viewport_to_pixel :: inline proc(a: Vec3, pixel_width: f32, pixel_height: f32) -> Vec3 {
	a += Vec3{1, 1, 0};
	a *= Vec3{pixel_width/2, pixel_height/2, 0};
	a.z = 0;
	return a;
}
viewport_to_unit :: inline proc(a: Vec3) -> Vec3 {
	a += Vec3{1, 1, 0};
	a /= 2;
	a.z = 0;
	return a;
}



create_framebuffer :: proc(width, height: int) -> Framebuffer {
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

	bind_texture2d(0);
	bind_rbo(0);
	bind_fbo(0);

	framebuffer := Framebuffer{fbo, texture, rbo, width, height};
	return framebuffer;
}

bind_framebuffer :: proc(framebuffer: ^Framebuffer) {
	bind_fbo(framebuffer.fbo);
	viewport(0, 0, cast(int)framebuffer.width, cast(int)framebuffer.height);
	set_clear_color(Colorf{.1, .5, .6, 1});
	clear_screen(Clear_Flags.Color_Buffer | Clear_Flags.Depth_Buffer);
}

unbind_framebuffer :: proc() {
	bind_fbo(0);
}

delete_framebuffer :: proc(framebuffer: Framebuffer) {
	delete_rbo(framebuffer.rbo);
	delete_texture(framebuffer.texture);
	delete_fbo(framebuffer.fbo);
}