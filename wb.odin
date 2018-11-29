package workbench

using import        "core:math"
using import        "core:fmt"
      import        "core:sort"
      import        "core:strings"
      import        "core:mem"
      import        "core:os"
      import        "core:sys/win32"

      import odingl "external/gl"
      import imgui  "external/imgui"

      import stb    "external/stb"
      import        "external/glfw"

	  import 		"console"

DEVELOPER :: true;

//
// Game loop stuff
//

client_target_framerate:  f32;
fixed_delta_time: f32;

whole_frame_time_ra: Rolling_Average(f64, 100);

do_log_frame_boundaries := false;

debug_console := console.new_console();

// _on_before_client_update := make_event(f32);
// _on_after_client_update  := make_event(f32);
f: f32;
make_simple_window :: proc(window_name: string,
                           window_width, window_height: int,
                           opengl_version_major, opengl_version_minor: int,
                           _target_framerate: f32,
                           workspace: Workspace,
                           camera: ^Camera) {

	current_camera = camera;

	client_target_framerate = _target_framerate;

	_init_glfw(window_name, window_width, window_height, opengl_version_major, opengl_version_minor);
	_init_opengl(opengl_version_major, opengl_version_minor);
	_init_random_number_generator();
	_init_dear_imgui();

	acc: f32;
	fixed_delta_time = cast(f32)1 / client_target_framerate;

	start_workspace(workspace);
	_init_new_workspaces();

	game_loop:
	for !glfw.WindowShouldClose(main_window) && !wb_should_close && (len(all_workspaces) > 0 || len(new_workspaces) > 0) {
		frame_start := glfw.GetTime();
		defer {
			frame_end := glfw.GetTime();
			rolling_average_push_sample(&whole_frame_time_ra, frame_end - frame_start);
		}

		last_time := time;
		time = cast(f32)glfw.GetTime();
		lossy_delta_time = time - last_time;
		acc += lossy_delta_time;

		if acc >= fixed_delta_time {
			for {
				if do_log_frame_boundaries {
					logln("[WB] FRAME #", frame_count);
				}

				frame_count += 1;

				_clear_render_buffers();

				_update_input();
				imgui_begin_new_frame();
	    		imgui.push_font(imgui_font_default);

				_update_catalog();
				_update_glfw();
				_update_tween();
				_update_ui();
				_update_debug_window();

				_init_new_workspaces();
				_update_workspaces(); // calls client updates

				_late_update_ui();

	    		imgui.pop_font();

				acc -= fixed_delta_time;
				if acc >= fixed_delta_time {
					imgui_render(false);
				}
				else {
					break;
				}
			}
		}

		_render_workspaces();

		glfw.SwapBuffers(main_window);

		log_gl_errors("after SwapBuffers()");

		_remove_ended_workspaces();
	}
}

wb_should_close: bool;
exit :: inline proc() {
	wb_should_close = true;
}

Workspace :: struct {
	name: string,

	init: proc(),
	update: proc(f32),
	render: proc(f32),
	end: proc(),
}

_Workspace_Internal :: struct {
	using workspace: Workspace,

	id: Workspace_ID,
}

Workspace_ID :: distinct int;
cur_workspace_serial: int;
all_workspaces: map[Workspace_ID]_Workspace_Internal;
new_workspaces: [dynamic]_Workspace_Internal;
end_workspaces: [dynamic]Workspace_ID;

start_workspace :: proc(workspace: Workspace) -> Workspace_ID {
	id := cast(Workspace_ID)cur_workspace_serial;
	cur_workspace_serial += 1;

	workspace_internal := _Workspace_Internal{workspace, id};
	append(&new_workspaces, workspace_internal);
	return id;
}

end_workspace :: proc(id: Workspace_ID) {
	append(&end_workspaces, id);
}

current_workspace: Workspace_ID;

_init_new_workspaces :: proc() {
	for workspace in new_workspaces {
		current_workspace = workspace.id;
		if workspace.init != nil {
			workspace.init();
		}
		all_workspaces[workspace.id] = workspace;
	}
	current_workspace = -1;
	clear(&new_workspaces);
}

_update_workspaces :: proc() {
	for id, workspace in all_workspaces {
		current_workspace = workspace.id;
		if workspace.update != nil {
			workspace.update(fixed_delta_time);
		}
	}
	current_workspace = -1;
}

_render_workspaces :: proc() {
	for id, workspace in all_workspaces {
		current_workspace = workspace.id;
		render_workspace(workspace);
	}
	current_workspace = -1;
}

_remove_ended_workspaces :: proc() {
	for id in end_workspaces {
		workspace, ok := all_workspaces[id];
		assert(ok);

		current_workspace = workspace.id;

		if workspace.end != nil {
			workspace.end();
		}

		delete_key(&all_workspaces, id);
	}
	current_workspace = -1;
	clear(&end_workspaces);
}

WB_Debug_Data :: struct {
	camera_position: Vec3,
	camera_rotation_euler: Vec3,
	camera_rotation_quat: Quat,
	precise_lossy_delta_time_ms: f64,
	fixed_delta_time: f32,
	client_target_framerate: f32,
	draw_calls: i32,
}

debug_window_open: bool;
last_saved_dt: f32;

_update_debug_window :: proc() {
	if get_input_down(Input.F1) {
		debug_window_open = !debug_window_open;
	}

	if debug_window_open {
		data := WB_Debug_Data{
			current_camera.position,
			current_camera.rotation,
			degrees_to_quaternion(current_camera.rotation),
			rolling_average_get_value(&whole_frame_time_ra) * 1000,
			fixed_delta_time,
			client_target_framerate,
			num_draw_calls,

		};
		if imgui.begin("Debug") {
			defer imgui.end();

			imgui_struct(&data, "wb_debug_data");
			imgui.checkbox("Debug Rendering", &debugging_rendering);
			imgui.checkbox("Debug UI", &debugging_ui);
			imgui.checkbox("Log Frame Boundaries", &do_log_frame_boundaries);
			imgui.im_slider_int("max_draw_calls", &debugging_rendering_max_draw_calls, -1, num_draw_calls, nil);
		}

		console.update_console_window(debug_console);
	}
}

main :: proc() {
	when DEVELOPER {
		_test_csv();
		_test_alphabetical_notation();
	}
}