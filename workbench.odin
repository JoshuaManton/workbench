package workbench

using import        "core:fmt"
      import        "core:sort"
      import        "core:strings"
      import        "core:mem"
      import        "core:os"
      import        "core:sys/win32"
	  import        "core:runtime"

using import        "math"
      import        "gpu"
      import        "platform"
using import        "logging"
using import        "types"
using import        "basic"

      import imgui  "external/imgui"

      import stb    "external/stb"
      import        "external/glfw"

	  import        "console"
      import pf     "profiler"

DEVELOPER :: true;

WORKBENCH_PATH: string;

//
// Game loop stuff
//

main_window: platform.Window;

update_loop_ra: Rolling_Average(f32, 100);
whole_frame_time_ra: Rolling_Average(f32, 100);

do_log_frame_boundaries := false;

wb_profiler: pf.Profiler;

frame_count: u64;
time: f32;
precise_time: f64;
fixed_delta_time: f32;
lossy_delta_time: f32;
precise_lossy_delta_time: f64;

wb_catalog: Asset_Catalog;

make_simple_window :: proc(window_width, window_height: int,
                           target_framerate: f32,
                           workspace: Workspace) {
	defer logln("workbench successfully shutdown.");

	wbpathok: bool;
	WORKBENCH_PATH, wbpathok = get_file_directory(#location().file_path);
	assert(wbpathok);

	startup_start_time := glfw.GetTime();

	wb_profiler = pf.make_profiler(proc() -> f64 { return glfw.GetTime(); } );
	defer pf.destroy_profiler(&wb_profiler);

	platform.init_platform(&main_window, workspace.name, window_width, window_height);
	init_draw(window_width, window_height);
	defer deinit_draw();

	init_random(cast(u64)glfw.GetTime());
	init_dear_imgui();

	assert(WORKBENCH_PATH != "");
	load_asset_folder(tprint(WORKBENCH_PATH, "/resources"), &wb_catalog);
	defer delete_asset_catalog(wb_catalog);

	init_default_fonts();

	init_gizmo();

	init_builtin_debug_programs();



	acc: f32;
	fixed_delta_time = cast(f32)1 / target_framerate;

	init_workspace(workspace);

	startup_end_time := glfw.GetTime();
	logln("Startup time: ", startup_end_time - startup_start_time);

	last_frame_start_time: f32;

	game_loop:
	for !glfw.WindowShouldClose(main_window) && !wb_should_close {
		pf.profiler_new_frame(&wb_profiler);
		pf.TIMED_SECTION(&wb_profiler, "full engine frame");
		frame_start_time := cast(f32)glfw.GetTime();
		lossy_delta_time = frame_start_time - last_frame_start_time;
		last_frame_start_time = frame_start_time;
		acc += lossy_delta_time;

		if acc > 0.1 { // note(josh): stop spiral of death ensuring a minimum render framerate
			acc = 0.1;
		}


		check_for_file_updates(&wb_catalog);

		if acc >= fixed_delta_time {
			for {
				acc -= fixed_delta_time;

				pf.TIMED_SECTION(&wb_profiler, "update loop frame");
				if do_log_frame_boundaries {
					logln("[WB] FRAME #", frame_count);
				}

				precise_time = glfw.GetTime();
				time = cast(f32)precise_time;
				frame_count += 1;

				platform.update_platform();
				imgui_begin_new_frame(fixed_delta_time);
	    		imgui.push_font(imgui_font_default);

	    		update_draw();
				update_tween(fixed_delta_time);
				update_ui();
				update_debug_menu(fixed_delta_time);

				update_workspace(workspace, fixed_delta_time); // calls client updates

				late_update_ui();

	    		imgui.pop_font();

				if acc >= fixed_delta_time {
					imgui_render(false);
					continue;
				}
				else {
					break;
				}
			}

			render_workspace(workspace);

			glfw.SwapBuffers(main_window);

			gpu.log_errors("after SwapBuffers()");

			rolling_average_push_sample(&whole_frame_time_ra, lossy_delta_time);
		}
	}

	end_workspace(workspace);
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

init_workspace :: proc(workspace: Workspace) {
	if workspace.init != nil {
		workspace.init();
	}
}

update_workspace :: proc(workspace: Workspace, dt: f32) {
	if workspace.update != nil {
		workspace.update(dt);
	}
}

end_workspace :: proc(workspace: Workspace) {
	if workspace.end != nil {
		workspace.end();
	}
}



default_font:      Font;
default_font_mono: Font;
init_default_fonts :: proc() {
	default_font      = get_font(&wb_catalog, "Roboto-Regular");
	default_font_mono = get_font(&wb_catalog, "RobotoMono-Regular");
}



main :: proc() {
	when DEVELOPER {
		// _test_csv();
	}
}