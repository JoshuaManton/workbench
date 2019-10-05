package workbench

using import "core:math"

using import "types"
using import "logging"
      import "gpu"

Render_Scene :: struct {
	queue: [dynamic]Model_Draw_Info,
}

Model_Draw_Info :: struct {
	model: gpu.Model,
	shader: gpu.Shader_Program,
	texture: gpu.Texture,
	material: Material,
	position: Vec3,
	scale: Vec3,
	rotation: Quat,
	color: Colorf,
}

render_scene: Render_Scene;

submit_model :: proc(model: gpu.Model, shader: gpu.Shader_Program, texture: gpu.Texture, material: Material, position: Vec3, scale: Vec3, rotation: Quat, color: Colorf) {
	append(&render_scene.queue, Model_Draw_Info{model, shader, texture, material, position, scale, rotation, color});
}

draw_render_scene :: proc() {
	for info in render_scene.queue {
		using info;

		gpu.use_program(shader);
		gpu.rendermode_world();

		flush_lights_to_shader(shader);
		set_current_material(shader, material);
		gpu.draw_model(model, position, scale, rotation, texture, color, true);
	}
}

clear_render_scene :: proc() {
	clear(&render_scene.queue);
}