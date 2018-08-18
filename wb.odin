package workbench

using import        "core:math"
using import        "core:fmt"
      import        "core:sort"
      import        "core:strings"
      import        "core:mem"
      import        "core:os"
      import        "core:sys/win32"
      import coregl "core:opengl"

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

_on_before_client_update := make_event(f32);
_on_after_client_update  := make_event(f32);

make_simple_window :: proc(window_name: string, window_width, window_height: int, opengl_version_major, opengl_version_minor: int, _init: proc(Workbench_Init_Args), _update: proc(f32) -> bool, _render: proc(f32), _target_framerate: f32) {
	client_init_proc = _init;
	client_update_proc = _update;
	client_render_proc = _render;
	client_target_framerate = _target_framerate;

	_init_glfw(window_name, window_width, window_height, opengl_version_major, opengl_version_minor);
	_init_opengl(opengl_version_major, opengl_version_minor);
	_init_renderer();
	_init_input();
	_init_ui();

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
		last_delta_time = time - last_time;

		acc += last_delta_time;
		old_frame_count := frame_count;

		// todo(josh): should this be above or below update? not sure
		update_tweeners(last_delta_time);

		for acc >= client_target_delta_time {
			frame_count += 1;
			acc -= client_target_delta_time;

			fire_event(&_on_before_client_update, client_target_delta_time);
			if !client_update_proc(client_target_delta_time) do break game_loop;
			fire_event(&_on_after_client_update, client_target_delta_time);
		}

		_renderer_render();

		frame_end := win32.time_get_time();
		glfw.SwapBuffers(main_window);
		odingl.Finish();
		log_gl_errors("after SwapBuffers()");
	}
}

main :: proc() {

}