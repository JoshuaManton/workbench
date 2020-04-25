package workbench

import "core:fmt"
import "core:sort"
import "core:strings"
import "core:mem"
import rt "core:runtime"
import "core:os"

import "platform"
import "gpu"

import "external/stb"
import "external/glfw"
import "external/imgui"

/*

// todo(josh): these are quite out of date. we should have a preprocessor for documentation generation or something.

--- Cameras
{
	init_camera                 :: proc(camera: ^Camera, is_perspective: bool, size: f32, pixel_width, pixel_height: int, make_framebuffer := false)
	delete_camera               :: proc(camera: Camera)
	PUSH_CAMERA                 :: proc(camera: ^Camera) -> ^Camera
	push_camera_non_deferred    :: proc(camera: ^Camera) -> ^Camera
	pop_camera                  :: proc(old_camera: ^Camera)
	camera_prerender            :: proc(camera: ^Camera)
	update_camera_pixel_size    :: proc(using camera: ^Camera, new_width: f32, new_height: f32)
	construct_view_matrix       :: proc(camera: ^Camera) -> Mat4
	construct_projection_matrix :: proc(camera: ^Camera) -> Mat4
	construct_rendermode_projection_matrix :: proc(camera: ^Camera) -> Mat4
}

--- Textures
{
	create_texture        :: proc(w, h: int, gpu_format: gpu.Internal_Color_Format, pixel_format: gpu.Pixel_Data_Format, element_type: gpu.Texture2D_Data_Type, initial_data: ^u8 = nil, texture_target := gpu.Texture_Target.Texture2D) -> Texture
	delete_texture        :: proc(texture: Texture)
	draw_texture          :: proc(texture: Texture, pixel1: Vec2, pixel2: Vec2, color := Colorf{1, 1, 1, 1})
	write_texture_to_file :: proc(filepath: string, texture: Texture)
}

--- Framebuffers
{
	default_framebuffer_settings :: proc() -> Framebuffer_Settings
	create_framebuffer     :: proc(width, height: int) -> Framebuffer
	delete_framebuffer           :: proc(framebuffer: Framebuffer)
}

--- Models
{
	add_mesh_to_model      :: proc(model: ^Model, vertices: []$Vertex_Type, indices: []u32) -> int
	remove_mesh_from_model :: proc(model: ^Model, idx: int)
	update_mesh            :: proc(model: ^Model, idx: int, vertices: []$Vertex_Type, indices: []u32)
	delete_model           :: proc(model: Model)
	draw_model             :: proc(model: Model, position: Vec3, scale: Vec3, rotation: Quat, texture: Texture, color: Colorf, depth_test: bool)
}

--- Rendermodes
{
	rendermode_world :: proc()
	rendermode_unit  :: proc()
	rendermode_pixel :: proc()
}

--- Helpers
{
	create_cube_model :: proc() -> Model
	create_quad_model :: proc() -> Model

	get_mouse_world_position        :: proc(camera: ^Camera, cursor_unit_position: Vec2) -> Vec3
	get_mouse_direction_from_camera :: proc(camera: ^Camera, cursor_unit_position: Vec2) -> Vec3

	world_to_viewport :: proc(position: Vec3, camera: ^Camera) -> Vec3
	world_to_pixel    :: proc(a: Vec3, camera: ^Camera, pixel_width: f32, pixel_height: f32) -> Vec3
	world_to_unit     :: proc(a: Vec3, camera: ^Camera) -> Vec3

	unit_to_pixel    :: proc(a: Vec3, pixel_width: f32, pixel_height: f32) -> Vec3
	unit_to_viewport :: proc(a: Vec3) -> Vec3

	pixel_to_viewport :: proc(a: Vec3, pixel_width: f32, pixel_height: f32) -> Vec3
	pixel_to_unit     :: proc(a: Vec3, pixel_width: f32, pixel_height: f32) -> Vec3

	viewport_to_pixel :: proc(a: Vec3, pixel_width: f32, pixel_height: f32) -> Vec3
	viewport_to_unit  :: proc(a: Vec3) -> Vec3
}

*/

current_framebuffer: Framebuffer;

//
// Camera
//

Camera :: struct {
    is_perspective: bool,

    // orthographic -> size in world units from center of screen to top of screen
    // perspective  -> fov
    size: f32,

    near_plane: f32,
    far_plane:  f32,

    clear_color: Colorf,

    position: Vec3,
    rotation: Quat,
	view_matrix: Mat4, // note(josh): do not move or rotate the camera during rendering since we cache the view matrix at the start of rendering

    pixel_width: f32,
    pixel_height: f32,
    aspect: f32,

    framebuffer: Framebuffer,
    bloom_ping_pong_framebuffers: Maybe([2]Framebuffer),

    current_rendermode: Rendermode,
    draw_mode: gpu.Draw_Mode,
    polygon_mode: gpu.Polygon_Mode,

    // render data for this frame
	render_queue: [dynamic]Draw_Command_3D,
	im_draw_commands: [dynamic]Draw_Command_2D,

	point_light_positions:   []Vec3,
	point_light_colors:      []Vec4,
	point_light_intensities: []f32,
	num_point_lights: i32,

	sun_direction: Vec3,
	sun_color:     Vec4,
	sun_intensity: f32,
	sun_rotation:  Quat,
	shadow_map_cameras: Maybe([NUM_SHADOW_MAPS]^Camera),

	auto_resize_framebuffer: bool,

	skybox: Maybe(Texture),
}

Render_Settings :: struct {
	gamma: f32,
	exposure: f32,
	bloom_threshhold: f32,
	bloom_blur_passes: i32,
	bloom_range: i32,
	bloom_weight: f32,
}

render_settings: Render_Settings;

MAX_LIGHTS :: 100;
NUM_SHADOW_MAPS :: 4;
SHADOW_MAP_DIM :: 2048;

init_camera :: proc(camera: ^Camera, is_perspective: bool, size: f32, pixel_width, pixel_height: int, framebuffer := Framebuffer{}) {
	framebuffer := framebuffer;

    camera.is_perspective = is_perspective;
    camera.size = size;
    camera.near_plane = 0.01;
    camera.far_plane = 1000;
    camera.position = Vec3{};
    camera.rotation = Quat{0, 0, 0, 1};
    camera.draw_mode = .Triangles;
    camera.polygon_mode = .Fill;
    camera.clear_color = {0, 0, 0, 1};
    camera.pixel_width = cast(f32)pixel_width;
    camera.pixel_height = cast(f32)pixel_height;
    camera.aspect = camera.pixel_width / camera.pixel_height;

    if framebuffer.fbo == 0 {
    	// put valid values into cameras without real framebuffers
    	framebuffer.width = pixel_width;
    	framebuffer.height = pixel_height;
    }
    assert(camera.framebuffer.fbo == 0);
    camera.framebuffer = framebuffer;

    camera.point_light_positions   = make([]Vec3, MAX_LIGHTS);
	camera.point_light_colors      = make([]Vec4, MAX_LIGHTS);
	camera.point_light_intensities = make([]f32,  MAX_LIGHTS);
}

delete_camera :: proc(camera: ^Camera) { // note(josh): does NOT free the camera you pass in
    if camera.framebuffer.fbo != 0 {
        delete_framebuffer(camera.framebuffer);
    }
    destroy_bloom(camera);
    destroy_shadow_maps(camera);
}

setup_bloom :: proc(camera: ^Camera) {
	assert(camera.bloom_ping_pong_framebuffers == nil);

	fbos: [2]Framebuffer;
	for _, idx in fbos {
		// todo(josh): apparently these should use Linear and Clamp_To_Border, not Nearest and Repeat as is hardcoded in create_framebuffer
		fbos[idx] = create_framebuffer(cast(int)camera.pixel_width, cast(int)camera.pixel_height, 1);
	}
	camera.bloom_ping_pong_framebuffers = fbos;
}
destroy_bloom :: proc(camera: ^Camera) {
	if fbos, ok := getval(&camera.bloom_ping_pong_framebuffers); ok {
    	for fbo in fbos do delete_framebuffer(fbo);
    }
    camera.bloom_ping_pong_framebuffers = {};
}

setup_shadow_maps :: proc(camera: ^Camera) {
	assert(camera.shadow_map_cameras == nil);

	shadow_maps: [NUM_SHADOW_MAPS]^Camera;
	for idx in 0..<NUM_SHADOW_MAPS {
		cascade_camera := new(Camera);
		init_camera(cascade_camera, false, 10, SHADOW_MAP_DIM, SHADOW_MAP_DIM, create_framebuffer(SHADOW_MAP_DIM, SHADOW_MAP_DIM, 0));
		cascade_camera.near_plane = 0.01;
		cascade_camera.clear_color = {1, 1, 1, 1}; // todo(josh): what the heck should this be?
		shadow_maps[idx] = cascade_camera;
	}
	camera.shadow_map_cameras = shadow_maps;
}
destroy_shadow_maps :: proc(camera: ^Camera) {
	if shadow_maps, ok := getval(&camera.shadow_map_cameras); ok {
		for cascade_camera in shadow_maps {
	    	if cascade_camera != nil {
	    		delete_camera(cascade_camera);
	    		free(cascade_camera);
	    	}
	    }
	}
}

@(deferred_out=pop_camera)
PUSH_CAMERA :: proc(camera: ^Camera) -> ^Camera {
	return push_camera_non_deferred(camera);
}

push_camera_non_deferred :: proc(camera: ^Camera) -> ^Camera {
	old_camera := main_camera;
	main_camera = camera;

	push_framebuffer_non_deferred(&camera.framebuffer, camera.auto_resize_framebuffer);
	camera.pixel_width  = cast(f32)camera.framebuffer.width;
    camera.pixel_height = cast(f32)camera.framebuffer.height;
    camera.aspect = camera.pixel_width / camera.pixel_height;

	gpu.enable(gpu.Capabilities.Blend);
	gpu.blend_func(.Src_Alpha, .One_Minus_Src_Alpha);

	gpu.set_clear_color(camera.clear_color);
	gpu.clear_screen(.Color_Buffer | .Depth_Buffer);

	camera.view_matrix = construct_rendermode_view_matrix(camera);

	return old_camera;
}

pop_camera :: proc(old_camera: ^Camera) {
	main_camera = old_camera;

	if main_camera != nil {
		gpu.viewport(0, 0, cast(int)main_camera.pixel_width, cast(int)main_camera.pixel_height);
		pop_framebuffer(main_camera.framebuffer);
	}
	else {
		pop_framebuffer({});
	}
}

// todo(josh): it's probably slow that we dont cache matrices at all :grimacing:
construct_rendermode_view_matrix :: proc(camera: ^Camera) -> Mat4 {
	#partial
	switch camera.current_rendermode {
		case .World: {
			return construct_view_matrix(camera);
		}
		case .Viewport_World: {
			view_matrix := identity(Mat4);
		    rotation_matrix := quat_to_mat4(inverse(camera.rotation));
		    view_matrix = mul(rotation_matrix, view_matrix);
		    return view_matrix;
		}
		case: {
			return identity(Mat4);
		}
	}

	unreachable();
	return {};
}

construct_view_matrix :: proc(camera: ^Camera) -> Mat4 {
	view_matrix := translate(identity(Mat4), -camera.position);
	rotation := camera.rotation;
    rotation_matrix := quat_to_mat4(inverse(rotation));
    view_matrix = mul(rotation_matrix, view_matrix);
    return view_matrix;
}

construct_rendermode_projection_matrix :: proc(camera: ^Camera) -> Mat4 {
    switch camera.current_rendermode {
        case .World: {
            return construct_projection_matrix(camera);
        }
        case .Unit: {
            unit := mat4_scale(identity(Mat4), Vec3{2, 2, 0});
            unit = translate(unit, Vec3{-1, -1, 0});
            return unit;
        }
        case .Pixel: {
            pixel := mat4_scale(identity(Mat4), Vec3{1.0 / camera.pixel_width, 1.0 / camera.pixel_height, 0});
            pixel = mat4_scale(pixel, 2);
            pixel = translate(pixel, Vec3{-1, -1, 0});
            return pixel;
        }
        case .Aspect: {
        	aspect := mat4_scale(identity(Mat4), Vec3{1/camera.aspect, 1, 0});
            return aspect;
        }
        case .Viewport_World: {
            return construct_projection_matrix(camera);
        }
        case: panic(tprint(camera.current_rendermode));
    }

    unreachable();
    return {};
}

construct_projection_matrix :: proc(camera: ^Camera) -> Mat4 {
    if camera.is_perspective {
        return perspective(to_radians(camera.size), camera.aspect, camera.near_plane, camera.far_plane);
    }
    else {
        top    : f32 =  1 * camera.size;
        bottom : f32 = -1 * camera.size;
        left   : f32 = -1 * camera.aspect * camera.size;
        right  : f32 =  1 * camera.aspect * camera.size;
        return ortho3d(left, right, bottom, top, camera.near_plane, camera.far_plane);
    }
}

camera_render :: proc(camera: ^Camera, user_render_proc: proc(f32)) {
	TIMED_SECTION();


	// pre-render
	gpu.log_errors(#procedure);
	PUSH_CAMERA(camera);

	set_sun_data(Quat{0, 0, 0, 1}, Colorf{0, 0, 0, 0}, 0);

	if user_render_proc != nil {
		user_render_proc(lossy_delta_time);
		gpu.log_errors(#procedure);
	}



	// draw shadow maps
	shadow_cascade_positions := [NUM_SHADOW_MAPS+1]f32{0, 20, 40, 150, 1000};
	assert(NUM_SHADOW_MAPS == 4);
	light_matrices: [NUM_SHADOW_MAPS]Mat4;
	if shadow_maps, ok := getval(&camera.shadow_map_cameras); ok {
		TIMED_SECTION("camera_render.shadow_maps");

		for shadow_map_camera, map_idx in shadow_maps {
			assert(shadow_map_camera != nil);

			// todo(josh): I think I am depending on undefined behaviour here since I modify frustum corners but I don't think Bill has decided if array literals on the stack will live in the data segment and then do a copy or actually construct the array with instructions. If he chooses to make it live in the data segment then modifying it is dangerous
			// todo(josh): I think I am depending on undefined behaviour here since I modify frustum corners but I don't think Bill has decided if array literals on the stack will live in the data segment and then do a copy or actually construct the array with instructions. If he chooses to make it live in the data segment then modifying it is dangerous
			// todo(josh): I think I am depending on undefined behaviour here since I modify frustum corners but I don't think Bill has decided if array literals on the stack will live in the data segment and then do a copy or actually construct the array with instructions. If he chooses to make it live in the data segment then modifying it is dangerous
			frustum_corners := [8]Vec3 {
				{-1,  1, -1},
				{ 1,  1, -1},
				{ 1, -1, -1},
				{-1, -1, -1},
				{-1,  1,  1},
				{ 1,  1,  1},
				{ 1, -1,  1},
				{-1, -1,  1},
			};



			// calculate sub-frustum for this cascade
			cascade_proj := perspective(to_radians(camera.size), camera.aspect, camera.near_plane + shadow_cascade_positions[map_idx], min(camera.far_plane, camera.near_plane + shadow_cascade_positions[map_idx+1]));
			cascade_view := construct_rendermode_view_matrix(camera);
			cascade_viewport_to_world := mat4_inverse(mul(cascade_proj, cascade_view));

			transform_point :: proc(matrix: Mat4, pos: Vec3) -> Vec3 {
				pos4 := to_vec4(pos);
				pos4.w = 1;
				pos4 = mul(matrix, pos4);
				if pos4.w != 0 do pos4 /= pos4.w;
				return to_vec3(pos4);
			}



			// calculate center point and radius of frustum
			center_point: Vec3;
			for _, idx in frustum_corners {
				frustum_corners[idx] = transform_point(cascade_viewport_to_world, frustum_corners[idx]);
				center_point += frustum_corners[idx];
			}
			center_point /= len(frustum_corners);



			// todo(josh): this radius changes very slightly as the camera rotates around for some reason. this shouldn't be happening and I believe it's causing the flickering
			// todo(josh): this radius changes very slightly as the camera rotates around for some reason. this shouldn't be happening and I believe it's causing the flickering
			// todo(josh): this radius changes very slightly as the camera rotates around for some reason. this shouldn't be happening and I believe it's causing the flickering
			// note(josh): @ShadowFlickerHack hacked around the problem by clamping the radius to an int. pretty shitty, should investigate a proper solution
			// note(josh): @ShadowFlickerHack hacked around the problem by clamping the radius to an int. pretty shitty, should investigate a proper solution
			// note(josh): @ShadowFlickerHack hacked around the problem by clamping the radius to an int. pretty shitty, should investigate a proper solution
			radius := cast(f32)cast(int)(length(frustum_corners[0] - frustum_corners[6]) / 2 + 1.0);



			light_rotation := camera.sun_rotation;
			light_direction := quaternion_forward(light_rotation);

			texels_per_unit := SHADOW_MAP_DIM / (radius * 2);
			scale_matrix := identity(Mat4);
			scale_matrix = mat4_scale(scale_matrix, Vec3{texels_per_unit, texels_per_unit, texels_per_unit});
			scale_matrix = mul(scale_matrix, quat_to_mat4(inverse(light_rotation)));

			// draw_debug_box(center_point, Vec3{1/texels_per_unit, 1/texels_per_unit, 1/texels_per_unit}, COLOR_RED, light_rotation);
			center_point_texel_space := transform_point(scale_matrix, center_point);
			center_point_texel_space.x = round(center_point_texel_space.x);
			center_point_texel_space.y = round(center_point_texel_space.y);
			center_point_texel_space.z = round(center_point_texel_space.z);
			center_point = transform_point(mat4_inverse(scale_matrix), center_point_texel_space);
			// if map_idx == 0 do draw_debug_box(center_point, Vec3{1/texels_per_unit, 1/texels_per_unit, 1/texels_per_unit}, COLOR_GREEN, light_rotation, false);


			// position the shadow camera looking at that point
			shadow_map_camera.position = center_point - light_direction * radius;
			shadow_map_camera.rotation = light_rotation;
			shadow_map_camera.size = radius;
			shadow_map_camera.far_plane = radius * 2;

			// render scene from perspective of sun
			PUSH_CAMERA(shadow_map_camera);

			depth_shader := get_shader("shadow");
			gpu.use_program(depth_shader);

			PUSH_RENDERMODE(.World);

			for cmd in camera.render_queue {
				if on_render_object != nil do on_render_object(cmd.userdata);
				execute_draw_command(cmd);
			}

			light_matrices[map_idx] = mul(construct_rendermode_projection_matrix(shadow_map_camera), shadow_map_camera.view_matrix);
		}
	}

	// draw scene for real
	{
		TIMED_SECTION("camera_render.draw_for_real");

		if skybox_texture, ok := getval(&camera.skybox); ok {
			PUSH_GPU_ENABLED(.Cull_Face, false);
			skybox_shader := get_shader("skybox");
			gpu.use_program(skybox_shader);
			PUSH_RENDERMODE(.Viewport_World);
			draw_model(wb_skybox_model, {}, {1, 1, 1}, {0, 0, 0, 1}, skybox_texture^, {1, 1, 1, 1}, true);
			gpu.clear_screen(.Depth_Buffer);
		}

		PUSH_RENDERMODE(.World);

		for _, idx in camera.render_queue {
			cmd := &camera.render_queue[idx];

			shader := cmd.shader;
			gpu.use_program(shader);

			flush_lights(camera, shader);

			if shadow_maps, ok := getval(&camera.shadow_map_cameras); ok {
				gpu.uniform_float_array(shader, "cascade_distances", shadow_cascade_positions[1:]);

				for shadow_map, map_idx in shadow_maps {
					add_texture_binding(cmd, tprint_cstring("shadow_maps[", map_idx, "]"), shadow_map.framebuffer.depth_texture);
				}
				gpu.uniform_mat4_array(shader, "cascade_light_space_matrices", light_matrices[:]);
			}

			if visualize_shadow_cascades do gpu.uniform_int(shader, "visualize_shadow_cascades", 1);
			else                         do gpu.uniform_int(shader, "visualize_shadow_cascades", 0);

			if skybox_texture, ok := getval(&camera.skybox); ok {
				add_texture_binding(cmd, "skybox_texture", skybox_texture^);
			}

			// issue draw call
			if on_render_object != nil do on_render_object(cmd.userdata);
			execute_draw_command(cmd^);
		}
	}

	// todo(josh): ambient occlusion

	if post_render_proc != nil {
		post_render_proc();
	}

	// do bloom
	if bloom_fbos, ok := getval(&camera.bloom_ping_pong_framebuffers); ok {
		TIMED_SECTION("camera_render.bloom");

		for fbo in bloom_fbos {
			PUSH_FRAMEBUFFER(&fbo, true);
			gpu.clear_screen(.Color_Buffer | .Depth_Buffer);
		}

		horizontal := true;
		first := true;
		last_bloom_fbo: Maybe(Framebuffer);
		shader_blur := get_shader("blur");
		gpu.use_program(shader_blur);
		gpu.uniform_int  (shader_blur, "bloom_range",  render_settings.bloom_range);
		gpu.uniform_float(shader_blur, "bloom_weight", render_settings.bloom_weight);

		for i in 0..<render_settings.bloom_blur_passes {
			PUSH_FRAMEBUFFER(&bloom_fbos[cast(int)horizontal], true);
			gpu.uniform_int(shader_blur, "horizontal", cast(i32)horizontal);
			if first {
				draw_texture(camera.framebuffer.textures[1], {0, 0}, {1, 1});
			}
			else {
				bloom_fbo := bloom_fbos[cast(int)(!horizontal)];
				draw_texture(bloom_fbo.textures[0], {0, 0}, {1, 1});
				last_bloom_fbo = bloom_fbo;
			}
			horizontal = !horizontal;
			first = false;
		}

		if last_bloom_fbo, ok := getval(&last_bloom_fbo); ok {
			shader_bloom := get_shader("bloom");
			gpu.use_program(shader_bloom);
			bind_texture_to_shader("bloom_texture", last_bloom_fbo.textures[0], 1, shader_bloom);
			draw_texture(camera.framebuffer.textures[0], {0, 0}, {1, 1});

			if visualize_bloom_texture {
				gpu.use_program(get_shader("default"));
				draw_texture(last_bloom_fbo.textures[0], {256, 0} / platform.current_window_size, {512, 256} / platform.current_window_size);
			}
		}
	}

	// todo(josh): should this be before bloom?
	im_flush(camera);

	debug_geo_flush();

	// visualize depth buffer
	if visualize_shadow_texture {
		if shadow_maps, ok := getval(&camera.shadow_map_cameras); ok {
			if length(camera.sun_direction) > 0 {
				gpu.use_program(get_shader("depth"));
				for shadow_map, map_idx in shadow_maps {
					draw_texture(shadow_map.framebuffer.depth_texture, {256 * cast(f32)map_idx, 0} / platform.current_window_size, {256 * (cast(f32)map_idx+1), 256} / platform.current_window_size);
				}
			}
		}
	}



	if _pooled_draw_commands_taken_out != len(camera.render_queue) {
		logf("LEAK!!! Somebody pulled a draw command out of the pool and didn't submit or return it!!! taken out: %, returned: %", _pooled_draw_commands_taken_out, len(camera.render_queue));
	}
	for cmd in camera.render_queue {
		return_draw_command_to_pool(cmd);
	}
	clear(&camera.render_queue);



	// clear lights
	camera.num_point_lights = 0;

	if done_postprocessing_proc != nil {
		done_postprocessing_proc();
	}
}

flush_lights :: proc(camera: ^Camera, shader: gpu.Shader_Program) {
	if camera.num_point_lights > 0 {
		gpu.uniform_vec3_array(shader,  "point_light_positions",   camera.point_light_positions[:camera.num_point_lights]);
		gpu.uniform_vec4_array(shader,  "point_light_colors",      camera.point_light_colors[:camera.num_point_lights]);
		gpu.uniform_float_array(shader, "point_light_intensities", camera.point_light_intensities[:camera.num_point_lights]);
	}
	gpu.uniform_int(shader, "num_point_lights", camera.num_point_lights);

	if len(camera.sun_direction) > 0 {
		gpu.uniform_vec3(shader,  "sun_direction", camera.sun_direction);
		gpu.uniform_vec4(shader,  "sun_color",     camera.sun_color);
		gpu.uniform_float(shader, "sun_intensity", camera.sun_intensity);
	}
}

do_camera_movement :: proc(camera: ^Camera, dt: f32, normal_speed: f32, fast_speed: f32, slow_speed: f32) {
	speed := normal_speed;

	if platform.get_input(.Left_Shift) {
		speed = fast_speed;
	}
	else if platform.get_input(.Left_Alt) {
		speed = slow_speed;
	}

    up      := quaternion_up(camera.rotation);
    forward := quaternion_forward(camera.rotation);
	right   := quaternion_right(camera.rotation);

    down := -up;
    back := -forward;
    left := -right;

	if platform.get_input(.E) { camera.position += up      * speed * dt; }
	if platform.get_input(.Q) { camera.position += down    * speed * dt; }
	if platform.get_input(.W) { camera.position += forward * speed * dt; }
	if platform.get_input(.S) { camera.position += back    * speed * dt; }
	if platform.get_input(.A) { camera.position += left    * speed * dt; }
	if platform.get_input(.D) { camera.position += right   * speed * dt; }

	rotate_vector: Vec3;
	if platform.get_input(.Mouse_Right) {
		MOUSE_ROTATE_SENSITIVITY :: 0.1;
		delta := platform.mouse_screen_position_delta;
		delta *= MOUSE_ROTATE_SENSITIVITY;
		rotate_vector = Vec3{delta.y, -delta.x, 0};

		camera.size -= platform.mouse_scroll * camera.size * 0.05;
	}
	else {
		KEY_ROTATE_SENSITIVITY :: 1;
		if platform.get_input(.J) do rotate_vector.y =  KEY_ROTATE_SENSITIVITY;
		if platform.get_input(.L) do rotate_vector.y = -KEY_ROTATE_SENSITIVITY;
		if platform.get_input(.I) do rotate_vector.x =  KEY_ROTATE_SENSITIVITY;
		if platform.get_input(.K) do rotate_vector.x = -KEY_ROTATE_SENSITIVITY;
	}

	// rotate quat by degrees
	x := axis_angle(Vec3{1, 0, 0}, to_radians(rotate_vector.x));
	y := axis_angle(Vec3{0, 1, 0}, to_radians(rotate_vector.y));
	z := axis_angle(Vec3{0, 0, 1}, to_radians(rotate_vector.z));
	result := mul(y, camera.rotation);
	result  = mul(result, x);
	result  = mul(result, z);
	result  = quat_norm(result);
	camera.rotation = result;
}

@(deferred_out=pop_polygon_mode)
PUSH_POLYGON_MODE :: proc(mode: gpu.Polygon_Mode) -> gpu.Polygon_Mode {
	old := main_camera.polygon_mode;
	main_camera.polygon_mode = mode;
	return old;
}

pop_polygon_mode :: proc(old_mode: gpu.Polygon_Mode) {
	main_camera.polygon_mode = old_mode;
}

@(deferred_out=pop_gpu_enabled)
PUSH_GPU_ENABLED :: proc(cap: gpu.Capabilities, enable: bool) -> (gpu.Capabilities, bool) {
	old := gpu.is_enabled(cap);
	if enable do gpu.enable(cap);
	else      do gpu.disable(cap);
	return cap, old;
}
pop_gpu_enabled :: proc(old: gpu.Capabilities, enable: bool) {
	if enable do gpu.enable(old);
	else      do gpu.disable(old);
}



Material :: struct {
	metallic:  f32 `imgui_range="0":"1"`,
	roughness: f32 `imgui_range="0":"1"`,
	ao:        f32 `imgui_range="0":"1"`,
}

flush_material :: proc(material: Material, shader: gpu.Shader_Program) {
	gpu.uniform_float(shader, "material.metallic",  material.metallic);
	gpu.uniform_float(shader, "material.roughness", material.roughness);
	gpu.uniform_float(shader, "material.ao",        material.ao);
}

push_point_light :: proc(position: Vec3, color: Colorf, intensity: f32) {
	if main_camera.num_point_lights >= MAX_LIGHTS {
		logln("Too many lights! The max is ", MAX_LIGHTS);
		return;
	}

	main_camera.point_light_positions  [main_camera.num_point_lights] = position;
	main_camera.point_light_colors     [main_camera.num_point_lights] = transmute(Vec4)color;
	main_camera.point_light_intensities[main_camera.num_point_lights] = intensity;
	main_camera.num_point_lights += 1;
}

set_sun_data :: proc(rotation: Quat, color: Colorf, intensity: f32) {
	main_camera.sun_direction  = quaternion_forward(rotation);
	main_camera.sun_color      = transmute(Vec4)color;
	main_camera.sun_intensity  = intensity;
	main_camera.sun_rotation   = rotation;
}



//
// Textures
//

Texture :: struct {
    gpu_id: gpu.TextureId,

    width, height, depth: int,

    target: gpu.Texture_Target,
    format: gpu.Pixel_Data_Format,
    element_type: gpu.Texture2D_Data_Type,
}

create_texture_2d :: proc(ww, hh: int, gpu_format: gpu.Internal_Color_Format, initial_data_format := gpu.Pixel_Data_Format.RGBA, initial_data_element_type := gpu.Texture2D_Data_Type.Unsigned_Byte, initial_data: ^u8 = nil) -> Texture {
	texture := gpu.gen_texture();
	gpu.bind_texture_2d(texture);

	gpu.tex_image_2d(.Texture2D, 0, gpu_format, cast(i32)ww, cast(i32)hh, 0, initial_data_format, initial_data_element_type, initial_data);
	gpu.tex_parameteri(.Texture2D, .Mag_Filter, .Nearest);
	gpu.tex_parameteri(.Texture2D, .Min_Filter, .Nearest);

	return Texture{texture, ww, hh, 1, .Texture2D, initial_data_format, initial_data_element_type};
}

create_texture_3d :: proc(ww, hh, dd: int, gpu_format: gpu.Internal_Color_Format, initial_data_format := gpu.Pixel_Data_Format.RGBA, initial_data_element_type := gpu.Texture2D_Data_Type.Unsigned_Byte, initial_data: ^u8 = nil) -> Texture {
	texture := gpu.gen_texture();
	gpu.bind_texture_3d(texture);
	gpu.tex_image_3d(.Texture3D, 0, gpu_format, cast(i32)ww, cast(i32)hh, cast(i32)dd, 0, initial_data_format, initial_data_element_type, initial_data);
	gpu.tex_parameteri(.Texture3D, .Min_Filter, .Linear);
	gpu.tex_parameteri(.Texture3D, .Min_Filter, .Linear);
	gpu.tex_parameteri(.Texture3D, .Wrap_S, .Repeat);
	gpu.tex_parameteri(.Texture3D, .Wrap_T, .Repeat);
	gpu.tex_parameteri(.Texture3D, .Wrap_R, .Repeat);
	return Texture{texture, ww, hh, dd, .Texture3D, initial_data_format, initial_data_element_type};
}

create_cubemap :: proc() -> Texture {
	texture := gpu.gen_texture();
	gpu.bind_texture(.Texture_Cube_Map, texture);
	gpu.tex_parameteri(.Texture_Cube_Map, .Mag_Filter, .Linear);
	gpu.tex_parameteri(.Texture_Cube_Map, .Min_Filter, .Linear);
	gpu.tex_parameteri(.Texture_Cube_Map, .Wrap_S, .Clamp_To_Edge);
	gpu.tex_parameteri(.Texture_Cube_Map, .Wrap_T, .Clamp_To_Edge);
	gpu.tex_parameteri(.Texture_Cube_Map, .Wrap_R, .Clamp_To_Edge);
	return Texture{texture, 0, 0, 1, .Texture_Cube_Map, {}, {}};
}

set_cubemap_textures :: proc(cubemap: ^Texture, ww, hh: int, right, left, top, bottom, back, front: ^byte, gpu_format: gpu.Internal_Color_Format, initial_data_format := gpu.Pixel_Data_Format.RGBA, initial_data_element_type := gpu.Texture2D_Data_Type.Unsigned_Byte) {
	assert(cubemap.target == .Texture_Cube_Map);
	faces := [6]^byte{right, left, top, bottom, back, front};
	for face, i in faces {
		gpu.tex_image_2d(.Cube_Map_Positive_X + gpu.Texture_Target(i), 0, gpu_format, cast(i32)ww, cast(i32)hh, 0, initial_data_format, initial_data_element_type, face);
	}
	cubemap.width = ww;
	cubemap.height = hh;
	cubemap.format = initial_data_format;
	cubemap.element_type = initial_data_element_type;
}

delete_texture :: proc(texture: Texture) {
	gpu.delete_texture(texture.gpu_id);
}

draw_texture :: proc(texture: Texture, unit0: Vec2, unit1: Vec2, color := Colorf{1, 1, 1, 1}) {
	PUSH_RENDERMODE(.Unit);
	center := to_vec3(lerp(unit0, unit1, f32(0.5)));
	size   := to_vec3(unit1 - unit0);
	draw_model(wb_quad_model, center, size, {0, 0, 0, 1}, texture, color, false);
}

bind_texture_to_shader :: proc(name: cstring, texture: Texture, texture_unit: int, shader: gpu.Shader_Program) {
	gpu.active_texture(u32(texture_unit));
	gpu.uniform_int(shader, name, i32(texture_unit));
	#partial
	switch texture.target {
		case .Texture2D:        gpu.bind_texture(.Texture2D,        texture.gpu_id); gpu.uniform_int(shader, tprint_cstring("has_", name), 1); // todo(josh): handle multiple textures per model
		case .Texture3D:        gpu.bind_texture(.Texture3D,        texture.gpu_id); gpu.uniform_int(shader, tprint_cstring("has_", name), 1); // todo(josh): handle multiple textures per model
		case .Texture_Cube_Map: gpu.bind_texture(.Texture_Cube_Map, texture.gpu_id); gpu.uniform_int(shader, tprint_cstring("has_", name), 1); // todo(josh): handle multiple textures per model
		case cast(gpu.Texture_Target)0: gpu.uniform_int(shader, tprint_cstring("has_", name), 0); // todo(josh): should this be an error/warning?
		case: panic(tprint(texture.target));
	}
}

tprint_cstring :: proc(args: ..any) -> cstring {
	sb := strings.make_builder(context.temp_allocator);
	sbprint(&sb, ..args);
	sbprint(&sb, '\x00');
	str := strings.to_string(sb);
	cstr := strings.unsafe_string_to_cstring(str);
	return cstr;
}

write_texture_to_file :: proc(filepath: string, texture: Texture) {
	assert(texture.target == .Texture2D, "Not sure if this is an error, delete this if it isn't");
	data := make([]u8, 4 * texture.width * texture.height);
	defer delete(data);
	gpu.bind_texture_2d(texture.gpu_id);
	gpu.get_tex_image(texture.target, .RGBA, .Unsigned_Byte, &data[0]);
	stb.write_png(filepath, texture.width, texture.height, 4, data, 4 * texture.width);
	gpu.log_errors(#procedure);
}



//
// Framebuffers
//

Framebuffer :: struct {
    fbo: gpu.FBO,
    textures: []Texture,
    depth_texture: Texture,

    width, height: int,
    attachments: []gpu.Framebuffer_Attachment,

    texture_format: gpu.Internal_Color_Format,
    data_format: gpu.Pixel_Data_Format,
    data_element_format: gpu.Texture2D_Data_Type,
}

create_framebuffer :: proc(width, height: int, num_color_buffers := 1, texture_format := gpu.Internal_Color_Format.RGBA16F, data_format := gpu.Pixel_Data_Format.RGBA, data_element_format := gpu.Texture2D_Data_Type.Unsigned_Byte, loc := #caller_location) -> Framebuffer {
	fbo := gpu.gen_framebuffer();
	gpu.bind_fbo(fbo);

	textures: [dynamic]Texture;
	attachments: [dynamic]gpu.Framebuffer_Attachment;
	assert(num_color_buffers <= 32, tprint(num_color_buffers, " is more than ", gpu.Framebuffer_Attachment.Color31));
	for buf_idx in 0..<num_color_buffers {
		texture := gpu.gen_texture();
		append(&textures, Texture{texture, width, height, 1, .Texture2D, data_format, data_element_format});
		gpu.bind_texture_2d(texture);

		// todo(josh): is 16-bit float enough?
		gpu.tex_image_2d(.Texture2D, 0, texture_format, cast(i32)width, cast(i32)height, 0, data_format, data_element_format, nil);
		gpu.tex_parameteri(.Texture2D, .Mag_Filter, .Nearest);
		gpu.tex_parameteri(.Texture2D, .Min_Filter, .Nearest);
		gpu.tex_parameteri(.Texture2D, .Wrap_S, .Clamp_To_Border);
		gpu.tex_parameteri(.Texture2D, .Wrap_T, .Clamp_To_Border);

		attachment := cast(gpu.Framebuffer_Attachment)(cast(u32)gpu.Framebuffer_Attachment.Color0 + cast(u32)buf_idx);
		gpu.framebuffer_texture2d(cast(gpu.Framebuffer_Attachment)attachment, texture);

		append(&attachments, attachment);
	}

	depth_texture_id := gpu.gen_texture();
	gpu.bind_texture_2d(depth_texture_id);
	depth_texture := Texture{depth_texture_id, width, height, 1, .Texture2D, .Depth_Component, .Float};

	gpu.tex_image_2d(.Texture2D, 0, .Depth_Component, cast(i32)width, cast(i32)height, 0, .Depth_Component, .Float, nil);
	gpu.tex_parameteri(.Texture2D, .Mag_Filter, .Nearest);
	gpu.tex_parameteri(.Texture2D, .Min_Filter, .Nearest);
	gpu.tex_parameteri(.Texture2D, .Wrap_S, .Clamp_To_Border);
	gpu.tex_parameteri(.Texture2D, .Wrap_T, .Clamp_To_Border);
	c := Colorf{1, 1, 1, 1};
	gpu.tex_parameterfv(.Texture2D, .Texture_Border_Color, &c.r);

	gpu.framebuffer_texture2d(.Depth, depth_texture_id);

	if num_color_buffers > 0 {
		gpu.draw_buffers(attachments[:]);
	}
	else {
		gpu.draw_buffer(0);
		gpu.read_buffer(0);
	}



	gpu.assert_framebuffer_complete();
	gpu.bind_texture_2d(0);
	gpu.bind_rbo(0);
	gpu.bind_fbo(0);

	framebuffer := Framebuffer{fbo, textures[:], depth_texture, width, height, attachments[:], texture_format, data_format, data_element_format};
	return framebuffer;
}

delete_framebuffer :: proc(framebuffer: Framebuffer) {
	for t in framebuffer.textures {
		delete_texture(t);
	}
	delete_texture(framebuffer.depth_texture);
	delete(framebuffer.textures);
	delete(framebuffer.attachments);
	gpu.delete_fbo(framebuffer.fbo);
}

@(deferred_out=pop_framebuffer)
PUSH_FRAMEBUFFER :: proc(framebuffer: ^Framebuffer, auto_resize_framebuffer: bool) -> Framebuffer {
	return push_framebuffer_non_deferred(framebuffer, auto_resize_framebuffer);
}

push_framebuffer_non_deferred :: proc(framebuffer: ^Framebuffer, auto_resize_framebuffer: bool) -> Framebuffer {
	if auto_resize_framebuffer {
	    if framebuffer.width != cast(int)platform.current_window_width || framebuffer.height != cast(int)platform.current_window_height {
	        logln("Rebuilding framebuffer...");

		    if framebuffer.fbo != 0 {
		    	texture_format := framebuffer.texture_format;
				data_format := framebuffer.data_format;
				data_element_format := framebuffer.data_element_format;
				num_color_buffers := len(framebuffer.attachments);
		        delete_framebuffer(framebuffer^);
		        framebuffer^ = create_framebuffer(cast(int)(platform.current_window_width+0.5), cast(int)(platform.current_window_height+0.5), num_color_buffers, texture_format, data_format, data_element_format);
		    }
		    else {
	    	    framebuffer.width  = cast(int)(platform.current_window_width+0.5);
		        framebuffer.height = cast(int)(platform.current_window_height+0.5);
		    }
	    }
	}

	old := current_framebuffer;
	gpu.bind_fbo(framebuffer.fbo); // note(josh): can be 0
	current_framebuffer = framebuffer^;
	gpu.viewport(0, 0, cast(int)framebuffer.width, cast(int)framebuffer.height);

	return old;
}

pop_framebuffer :: proc(old_framebuffer: Framebuffer) {
	gpu.bind_fbo(old_framebuffer.fbo); // note(josh): can be 0
	current_framebuffer = old_framebuffer;
	gpu.viewport(0, 0, cast(int)old_framebuffer.width, cast(int)old_framebuffer.height);
}



//
// Models and Meshes
//

BONES_PER_VERTEX :: 4;

Model :: struct {
    name: string,
    meshes: [dynamic]Mesh,
    center: Vec3,
    size: Vec3,
    has_bones: bool,
}

Mesh :: struct {
    vao: gpu.VAO,
    vbo: gpu.VBO,
    ibo: gpu.EBO,
    vertex_type: ^rt.Type_Info,

    index_count:  int,
    vertex_count: int,

    center: Vec3,
    vmin: Vec3,
    vmax: Vec3,

	skin: Skinned_Mesh,
}

Skinned_Mesh :: struct {
	bones: []Mesh_Bone,
    nodes: [dynamic]Mesh_Node, // todo(josh): pretty sure we @Leak these and any data inside them, pls fix!
	name_mapping: map[string]int,
	global_inverse: Mat4,

    parent_node: ^Mesh_Node, // points into array above
}

Mesh_Bone :: struct {
	offset: Mat4,
	name: string,
}

Mesh_Node :: struct {
    name: string,
    local_transform: Mat4,

    parent: ^Mesh_Node,
    children: [dynamic]^Mesh_Node,
}

Vertex2D :: struct {
	position: Vec2,
	tex_coord: Vec2,
	color: Colorf,
}

Vertex3D :: struct {
	position: Vec3,
	tex_coord: Vec3,
	color: Colorf,
	normal: Vec3,

	bone_indicies: [BONES_PER_VERTEX]u32,
	bone_weights: [BONES_PER_VERTEX]f32,
}

add_mesh_to_model :: proc(model: ^Model, vertices: []$Vertex_Type, indices: []u32 = {}, skin: Skinned_Mesh = {}, loc := #caller_location) -> int {
	vao := gpu.gen_vao();
	vbo := gpu.gen_vbo();
	ibo := gpu.gen_ebo();

	center: Vec3;
	vmin := Vec3{max(f32), max(f32), max(f32)};
	vmax := Vec3{min(f32), min(f32), min(f32)};

	for v in vertices {
		pos := to_vec3(v.position);
		center += pos;

		if pos.x < vmin.x do vmin.x = pos.x;
		if pos.y < vmin.y do vmin.y = pos.y;
		if pos.z < vmin.z do vmin.z = pos.z;
		if pos.x > vmax.x do vmax.x = pos.x;
		if pos.y > vmax.y do vmax.y = pos.y;
		if pos.z > vmax.z do vmax.z = pos.z;
	}
	if len(vertices) > 0 {
		center /= cast(f32)len(vertices);
	}

	idx := len(model.meshes);
	mesh := Mesh{vao, vbo, ibo, type_info_of(Vertex_Type), len(indices), len(vertices), center, vmin, vmax, skin};
	append(&model.meshes, mesh, loc);

	update_mesh(model, idx, vertices, indices);
	update_model(model);

	return idx;
}

remove_mesh_from_model :: proc(model: ^Model, idx: int, loc := #caller_location) {
	assert(idx < len(model.meshes));
	mesh := model.meshes[idx];
	_internal_delete_mesh(mesh, loc);
	unordered_remove(&model.meshes, idx);
	update_model(model);
}

update_mesh :: proc(model: ^Model, idx: int, vertices: []$Vertex_Type, indices: []u32) {
	assert(idx < len(model.meshes));
	mesh := &model.meshes[idx];

	gpu.bind_vao(mesh.vao);

	gpu.bind_vbo(mesh.vbo);
	gpu.buffer_vertices(vertices);

	gpu.bind_ibo(mesh.ibo);
	gpu.buffer_elements(indices);

	gpu.bind_vao(0);

	mesh.vertex_type  = type_info_of(Vertex_Type);
	mesh.index_count  = len(indices);
	mesh.vertex_count = len(vertices);
}

update_model :: proc(model: ^Model) {
	center: Vec3;
	vmin := Vec3{max(f32), max(f32), max(f32)};
	vmax := Vec3{min(f32), min(f32), min(f32)};
	for mesh in model.meshes {
		center += mesh.center;
		if mesh.vmin.x < vmin.x do vmin.x = mesh.vmin.x;
		if mesh.vmin.y < vmin.y do vmin.y = mesh.vmin.y;
		if mesh.vmin.z < vmin.z do vmin.z = mesh.vmin.z;
		if mesh.vmax.x > vmax.x do vmax.x = mesh.vmax.x;
		if mesh.vmax.y > vmax.y do vmax.y = mesh.vmax.y;
		if mesh.vmax.z > vmax.z do vmax.z = mesh.vmax.z;
	}
	if len(model.meshes) > 0 {
		center /= cast(f32)len(model.meshes);
	}
	model.center = center;
	model.size = vmax - vmin;
}

delete_model :: proc(model: Model, loc := #caller_location) {
	for mesh in model.meshes {
		_internal_delete_mesh(mesh, loc);
	}
	delete(model.meshes);
}

_internal_delete_mesh :: proc(mesh: Mesh, loc := #caller_location) {
	gpu.delete_vao(mesh.vao);
	gpu.delete_buffer(mesh.vbo);
	gpu.delete_buffer(mesh.ibo);
	gpu.log_errors(#procedure, loc);

	for b in mesh.skin.bones {
		delete(b.name);
	}
	delete(mesh.skin.bones);
	for name in mesh.skin.name_mapping {
		delete(name);
	}
	delete(mesh.skin.name_mapping);
}

draw_model :: proc(model: Model,
				   position: Vec3,
				   scale: Vec3,
				   rotation: Quat,
				   texture: Texture,
				   color: Colorf,
				   depth_test: bool,
				   anim_state := Model_Animation_State{},
				   loc := #caller_location) {

	gpu.polygon_mode(.Front_And_Back, main_camera.polygon_mode);

	// projection matrix
	projection_matrix := construct_rendermode_projection_matrix(main_camera);

	// view matrix
	view_matrix := construct_rendermode_view_matrix(main_camera);

	// model_matrix
	model_p := translate(identity(Mat4), position);
	model_s := mat4_scale(identity(Mat4), scale);
	model_r := quat_to_mat4(rotation);
	model_matrix := mul(mul(model_p, model_r), model_s);

	// shader stuff
	program := gpu.get_current_shader();

	gpu.active_texture0();
	gpu.uniform_int(program, "texture_handle", 0);
	gpu.uniform_int(program, "has_texture_handle", texture.gpu_id != 0 ? 1 : 0);

	gpu.uniform_vec3(program, "camera_position", main_camera.position);
	gpu.uniform_vec4(program, "mesh_color", transmute(Vec4)color);
	gpu.uniform_float(program, "bloom_threshhold", render_settings.bloom_threshhold);

	gpu.uniform_mat4(program, "model_matrix",      &model_matrix);
	gpu.uniform_mat4(program, "view_matrix",       &view_matrix);
	gpu.uniform_mat4(program, "projection_matrix", &projection_matrix);

	gpu.uniform_vec3(program, "position", position);
	gpu.uniform_vec3(program, "scale", scale);

	gpu.uniform_float(program, "time", time);

	PUSH_GPU_ENABLED(.Depth_Test, depth_test);
	gpu.log_errors(#procedure);

	for mesh, i in model.meshes {
		gpu.bind_vao(mesh.vao);
		gpu.bind_vbo(mesh.vbo);
		gpu.bind_ibo(mesh.ibo);

		// todo(josh): handle multiple textures per model
		#partial
		switch texture.target {
			case .Texture2D:        gpu.bind_texture(.Texture2D,        texture.gpu_id);
			case .Texture3D:        gpu.bind_texture(.Texture3D,        texture.gpu_id);
			case .Texture_Cube_Map: gpu.bind_texture(.Texture_Cube_Map, texture.gpu_id);
			case cast(gpu.Texture_Target)0:
			case: panic(tprint(texture.target));
		}

		gpu.log_errors(#procedure);

		if len(anim_state.mesh_states) > i {

			mesh_state := anim_state.mesh_states[i];
			for _, i in mesh_state.state {
				s := mesh_state.state[i];
				bone := strings.unsafe_string_to_cstring(tprint("bones[", i, "]\x00"));
				gpu.uniform_matrix4fv(program, bone, 1, false, &s[0][0]);
			}
		}

		// todo(josh): I don't think we need this since VAOs store the VertexAttribPointer calls
		gpu.set_vertex_format(mesh.vertex_type);
		gpu.log_errors(#procedure);

		if mesh.index_count > 0 {
			gpu.draw_elephants(main_camera.draw_mode, mesh.index_count, .Unsigned_Int, nil);
		}
		else {
			gpu.draw_arrays(main_camera.draw_mode, 0, mesh.vertex_count);
		}
	}
}



//
// Draw Commands
//

Draw_Command_3D :: struct {
	model: Model,
	color: Colorf,
	position: Vec3,
	scale: Vec3,
	rotation: Quat,
	depth_test: bool,

	shader: gpu.Shader_Program,
	material: Material,
	texture_bindings: [dynamic]Texture_Binding,
	uniform_bindings: [dynamic]Uniform_Binding,
	anim_state: Model_Animation_State,

	userdata: rawptr,
}
Texture_Binding :: struct {
	name: cstring,
	texture: Texture,
}
Uniform_Binding :: struct {
	name: cstring,
	value: union {
		f32,
		i32,
		Vec2,
		Vec3,
		Vec4,
		Mat4,
		Colorf,

		[]f32,
		[]i32,
		[]Vec2,
		[]Vec3,
		[]Vec4,
		[]Mat4,
		[]Colorf,
	},
}

add_texture_binding :: proc(cmd: ^Draw_Command_3D, name: cstring, texture: Texture, loc := #caller_location) {
	append(&cmd.texture_bindings, Texture_Binding{name, texture}, loc);
}

add_uniform_binding :: proc(cmd: ^Draw_Command_3D, name: cstring, value: $T, loc := #caller_location) {
	append(&cmd.uniform_bindings, Uniform_Binding{name, value}, loc);
}

_pooled_draw_commands: [dynamic]Draw_Command_3D;
_pooled_draw_commands_taken_out: int;

get_pooled_draw_command :: proc() -> Draw_Command_3D {
	_pooled_draw_commands_taken_out += 1;
	if len(_pooled_draw_commands) > 0 {
		return pop(&_pooled_draw_commands);
	}
	return Draw_Command_3D{};
}

create_draw_command :: proc(model: Model, shader: gpu.Shader_Program, position, scale: Vec3, rotation: Quat, color: Colorf, material: Material, texture: Texture = {}, loc := #caller_location) -> Draw_Command_3D {
    cmd := get_pooled_draw_command();
    cmd.depth_test = true;
    cmd.model = model;
    cmd.shader = shader;
    add_texture_binding(&cmd, "texture_handle", texture);
    cmd.material = material;
    cmd.position = position;
    cmd.scale = scale;
    cmd.rotation = rotation;
    cmd.color = color;
    return cmd;
}

submit_draw_command :: proc(cmd: Draw_Command_3D) {
	append(&main_camera.render_queue, cmd);
}

return_draw_command_to_pool :: proc(cmd: Draw_Command_3D) {
	// put the texture and uniform bindings back in the pool
	_pooled_draw_commands_taken_out -= 1;
	assert(_pooled_draw_commands_taken_out >= 0);
	pooled_cmd: Draw_Command_3D;
	pooled_cmd.texture_bindings = cmd.texture_bindings; clear(&pooled_cmd.texture_bindings);
	pooled_cmd.uniform_bindings = cmd.uniform_bindings; clear(&pooled_cmd.uniform_bindings);
	append(&_pooled_draw_commands, pooled_cmd);
}

execute_draw_command :: proc(using cmd: Draw_Command_3D, loc := #caller_location) {
	// note(josh): DO NOT TOUCH cmd.shader in this procedure because it could be shadows or the proper shader. use `bound_shader` defined below
	// note(josh): DO NOT TOUCH cmd.shader in this procedure because it could be shadows or the proper shader. use `bound_shader` defined below
	// note(josh): DO NOT TOUCH cmd.shader in this procedure because it could be shadows or the proper shader. use `bound_shader` defined below

	bound_shader := gpu.get_current_shader();

	for binding, idx in texture_bindings {
		bind_texture_to_shader(binding.name, binding.texture, idx, bound_shader);
	}
	for _, bidx in uniform_bindings {
		binding := &uniform_bindings[bidx];
		switch value in &binding.value {
			case f32:      gpu.uniform_float(bound_shader, binding.name, value);
			case i32:      gpu.uniform_int  (bound_shader, binding.name, value);
			case Vec2:     gpu.uniform_vec2 (bound_shader, binding.name, value);
			case Vec3:     gpu.uniform_vec3 (bound_shader, binding.name, value);
			case Vec4:     gpu.uniform_vec4 (bound_shader, binding.name, value);
			case Mat4:     gpu.uniform_mat4 (bound_shader, binding.name, &value);
			case Colorf:   gpu.uniform_vec4 (bound_shader, binding.name, transmute(Vec4)value);

			case []f32:    gpu.uniform_float_array(bound_shader, binding.name, value);
			case []i32:    gpu.uniform_int_array  (bound_shader, binding.name, value);
			case []Vec2:   gpu.uniform_vec2_array (bound_shader, binding.name, value);
			case []Vec3:   gpu.uniform_vec3_array (bound_shader, binding.name, value);
			case []Vec4:   gpu.uniform_vec4_array (bound_shader, binding.name, value);
			case []Mat4:   gpu.uniform_mat4_array (bound_shader, binding.name, value[:]);
			case []Colorf: gpu.uniform_vec4_array (bound_shader, binding.name, transmute([]Vec4)value[:]);
			case: panic(tprint(binding.value));
		}
	}

	flush_material(cmd.material, bound_shader);

	// model_matrix
	model_p := translate(identity(Mat4), position);
	model_s := mat4_scale(identity(Mat4), scale);
	model_r := quat_to_mat4(rotation);
	model_matrix := mul(mul(model_p, model_r), model_s);

	gpu.uniform_vec3(bound_shader, "camera_position", main_camera.position);

	gpu.uniform_float(bound_shader, "bloom_threshhold", render_settings.bloom_threshhold);

	gpu.uniform_mat4(bound_shader, "model_matrix",      &model_matrix);
	gpu.uniform_mat4(bound_shader, "view_matrix",       &main_camera.view_matrix);

	rendermode_matrix := construct_rendermode_projection_matrix(main_camera);
	gpu.uniform_mat4(bound_shader, "projection_matrix", &rendermode_matrix);

	gpu.uniform_vec3(bound_shader, "position", position);
	gpu.uniform_vec3(bound_shader, "scale", scale);
	gpu.uniform_vec4(bound_shader, "mesh_color", transmute(Vec4)color);

	gpu.uniform_float(bound_shader, "time", time);

	PUSH_GPU_ENABLED(.Depth_Test, depth_test);
	gpu.polygon_mode(.Front_And_Back, main_camera.polygon_mode);
	gpu.log_errors(#procedure);

	for mesh, i in model.meshes {
		gpu.bind_vao(mesh.vao);
		gpu.bind_vbo(mesh.vbo);
		gpu.bind_ibo(mesh.ibo);
		gpu.log_errors(#procedure);

		if len(anim_state.mesh_states) > i {
			gpu.uniform_int(bound_shader, "do_animation", 1);
			mesh_state := anim_state.mesh_states[i];
			for _, i in mesh_state.state {
				s := mesh_state.state[i];
				bone := strings.unsafe_string_to_cstring(tprint("bones[", i, "]\x00"));
				gpu.uniform_matrix4fv(bound_shader, bone, 1, false, &s[0][0]);
			}
		}
		else {
			gpu.uniform_int(bound_shader, "do_animation", 0);
		}

		// todo(josh): I don't think we need this since VAOs store the VertexAttribPointer calls
		gpu.set_vertex_format(mesh.vertex_type);
		gpu.log_errors(#procedure);

		if mesh.index_count > 0 {
			gpu.draw_elephants(main_camera.draw_mode, mesh.index_count, .Unsigned_Int, nil);
		}
		else {
			gpu.draw_arrays(main_camera.draw_mode, 0, mesh.vertex_count);
		}
	}
}



//
// Rendermodes
//

// todo(josh): maybe do a push/pop rendermode kinda thing?
// todo(josh): we should _definitely_ do a push/pop rendermode kinda thing. have had bugs related to this a few times now

Rendermode :: enum {
    World,
    Unit,
    Pixel,
    Aspect,
    Viewport_World,
}

@(deferred_out=pop_rendermode)
PUSH_RENDERMODE :: proc(r: Rendermode) -> Rendermode {
	old := main_camera.current_rendermode;
	main_camera.current_rendermode = r;
	return old;
}
pop_rendermode :: proc(r: Rendermode) {
	main_camera.current_rendermode = r;
}



//
// Debug
//

Debug_Line :: struct {
	a, b: Vec3,
	color: Colorf,
	rotation: Quat,
	rendermode: Rendermode,
	depth_test: bool,
}
Debug_Cube :: struct {
	position: Vec3,
	scale: Vec3,
	rotation: Quat,
	color: Colorf,
	rendermode: Rendermode,
	depth_test: bool,
}

// todo(josh): test all rendermodes for debug lines/boxes
draw_debug_line :: proc(a, b: Vec3, color: Colorf, rendermode := Rendermode.World, depth_test := true) {
	append(&debug_lines, Debug_Line{a, b, color, {0, 0, 0, 1}, rendermode, depth_test});
}

draw_debug_box :: proc(position, scale: Vec3, color: Colorf, rotation := Quat{0, 0, 0, 1}, rendermode := Rendermode.World, depth_test := true) {
	append(&debug_cubes, Debug_Cube{position, scale, rotation, color, rendermode, depth_test});
}

debug_geo_flush :: proc() {
	PUSH_POLYGON_MODE(.Line);
	PUSH_GPU_ENABLED(.Cull_Face, false);

	gpu.use_program(get_shader("default"));
	for line in debug_lines {
		PUSH_RENDERMODE(line.rendermode);
		verts: [3]Vertex3D;
		verts[0] = Vertex3D{line.a, {}, line.color, {}, {}, {}};
		verts[1] = Vertex3D{line.b, {}, line.color, {}, {}, {}};
		verts[2] = Vertex3D{line.b, {}, line.color, {}, {}, {}};
		update_mesh(&debug_line_model, 0, verts[:], []u32{});
		draw_model(debug_line_model, {}, {1, 1, 1}, {0, 0, 0, 1}, {}, {1, 1, 1, 1}, line.depth_test);
	}

	for cube in debug_cubes {
		PUSH_RENDERMODE(cube.rendermode);
		draw_model(wb_cube_model, cube.position, cube.scale, cube.rotation, {}, cube.color, cube.depth_test);
	}
}




//
// Helpers
//

get_mouse_world_position :: proc(camera: ^Camera, cursor_unit_position: Vec2) -> Vec3 {
	cursor_viewport_position := to_vec4((cursor_unit_position * 2) - Vec2{1, 1});
	cursor_viewport_position.w = 1;

	cursor_viewport_position.z = 0.1; // just some way down the frustum, will behave differently for opengl and directx

	inv := mat4_inverse(mul(construct_projection_matrix(camera), construct_view_matrix(camera)));

	cursor_world_position4 := mul(inv, cursor_viewport_position);
	if cursor_world_position4.w != 0 do cursor_world_position4 /= cursor_world_position4.w;
	cursor_world_position := to_vec3(cursor_world_position4);

	return cursor_world_position;
}

get_mouse_direction_from_camera :: proc(camera: ^Camera, cursor_unit_position: Vec2) -> Vec3 {
	if !camera.is_perspective {
		return quaternion_forward(camera.rotation);
	}

	cursor_world_position := get_mouse_world_position(camera, cursor_unit_position);
	cursor_direction := norm(cursor_world_position - camera.position);
	return cursor_direction;
}

world_to_viewport :: proc(position: Vec3, camera: ^Camera) -> Vec3 {
	proj := construct_projection_matrix(camera);
	mv := mul(proj, construct_view_matrix(camera));
	result := mul(mv, Vec4{position.x, position.y, position.z, 1});
	if result.w > 0 do result /= result.w;
	return Vec3{result.x, result.y, result.z};
}
world_to_pixel :: proc(a: Vec3, camera: ^Camera, pixel_width: f32, pixel_height: f32) -> Vec3 {
	result := world_to_viewport(a, camera);
	result = viewport_to_pixel(result, pixel_width, pixel_height);
	return result;
}
world_to_unit :: proc(a: Vec3, camera: ^Camera) -> Vec3 {
	result := world_to_viewport(a, camera);
	result = viewport_to_unit(result);
	return result;
}
world_to_aspect :: proc(a: Vec3, camera: ^Camera) -> Vec3 {
	vp := world_to_viewport(a, camera);
	result := viewport_to_aspect(vp, camera.aspect);
	return result;
}

unit_to_pixel :: proc(a: Vec3, pixel_width: f32, pixel_height: f32) -> Vec3 {
	result := a * Vec3{pixel_width, pixel_height, 1};
	return result;
}
unit_to_viewport :: proc(a: Vec3) -> Vec3 {
	result := (a * 2) - Vec3{1, 1, 0};
	return result;
}
unit_to_aspect :: proc(a: Vec3, camera: ^Camera) -> Vec3 {
	result := (a * 2) - Vec3{1, 1, 0};
	result.x *= camera.aspect;
	return result;
}

pixel_to_viewport :: proc(a: Vec3, pixel_width: f32, pixel_height: f32) -> Vec3 {
	a := a;
	a /= Vec3{pixel_width/2, pixel_height/2, 1};
	a -= Vec3{1, 1, 0};
	return a;
}
pixel_to_unit :: proc(a: Vec3, pixel_width: f32, pixel_height: f32) -> Vec3 {
	a := a;
	a /= Vec3{pixel_width, pixel_height, 1};
	return a;
}

viewport_to_world :: proc(camera: ^Camera, viewport_position: Vec3) -> Vec3 {
	viewport_position4 := to_vec4(viewport_position);

	inv := mat4_inverse(mul(construct_projection_matrix(camera), construct_view_matrix(camera)));

	viewport_position4 = mul(inv, viewport_position4);
	if viewport_position4.w != 0 do viewport_position4 /= viewport_position4.w;
	world_position := to_vec3(viewport_position4);

	return world_position;
}
viewport_to_pixel :: proc(a: Vec3, pixel_width: f32, pixel_height: f32) -> Vec3 {
	a := a;
	a += Vec3{1, 1, 0};
	a *= Vec3{pixel_width/2, pixel_height/2, 0};
	a.z = 0;
	return a;
}
viewport_to_unit :: proc(a: Vec3) -> Vec3 {
	a := a;
	a += Vec3{1, 1, 0};
	a /= 2;
	a.z = 0;
	return a;
}
viewport_to_aspect :: proc(a: Vec3, aspect: f32) -> Vec3 {
	a := a;
	a.x *= aspect;
	a.z = 0;
	return a;
}