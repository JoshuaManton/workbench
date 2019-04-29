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
                           target_framerate: f32,
                           workspace: Workspace,
                           camera: ^Camera) {

	wb_profiler = pf.make_profiler(proc() -> f64 {
		return glfw.GetTime();
	});
	defer pf.destroy_profiler(&wb_profiler);

	current_camera = camera;

	client_target_framerate = target_framerate;

	init_glfw(window_name, window_width, window_height, opengl_version_major, opengl_version_minor);
	init_draw(opengl_version_major, opengl_version_minor);
	init_random(cast(u64)glfw.GetTime());
	init_dear_imgui();
	init_default_fonts();



	acc: f32;
	fixed_delta_time = cast(f32)1 / client_target_framerate;

	start_workspace(workspace);
	init_new_workspaces();

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

				update_input();
				imgui_begin_new_frame();
	    		imgui.push_font(imgui_font_default);

	    		update_draw();
				update_catalog();
				update_glfw();
				update_tween();
				update_ui();
				update_debug_menu();

				init_new_workspaces();
				update_workspaces(); // calls client updates

				late_update_ui();

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

		render_workspaces();

		glfw.SwapBuffers(main_window);

		gpu.log_errors("after SwapBuffers()");

		remove_ended_workspaces();
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

init_new_workspaces :: proc() {
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

update_workspaces :: proc() {
	for id, workspace in all_workspaces {
		current_workspace = workspace.id;
		if workspace.update != nil {
			workspace.update(fixed_delta_time);
		}
	}
	current_workspace = -1;
}

render_workspaces :: proc() {
	for id, workspace in all_workspaces {
		current_workspace = workspace.id;
		if workspace.render != nil {
			workspace.render(lossy_delta_time);
		}

		draw_render();
		gpu.log_errors(tprint("workspace_name: ", workspace.name));
	}
	current_workspace = -1;
}

remove_ended_workspaces :: proc() {
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

_end_all_workspaces :: proc() {
	for id, workspace in all_workspaces {
		end_workspace(id);
	}
	remove_ended_workspaces();
}



_default_font_data := #load("resources/fonts/Roboto/Roboto-Regular.ttf");
_default_font_mono_data := #load("resources/fonts/Roboto_Mono/RobotoMono-Regular.ttf");
default_font:      Font;
default_font_mono: Font;
init_default_fonts :: proc() {
	default_font      = load_font(_default_font_data, 72);
	default_font_mono = load_font(_default_font_mono_data, 72);
}



main :: proc() {
	when DEVELOPER {
		_test_csv();
	}
}