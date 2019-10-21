package workbench

using import          "core:math"
using import          "core:fmt"
      import          "core:sort"
      import          "core:strings"
      import          "core:mem"
      import          "core:os"

      import          "platform"
      import          "gpu"
using import wbmath   "math"
using import          "types"
using import          "logging"
using import          "basic"

      import          "external/stb"
      import          "external/glfw"
      import          "external/imgui"

//
// API
//

// Debug

Debug_Line :: struct {
	a, b: Vec3,
	color: Colorf,
	rotation: Quat,
}

// todo(josh): support all rendermodes for debug lines, right now we force rendermode_world
draw_debug_line :: proc(a, b: Vec3, color: Colorf) {
	append(&debug_lines, Debug_Line{a, b, color, {0, 0, 0, 1}});
}

Debug_Cube :: struct {
	position: Vec3,
	scale: Vec3,
	rotation: Quat,
	color: Colorf,
}

draw_debug_box :: proc(position, scale: Vec3, color: Colorf, rotation := Quat{0, 0, 0, 1}) {
	append(&debug_cubes, Debug_Cube{position, scale, rotation, color});
}



//
// Internal
//

screen_camera: Camera;
wb_camera: Camera;
current_camera: ^Camera;

wb_cube_model: Model;
wb_quad_model: Model;

shader_rgba_2d: gpu.Shader_Program;
shader_text: gpu.Shader_Program;
shader_rgba_3d: gpu.Shader_Program;

shader_texture_unlit: gpu.Shader_Program;
shader_texture_lit: gpu.Shader_Program;

shader_shadow_depth: gpu.Shader_Program;
shader_depth: gpu.Shader_Program;

shader_framebuffer_gamma_corrected: gpu.Shader_Program;

debug_lines: [dynamic]Debug_Line;
debug_cubes: [dynamic]Debug_Cube;
debug_line_model: Model;

debugging_rendering: bool;

SHADOW_MAP_DIM :: 2048;
shadow_map_camera: Camera;

init_draw :: proc(screen_width, screen_height: int) {
	gpu.init(proc(p: rawptr, name: cstring) {
			(cast(^rawptr)p)^ = rawptr(glfw.GetProcAddress(name));
		});

	init_camera(&screen_camera, true, 85, screen_width, screen_height);
	screen_camera.clear_color = {1, 0, 1, 1};
	push_camera_non_deferred(&screen_camera);
	init_camera(&wb_camera, true, 85, screen_width, screen_height, true);
	wb_camera.clear_color = {.1, 0.7, 0.5, 1};

	add_mesh_to_model(&_internal_im_model, []Vertex2D{}, []u32{});

	ok: bool;
	shader_rgba_2d, ok       = gpu.load_shader_text(SHADER_RGBA_2D_VERT, SHADER_RGBA_2D_FRAG);
	assert(ok);
	shader_texture_unlit, ok = gpu.load_shader_text(SHADER_TEXTURE_3D_UNLIT_VERT, SHADER_TEXTURE_3D_UNLIT_FRAG);
	assert(ok);
	shader_texture_lit, ok   = gpu.load_shader_text(SHADER_TEXTURE_3D_LIT_VERT, SHADER_TEXTURE_3D_LIT_FRAG);
	assert(ok);
	shader_text, ok          = gpu.load_shader_text(SHADER_TEXT_VERT, SHADER_TEXT_FRAG);
	assert(ok);
	shader_rgba_3d, ok       = gpu.load_shader_text(SHADER_RGBA_3D_VERT, SHADER_RGBA_3D_FRAG);
	assert(ok);
	shader_shadow_depth, ok  = gpu.load_shader_text(SHADER_SHADOW_VERT, SHADER_SHADOW_FRAG);
	assert(ok);
	shader_depth, ok         = gpu.load_shader_text(SHADER_TEXTURE_3D_UNLIT_VERT, SHADER_DEPTH_FRAG);
	assert(ok);
	shader_framebuffer_gamma_corrected, ok = gpu.load_shader_text(SHADER_FRAMEBUFFER_GAMMA_CORRECTED_VERT, SHADER_FRAMEBUFFER_GAMMA_CORRECTED_FRAG);
	assert(ok);

	wb_cube_model = create_cube_model();
	wb_quad_model = create_quad_model();
	add_mesh_to_model(&debug_line_model, []Vertex3D{}, []u32{});

	init_camera(&shadow_map_camera, false, 10, SHADOW_MAP_DIM, SHADOW_MAP_DIM, false);
	assert(shadow_map_camera.framebuffer.fbo == 0);
	shadow_map_camera.framebuffer = create_framebuffer(SHADOW_MAP_DIM, SHADOW_MAP_DIM, Framebuffer_Settings{.Depth_Component, .Depth_Component, .Float, .Depth, false});
	shadow_map_camera.position = Vec3{0, 5, 0};
	shadow_map_camera.rotation = rotate_quat_by_degrees({0, 0, 0, 1}, Vec3{-45, -45, 0});
	shadow_map_camera.near_plane = 0.01;
	shadow_map_camera.far_plane = 20;
}

update_draw :: proc() {
	clear(&debug_lines);
	clear(&debug_cubes);
	clear(&buffered_draw_commands);

	if debug_window_open {
		if imgui.begin("Scene View") {
		    window_size := imgui.get_window_size();

			imgui.image(rawptr(uintptr(wb_camera.framebuffer.texture.gpu_id)),
				imgui.Vec2{window_size.x - 10, window_size.y - 30},
				imgui.Vec2{0,1},
				imgui.Vec2{1,0});
		} imgui.end();
	}
}

// todo(josh): maybe put this in the Workspace?
post_render_proc: proc();

render_workspace :: proc(workspace: Workspace) {
	gpu.enable(.Cull_Face);

	assert(current_camera == &screen_camera);
	update_camera_pixel_size(&screen_camera, platform.current_window_width, platform.current_window_height);
	camera_prerender(&screen_camera);

	update_camera_pixel_size(&wb_camera, platform.current_window_width, platform.current_window_height);
	camera_prerender(current_camera);

	// this scope is important because of the PUSH_CAMERA() call
	{
		// pre-render
		gpu.log_errors(#procedure);
		num_draw_calls = 0;
		PUSH_CAMERA(&wb_camera);

		if workspace.render != nil {
			workspace.render(lossy_delta_time);
			gpu.log_errors(workspace.name);
		}

		// draw scene to shadow map
		{
			if len(directional_light_directions) > 0 {
				// shadow_map_camera.rotation = degrees_to_quaternion(Vec3{-60, time * 20, 0});
				PUSH_CAMERA(&shadow_map_camera);
				// gpu.cull_face(.Front);
				draw_render_scene(false, true, shader_shadow_depth);
				gpu.cull_face(.Back);
			}
		}

		// draw scene for real
		draw_render_scene(true, false);

		clear_render_scene();

		im_flush();

		if post_render_proc != nil {
			post_render_proc();
		}

		// draw debug lines
		{
			old_draw_mode := current_camera.draw_mode;
			defer current_camera.draw_mode = old_draw_mode;
			current_camera.draw_mode = .Line_Strip;

			// todo(josh): support all rendermodes
			rendermode_world();

			gpu.use_program(shader_rgba_3d);
			for line in debug_lines {
				verts: [2]Vertex3D;
				verts[0] = Vertex3D{line.a, {}, line.color, {}};
				verts[1] = Vertex3D{line.b, {}, line.color, {}};
				update_mesh(&debug_line_model, 0, verts[:], []u32{});
				draw_model(debug_line_model, {}, {1, 1, 1}, {0, 0, 0, 1}, {}, {1, 1, 1, 1}, true);
			}

			for cube in debug_cubes {
				draw_model(wb_cube_model, cube.position, cube.scale, cube.rotation, {}, {1, 1, 1, 1}, true);
			}
		}
	}

	gpu.use_program(shader_framebuffer_gamma_corrected);
	gpu.uniform_float(shader_framebuffer_gamma_corrected, "gamma", 1.0/2.0);
	draw_texture(wb_camera.framebuffer.texture, {0, 0}, {platform.current_window_width, platform.current_window_height});
	// gpu.use_program(shader_depth);
	// draw_texture(shadow_map_camera.framebuffer.texture, {0, 0}, {256, 256});

	imgui_render(true);
}

deinit_draw :: proc() {
	delete_camera(wb_camera);

	delete_model(wb_cube_model);
	delete_model(wb_quad_model);

	// todo(josh): figure out why deleting shaders was causing errors
	// gpu.delete_shader(shader_rgba_3d);
	// gpu.delete_shader(shader_rgba_2d);
	// gpu.delete_shader(shader_text);
	// gpu.delete_shader(shader_texture_unlit);
	// gpu.delete_shader(shader_texture_lit);
	// gpu.delete_shader(shader_shadow_depth);
	// gpu.delete_shader(shader_framebuffer_gamma_corrected);

	delete_model(debug_line_model);
	gpu.deinit();

	delete(debug_lines);
	delete(debug_cubes);
}

draw_rendering_debug_window :: proc() {
	if imgui.begin("Rendering") {
		// todo(josh): make this a combo box
		imgui.checkbox("Debug Rendering", &debugging_rendering);
		if debugging_rendering {
			wb_camera.draw_mode = .Lines;
		}
		else {
			wb_camera.draw_mode = .Triangles;
		}
	}
	imgui.end();
}