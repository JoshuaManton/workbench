package workbench

      import "core:math/rand"

using import "math"
using import "types"

rstate: rand.Rand;

init_random :: inline proc(seed: u64) {
	rand.init(&rstate, seed);
}

random_range :: inline proc(min, max: f32) -> f32 {
	value := random01();
	value = lerp(min, max, value);
	return value;
}

random_range_int :: inline proc(min, max: int) -> int {
	value := random01i();
	value = lerp(min, max, value);
	return value;
}

random01 :: inline proc() -> f32 {
	value := rand.float32(&rstate);
	return value;
}

random01i :: inline proc() -> int {
	return int(rand.int31(&rstate));
}

random_u64 :: inline proc() -> u64 {
	value := rand.uint64(&rstate);
	return value;
}

random_vec3 :: inline proc() -> Vec3 {
	return Vec3{random01(), random01(), random01()};
}

random_color :: inline proc() -> Colorf {
	return Colorf{random01(), random01(), random01(), 1};
}

random_unit_vector :: inline proc() -> Vec3 {
	v := Vec3{random_range(-1, 1), random_range(-1, 1), random_range(-1, 1)};
	return v;
}