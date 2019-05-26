package workbench

using import          "core:math"
using import          "core:fmt"
      import          "core:sort"
      import          "core:strings"
      import          "core:mem"
      import          "core:os"

      import          "gpu"
using import wbmath   "math"
using import          "types"
using import          "basic"

      import          "external/stb"
      import          "external/glfw"
      import          "external/imgui"

DEVELOPER :: true;

unit_to_pixel_matrix:  Mat4;
unit_to_viewport_matrix:  Mat4;

pixel_to_world_matrix: Mat4;
pixel_to_viewport_matrix: Mat4;

viewport_to_pixel_matrix: Mat4;
viewport_to_unit_matrix:  Mat4;



wb_camera: gpu.Camera;
current_camera: ^gpu.Camera;

//
// Debug
//

// Line_Segment :: struct {
// 	a, b: Vec3,
// 	color: Colorf,
// 	rendermode: Rendermode_Proc,
// }

// debug_vertices: [dynamic]Draw_Command;

// push_debug_vertex :: inline proc(rendermode: Rendermode_Proc, a: Vec3, color: Colorf) {
// 	v := Buffered_Vertex{0, len(debug_vertices), a, {}, color, rendermode, shader_rgba, {}, false, full_screen_scissor_rect()};
// 	append(&debug_vertices, v);
// }

// push_debug_line :: inline proc(rendermode: Rendermode_Proc, a, b: Vec3, color: Colorf) {
// 	push_debug_vertex(rendermode, a, color);
// 	push_debug_vertex(rendermode, b, color);
// }

// push_debug_box :: proc{push_debug_box_min_max, push_debug_box_points};
// push_debug_box_min_max :: inline proc(rendermode: Rendermode_Proc, min, max: Vec3, color: Colorf) {
// 	push_debug_line(rendermode, Vec3{min.x, min.y, min.z}, Vec3{min.x, max.y, max.z}, color);
// 	push_debug_line(rendermode, Vec3{min.x, max.y, max.z}, Vec3{max.x, max.y, max.z}, color);
// 	push_debug_line(rendermode, Vec3{max.x, max.y, max.z}, Vec3{max.x, min.y, min.z}, color);
// 	push_debug_line(rendermode, Vec3{max.x, min.y, min.z}, Vec3{min.x, min.y, min.z}, color);
// }
// push_debug_box_points :: inline proc(rendermode: Rendermode_Proc, a, b, c, d: Vec3, color: Colorf) {
// 	push_debug_line(rendermode, a, b, color);
// 	push_debug_line(rendermode, b, c, color);
// 	push_debug_line(rendermode, c, d, color);
// 	push_debug_line(rendermode, d, a, color);
// }

// draw_debug_lines :: inline proc() {
// 	assert(len(debug_vertices) % 2 == 0);
// 	depth_test := odingl.IsEnabled(odingl.DEPTH_TEST);
// 	odingl.Disable(odingl.DEPTH_TEST);
// 	im_draw_flush(odingl.LINES, debug_vertices[:]);
// 	if depth_test == odingl.TRUE {
// 		odingl.Enable(odingl.DEPTH_TEST);
// 	}
// }

shader_rgba: gpu.Shader_Program;
shader_text: gpu.Shader_Program;
shader_rgba_3d: gpu.Shader_Program;

shader_texture_unlit: gpu.Shader_Program;
shader_texture_lit:   gpu.Shader_Program;

shader_fbo:     gpu.Shader_Program;

wb_fbo: gpu.Framebuffer;

init_draw :: proc(opengl_version_major, opengl_version_minor: int) {
	gpu.init_gpu_opengl(opengl_version_major, opengl_version_minor, proc(p: rawptr, name: cstring) {
			(cast(^rawptr)p)^ = rawptr(glfw.GetProcAddress(name));
		});

	im_mesh = gpu.create_mesh([]gpu.Vertex3D{}, []u32{}, "im_mesh");

	ok: bool;
	shader_rgba, ok    = gpu.load_shader_text(SHADER_RGBA_VERT, SHADER_RGBA_FRAG);
	assert(ok);
	shader_texture_unlit, ok = gpu.load_shader_text(SHADER_TEXTURE_UNLIT_VERT, SHADER_TEXTURE_UNLIT_FRAG);
	assert(ok);
	shader_texture_lit, ok = gpu.load_shader_text(SHADER_TEXTURE_LIT_VERT, SHADER_TEXTURE_LIT_FRAG);
	assert(ok);
	shader_text, ok    = gpu.load_shader_text(SHADER_TEXT_VERT, SHADER_TEXT_FRAG);
	assert(ok);
	shader_rgba_3d, ok = gpu.load_shader_text(SHADER_RGBA_3D_VERT, SHADER_RGBA_3D_FRAG);

	register_debug_program("Rendering", _debug_rendering, nil);

	wb_fbo = gpu.create_framebuffer(1920, 1080);
}

update_draw :: proc() {
	if !debug_window_open do return;
	if imgui.begin("Scene View") {
	    window_size := imgui.get_window_size();

		imgui.image(rawptr(uintptr(wb_fbo.texture)),
			imgui.Vec2{window_size.x - 10, window_size.y - 30},
			imgui.Vec2{0,1},
			imgui.Vec2{1,0});
	} imgui.end();
}

_clear_render_buffers :: proc() {
	// clear(&debug_vertices);
	clear(&buffered_draw_commands);
}

draw_render :: proc() {
	gpu.log_errors(#procedure);
	num_draw_calls = 0;

	gpu.enable(gpu.Capabilities.Blend);
	gpu.blend_func(gpu.Blend_Factors.Src_Alpha, gpu.Blend_Factors.One_Minus_Src_Alpha);
	if current_camera.is_perspective {
		gpu.enable(gpu.Capabilities.Depth_Test); // note(josh): @DepthTest: fucks with the sorting of 2D stuff
		gpu.clear(gpu.Clear_Flags.Color_Buffer | gpu.Clear_Flags.Depth_Buffer);
	}
	else {
		gpu.disable(gpu.Capabilities.Depth_Test); // note(josh): @DepthTest: fucks with the sorting of 2D stuff
		gpu.clear(gpu.Clear_Flags.Color_Buffer);
	}

	gpu.viewport(0, 0, cast(int)current_window_width, cast(int)current_window_height);

	{
		if debug_window_open do gpu.bind_framebuffer(&wb_fbo);
		defer if debug_window_open do gpu.unbind_framebuffer();

		im_draw_flush(buffered_draw_commands[:]);
	}

	gpu.set_clear_color(Colorf{0,0,0,0});

	imgui_render(true);

	clear_lights();
}


debugging_rendering: bool;
_debug_rendering :: proc(_: rawptr) {
	imgui.checkbox("Debug Rendering", &debugging_rendering);
	if debugging_rendering {
		current_camera.draw_mode = .Lines;
	}
	else {
		current_camera.draw_mode = .Triangles;
	}
}