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
	plane_sprite := load_sprite("tall_guy.png");

	append(&entities, Entity{Vector2{0, 0}, Vector2{1, 1}, guy_sprite});
	append(&entities, Entity{Vector2{5, 5}, Vector2{1, 1}, plane_sprite});
}

update :: proc() {
	for i in 0..len(entities) {
		using entity := entities[i];
		submit_sprite(sprite, position, scale);
	}

	flush_sprites();
}