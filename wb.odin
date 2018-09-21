package workbench

using import        "core:math"
using import        "core:fmt"
      import        "core:sort"
      import        "core:strings"
      import        "core:mem"
      import        "core:os"
      import        "core:sys/win32"

      import odingl "shared:odin-gl"
      import imgui "shared:odin-imgui"

      import stb    "shared:workbench/stb"
      import        "shared:workbench/glfw"

DEVELOPER :: true;

//
// Game loop stuff
//

Workbench_Init_Args :: struct {
	target_delta_time: f32,
}

// Maybe '_' these?
client_init_proc:   proc(Workbench_Init_Args);
client_update_proc: proc(f32) -> bool;
client_render_proc: proc(f32);

client_target_framerate:  f32;
client_target_delta_time: f32;

// _on_before_client_update := make_event(f32);
// _on_after_client_update  := make_event(f32);
f: f32;
make_simple_window :: proc(window_name: string, window_width, window_height: int, opengl_version_major, opengl_version_minor: int, _init: proc(Workbench_Init_Args), _update: proc(f32) -> bool, _render: proc(f32), _target_framerate: f32) {
	client_init_proc = _init;
	client_update_proc = _update;
	client_render_proc = _render;
	client_target_framerate = _target_framerate;

	_init_glfw(window_name, window_width, window_height, opengl_version_major, opengl_version_minor);
	_init_opengl(opengl_version_major, opengl_version_minor);
	_init_random_number_generator();
	_init_dear_imgui();

	acc: f32;
	client_target_delta_time = cast(f32)1 / client_target_framerate;

	if client_init_proc != nil {
		args := Workbench_Init_Args{client_target_delta_time};
		client_init_proc(args);
	}

	game_loop:
	for !window_should_close(main_window) {
		frame_start := win32.time_get_time();

		last_time := time;
		time = cast(f32)glfw.GetTime();
		lossy_delta_time = time - last_time;
		acc += lossy_delta_time;

		for acc >= client_target_delta_time {
			frame_count += 1;
			acc -= client_target_delta_time;

			imgui_begin_new_frame();

			_update_catalog();
			_update_renderer();
			_update_glfw();
			_update_input();
			_update_tween();
			_update_ui();
			_update_wb_debugger();

			if !client_update_proc(client_target_delta_time) do break game_loop;
			_late_update_ui();

			// call_coroutines();
			if acc >= client_target_delta_time {
				imgui_render(false);
			}
		}

		_wb_render();
		imgui_render(true);

		frame_end := win32.time_get_time();
		glfw.SwapBuffers(main_window);

		odingl.Finish(); // <- what?

		log_gl_errors("after SwapBuffers()");
	}
}

WB_Debug_Data :: struct {
	lossy_delta_time: f32,
	client_target_delta_time: f32,
	client_target_framerate: f32,
}

debug_window_open: bool;
last_saved_dt: f32;

_update_wb_debugger :: proc() {
	if get_key_down(Key.F1) {
		debug_window_open = !debug_window_open;
	}

	if debug_window_open {
		data := WB_Debug_Data{lossy_delta_time, client_target_delta_time, client_target_framerate};
		if imgui.begin("Debug") {
			defer imgui.end();

			imgui_struct(&data, "wb_debug_data");
			imgui.checkbox("Debug UI", &ui_debugging);
		}
	}
}

// Coroutine :: struct {
// 	callback: proc(rawptr, int),
// 	userdata: rawptr,

// 	state: int,
// }

// coroutines: [dynamic]Coroutine;

// start_coroutine :: proc(callback: proc(rawptr, int), userdata: rawptr, loc := #caller_location) -> bool {
// 	if callback == nil {
// 		logln("Nil callback passed to start_coroutine() from: ", loc);
// 		return false;
// 	}

// 	coroutine := Coroutine{callback, userdata, 0};
// 	append(&coroutines, coroutine);
// 	return true;
// }

// call_coroutines :: proc() {
// 	for _, i in coroutines {
// 		coroutine := &coroutines[i];
// 		assert(coroutine.callback != nil);

// 		continue_calling := coroutine.callback(coroutine.userdata, coroutine.state);
// 	}
// }

main :: proc() {
	when DEVELOPER {
		_test_csv();
		_test_alphabetical_notation();
	}
}