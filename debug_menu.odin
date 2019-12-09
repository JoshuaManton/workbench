package workbench

using import "math"
using import "logging"

      import "platform"
      import wbm "math"
      import     "external/imgui"
      import pf  "profiler"
      import     "gpu"

//
// API
//

register_debug_program :: proc(name: string, procedure: proc(userdata: rawptr), userdata: rawptr) {
	append(&debug_programs, Debug_Program{name, procedure, userdata, false});
}

unregister_debug_program :: proc(name: string) {
	for p, idx in debug_programs {
		if p.name == name {
			ordered_remove(&debug_programs, idx);
			return;
		}
	}
	logln("Warning: Tried to unregister program that didn't exist: ", name);
}



//
// Internal
//

Debug_Program :: struct {
	name: string,
	procedure: proc(rawptr),
	userdata: rawptr,
	is_open: bool,
}

debug_programs: [dynamic]Debug_Program;

update_debug_menu :: proc(dt: f32) {
	@static debug_window_open: bool;

	if platform.get_input_down(.F1) do debug_window_open = !debug_window_open;

	if debug_window_open {
		HEIGHT :: 35;
		imgui.set_next_window_pos(imgui.Vec2{0, platform.current_window_height - HEIGHT});
		imgui.set_next_window_size(imgui.Vec2{platform.current_window_width, HEIGHT});
		if imgui.begin("Debug", nil, imgui.Window_Flags.NoResize |
	                                 imgui.Window_Flags.NoMove |
	                                 imgui.Window_Flags.NoTitleBar |
	                                 imgui.Window_Flags.NoCollapse |
	                                 imgui.Window_Flags.NoBringToFrontOnFocus) {

			first := true;
			for _, pidx in debug_programs {
				program := &debug_programs[pidx];
				if !first do imgui.same_line();
				if imgui.button(program.name) {
					program.is_open = !program.is_open;
				}
				first = false;
			}

			for _, pidx in debug_programs {
				program := &debug_programs[pidx];
				if program.is_open {
					program.procedure(program.userdata);
				}
			}
		}
		imgui.end();
	}
}

init_builtin_debug_programs :: proc() {
	register_debug_program("WB Info", wb_info_program, nil);
}

wb_info_program :: proc(_: rawptr) {
	@static show_imgui_demo_window := false;
	@static show_profiler_window := false;

	WB_Debug_Data :: struct {
		camera_position: Vec3,
		camera_rotation: Quat,
		precise_lossy_delta_time_ms: f32,
		dt: f32,
	};

	if imgui.begin("WB Info") {
		data := WB_Debug_Data{
			wb_camera.position,
			wb_camera.rotation,
			rolling_average_get_value(&whole_frame_time_ra) * 1000,
			fixed_delta_time,
		};

		imgui_struct(&data, "wb_debug_data");
		imgui.checkbox("Debug UI", &debugging_ui);
		imgui.checkbox("Log Frame Boundaries", &do_log_frame_boundaries);
		imgui.checkbox("Show Profiler", &show_profiler_window); if show_profiler_window do pf.profiler_imgui_window(&wb_profiler);
		imgui.checkbox("Show dear-imgui Demo Window", &show_imgui_demo_window); if show_imgui_demo_window do imgui.show_demo_window(&show_imgui_demo_window);
	}
	imgui.end();
}