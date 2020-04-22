package workbench

import "platform"
import "external/imgui"
import "gpu"
import "profiler"

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
debug_window_open: bool;

update_debug_menu :: proc(dt: f32) {

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