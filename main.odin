using import "core:fmt.odin"
using import "shared:sd/math.odin"
using import "shared:sd/basic.odin"

import "shared:odin-glfw/glfw.odin"
using import "engine.odin"
using import "rendering.odin"

Entity :: struct {
	position: Vec2,
	scale: Vec2,
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
	config.camera_size = 1000;

	engine.start(config);
}

all_sprites := make([dynamic]Sprite, 0, 10);

init :: proc() {
	append(&all_sprites, load_sprite("guy.png"));

	sprite_idx := 0;

	for i in 0..100 {
		append(&entities, Entity{{0, 0}, {1, 1}, all_sprites[sprite_idx]});
		sprite_idx = (sprite_idx + 1) % len(all_sprites);
	}
}

update :: proc() {
	for i in 0..len(entities) {
		using entity := entities[i];
		x := cast(f32)sin(glfw.GetTime() + cast(f64)i) * cast(f32)i;
		y := cast(f32)cos(glfw.GetTime() + cast(f64)i) * cast(f32)i;
		position = Vec2{x, y} * 10;
		submit_sprite(sprite, position, scale);
	}

	flush_sprites();
}
