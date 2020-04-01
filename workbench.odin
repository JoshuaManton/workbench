package workbench

import "core:fmt"
import "core:sort"
import "core:strings"
import "core:mem"
import "core:os"
import "core:runtime"

import "math"
import "gpu"
import "types"
import "basic"

import "external/imgui"
import "external/stb"

import pf "profiler"
import "allocators"
import "shared"

HEADLESS :: shared.HEADLESS;
when !HEADLESS {
	import "external/glfw"
	import "platform"

	main_window: platform.Window;
}

DEVELOPER :: true;

//
// Game loop stuff
//

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

frame_allocator: mem.Allocator;

make_simple_window :: proc(window_width, window_height: int,
                           target_framerate: f32,
                           workspace: Workspace) {

	when !HEADLESS {
		startup_start_time := glfw.GetTime();
	}

	// init frame allocator
	@static frame_allocator_raw: allocators.Frame_Allocator;
	allocators.init_frame_allocator(&frame_allocator_raw, make([]byte, 4 * 1024 * 1024)); // todo(josh): destroy the frame allocator
    defer allocators.destroy_frame_allocator(&frame_allocator_raw);

	frame_allocator = allocators.frame_allocator(&frame_allocator_raw);
    context.temp_allocator = frame_allocator;

    // init profiler
    when !HEADLESS {
		wb_profiler = pf.make_profiler(proc() -> f64 { return glfw.GetTime(); } );
		defer pf.destroy_profiler(&wb_profiler);
	}

	when !HEADLESS { 
		// init platform and graphics
		platform.init_platform(&main_window, workspace.name, window_width, window_height);

		init_draw(window_width, window_height);
		defer deinit_draw();

		init_random(cast(u64)glfw.GetTime());
		init_dear_imgui();
	}

	when !HEADLESS {
		// init catalog
		add_default_handlers(&wb_catalog);
		defer delete_asset_catalog(wb_catalog);
		init_builtin_assets();
		init_gizmo();
		init_builtin_debug_programs();
	}

	init_workspace(workspace);

	when !HEADLESS {
		startup_end_time := glfw.GetTime();
		logln("Startup time: ", startup_end_time - startup_start_time);
	}

	acc: f32;
	fixed_delta_time = cast(f32)1 / target_framerate;
	last_frame_start_time: f32;
	should_window_close := false;
	game_loop:
	for !should_window_close && !wb_should_close {
		when !HEADLESS {
			should_window_close = glfw.WindowShouldClose(main_window);
		
			pf.profiler_new_frame(&wb_profiler);
			pf.TIMED_SECTION(&wb_profiler, "full engine frame");
			frame_start_time := cast(f32)glfw.GetTime();
			lossy_delta_time = frame_start_time - last_frame_start_time;
			last_frame_start_time = frame_start_time;
			acc += lossy_delta_time;
		}

		if acc > 0.1 { // note(josh): stop spiral of death ensuring a minimum render framerate
			acc = 0.1;
		}


		check_for_file_updates(&wb_catalog);

		if acc >= fixed_delta_time {
			for {
				pf.TIMED_SECTION(&wb_profiler, "update loop frame");

				acc -= fixed_delta_time;

			    if frame_allocator_raw.cur_offset > len(frame_allocator_raw.memory)/2 {
			        logln("Frame allocator over half capacity: ", frame_allocator_raw.cur_offset, " / ", len(frame_allocator_raw.memory));
			    }
			    mem.free_all(frame_allocator);

				if do_log_frame_boundaries {
					logln("[WB] FRAME #", frame_count);
				}

				//
				when !HEADLESS {
					precise_time = glfw.GetTime();
					time = cast(f32)precise_time;
				}
				frame_count += 1;


				when !HEADLESS {
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

	    		when !HEADLESS {
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
			}

			render_workspace(workspace);

			when !HEADLESS {
				glfw.SwapBuffers(main_window);
			}

			gpu.log_errors("after SwapBuffers()");

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
wba_font_default_data              := #load("resources/fonts/Roboto-Regular.ttf");
wba_font_mono_data                 := #load("resources/fonts/RobotoMono-Regular.ttf");
wba_font_fredoka_data              := #load("resources/fonts/FredokaOne-Regular.ttf");
wba_bloom_shader_data              := #load("resources/shaders/bloom.shader");
wba_blur_shader_data               := #load("resources/shaders/blur.shader");
wba_default_shader_data            := #load("resources/shaders/default.shader");
wba_default_3d_texture_shader_data := #load("resources/shaders/default_3d_texture.shader");
wba_default_vert_glsl_data         := #load("resources/shaders/default_vert.glsl");
wba_depth_shader_data              := #load("resources/shaders/depth.shader");
wba_error_shader_data              := #load("resources/shaders/error.shader");
wba_gamma_shader_data              := #load("resources/shaders/gamma.shader");
wba_lit_shader_data                := #load("resources/shaders/lit.shader");
wba_outline_shader_data            := #load("resources/shaders/outline.shader");
wba_particle_shader_data           := #load("resources/shaders/particle.shader");
wba_shadow_shader_data             := #load("resources/shaders/shadow.shader");
wba_skinning_shader_data           := #load("resources/shaders/skinning.shader");
wba_text_shader_data               := #load("resources/shaders/text.shader");
wba_terrain_shader_data            := #load("resources/shaders/terrain.shader");

init_builtin_assets :: proc() {
	load_asset(&wb_catalog, "default",            "ttf",    wba_font_default_data);
	load_asset(&wb_catalog, "mono",               "ttf",    wba_font_mono_data);
	load_asset(&wb_catalog, "fredoka",            "ttf",    wba_font_fredoka_data);
	load_asset(&wb_catalog, "default_vert",       "glsl",   wba_default_vert_glsl_data);
	load_asset(&wb_catalog, "default_3d_texture", "shader", wba_default_3d_texture_shader_data);
	load_asset(&wb_catalog, "default",            "shader", wba_default_shader_data);
	load_asset(&wb_catalog, "bloom",              "shader", wba_bloom_shader_data);
	load_asset(&wb_catalog, "blur",               "shader", wba_blur_shader_data);
	load_asset(&wb_catalog, "depth",              "shader", wba_depth_shader_data);
	load_asset(&wb_catalog, "error",              "shader", wba_error_shader_data);
	load_asset(&wb_catalog, "gamma",              "shader", wba_gamma_shader_data);
	load_asset(&wb_catalog, "lit",                "shader", wba_lit_shader_data);
	load_asset(&wb_catalog, "outline",            "shader", wba_outline_shader_data);
	load_asset(&wb_catalog, "particle",           "shader", wba_particle_shader_data);
	load_asset(&wb_catalog, "shadow",             "shader", wba_shadow_shader_data);
	load_asset(&wb_catalog, "skinning",           "shader", wba_skinning_shader_data);
	load_asset(&wb_catalog, "text",               "shader", wba_text_shader_data);
	load_asset(&wb_catalog, "terrain",            "shader", wba_terrain_shader_data);
}



main :: proc() {
	when DEVELOPER {
		// _test_csv();
	}
}