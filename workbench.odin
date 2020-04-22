package workbench

import "core:fmt"
import "core:sort"
import "core:strings"
import "core:mem"
import "core:os"
import "core:runtime"
import core_time "core:time"

import "math"
import "gpu"
import "platform"
import "profiler"
import "types"
import "basic"

import "external/imgui"
import "external/stb"

import "allocators"
import "shared"

import "external/glfw"

DEVELOPER :: true;

//
// Game loop stuff
//

main_window: platform.Window;

update_loop_ra: Rolling_Average(f32, 100);
whole_frame_time_ra: Rolling_Average(f32, 100);

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
	startup_start_time := core_time.now()._nsec;
	target_framerate = requested_framerate;

	// init frame allocator
	// @static frame_allocator_raw: allocators.Arena;
	// allocators.init_arena(&frame_allocator_raw, make([]byte, 4 * 1024 * 1024)); // todo(josh): destroy the frame allocator
 //    defer allocators.destroy_arena(&frame_allocator_raw);

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

    register_debug_program("Profiler", proc(_: rawptr) {
    		profiler.draw_profiler_window();
    	}, nil);

    // init profiler
    profiler.init_profiler();
    defer profiler.deinit_profiler();

	init_random(u64(core_time.now()._nsec));

	when !shared.HEADLESS { 
		// init platform and graphics
		platform.init_platform(&main_window, workspace.name, window_width, window_height);

		init_draw(window_width, window_height);
		defer deinit_draw();
		
		init_dear_imgui();

		// init catalog
		init_asset_system();
		init_builtin_assets();
		init_gizmo();
		init_builtin_debug_programs();
	}

	register_debug_program("WB Info", wb_info_program, nil);

	init_workspace(workspace);

	startup_end_time := core_time.now()._nsec;
	logln("Startup time: ", startup_end_time - startup_start_time);

	profiler.end_timed_section(init_section);

	acc: f32;
	fixed_delta_time = cast(f32)1 / cast(f32)target_framerate;
	last_frame_start_time: f64;
	should_window_close := false;
	game_loop:
	for !should_window_close && !wb_should_close {
		when !shared.HEADLESS {
			should_window_close = glfw.WindowShouldClose(main_window);
		}

		profiler.profiler_new_frame();
		profiler.TIMED_SECTION("full engine frame");
		frame_start_time := f64(core_time.now()._nsec) / f64(core_time.Second);
		lossy_delta_time = f32(frame_start_time - last_frame_start_time);
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

			    // if frame_allocator_raw.cur_offset > len(frame_allocator_raw.memory)/2 {
			    //     logln("Frame allocator over half capacity: ", frame_allocator_raw.cur_offset, " / ", len(frame_allocator_raw.memory));
			    // }
			    // mem.free_all(frame_allocator);

				if do_log_frame_boundaries {
					logln("[WB] FRAME #", frame_count);
				}

				//
				precise_time = f64(core_time.now()._nsec);
				time = cast(f32)precise_time;
				frame_count += 1;

				when !shared.HEADLESS {
					//
					platform.update_platform();
					imgui_begin_new_frame(fixed_delta_time);
		    		imgui.push_font(imgui_font_default); // todo(josh): pop this?

		    		//
		    		gizmo_new_frame();
		    		update_draw();
		    		update_ui();
					update_debug_menu(fixed_delta_time);
	    		}
				
				update_tween(fixed_delta_time);
				update_workspace(workspace, fixed_delta_time); // calls client updates

	    		when !shared.HEADLESS {
					late_update_ui();
	    			imgui.pop_font();

					if acc >= fixed_delta_time {
						imgui_render(false);
					}
				}

				if acc >= fixed_delta_time {
					continue;
				}
				else {
					break;
				}
			}

			when !shared.HEADLESS {
				render_workspace(workspace);
				glfw.SwapBuffers(main_window);
				gpu.log_errors("after SwapBuffers()");
			}

			rolling_average_push_sample(&whole_frame_time_ra, lossy_delta_time);
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
    TIMED_SECTION();

	fileloc := #location().file_path;
	wbfolder, ok := basic.get_file_directory(fileloc);
	assert(ok);
	resources_folder := fmt.aprint(wbfolder, "/resources");
	defer delete(resources_folder);
	track_asset_folder(resources_folder, true);
}

wb_info_program :: proc(_: rawptr) {
	@static show_imgui_demo_window := false;
	@static show_profiler_window := false;

	WB_Debug_Data :: struct {
		camera_position: Vec3,
		camera_rotation: Quat,
		dt: f32,
	};

	if imgui.begin("WB Info") {
		data := WB_Debug_Data{
			main_camera.position,
			main_camera.rotation,
			fixed_delta_time,
		};

		imgui_struct(&data, "wb_debug_data");
		imgui.checkbox("Debug UI", &debugging_ui);
		imgui.checkbox("Log Frame Boundaries", &do_log_frame_boundaries);
		imgui.checkbox("Show dear-imgui Demo Window", &show_imgui_demo_window); if show_imgui_demo_window do imgui.show_demo_window(&show_imgui_demo_window);
	}
	imgui.end();
}



main :: proc() {
	when DEVELOPER {
		// _test_csv();
	}
}