package workbench

using import        "core:math"
using import        "core:fmt"
      import        "core:sort"
      import        "core:strings"
      import        "core:mem"
      import        "core:os"
      import        "core:sys/win32"

      import odingl "shared:odin-gl"

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

client_target_framerate: f32;
client_target_delta_time: f32;

// _on_before_client_update := make_event(f32);
// _on_after_client_update  := make_event(f32);

make_simple_window :: proc(window_name: string, window_width, window_height: int, opengl_version_major, opengl_version_minor: int, _init: proc(Workbench_Init_Args), _update: proc(f32) -> bool, _render: proc(f32), _target_framerate: f32) {
	client_init_proc = _init;
	client_update_proc = _update;
	client_render_proc = _render;
	client_target_framerate = _target_framerate;

	_init_glfw(window_name, window_width, window_height, opengl_version_major, opengl_version_minor);
	_init_opengl(opengl_version_major, opengl_version_minor);

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

			_update_glfw(client_target_delta_time);
			_update_input(client_target_delta_time);
			_update_tween(client_target_delta_time);
			_update_ui(client_target_delta_time);
			_update_renderer(client_target_delta_time);

			if !client_update_proc(client_target_delta_time) do break game_loop;
			_ui_debug_screen_update(client_target_delta_time);
			// call_coroutines();
		}

		_wb_render();

		frame_end := win32.time_get_time();
		glfw.SwapBuffers(main_window);
		odingl.Finish();
		log_gl_errors("after SwapBuffers()");
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