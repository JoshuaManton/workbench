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
using import          "basic"

      import          "external/stb"
      import          "external/glfw"
      import          "external/imgui"

DEVELOPER :: true;

wb_cube_model: gpu.Model;

shader_rgba_2d: gpu.Shader_Program;
shader_text: gpu.Shader_Program;
shader_rgba_3d: gpu.Shader_Program;

shader_texture_unlit: gpu.Shader_Program;

wb_fbo: gpu.Framebuffer;

debug_lines: [dynamic]Debug_Line;
debug_cubes: [dynamic]Debug_Cube;
debug_line_model: gpu.Model;

init_draw :: proc(opengl_version_major, opengl_version_minor: int) {
	gpu.init_gpu(opengl_version_major, opengl_version_minor, proc(p: rawptr, name: cstring) {
			(cast(^rawptr)p)^ = rawptr(glfw.GetProcAddress(name));
		});

	gpu.add_mesh_to_model(&im_model, "im_model", []gpu.Vertex2D{}, []u32{});

	ok: bool;
	shader_rgba_2d, ok    = gpu.load_shader_text(SHADER_RGBA_2D_VERT, SHADER_RGBA_2D_FRAG);
	assert(ok);
	shader_texture_unlit, ok = gpu.load_shader_text(SHADER_TEXTURE_UNLIT_VERT, SHADER_TEXTURE_UNLIT_FRAG);
	assert(ok);
	shader_text, ok    = gpu.load_shader_text(SHADER_TEXT_VERT, SHADER_TEXT_FRAG);
	assert(ok);
	shader_rgba_3d, ok = gpu.load_shader_text(SHADER_RGBA_3D_VERT, SHADER_RGBA_3D_FRAG);
	assert(ok);

	register_debug_program("Rendering", _debug_rendering, nil);

	wb_fbo = gpu.create_framebuffer(1920, 1080);

	wb_cube_model = create_cube_model();
	gpu.add_mesh_to_model(&debug_line_model, "lines", []gpu.Vertex3D{}, []u32{});
}

update_draw :: proc() {
	if !debug_window_open do return;
	// if imgui.begin("Scene View") {
	//     window_size := imgui.get_window_size();

	// 	imgui.image(rawptr(uintptr(wb_fbo.texture)),
	// 		imgui.Vec2{window_size.x - 10, window_size.y - 30},
	// 		imgui.Vec2{0,1},
	// 		imgui.Vec2{1,0});
	// } imgui.end();
}

_clear_render_buffers :: proc() {
	clear(&debug_lines);
	clear(&debug_cubes);
	clear(&buffered_draw_commands);
}

draw_prerender :: proc() {
	gpu.log_errors(#procedure);
	num_draw_calls = 0;

	gpu.enable(gpu.Capabilities.Blend);
	gpu.blend_func(gpu.Blend_Factors.Src_Alpha, gpu.Blend_Factors.One_Minus_Src_Alpha);
	gpu.set_clear_color(Colorf{0,0,0,0});
	if gpu.current_camera.is_perspective {
		gpu.enable(gpu.Capabilities.Depth_Test); // note(josh): @DepthTest: fucks with the sorting of 2D stuff
		gpu.clear_screen(gpu.Clear_Flags.Color_Buffer | gpu.Clear_Flags.Depth_Buffer);
	}
	else {
		gpu.disable(gpu.Capabilities.Depth_Test); // note(josh): @DepthTest: fucks with the sorting of 2D stuff
		gpu.clear_screen(gpu.Clear_Flags.Color_Buffer);
	}

	gpu.viewport(0, 0, cast(int)platform.current_window_width, cast(int)platform.current_window_height);

	if debug_window_open do gpu.bind_framebuffer(&wb_fbo);
}

draw_postrender :: proc() {
	im_draw_flush(buffered_draw_commands[:]);

	// draw debug lines
	{
		old_draw_mode := gpu.current_camera.draw_mode;
		defer gpu.current_camera.draw_mode = old_draw_mode;
		gpu.current_camera.draw_mode = .Line_Strip;

		// todo(josh): support all rendermodes
		gpu.rendermode_world();

		gpu.use_program(shader_rgba_3d);
		for line in debug_lines {
			verts: [2]gpu.Vertex3D;
			verts[0] = gpu.Vertex3D{line.a, {}, line.color, {}};
			verts[1] = gpu.Vertex3D{line.b, {}, line.color, {}};
			gpu.update_mesh(&debug_line_model, 0, verts[:], []u32{});
			gpu.draw_model(debug_line_model, {}, {1, 1, 1}, {0, 0, 0, 1}, {}, {1, 1, 1, 1}, true);
		}

		for cube in debug_cubes {
			gpu.draw_model(wb_cube_model, cube.position, cube.scale, cube.rotation, {}, {1, 1, 1, 1}, true);
		}
	}


	if debug_window_open do gpu.unbind_framebuffer();
	imgui_render(true);
}


debugging_rendering: bool;
_debug_rendering :: proc(_: rawptr) {
	// todo(josh): make this a combo box
	imgui.checkbox("Debug Rendering", &debugging_rendering);
	if debugging_rendering {
		gpu.current_camera.draw_mode = .Lines;
	}
	else {
		gpu.current_camera.draw_mode = .Triangles;
	}
}



//
// Debug
//

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