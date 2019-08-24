package gpu

using import "core:math"
using import "core:fmt"

using import "../types"
using import "../basic"
using import "../logging"
using import wbm "../math"

      import odingl "../external/gl"

/*

--- Cameras
{
	init_camera              :: proc(camera: ^Camera, is_perspective: bool, size: f32, pixel_width, pixel_height: int, make_framebuffer := false)
	delete_camera            :: proc(camera: ^Camera)
	update_camera_pixel_size :: proc(using camera: ^Camera, new_width: f32, new_height: f32)

	PUSH_CAMERA              :: proc(camera: ^Camera) -> ^Camera
	push_camera_non_deferred :: proc(camera: ^Camera) -> ^Camera
	pop_camera               :: proc(old_camera: ^Camera)

	construct_view_matrix       :: proc(camera: ^Camera) -> Mat4
	construct_projection_matrix :: proc(camera: ^Camera) -> Mat4
	construct_rendermode_matrix :: proc(camera: ^Camera) -> Mat4

	rendermode_world :: proc()
	rendermode_unit  :: proc()
	rendermode_pixel :: proc()
}

--- Textures
{
	draw_texture :: proc(texture: Texture, shader: Shader_Program, pixel1: Vec2, pixel2: Vec2, color := Colorf{1, 1, 1, 1})
}

--- Models and Meshes
{
	add_mesh_to_model      :: proc(model: ^Model, name: string, vertices: []$Vertex_Type, indicies: []u32)
	remove_mesh_from_model :: proc(model: ^Model, name: string) -> bool
	update_mesh            :: proc(model: ^Model, name: string, vertices: []$Vertex_Type, indicies: []u32) -> bool
	draw_model             :: proc(model: Model, position: Vec3, scale: Vec3, rotation: Quat, texture: Texture, color: Colorf, depth_test: bool)
	delete_model           :: proc(model: Model)
}

--- Helpers
{
	create_cube_model :: proc() -> Model
	create_quad_model :: proc() -> Model

	camera_up      :: proc(camera: ^Camera) -> Vec3
	camera_down    :: proc(camera: ^Camera) -> Vec3
	camera_left    :: proc(camera: ^Camera) -> Vec3
	camera_right   :: proc(camera: ^Camera) -> Vec3
	camera_forward :: proc(camera: ^Camera) -> Vec3
	camera_back    :: proc(camera: ^Camera) -> Vec3

	get_mouse_world_position        :: proc(camera: ^Camera, cursor_unit_position: Vec2) -> Vec3
	get_mouse_direction_from_camera :: proc(camera: ^Camera, cursor_unit_position: Vec2) -> Vec3

	world_to_viewport               :: proc(position: Vec3, camera: ^Camera) -> Vec3
	world_to_pixel                  :: proc(a: Vec3, camera: ^Camera, pixel_width: f32, pixel_height: f32) -> Vec3
	world_to_unit                   :: proc(a: Vec3, camera: ^Camera) -> Vec3
	unit_to_pixel                   :: proc(a: Vec3, pixel_width: f32, pixel_height: f32) -> Vec3
	unit_to_viewport                :: proc(a: Vec3) -> Vec3
	pixel_to_viewport               :: proc(a: Vec3, pixel_width: f32, pixel_height: f32) -> Vec3
	pixel_to_unit                   :: proc(a: Vec3, pixel_width: f32, pixel_height: f32) -> Vec3
	viewport_to_pixel               :: proc(a: Vec3, pixel_width: f32, pixel_height: f32) -> Vec3
	viewport_to_unit                :: proc(a: Vec3) -> Vec3
}

--- Framebuffers
{
	create_framebuffer :: proc(width, height: int) -> Framebuffer
	delete_framebuffer :: proc(framebuffer: Framebuffer)
	bind_framebuffer   :: proc(framebuffer: ^Framebuffer)
	unbind_framebuffer :: proc()
}

*/



//
// Cameras
//

init_camera :: proc(camera: ^Camera, is_perspective: bool, size: f32, pixel_width, pixel_height: int, make_framebuffer := false) {
    camera.is_perspective = is_perspective;
    camera.size = size;
    camera.position = Vec3{};
    camera.rotation = Quat{0, 0, 0, 1};
    camera.draw_mode = .Triangles;
    camera.pixel_width = cast(f32)pixel_width;
    camera.pixel_height = cast(f32)pixel_height;
    camera.aspect = camera.pixel_width / camera.pixel_height;

    if make_framebuffer {
        assert(pixel_width > 0);
        assert(pixel_height > 0);
        camera.framebuffer = create_framebuffer(pixel_width, pixel_height);
    }
}

@(deferred_out=pop_camera)
PUSH_CAMERA :: inline proc(camera: ^Camera) -> ^Camera {
	return push_camera_non_deferred(camera);
}

push_camera_non_deferred :: proc(camera: ^Camera) -> ^Camera {
	old_camera := current_camera;
	current_camera = camera;

	enable(Capabilities.Blend);
	blend_func(Blend_Factors.Src_Alpha, Blend_Factors.One_Minus_Src_Alpha);
	viewport(0, 0, cast(int)current_camera.pixel_width, cast(int)current_camera.pixel_height);

	if current_camera.framebuffer.fbo != 0 {
		bind_framebuffer(&current_camera.framebuffer);
	}
	else {
		unbind_framebuffer();
	}

	set_clear_color(camera.clear_color);
	if current_camera.is_perspective {
		enable(Capabilities.Depth_Test);
		clear_screen(Clear_Flags.Color_Buffer | Clear_Flags.Depth_Buffer);
	}
	else {
		disable(Capabilities.Depth_Test);
		clear_screen(Clear_Flags.Color_Buffer);
	}
	return old_camera;
}

pop_camera :: proc(old_camera: ^Camera) {
	current_camera = old_camera;

	viewport(0, 0, cast(int)current_camera.pixel_width, cast(int)current_camera.pixel_height);
	if current_camera.framebuffer.fbo != 0 {
		bind_framebuffer(&current_camera.framebuffer);
	}
	else {
		unbind_framebuffer();
	}
}

update_camera_pixel_size :: proc(using camera: ^Camera, new_width: f32, new_height: f32) {
    pixel_width = new_width;
    pixel_height = new_height;
    aspect = new_width / new_height;

    if framebuffer.fbo != 0 {
        if framebuffer.width != cast(int)new_width || framebuffer.height != cast(int)new_height {
            logln("Rebuilding framebuffer...");
            delete_framebuffer(framebuffer);
            framebuffer = create_framebuffer(cast(int)new_width, cast(int)new_height);
        }
    }
}

delete_camera :: proc(camera: ^Camera) {
    if camera.framebuffer.fbo != 0 {
        delete_framebuffer(camera.framebuffer);
    }
}

// todo(josh): it's probably slow that we dont cache matrices at all :grimacing:
construct_view_matrix :: proc(camera: ^Camera) -> Mat4 {
    view_matrix := identity(Mat4);
    view_matrix = translate(view_matrix, Vec3{-camera.position.x, -camera.position.y, -camera.position.z});
    rotation_matrix := quat_to_mat4(inverse(camera.rotation));
    view_matrix = mul(rotation_matrix, view_matrix);
    return view_matrix;
}

construct_projection_matrix :: proc(camera: ^Camera) -> Mat4 {
    if camera.is_perspective {
        return perspective(to_radians(camera.size), camera.aspect, 0.01, 1000);
    }
    else {
        top    : f32 =  1 * camera.size;
        bottom : f32 = -1 * camera.size;
        left   : f32 = -1 * camera.aspect * camera.size;
        right  : f32 =  1 * camera.aspect * camera.size;
        return ortho3d(left, right, bottom, top, -1, 1);
    }
}

construct_rendermode_matrix :: proc(camera: ^Camera) -> Mat4 {
    #complete
    switch camera.current_rendermode {
        case .World: {
            return construct_projection_matrix(camera);
        }
        case .Unit: {
            unit := translate(identity(Mat4), Vec3{-1, -1, 0});
            unit = scale(unit, 2);
            return unit;
        }
        case .Pixel: {
            pixel := scale(identity(Mat4), Vec3{1.0 / camera.pixel_width, 1.0 / camera.pixel_height, 0});
            pixel = scale(pixel, 2);
            pixel = translate(pixel, Vec3{-1, -1, 0});
            return pixel;
        }
        case: panic(tprint(camera.current_rendermode));
    }

    unreachable();
    return {};
}



//
// Textures
//

draw_texture :: proc(texture: Texture, shader: Shader_Program, pixel1: Vec2, pixel2: Vec2, color := Colorf{1, 1, 1, 1}) {
	rendermode_pixel();
	use_program(shader);
	center := to_vec3(pixel1 + ((pixel2 - pixel1) / 2));
	size   := to_vec3(pixel2 - pixel1);
	draw_model(_internal_quad_model, center, size, {0, 0, 0, 1}, texture, {1, 1, 1, 1}, false);
}



//
// Models and Meshes
//

// todo(josh): maybe shouldn't use strings for mesh names, not sure
add_mesh_to_model :: proc(model: ^Model, name: string, vertices: []$Vertex_Type, indicies: []u32) {
	vao := gen_vao();
	vbo := gen_vbo();
	ibo := gen_ebo();

	mesh := Mesh{name, vao, vbo, ibo, type_info_of(Vertex_Type), len(indicies), len(vertices)};
	append(&model.meshes, mesh);

	update_mesh(model, name, vertices, indicies);
}

remove_mesh_from_model :: proc(model: ^Model, name: string) -> bool {
	for mesh, idx in model.meshes {
		if mesh.name != name do continue;
		_internal_delete_mesh(mesh);
		unordered_remove(&model.meshes, idx);
		return true;
	}

	// todo(josh): maybe remove this log? idk
	logln("Couldn't find mesh '", name, "'.");
	return false;
}

update_mesh :: proc(model: ^Model, name: string, vertices: []$Vertex_Type, indicies: []u32) -> bool {
	for _, i in model.meshes {
		mesh := &model.meshes[i];
		if mesh.name != name do continue;

		bind_vao(mesh.vao);

		bind_vbo(mesh.vbo);
		buffer_vertices(vertices);

		bind_ibo(mesh.ibo);
		buffer_elements(indicies);

		bind_vao(cast(VAO)0);

		mesh.vertex_type  = type_info_of(Vertex_Type);
		mesh.index_count  = len(indicies);
		mesh.vertex_count = len(vertices);

		return true;
	}

	// todo(josh): maybe remove this log? idk
	logln("Couldn't find mesh '", name, "'.");
	return false;
}

draw_model :: proc(model: Model, position: Vec3, scale: Vec3, rotation: Quat, texture: Texture, color: Colorf, depth_test: bool, loc := #caller_location) {
	// projection matrix
	projection_matrix := construct_rendermode_matrix(current_camera);

	// view matrix
	view_matrix := construct_view_matrix(current_camera);

	// model_matrix
	model_p := translate(identity(Mat4), position);
	model_s := math.scale(identity(Mat4), scale);
	model_r := quat_to_mat4(rotation);
	model_matrix := mul(mul(model_p, model_r), model_s);

	for mesh in model.meshes {
		bind_vao(mesh.vao);
		bind_vbo(mesh.vbo);
		bind_ibo(mesh.ibo);
		bind_texture2d(texture);

		set_vertex_format(mesh.vertex_type);

		program := get_current_shader();

		uniform3f(program, "camera_position", expand_to_tuple(current_camera.position));

		uniform1i(program, "has_texture", texture != 0 ? 1 : 0);
		uniform4f(program, "mesh_color", color.r, color.g, color.b, color.a);

		uniform_matrix4fv(program, "model_matrix",      1, false, &model_matrix[0][0]);
		uniform_matrix4fv(program, "view_matrix",       1, false, &view_matrix[0][0]);
		uniform_matrix4fv(program, "projection_matrix", 1, false, &projection_matrix[0][0]);

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
			odingl.DrawElements(cast(u32)current_camera.draw_mode, i32(mesh.index_count), odingl.UNSIGNED_INT, nil);
		}
		else {
			odingl.DrawArrays(cast(u32)current_camera.draw_mode, 0, cast(i32)mesh.vertex_count);
		}
	}
}

delete_model :: proc(model: Model) {
	for mesh in model.meshes {
		_internal_delete_mesh(mesh);
	}
	delete(model.meshes);
}

create_cube_model :: proc() -> Model {
    verts := []Vertex3D {
        {{-0.5, -0.5, -0.5}, {}, Colorf{1, 1, 1, 1}, Vec3{ 0.0,  0.0, -1.0}},
        {{ 0.5, -0.5, -0.5}, {}, Colorf{1, 1, 1, 1}, Vec3{ 0.0,  0.0, -1.0}},
        {{ 0.5,  0.5, -0.5}, {}, Colorf{1, 1, 1, 1}, Vec3{ 0.0,  0.0, -1.0}},
        {{ 0.5,  0.5, -0.5}, {}, Colorf{1, 1, 1, 1}, Vec3{ 0.0,  0.0, -1.0}},
        {{-0.5,  0.5, -0.5}, {}, Colorf{1, 1, 1, 1}, Vec3{ 0.0,  0.0, -1.0}},
        {{-0.5, -0.5, -0.5}, {}, Colorf{1, 1, 1, 1}, Vec3{ 0.0,  0.0, -1.0}},
        {{-0.5, -0.5,  0.5}, {}, Colorf{1, 1, 1, 1}, Vec3{ 0.0,  0.0,  1.0}},
        {{ 0.5, -0.5,  0.5}, {}, Colorf{1, 1, 1, 1}, Vec3{ 0.0,  0.0,  1.0}},
        {{ 0.5,  0.5,  0.5}, {}, Colorf{1, 1, 1, 1}, Vec3{ 0.0,  0.0,  1.0}},
        {{ 0.5,  0.5,  0.5}, {}, Colorf{1, 1, 1, 1}, Vec3{ 0.0,  0.0,  1.0}},
        {{-0.5,  0.5,  0.5}, {}, Colorf{1, 1, 1, 1}, Vec3{ 0.0,  0.0,  1.0}},
        {{-0.5, -0.5,  0.5}, {}, Colorf{1, 1, 1, 1}, Vec3{ 0.0,  0.0,  1.0}},
        {{-0.5,  0.5,  0.5}, {}, Colorf{1, 1, 1, 1}, Vec3{-1.0,  0.0,  0.0}},
        {{-0.5,  0.5, -0.5}, {}, Colorf{1, 1, 1, 1}, Vec3{-1.0,  0.0,  0.0}},
        {{-0.5, -0.5, -0.5}, {}, Colorf{1, 1, 1, 1}, Vec3{-1.0,  0.0,  0.0}},
        {{-0.5, -0.5, -0.5}, {}, Colorf{1, 1, 1, 1}, Vec3{-1.0,  0.0,  0.0}},
        {{-0.5, -0.5,  0.5}, {}, Colorf{1, 1, 1, 1}, Vec3{-1.0,  0.0,  0.0}},
        {{-0.5,  0.5,  0.5}, {}, Colorf{1, 1, 1, 1}, Vec3{-1.0,  0.0,  0.0}},
        {{ 0.5,  0.5,  0.5}, {}, Colorf{1, 1, 1, 1}, Vec3{ 1.0,  0.0,  0.0}},
        {{ 0.5,  0.5, -0.5}, {}, Colorf{1, 1, 1, 1}, Vec3{ 1.0,  0.0,  0.0}},
        {{ 0.5, -0.5, -0.5}, {}, Colorf{1, 1, 1, 1}, Vec3{ 1.0,  0.0,  0.0}},
        {{ 0.5, -0.5, -0.5}, {}, Colorf{1, 1, 1, 1}, Vec3{ 1.0,  0.0,  0.0}},
        {{ 0.5, -0.5,  0.5}, {}, Colorf{1, 1, 1, 1}, Vec3{ 1.0,  0.0,  0.0}},
        {{ 0.5,  0.5,  0.5}, {}, Colorf{1, 1, 1, 1}, Vec3{ 1.0,  0.0,  0.0}},
        {{-0.5, -0.5, -0.5}, {}, Colorf{1, 1, 1, 1}, Vec3{ 0.0, -1.0,  0.0}},
        {{ 0.5, -0.5, -0.5}, {}, Colorf{1, 1, 1, 1}, Vec3{ 0.0, -1.0,  0.0}},
        {{ 0.5, -0.5,  0.5}, {}, Colorf{1, 1, 1, 1}, Vec3{ 0.0, -1.0,  0.0}},
        {{ 0.5, -0.5,  0.5}, {}, Colorf{1, 1, 1, 1}, Vec3{ 0.0, -1.0,  0.0}},
        {{-0.5, -0.5,  0.5}, {}, Colorf{1, 1, 1, 1}, Vec3{ 0.0, -1.0,  0.0}},
        {{-0.5, -0.5, -0.5}, {}, Colorf{1, 1, 1, 1}, Vec3{ 0.0, -1.0,  0.0}},
        {{-0.5,  0.5, -0.5}, {}, Colorf{1, 1, 1, 1}, Vec3{ 0.0,  1.0,  0.0}},
        {{ 0.5,  0.5, -0.5}, {}, Colorf{1, 1, 1, 1}, Vec3{ 0.0,  1.0,  0.0}},
        {{ 0.5,  0.5,  0.5}, {}, Colorf{1, 1, 1, 1}, Vec3{ 0.0,  1.0,  0.0}},
        {{ 0.5,  0.5,  0.5}, {}, Colorf{1, 1, 1, 1}, Vec3{ 0.0,  1.0,  0.0}},
        {{-0.5,  0.5,  0.5}, {}, Colorf{1, 1, 1, 1}, Vec3{ 0.0,  1.0,  0.0}},
        {{-0.5,  0.5, -0.5}, {}, Colorf{1, 1, 1, 1}, Vec3{ 0.0,  1.0,  0.0}},
    };

    model: Model;
    add_mesh_to_model(&model, "cube", verts, {});
    return model;
}

create_quad_model :: proc() -> Model {
    verts := []Vertex3D {
        {{-0.5, -0.5, 0}, {0, 0, 0}, Colorf{1, 1, 1, 1}, Vec3{0, 0, -1}},
        {{-0.5,  0.5, 0}, {0, 1, 0}, Colorf{1, 1, 1, 1}, Vec3{0, 0, -1}},
        {{ 0.5,  0.5, 0}, {1, 1, 0}, Colorf{1, 1, 1, 1}, Vec3{0, 0, -1}},
        {{ 0.5,  0.5, 0}, {1, 1, 0}, Colorf{1, 1, 1, 1}, Vec3{0, 0, -1}},
        {{ 0.5, -0.5, 0}, {1, 0, 0}, Colorf{1, 1, 1, 1}, Vec3{0, 0, -1}},
        {{-0.5, -0.5, 0}, {0, 0, 0}, Colorf{1, 1, 1, 1}, Vec3{0, 0, -1}},
    };

    model: Model;
    add_mesh_to_model(&model, "quad", verts, {});
    return model;
}



//
// Rendermodes
//

// todo(josh): maybe do a push/pop rendermode kinda thing?

Rendermode_Proc :: #type proc();

rendermode_world :: proc() {
	current_camera.current_rendermode = .World;
}
rendermode_unit :: proc() {
	current_camera.current_rendermode = .Unit;
}
rendermode_pixel :: proc() {
	current_camera.current_rendermode = .Pixel;
}



//
// Framebuffers
//

create_framebuffer :: proc(width, height: int) -> Framebuffer {
	fbo := gen_framebuffer();
	bind_fbo(fbo);

	texture := gen_texture();
	bind_texture2d(texture);

	tex_image2d(.Texture2D, 0, .RGBA, cast(i32)width, cast(i32)height, 0, .RGBA, .Unsigned_Byte, nil);
	// tex_image2d(Texture_Target.Texture2D, 0, Internal_Color_Format.RGBA32F, cast(i32)width, cast(i32)height, 0, Pixel_Data_Format.RGB, Texture2D_Data_Type.Unsigned_Byte, nil);
	tex_parameteri(Texture_Target.Texture2D, Texture_Parameter.Mag_Filter, Texture_Parameter_Value.Nearest);
	tex_parameteri(Texture_Target.Texture2D, Texture_Parameter.Min_Filter, Texture_Parameter_Value.Nearest);

	rbo := gen_renderbuffer();
	bind_rbo(rbo);

	renderbuffer_storage(Renderbuffer_Storage.Depth24_Stencil8, cast(i32)width, cast(i32)height);
	framebuffer_renderbuffer(Framebuffer_Attachment.Depth_Stencil, rbo);

	framebuffer_texture2d(Framebuffer_Attachment.Color0, texture);

	draw_buffer := Framebuffer_Attachment.Color0;
	odingl.DrawBuffers(1, transmute(^u32)&draw_buffer);

	assert_framebuffer_complete();

	bind_texture2d(0);
	bind_rbo(0);
	bind_fbo(0);

	framebuffer := Framebuffer{fbo, texture, rbo, width, height};
	return framebuffer;
}

bind_framebuffer :: proc(framebuffer: ^Framebuffer) {
	bind_fbo(framebuffer.fbo);
}

unbind_framebuffer :: proc() {
	bind_fbo(0);
}

delete_framebuffer :: proc(framebuffer: Framebuffer) {
	delete_rbo(framebuffer.rbo);
	delete_texture(framebuffer.texture);
	delete_fbo(framebuffer.fbo);
}



//
// Helpers
//

camera_up      :: inline proc(using camera: ^Camera) -> Vec3 do return quaternion_up     (rotation);
camera_down    :: inline proc(using camera: ^Camera) -> Vec3 do return quaternion_down   (rotation);
camera_left    :: inline proc(using camera: ^Camera) -> Vec3 do return quaternion_left   (rotation);
camera_right   :: inline proc(using camera: ^Camera) -> Vec3 do return quaternion_right  (rotation);
camera_forward :: inline proc(using camera: ^Camera) -> Vec3 do return quaternion_forward(rotation);
camera_back    :: inline proc(using camera: ^Camera) -> Vec3 do return quaternion_back   (rotation);

get_mouse_world_position :: proc(camera: ^Camera, cursor_unit_position: Vec2) -> Vec3 {
	cursor_viewport_position := to_vec4((cursor_unit_position * 2) - Vec2{1, 1});
	cursor_viewport_position.w = 1;

	// todo(josh): should probably make this 0.5 because I think directx is 0 -> 1 instead of -1 -> 1 like opengl
	cursor_viewport_position.z = 0.1; // just some way down the frustum

	inv := mat4_inverse_(mul(construct_projection_matrix(camera), construct_view_matrix(camera)));

	cursor_world_position4 := mul(inv, cursor_viewport_position);
	if cursor_world_position4.w != 0 do cursor_world_position4 /= cursor_world_position4.w;
	cursor_world_position := to_vec3(cursor_world_position4);

	return cursor_world_position;
}

get_mouse_direction_from_camera :: proc(camera: ^Camera, cursor_unit_position: Vec2) -> Vec3 {
	if !camera.is_perspective {
		return camera_forward(camera);
	}

	cursor_world_position := get_mouse_world_position(camera, cursor_unit_position);
	cursor_direction := norm(cursor_world_position - camera.position);
	return cursor_direction;
}

world_to_viewport :: inline proc(position: Vec3, camera: ^Camera) -> Vec3 {
	proj := construct_projection_matrix(camera);
	if camera.is_perspective {
		mv := mul(proj, construct_view_matrix(camera));
		result := mul(mv, Vec4{position.x, position.y, position.z, 1});
		if result.w > 0 do result /= result.w;
		new_result := Vec3{result.x, result.y, result.z};
		return new_result;
	}

	result := mul(proj, Vec4{position.x, position.y, position.z, 1});
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
	a := a;
	a /= Vec3{pixel_width/2, pixel_height/2, 1};
	a -= Vec3{1, 1, 0};
	return a;
}
pixel_to_unit :: inline proc(a: Vec3, pixel_width: f32, pixel_height: f32) -> Vec3 {
	a := a;
	a /= Vec3{pixel_width, pixel_height, 1};
	return a;
}

viewport_to_pixel :: inline proc(a: Vec3, pixel_width: f32, pixel_height: f32) -> Vec3 {
	a := a;
	a += Vec3{1, 1, 0};
	a *= Vec3{pixel_width/2, pixel_height/2, 0};
	a.z = 0;
	return a;
}
viewport_to_unit :: inline proc(a: Vec3) -> Vec3 {
	a := a;
	a += Vec3{1, 1, 0};
	a /= 2;
	a.z = 0;
	return a;
}



//
// Internal
//

_internal_quad_model: Model;
_internal_cube_model: Model;

default_camera: Camera;
current_camera: ^Camera;

init_gpu :: proc(screen_width, screen_height: int, version_major, version_minor: int, set_proc_address: odingl.Set_Proc_Address_Type) {
	odingl.load_up_to(version_major, version_minor, set_proc_address);

	init_camera(&default_camera, true, 85, screen_width, screen_height);
	default_camera.clear_color = {1, 1, 0, 1};
	push_camera_non_deferred(&default_camera);

	_internal_cube_model = create_cube_model();
	_internal_quad_model = create_quad_model();
}

_internal_delete_mesh :: proc(mesh: Mesh) {
	delete_vao(mesh.vao);
	delete_buffer(mesh.vbo);
	delete_buffer(mesh.ibo);
}