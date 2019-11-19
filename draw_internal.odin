package workbench

using import          "core:fmt"
      import          "core:sort"
      import          "core:strings"
      import          "core:mem"
      import          "core:os"

      import          "platform"
      import          "gpu"
using import wbmath   "math"
using import          "types"
using import          "logging"
using import          "basic"

      import          "external/stb"
      import          "external/glfw"
      import          "external/imgui"

//
// Internal
//

screen_camera: Camera;
wb_camera: Camera;

wb_cube_model: Model;
wb_quad_model: Model;

debug_lines: [dynamic]Debug_Line;
debug_cubes: [dynamic]Debug_Cube;
debug_line_model: Model;

debugging_rendering: bool;

render_settings: Render_Settings;

Render_Settings :: struct {
	gamma: f32,
	exposure: f32,
	bloom_threshhold: f32,

	visualize_bloom_texture: bool,
	visualize_shadow_texture: bool,
}

init_draw :: proc(screen_width, screen_height: int) {
	gpu.init(proc(p: rawptr, name: cstring) {
			(cast(^rawptr)p)^ = rawptr(glfw.GetProcAddress(name));
		});

	init_camera(&screen_camera, false, 10, screen_width, screen_height);
	screen_camera.clear_color = {1, 0, 1, 1};

	init_camera(&wb_camera, true, 85, screen_width, screen_height, create_color_framebuffer(screen_width, screen_height, 2));
	add_bloom_data(&wb_camera);
	wb_camera.clear_color = {.1, 0.7, 0.5, 1};

	add_mesh_to_model(&_internal_im_model, []Vertex2D{}, []u32{}, {});

	wb_cube_model = create_cube_model();
	wb_quad_model = create_quad_model();
	add_mesh_to_model(&debug_line_model, []Vertex3D{}, []u32{}, {});

	render_settings = Render_Settings{
		gamma = 2.2,
		exposure = 1.5,
		bloom_threshhold = 5.0,
	};
}

update_draw :: proc() {
	clear(&debug_lines);
	clear(&debug_cubes);
	clear(&buffered_draw_commands);

	if debug_window_open {
		if imgui.begin("Scene View") {
		    window_size := imgui.get_window_size();

			imgui.image(rawptr(uintptr(wb_camera.framebuffer.textures[0].gpu_id)),
				imgui.Vec2{window_size.x - 10, window_size.y - 30},
				imgui.Vec2{0,1},
				imgui.Vec2{1,0});
		} imgui.end();
	}
}

// todo(josh): maybe put this in the Workspace?
post_render_proc: proc();

render_workspace :: proc(workspace: Workspace) {
	check_for_file_updates(&wb_catalog);

	gpu.enable(.Cull_Face);

	assert(current_camera == nil);
	update_camera_pixel_size(&screen_camera, platform.current_window_width, platform.current_window_height);
	PUSH_CAMERA(&screen_camera);

	update_camera_pixel_size(&wb_camera, platform.current_window_width, platform.current_window_height);

	// this scope is important because of the PUSH_CAMERA() call
	{
		// pre-render
		gpu.log_errors(#procedure);
		num_draw_calls = 0;
		PUSH_CAMERA(&wb_camera);

		if workspace.render != nil {
			workspace.render(lossy_delta_time);
			gpu.log_errors(workspace.name);
		}

		// draw shadow maps
		{
			for idx in 0..<num_directional_lights {
				light_camera := &directional_light_cameras[idx];
				PUSH_CAMERA(light_camera);
				// gpu.cull_face(.Front);

				depth_shader := get_shader(&wb_catalog, "depth");
				gpu.use_program(depth_shader);

				rendermode_world();

				for info in wb_camera.render_queue {
					using info;

					draw_model(model, position, scale, rotation, texture, color, true, animation_state);
				}

				// gpu.cull_face(.Back);
			}
		}

		// draw scene for real
		rendermode_world();

		for info in wb_camera.render_queue {
			using info;

			gpu.use_program(shader);

			flush_lights_to_shader(shader);
			set_current_material(shader, material);

			if num_directional_lights > 0 {
				light_camera := &directional_light_cameras[0];
				program := gpu.get_current_shader();
				gpu.uniform_int(program, "shadow_map", 1);
				gpu.active_texture1();
				gpu.bind_texture2d(light_camera.framebuffer.textures[0].gpu_id);

				light_view := construct_view_matrix(light_camera);
				light_proj := construct_projection_matrix(light_camera);
				light_space := mul(light_proj, light_view);
				gpu.uniform_mat4(program, "light_space_matrix", &light_space);
			}

			draw_model(model, position, scale, rotation, texture, color, true, animation_state);
		}

		clear(&wb_camera.render_queue);

		// draw bloom
		if bloom_data, ok := getval(wb_camera.bloom_data); ok {
			for fbo in bloom_data.pingpong_fbos {
				PUSH_FRAMEBUFFER(fbo);
				gpu.clear_screen(.Color_Buffer | .Depth_Buffer);
			}

			horizontal := true;
			first := true;
			amount := 5;
			last_bloom_fbo: Maybe(Framebuffer);
			shader_blur := get_shader(&wb_catalog, "blur");
			gpu.use_program(shader_blur);
			for i in 0..<amount {
				PUSH_FRAMEBUFFER(bloom_data.pingpong_fbos[cast(int)horizontal]);
				gpu.uniform_int(shader_blur, "horizontal", cast(i32)horizontal);
				if first {
					draw_texture(wb_camera.framebuffer.textures[1], {0, 0}, {platform.current_window_width, platform.current_window_height});
				}
				else {
					bloom_fbo := bloom_data.pingpong_fbos[cast(int)(!horizontal)];
					draw_texture(bloom_fbo.textures[0], {0, 0}, {platform.current_window_width, platform.current_window_height});
					last_bloom_fbo = bloom_fbo;
				}
				horizontal = !horizontal;
				first = false;
			}

			if last_bloom_fbo, ok := getval(last_bloom_fbo); ok {
				shader_bloom := get_shader(&wb_catalog, "bloom");
				gpu.use_program(shader_bloom);
				gpu.uniform_int(shader_bloom, "bloom_texture", 1);
				gpu.active_texture1();
				gpu.bind_texture2d(last_bloom_fbo.textures[0].gpu_id);
				draw_texture(wb_camera.framebuffer.textures[0], {0, 0}, {platform.current_window_width, platform.current_window_height});

				if render_settings.visualize_bloom_texture {
					gpu.use_program(get_shader(&wb_catalog, "default"));
					draw_texture(last_bloom_fbo.textures[0], {256, 0}, {512, 256});
				}
			}
		}

		im_flush();
		debug_geo_flush();

		if post_render_proc != nil {
			post_render_proc();
		}

		// gpu.use_program(get_shader(&wb_catalog, "outline"));
		// draw_texture(wb_camera.framebuffer.textures[0], {0, 0}, {platform.current_window_width, platform.current_window_height});
	}

	// do gamma correction and draw to screen!
	shader_gamma := get_shader(&wb_catalog, "gamma");
	gpu.use_program(shader_gamma);
	gpu.uniform_float(shader_gamma, "gamma", render_settings.gamma);
	gpu.uniform_float(shader_gamma, "exposure", render_settings.exposure);
	draw_texture(wb_camera.framebuffer.textures[0], {0, 0}, {platform.current_window_width, platform.current_window_height});

	// visualize depth buffer
	if render_settings.visualize_shadow_texture {
		if num_directional_lights > 0 {
			gpu.use_program(get_shader(&wb_catalog, "depth"));
			draw_texture(directional_light_cameras[0].framebuffer.textures[0], {0, 0}, {256, 256});
		}
	}

	imgui_render(true);
}

deinit_draw :: proc() {
	delete_camera(wb_camera);

	// todo(josh): figure out why deleting shaders was causing errors
	// delete_asset_catalog(wb_catalog);

	delete_model(wb_cube_model);
	delete_model(wb_quad_model);

	// todo(josh): figure out why deleting shaders was causing errors
	// gpu.delete_shader(shader_rgba_3d);
	// gpu.delete_shader(shader_rgba_2d);
	// gpu.delete_shader(shader_text);
	// gpu.delete_shader(shader_texture_unlit);
	// gpu.delete_shader(shader_texture_lit);
	// gpu.delete_shader(shader_shadow_depth);
	// gpu.delete_shader(shader_framebuffer_gamma_corrected);

	delete_model(debug_line_model);
	gpu.deinit();

	delete(debug_lines);
	delete(debug_cubes);
}

draw_rendering_debug_window :: proc() {
	if imgui.begin("Rendering") {
		// todo(josh): make this a combo box
		imgui.checkbox("Debug Rendering", &debugging_rendering);
		if debugging_rendering {
			wb_camera.draw_mode = .Lines;
		}
		else {
			wb_camera.draw_mode = .Triangles;
		}

		imgui_struct(&render_settings, "Render Settings");
	}
	imgui.end();
}