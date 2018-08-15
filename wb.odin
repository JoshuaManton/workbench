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

make_simple_window :: proc(window_name: string, window_width, window_height: int, opengl_version_major, opengl_version_minor: int, init: proc(Workbench_Init_Args), update: proc(f32) -> bool, render: proc(f32), target_framerate: f32) {
	client_init_proc = init;
	client_update_proc = update;
	client_render_proc = render;
	client_target_framerate = target_framerate;

	init_glfw(window_name, window_width, window_height, opengl_version_major, opengl_version_minor);
	init_opengl(opengl_version_major, opengl_version_minor);

	acc: f32;
	client_target_delta_time = 1 / target_framerate;

	if init != nil {
		args := Workbench_Init_Args{client_target_delta_time};
		init(args);
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

			// Update vars from callbacks
			{
				ortho_matrix = _new_ortho_matrix;

				current_window_width   = _new_window_width;
				current_window_height  = _new_window_height;
				current_aspect_ratio   = _new_aspect_ratio;
				cursor_screen_position = _new_cursor_screen_position;
				cursor_unit_position   = cursor_screen_position / Vec2{cast(f32)current_window_width, cast(f32)current_window_height};
				cursor_world_position  = screen_to_world(cursor_screen_position);

				cursor_scroll          = _new_cursor_scroll;
				_new_cursor_scroll     = 0;
			}

			clear(&buffered_vertices);
			_input_update();
			_ui_update(client_target_delta_time);
			if !update(client_target_delta_time) do break game_loop;
		}

		_renderer_update();

		frame_end := win32.time_get_time();
		glfw.SwapBuffers(main_window);
		odingl.Finish();
		log_gl_errors("after SwapBuffers()");
	}
}

main :: proc() {

}