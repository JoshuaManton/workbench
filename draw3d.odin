package workbench

using import "math"
using import "types"
using import "logging"
      import "gpu"

Render_Scene :: struct {
	queue: [dynamic]Model_Draw_Info,
}

Model_Draw_Info :: struct {
	model: Model,
	shader: gpu.Shader_Program,
	texture: Texture,
	material: Material,
	position: Vec3,
	scale: Vec3,
	rotation: Quat,
	color: Colorf,
	cast_shadows: bool,
}

render_scene: Render_Scene;

submit_model :: proc(model: Model, shader: gpu.Shader_Program, texture: Texture, material: Material, position: Vec3, scale: Vec3, rotation: Quat, color: Colorf, cast_shadows := true) {
	append(&render_scene.queue, Model_Draw_Info{model, shader, texture, material, position, scale, rotation, color, cast_shadows});
}

draw_render_scene :: proc($do_lighting: bool, $do_shader_override: bool, shader_override: gpu.Shader_Program = 0) {
	when do_shader_override {
		assert(shader_override != 0);
		gpu.use_program(shader_override);
	}
	else {
		assert(shader_override == 0);
	}

	rendermode_world();

	for info in render_scene.queue {
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
				gpu.uniform1i(program, "shadow_map", 1);
				gpu.active_texture1();
				gpu.bind_texture2d(light_camera.framebuffer.texture.gpu_id);

				light_view := construct_view_matrix(light_camera);
				light_proj := construct_projection_matrix(light_camera);
				light_space := mul(light_proj, light_view);
				gpu.uniform_matrix4fv(program, "light_space_matrix", 1, false, &light_space[0][0]);
			}
		}

		draw_model(model, position, scale, rotation, texture, color, true);
	}
}

clear_render_scene :: proc() {
	clear(&render_scene.queue);
}