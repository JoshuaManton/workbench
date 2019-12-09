package workbench

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
// Internal
//

screen_camera: Camera;
wb_camera: Camera;

wb_cube_model: Model;
wb_quad_model: Model;

debug_lines: [dynamic]Debug_Line;
debug_cubes: [dynamic]Debug_Cube;
debug_line_model: Model;

render_settings: Render_Settings;

Render_Settings :: struct {
	gamma: f32,
	exposure: f32,
	bloom_threshhold: f32,

	visualize_bloom_texture: bool,
	visualize_shadow_texture: bool,
}

init_draw :: proc(screen_width, screen_height: int) {
	gpu.init(proc(p: rawptr, name: cstring) {
			(cast(^rawptr)p)^ = rawptr(glfw.GetProcAddress(name));
		});

	init_camera(&screen_camera, false, 10, screen_width, screen_height);
	screen_camera.clear_color = {1, 0, 1, 1};
	screen_camera.auto_resize_framebuffer = true;

	init_camera(&wb_camera, true, 85, screen_width, screen_height, create_color_framebuffer(screen_width, screen_height, 2));
	setup_bloom(&wb_camera);
	wb_camera.clear_color = {.1, 0.7, 0.5, 1};
	wb_camera.auto_resize_framebuffer = true;

	add_mesh_to_model(&_internal_im_model, []Vertex2D{}, []u32{}, {});

	wb_cube_model = create_cube_model();
	wb_quad_model = create_quad_model();
	add_mesh_to_model(&debug_line_model, []Vertex3D{}, []u32{}, {});

	render_settings = Render_Settings{
		gamma = 2.2,
		exposure = 1,
		bloom_threshhold = 5.0,
	};

	register_debug_program("Rendering", rendering_debug_program, nil);
	register_debug_program("Scene View", scene_view_debug_program, nil);
}
rendering_debug_program :: proc(_: rawptr) {
	if imgui.begin("Rendering") {
		imgui_struct(&wb_camera.draw_mode, "Draw Mode");
		imgui_struct(&wb_camera.polygon_mode, "Polygon Mode");
		imgui_struct(&render_settings, "Render Settings");
	}
	imgui.end();
}
scene_view_debug_program :: proc(_: rawptr) {
	if imgui.begin("Scene View") {
	    window_size := imgui.get_window_size();

		imgui.image(rawptr(uintptr(wb_camera.framebuffer.textures[0].gpu_id)),
			imgui.Vec2{window_size.x - 10, window_size.y - 30},
			imgui.Vec2{0,1},
			imgui.Vec2{1,0});
	}
	imgui.end();
}

update_draw :: proc() {
	clear(&debug_lines);
	clear(&debug_cubes);
	clear(&buffered_draw_commands);
}

// todo(josh): maybe put this in the Workspace?
post_render_proc: proc();
on_render_object: proc(rawptr);

render_workspace :: proc(workspace: Workspace) {
	check_for_file_updates(&wb_catalog);

	gpu.enable(.Cull_Face);

	assert(current_camera == nil);

	PUSH_CAMERA(&screen_camera);

	camera_render(&wb_camera, workspace.render);

	gpu.polygon_mode(.Front_And_Back, .Fill);
	gpu.viewport(0, 0, cast(int)platform.current_window_width, cast(int)platform.current_window_height); // note(josh): this is only needed because pop_framebuffer can't reset the value for viewport() if we are popping to an empty framebuffer (the screen camera)

	// do gamma correction and draw to screen!
	shader_gamma := get_shader(&wb_catalog, "gamma");
	gpu.use_program(shader_gamma);
	gpu.uniform_float(shader_gamma, "gamma", render_settings.gamma);
	gpu.uniform_float(shader_gamma, "exposure", render_settings.exposure);
	draw_texture(wb_camera.framebuffer.textures[0], {0, 0}, {1, 1});

	imgui_render(true);
}

deinit_draw :: proc() {
	delete_camera(&wb_camera);

	// todo(josh): figure out why deleting shaders was causing errors
	// delete_asset_catalog(wb_catalog);

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

	unregister_debug_program("Rendering");
	unregister_debug_program("Scene View");
}