package workbench

using import "core:math"

      import wbm "math"
      import     "external/imgui"
      import pf  "profiler"
      import     "console"

debug_window_open: bool;
update_debug_menu :: proc() {
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
			wbm.degrees_to_quaternion(current_camera.rotation),
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
			imgui.checkbox("Debug UI", &debugging_ui);
			imgui.checkbox("Log Frame Boundaries", &do_log_frame_boundaries);
			imgui.checkbox("Show Profiler", &show_profiler_window); if show_profiler_window do pf.profiler_imgui_window(&wb_profiler);

			for _, idx in debug_programs {
				program := &debug_programs[idx];
				imgui.checkbox(program.name, &program.is_open);
				if program.is_open {
					if imgui.begin(program.name) {
						program.procedure(program.userdata);
					}
					imgui.end();
				}
			}

			imgui.checkbox("Show dear-imgui Demo Window", &show_imgui_demo_window); if show_imgui_demo_window do imgui.show_demo_window(&show_imgui_demo_window);
			imgui.im_slider_int("max_draw_calls", &debugging_rendering_max_draw_calls, -1, num_draw_calls, nil);
		}
		imgui.end();


		console.update_console_window(debug_console);
	}
}



debug_programs: [dynamic]Debug_Program;
register_debug_program :: proc(name: string, procedure: proc(rawptr), userdata: rawptr) {
	append(&debug_programs, Debug_Program{name, procedure, userdata, false});
}

Debug_Program :: struct {
	name:      string,
	procedure: proc(rawptr),
	userdata:  rawptr,
	is_open:   bool,
}