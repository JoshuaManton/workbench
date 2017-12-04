using import "core:fmt.odin"
using import "shared:sd/math.odin"
using import "shared:sd/basic.odin"

import "shared:odin-glfw/glfw.odin"
using import "engine.odin"
using import "rendering.odin"

Entity :: struct {
	position: Vector2,
	scale: Vector2,
	sprite: Sprite,
}

entities := make([dynamic]Entity, 0, 10);

main :: proc() {
	config: Engine_Config;
	config.window_name = "Odin GL Engine";
	config.init_proc = init;
	config.update_proc = update;
	config.window_width = 1600;
	config.window_height = 900;

	engine.start(config);
}

init :: proc() {
	guy_sprite := load_sprite("guy.png");

	for i in 0..5000 {
		append(&entities, Entity{Vector2{cast(f32)i*2, cast(f32)i*2}, Vector2{1, 1}, guy_sprite});
	}
}

update :: proc() {
	for i in 0..len(entities) {
		using entity := entities[i];
		x := cast(f32)sin(glfw.GetTime() + cast(f64)i) * cast(f32)i;
		y := cast(f32)cos(glfw.GetTime() + cast(f64)i) * cast(f32)i;
		position = Vector2{x, y} * 0.1;
		//draw_sprite(sprite, position, scale);

		submit_sprite(sprite, position, scale);
	}

	//swap_buffers();

	flush_sprites();
}