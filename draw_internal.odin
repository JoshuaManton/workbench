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

shader_rgba_2d: gpu.Shader_Program;
shader_text: gpu.Shader_Program;
shader_rgba_3d: gpu.Shader_Program;

shader_texture_unlit: gpu.Shader_Program;
shader_texture_lit: gpu.Shader_Program;

shader_shadow_depth: gpu.Shader_Program;
shader_depth: gpu.Shader_Program;

shader_skinned: gpu.Shader_Program;

shader_blur: gpu.Shader_Program;
shader_bloom: gpu.Shader_Program;
shader_framebuffer_gamma_corrected: gpu.Shader_Program;

debug_lines: [dynamic]Debug_Line;
debug_cubes: [dynamic]Debug_Cube;
debug_line_model: Model;

debugging_rendering: bool;

render_settings: Render_Settings;

Render_Settings :: struct {
	gamma: f32,
	exposure: f32,
	bloom_threshhold: f32,
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

	ok: bool;
	shader_rgba_2d, ok       = gpu.load_shader_text(SHADER_RGBA_2D_VERT, SHADER_RGBA_2D_FRAG);
	assert(ok);
	shader_texture_unlit, ok = gpu.load_shader_text(SHADER_TEXTURE_3D_UNLIT_VERT, SHADER_TEXTURE_3D_UNLIT_FRAG);
	assert(ok);
	shader_texture_lit, ok   = gpu.load_shader_text(SHADER_TEXTURE_3D_LIT_VERT, SHADER_TEXTURE_3D_LIT_FRAG);
	assert(ok);
	shader_text, ok          = gpu.load_shader_text(SHADER_TEXT_VERT, SHADER_TEXT_FRAG);
	assert(ok);
	shader_rgba_3d, ok       = gpu.load_shader_text(SHADER_RGBA_3D_VERT, SHADER_RGBA_3D_FRAG);
	assert(ok);
	shader_shadow_depth, ok  = gpu.load_shader_text(SHADER_SHADOW_VERT, SHADER_SHADOW_FRAG);
	assert(ok);
	shader_depth, ok         = gpu.load_shader_text(SHADER_DEPTH_VERT, SHADER_DEPTH_FRAG);
	assert(ok);
	shader_framebuffer_gamma_corrected, ok = gpu.load_shader_text(SHADER_FRAMEBUFFER_GAMMA_CORRECTED_VERT, SHADER_FRAMEBUFFER_GAMMA_CORRECTED_FRAG);
	assert(ok);
	shader_skinned, ok       = gpu.load_shader_text(SHADER_SKINNING_VERT, SHADER_TEXTURE_3D_LIT_FRAG);
	assert(ok);
	shader_bloom, ok          = gpu.load_shader_text(SHADER_BLOOM_VERT, SHADER_BLOOM_FRAG);
	assert(ok);
	shader_blur, ok          = gpu.load_shader_text(SHADER_GAUSSIAN_BLUR_VERT, SHADER_GAUSSIAN_BLUR_FRAG);
	assert(ok);

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
				draw_render_scene(wb_camera.render_queue[:], false, true, shader_shadow_depth);
				// gpu.cull_face(.Back);
			}
		}

		// draw scene for real
		draw_render_scene(wb_camera.render_queue[:], true, false);
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
				gpu.use_program(shader_bloom);
				gpu.uniform_int(shader_bloom, "bloom_texture", 1);
				gpu.active_texture1();
				gpu.bind_texture2d(last_bloom_fbo.textures[0].gpu_id);
				draw_texture(wb_camera.framebuffer.textures[0], {0, 0}, {platform.current_window_width, platform.current_window_height});

				// visualize bloom
				gpu.use_program(shader_texture_unlit);
				draw_texture(last_bloom_fbo.textures[0], {100, 100}, {400, 400});
			}
		}

		im_flush();
		debug_geo_flush();

		if post_render_proc != nil {
			post_render_proc();
		}
	}

	// do final gamma correction and draw to screen!
	gpu.use_program(shader_framebuffer_gamma_corrected);
	gpu.uniform_float(shader_framebuffer_gamma_corrected, "gamma", render_settings.gamma);
	gpu.uniform_float(shader_framebuffer_gamma_corrected, "exposure", render_settings.exposure);
	draw_texture(wb_camera.framebuffer.textures[0], {0, 0}, {platform.current_window_width, platform.current_window_height});

	// visualize depth buffer
	if false {
		if num_directional_lights > 0 {
			gpu.use_program(shader_depth);
			draw_texture(directional_light_cameras[0].framebuffer.textures[0], {0, 0}, {256, 256});
		}
	}

	imgui_render(true);
}

deinit_draw :: proc() {
	delete_camera(wb_camera);

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