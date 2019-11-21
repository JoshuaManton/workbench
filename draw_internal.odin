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

NUM_SHADOW_MAPS :: 4;

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
		PUSH_CAMERA(&wb_camera);

		if workspace.render != nil {
			workspace.render(lossy_delta_time);
			gpu.log_errors(workspace.name);
		}

		cascade_positions := [NUM_SHADOW_MAPS+1]f32{0, 20, 80, 200, 1000};

		// draw shadow maps
		{
			assert(num_directional_lights == 1);
			for light_idx in 0..<num_directional_lights {

				// logln("-------------------------");

				for map_idx in 0..<NUM_SHADOW_MAPS {
					frustum_corners := [8]Vec3 {
						{-1,  1, -1},
						{ 1,  1, -1},
						{ 1, -1, -1},
						{-1, -1, -1},
						{-1,  1,  1},
						{ 1,  1,  1},
						{ 1, -1,  1},
						{-1, -1,  1},
					};



					// get the cascade projection from the main camera and make a vp matrix
					cascade_proj := perspective(to_radians(wb_camera.size), wb_camera.aspect, wb_camera.near_plane + cascade_positions[map_idx], min(wb_camera.far_plane, wb_camera.near_plane + cascade_positions[map_idx+1]));
					cascade_view := construct_view_matrix(&wb_camera);
					cascade_viewport_to_world := mat4_inverse(mul(cascade_proj, cascade_view));

					transform_point :: proc(matrix: Mat4, pos: Vec3) -> Vec3 {
						pos4 := to_vec4(pos);
						pos4.w = 1;
						pos4 = mul(matrix, pos4);
						if pos4.w != 0 do pos4 /= pos4.w;
						return to_vec3(pos4);
					}



					// calculate center point and radius of frustum
					center_point := Vec3{};
					for _, idx in frustum_corners {
						frustum_corners[idx] = to_vec3(transform_point(cascade_viewport_to_world, frustum_corners[idx]));
						center_point += frustum_corners[idx];
					}
					center_point /= len(frustum_corners);
					radius := length(frustum_corners[0] - frustum_corners[6]) / 2;



					light_rotation := directional_light_rotations[light_idx];
					light_direction := quaternion_forward(light_rotation);

					texels_per_unit := SHADOW_MAP_DIM / (radius * 2);
					scale_matrix := identity(Mat4);
					scale_matrix = mat4_scale(scale_matrix, Vec3{texels_per_unit, texels_per_unit, texels_per_unit});
					scale_matrix = mul(scale_matrix, quat_to_mat4(inverse(light_rotation))); // todo(josh): not sure about this inverse()

					light_point := center_point - light_direction * radius;

					draw_debug_box(light_point, Vec3{1/texels_per_unit, 1/texels_per_unit, 1/texels_per_unit}, COLOR_RED, light_rotation);
					light_point_texel_space := transform_point(scale_matrix, light_point);
					light_point_texel_space.x = round(light_point_texel_space.x);
					light_point_texel_space.y = round(light_point_texel_space.y);
					light_point_texel_space.z = round(light_point_texel_space.z);
					light_point = transform_point(mat4_inverse(scale_matrix), light_point_texel_space);
					draw_debug_box(light_point, Vec3{1/texels_per_unit, 1/texels_per_unit, 1/texels_per_unit}, COLOR_GREEN, light_rotation);

					// logln("radius: ", radius);

					// logln(center_point);
					// logln(light_point);

					// position the shadow camera looking at that point
					light_camera := get_directional_light_camera();
					light_camera.position = light_point;
					light_camera.rotation = light_rotation;
					light_camera.size = radius;
					light_camera.far_plane = radius * 2;

					PUSH_CAMERA(light_camera);
					// gpu.cull_face(.Front);

					depth_shader := get_shader(&wb_catalog, "depth");
					gpu.use_program(depth_shader);

					rendermode_world();

					for info in wb_camera.render_queue {
						using info;

						draw_model(model, position, scale, rotation, texture, color, true, animation_state);
					}
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
				gpu.uniform_float_array(shader, "cascade_distances", cascade_positions[1:]);

				assert(NUM_SHADOW_MAPS == 4);
				tex_indices := [NUM_SHADOW_MAPS]i32{1, 2, 3, 4};
				gpu.uniform_int_array(shader, "shadow_maps", tex_indices[:]);
				light_matrices: [NUM_SHADOW_MAPS]Mat4;
				for map_idx in 0..<NUM_SHADOW_MAPS {
					light_camera := &unpooled_shadow_cameras[map_idx];

					gpu.active_texture(1 + cast(u32)map_idx);
					gpu.bind_texture2d(light_camera.framebuffer.textures[0].gpu_id);

					light_view := construct_view_matrix(light_camera);
					light_proj := construct_projection_matrix(light_camera);
					light_space := mul(light_proj, light_view);
					light_matrices[map_idx] = light_space;
				}
				gpu.uniform_mat4_array(shader, "cascade_light_space_matrices", light_matrices[:]);
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
	if render_settings.visualize_shadow_texture || true {
		if num_directional_lights > 0 {
			gpu.use_program(get_shader(&wb_catalog, "depth"));
			for map_idx in 0..<NUM_SHADOW_MAPS {
				draw_texture(unpooled_shadow_cameras[map_idx].framebuffer.textures[0], {256 * cast(f32)map_idx, 0}, {256 * (cast(f32)map_idx+1), 256});
			}
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