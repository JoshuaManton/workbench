package workbench

using import "math"
using import "types"
using import "logging"
      import "gpu"

Render_Scene :: struct {
	queue: [dynamic]Model_Draw_Info,
}

render_scene: Render_Scene;


draw_render_scene :: proc(queue: []Model_Draw_Info, $do_lighting: bool, $do_shader_override: bool, shader_override: gpu.Shader_Program = 0) {
	when do_shader_override {
		assert(shader_override != 0);
		gpu.use_program(shader_override);
	}
	else {
		assert(shader_override == 0);
	}

	rendermode_world();

	for info in queue {
		using info;

		when !do_shader_override {
			gpu.use_program(shader);
		}

		when do_lighting {
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
		}

		draw_model(model, position, scale, rotation, texture, color, true, animation_state);
	}
}