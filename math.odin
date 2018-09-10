package workbench

using import "core:math"

sin01 :: inline proc(t: f32) -> f32 {
	result := (sin(t)+1)/2;
	return result;
}

Vec2i :: distinct [2]int;
Vec3i :: distinct [3]int;
Vec4i :: distinct [4]int;

sqr_magnitude :: inline proc(a: Vec2) -> f32 do return dot(a, a);
magnitude :: inline proc(a: Vec2) -> f32 do return sqrt(dot(a, a));

move_towards :: proc[move_towards_vec2, move_towards_f32];

move_towards_vec2 :: proc(a, b: Vec2, step: f32) -> Vec2 {
	direction := b - a;
	mag := magnitude(direction);

	if mag <= step || mag == 0 {
		return b;
	}

	return a + direction / mag * step;
}

move_towards_f32 :: proc(a, b: f32, step: f32) -> f32 {
	result := a;
	if a > b {
		result -= step;
		if result < b {
			result = b;
		}
	}
	else if a < b {
		result += step;
		if result > b {
			result = b;
		}
	}

	return result;
}


rotate_vector :: proc(vec: Vec2, degrees: f32) -> Vec2 {
	s := sin(to_radians(degrees));
	c := cos(to_radians(degrees));

	tx := vec.x;
	ty := vec.y;
	x := (c * tx) - (s * ty);
	y := (s * tx) + (c * ty);

	return Vec2{x, y};
}




project :: inline proc(vec, normal: $T/[$N]$E) -> T {
    num := dot(normal, normal);
    if (num < F32_EPSILON) {
        return T{};
    }

    return normal * dot(vec, normal) / num;
}




clamp :: inline proc(_a, min, max: f32) -> f32 {
	a := _a;
	if a < min do a = min;
	if a > max do a = max;
	return a;
}





sqr :: inline proc(x: $T) -> T {
	return x * x;
}

distance :: inline proc(x, y: $T) -> f32 {
	diff := x - y;
	return sqrt(sqr(diff.x) + sqr(diff.y));
}

sqr_distance :: inline proc(x, y: $T) -> f32 {
	diff := x - y;
	return sqr(diff.x) + sqr(diff.y);
}

minv :: inline proc(args: ..$T) -> T {
	assert(len(args) > 0);
	current := args[0];
	for arg in args {
		if arg < current {
			current = arg;
		}
	}

	return current;
}

maxv :: inline proc(args: ..$T) -> T {
	assert(len(args) > 0);
	current := args[0];
	for arg in args {
		if arg > current {
			current = arg;
		}
	}
}

degrees_to_vector :: inline proc(degrees: f32) -> Vec2 {
	radians := to_radians(degrees);
	vec := Vec2{cos(radians), sin(radians)};
	return vec;
}

to_vec2 :: inline proc(a: $T/[$N]$E) -> Vec2 {
	result: Vec2;
	idx := 0;
	for idx < len(a) && idx < len(result) {
		result[idx] = a[idx];
		idx += 1;
	}
	return result;
}

to_vec3 :: inline proc(a: $T/[$N]$E) -> Vec3 {
	result: Vec3;
	idx := 0;
	for idx < len(a) && idx < len(result) {
		result[idx] = a[idx];
		idx += 1;
	}
	return result;
}

to_vec4 :: inline proc(a: $T/[$N]$E) -> Vec4 {
	result: Vec4;
	idx := 0;
	for idx < len(a) && idx < len(result) {
		result[idx] = a[idx];
		idx += 1;
	}
	return result;
}

translate :: proc(m: Mat4, v: Vec3) -> Mat4 {
	m[3][0] += v[0];
	m[3][1] += v[1];
	m[3][2] += v[2];
	return m;
}