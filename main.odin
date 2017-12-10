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

all_sprites := make([dynamic]Sprite, 0, 10);

init :: proc() {
	append(&all_sprites, load_sprite("guy.png"));
	append(&all_sprites, load_sprite("plane.png"));
	append(&all_sprites, load_sprite("j.png"));
	append(&all_sprites, load_sprite("plane_red.png"));
	append(&all_sprites, load_sprite("block.png"));
	append(&all_sprites, load_sprite("crate.png"));
	append(&all_sprites, load_sprite("thing.png"));

	sprite_idx := 0;

	for i in 0..100_000 {
		append(&entities, Entity{Vector2{0, 0}, Vector2{100, 100}, all_sprites[sprite_idx]});
		sprite_idx = (sprite_idx + 1) % len(all_sprites);
	}
}

update :: proc() {
	for i in 0..len(entities) {
		using entity := entities[i];
		x := cast(f32)sin(glfw.GetTime() + cast(f64)i) * cast(f32)i;
		y := cast(f32)cos(glfw.GetTime() + cast(f64)i) * cast(f32)i;
		position = Vector2{x, y} * 5;
		submit_sprite(sprite, position, scale);
	}

	flush_sprites();
}