package workbench

import "core:fmt"
import "core:sort"
import "core:strings"
import "core:mem"
import "core:os"
import "core:sys/win32"
import "core:runtime"

import "math"
import "gpu"
import "platform"
import "profiler"
import "types"
import "basic"

import "external/imgui"

import "external/stb"
import "external/glfw"

import "allocators"

DEVELOPER :: true;

//
// Game loop stuff
//

main_window: platform.Window;

do_log_frame_boundaries := false;

target_framerate: int;
frame_count: u64;
time: f32;
precise_time: f64;
fixed_delta_time: f32;
lossy_delta_time: f32;
precise_lossy_delta_time: f64;

frame_allocator: mem.Allocator;

make_simple_window :: proc(window_width, window_height: int,
                           requested_framerate: int,
                           workspace: Workspace) {

	startup_start_time := glfw.GetTime();

	fixed_delta_time = cast(f32)1 / cast(f32)requested_framerate;
	target_framerate = requested_framerate;

	// init frame allocator
	@static frame_allocator_raw: allocators.Arena;
	allocators.init_arena(&frame_allocator_raw, make([]byte, 4 * 1024 * 1024)); // todo(josh): destroy the frame allocator
    defer allocators.destroy_arena(&frame_allocator_raw);

    default_temp_allocator := context.temp_allocator;
	frame_allocator = allocators.arena_allocator(&frame_allocator_raw);
    context.temp_allocator = frame_allocator;
    defer context.temp_allocator = default_temp_allocator;

    // init allocation tracker
    default_allocator := context.allocator;
    @static allocation_tracker: allocators.Allocation_Tracker;
    defer allocators.destroy_allocation_tracker(&allocation_tracker);
    context.allocator = allocators.init_allocation_tracker(&allocation_tracker);
    defer context.allocator = default_allocator;

    // init profiler
    profiler.init_profiler();
    defer profiler.deinit_profiler();

    register_debug_program("Profiler", proc(_: rawptr) {
    		profiler.draw_profiler_window();
    	}, nil);

	// init platform and graphics
	platform.init_platform(&main_window, workspace.name, window_width, window_height);
	init_draw(window_width, window_height);
	defer deinit_draw();

	init_random(cast(u64)glfw.GetTime());
	init_dear_imgui();

	init_asset_system();
	init_builtin_assets();

	init_gizmo();

	init_builtin_debug_programs();

	init_workspace(workspace);

	startup_end_time := glfw.GetTime();
	logln("Startup time: ", startup_end_time - startup_start_time);

	acc: f32;
	last_frame_start_time: f32;
	game_loop:
	for !glfw.WindowShouldClose(main_window) && !wb_should_close {
		frame_start_time := cast(f32)glfw.GetTime();
		lossy_delta_time = frame_start_time - last_frame_start_time;
		last_frame_start_time = frame_start_time;
		acc += lossy_delta_time;

		if acc > 0.1 { // note(josh): stop spiral of death ensuring a minimum render framerate
			acc = 0.1;
		}

		if acc >= fixed_delta_time {
			profiler.profiler_new_frame();
			TIMED_SECTION("full engine frame");

			check_for_file_updates();

			for {
				TIMED_SECTION("update loop frame");

				acc -= fixed_delta_time;

			    if frame_allocator_raw.cur_offset > len(frame_allocator_raw.memory)/2 {
			        logln("Frame allocator over half capacity: ", frame_allocator_raw.cur_offset, " / ", len(frame_allocator_raw.memory));
			    }
			    mem.free_all(frame_allocator);

				if do_log_frame_boundaries {
					logln("[WB] FRAME #", frame_count);
				}

				//
				precise_time = glfw.GetTime();
				time = cast(f32)precise_time;
				frame_count += 1;

				//
				platform.update_platform();
				imgui_begin_new_frame(fixed_delta_time);
	    		imgui.push_font(imgui_font_default); // todo(josh): pop this?

	    		//
	    		gizmo_new_frame();
	    		update_draw();
				update_tween(fixed_delta_time);
				update_ui();
				update_debug_menu(fixed_delta_time);

				update_workspace(workspace, fixed_delta_time); // calls client updates

				if platform.get_input_down(.F8, true) {
					context.temp_allocator = default_temp_allocator;
					for ptr, info in allocation_tracker.allocations {
						fmt.println(ptr, info.size, info.location.file_path == "" ? tprint("BROKEN FILE PATH: proc = ", info.location.procedure) : basic.pretty_location(info.location));
					}
				}

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
		}
	}

	end_workspace(workspace);

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

init_workspace :: proc(workspace: Workspace) {
	if workspace.init != nil {
		workspace.init();
	}
}

update_workspace :: proc(workspace: Workspace, dt: f32) {
	TIMED_SECTION();

	if workspace.update != nil {
		workspace.update(dt);
	}
}

end_workspace :: proc(workspace: Workspace) {
	if workspace.end != nil {
		workspace.end();
	}
}



// wba = wb asset
wba_font_default_data              := #load("resources/fonts/roboto.ttf");
wba_font_mono_data                 := #load("resources/fonts/roboto_mono.ttf");

init_builtin_assets :: proc() {
	fileloc := #location().file_path;
	wbfolder, ok := basic.get_file_directory(fileloc);
	assert(ok);
	resources_folder := fmt.aprint(wbfolder, "/resources");
	defer delete(resources_folder);
	track_asset_folder(resources_folder, true);
}



main :: proc() {
	when DEVELOPER {
		// _test_csv();
	}
}