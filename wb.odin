package workbench

using import        "core:math"
using import        "core:fmt"
      import        "core:sort"
      import        "core:strings"
      import        "core:mem"
      import        "core:os"
      import        "core:sys/win32"
	  import        "core:runtime"

      import wbmath "math"
      import        "gpu"
using import        "logging"
using import        "types"

      import imgui  "external/imgui"

      import stb    "external/stb"
      import        "external/glfw"

	  import        "console"
      import pf     "profiler"

WB_Context :: struct {
	logger_proc		: proc(log: string)
}

//
// Game loop stuff
//

client_target_framerate:  f32;
fixed_delta_time: f32;

update_loop_ra: Rolling_Average(f64, 100);
whole_frame_time_ra: Rolling_Average(f64, 100);

do_log_frame_boundaries := false;

debug_console := console.new_console();

wb_profiler: pf.Profiler;

make_simple_window :: proc(window_name: string,
                           window_width, window_height: int,
                           opengl_version_major, opengl_version_minor: int,
                           _target_framerate: f32,
                           workspace: Workspace,
                           camera: ^Camera) {

	context.derived = WB_Context{
		 _log_back
	};

	wb_profiler = pf.make_profiler(proc() -> f64 {
		return glfw.GetTime();
	});
	defer pf.destroy_profiler(&wb_profiler);

	current_camera = camera;

	client_target_framerate = _target_framerate;

	_init_glfw(window_name, window_width, window_height, opengl_version_major, opengl_version_minor);
	_init_draw(opengl_version_major, opengl_version_minor);
	_init_random_number_generator();
	_init_dear_imgui();

	acc: f32;
	fixed_delta_time = cast(f32)1 / client_target_framerate;

	start_workspace(workspace);
	_init_new_workspaces();

	game_loop:
	for !glfw.WindowShouldClose(main_window) && !wb_should_close && (len(all_workspaces) > 0 || len(new_workspaces) > 0) {
		pf.profiler_new_frame(&wb_profiler);

		pf.TIMED_SECTION(&wb_profiler, "full engine frame");
		update_loop_start := glfw.GetTime();

		last_time := time;
		time = cast(f32)glfw.GetTime();
		lossy_delta_time = time - last_time;
		acc += lossy_delta_time;

		if acc >= fixed_delta_time {
			for {
				pf.TIMED_SECTION(&wb_profiler, "update loop frame");
				if do_log_frame_boundaries {
					logln("[WB] FRAME #", frame_count);
				}

				frame_count += 1;

				_clear_render_buffers();

				_update_input();
				imgui_begin_new_frame();
	    		imgui.push_font(imgui_font_default);

	    		_update_draw();
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

		update_loop_end := glfw.GetTime();
		rolling_average_push_sample(&whole_frame_time_ra, update_loop_end - update_loop_start);

		_render_workspaces();

		glfw.SwapBuffers(main_window);

		gpu.log_errors("after SwapBuffers()");

		_remove_ended_workspaces();
	}

	_end_all_workspaces();
	logln("workbench successfully shutdown.");
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


	//
	render_workspace :: proc(workspace: Workspace) {
	gpu.log_errors(#procedure);

	num_draw_calls = 0;
	if workspace.render != nil {
		workspace.render(fixed_delta_time);
	}

	_prerender();

	{
		// BEGIN_FRAME_BUFFER();

		// flush_3d();
		im_draw_flush(gpu.Draw_Mode.Triangles, buffered_draw_commands[:]);
		// draw_debug_lines();
	}

	gpu.set_clear_color(Colorf{0,0,0,0});

	imgui_render(true);
	gpu.log_errors(tprint("workspace_name: ", workspace.name));
}
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

_log_back :: proc(log: string) {
	console.append_log(debug_console, log);
}

_end_all_workspaces :: proc() {
	for id, workspace in all_workspaces {
		end_workspace(id);
	}
	_remove_ended_workspaces();
}

client_debug_window_proc: proc();

debug_window_open: bool;
_update_debug_window :: proc() {

	if get_input_down(Input.F1) {
		debug_window_open = !debug_window_open;
	}

	if debug_window_open {
		WB_Debug_Data :: struct {
			camera_position: Vec3,
			camera_rotation_euler: Vec3,
			camera_rotation_quat: Quat,
			precise_lossy_delta_time_ms: f64,
			fixed_delta_time: f32,
			client_target_framerate: f32,
			draw_calls: i32,
		}

		data := WB_Debug_Data{
			current_camera.position,
			current_camera.rotation,
			wbmath.degrees_to_quaternion(current_camera.rotation),
			rolling_average_get_value(&whole_frame_time_ra) * 1000,
			fixed_delta_time,
			client_target_framerate,
			num_draw_calls,
		};

		imgui.set_next_window_pos(imgui.Vec2{0, 0});
		imgui.set_next_window_size(imgui.Vec2{200, current_window_height});
		if imgui.begin("Debug", nil, imgui.Window_Flags.NoResize |
	                                 imgui.Window_Flags.NoMove |
	                                 imgui.Window_Flags.NoCollapse |
	                                 imgui.Window_Flags.NoBringToFrontOnFocus) {
			@static show_imgui_demo_window := false;
			@static show_profiler_window := false;

			imgui_struct(&data, "wb_debug_data");
			imgui.checkbox("Debug Rendering", &debugging_rendering);
			imgui.checkbox("Debug UI", &debugging_ui);
			imgui.checkbox("Log Frame Boundaries", &do_log_frame_boundaries);
			imgui.checkbox("Show Profiler", &show_profiler_window); if show_profiler_window do pf.profiler_imgui_window(&wb_profiler);

			imgui.checkbox("Show dear-imgui Demo Window", &show_imgui_demo_window); if show_imgui_demo_window do imgui.show_demo_window(&show_imgui_demo_window);
			imgui.im_slider_int("max_draw_calls", &debugging_rendering_max_draw_calls, -1, num_draw_calls, nil);

			if client_debug_window_proc != nil do client_debug_window_proc();
		}
		imgui.end();


		console.update_console_window(debug_console);
	}
}

main :: proc() {
	when DEVELOPER {
		_test_csv();
		_test_alphabetical_notation();
	}
}