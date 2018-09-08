package workbench

using import "core:math"

      import "core:math/rand"

rstate: rand.Rand;

_init_random_number_generator :: proc() {
	rand.init(&rstate);
}

random_range :: inline proc(min, max: f32) -> f32 {
	value := random01();
	value = lerp(min, max, value);
	return value;
}

random01 :: inline proc() -> f32 {
	value := rand.float32(&rstate);
	return value;
}

random_unit_vector :: proc() -> Vec3 {
	v := Vec3{random_range(-1, 1), random_range(-1, 1), random_range(-1, 1)};
	return v;
}