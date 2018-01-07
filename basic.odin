import "core:fmt.odin"
import "core:mem.odin"

using import "core:math.odin"

//
// Arrays
//

inst :: proc[inst_no_value, inst_value];
inst_no_value :: inline proc(array: ^[dynamic]$T) -> ^T {
	length := append(array, T{});
	return &array[length-1];
}
inst_value :: inline proc(array: ^[dynamic]$T, value: T) -> ^T {
	length := append(array, value);
	return &array[length-1];
}

remove :: proc(array: ^[dynamic]$T, to_remove: T) {
	for item, index in array {
		if item == to_remove {
			array[index] = array[len(array)-1];
			pop(array);
			return;
		}
	}
}
remove_by_index :: proc(array: ^[dynamic]$T, to_remove: int) {
	array[to_remove] = array[len(array)-1];
	pop(array);
}
remove_all :: proc(array: ^[dynamic]$T, to_remove: T) {
	for item, index in array {
		if item == to_remove {
			array[index] = array[len(array)-1];
			pop(array);
		}
	}
}

//
// Enums
//

enum_length :: inline proc(enum_type: type) -> int {
	info := type_info_base(type_info_of(enum_type));
	return len(info.variant.(Type_Info_Enum).names);
}

enum_names :: inline proc(enum_type: type) -> []string {
	info := type_info_base(type_info_of(enum_type));
	return info.variant.(Type_Info_Enum).names;
}

//
// Math
//

sqr_magnitude :: inline proc(a: Vec2) -> f32 do return dot(a, a);
magnitude :: inline proc(a: Vec2) -> f32 do return sqrt(dot(a, a));

move_toward :: proc(a, b: Vec2, step: f32) -> Vec2 {
	direction := b - a;
	mag := magnitude(direction);

	if mag <= step || mag == 0 {
		return b;
	}

	return a + direction / mag * step;
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

minv :: inline proc(args: ...$T) -> T {
	assert(len(args) > 0);
	current := args[0];
	for arg in args {
		if arg < current {
			current = arg;
		}
	}

	return current;
}

maxv :: inline proc(args: ...$T) -> T {
	assert(len(args) > 0);
	current := args[0];
	for arg in args {
		if arg > current {
			current = arg;
		}
	}
}

to_vec3 :: proc[to_vec3_from_vec2, to_vec3_from_vec4];
to_vec3_from_vec2 :: inline proc(a: Vec2) -> Vec3 do return Vec3{a.x, a.y, 0};
to_vec3_from_vec4 :: inline proc(a: Vec4) -> Vec3 do return Vec3{a.x, a.y, a.z};

to_vec4 :: proc[to_vec4_from_vec2, to_vec4_from_vec3];
to_vec4_from_vec2 :: inline proc(a: Vec2) -> Vec4 do return Vec4{a.x, a.y, 0, 0};
to_vec4_from_vec3 :: inline proc(a: Vec3) -> Vec4 do return Vec4{a.x, a.y, a.z, 0};

translate :: proc(m: Mat4, v: Vec3) -> Mat4 {
	m[3][0] += v[0];
	m[3][1] += v[1];
	m[3][2] += v[2];
	return m;
}

//
// Logging
//

logln :: proc(args: ...any, location := #caller_location) {
	last_slash_idx: int;

	// Find the last slash in the file path
	last_slash_idx = len(location.file_path) - 1;
	for last_slash_idx >= 0 {
		if location.file_path[last_slash_idx] == '\\' {
			break;
		}

		last_slash_idx -= 1;
	}

	if last_slash_idx < 0 do last_slash_idx = 0;

	file := location.file_path[last_slash_idx+1..len(location.file_path)];

	fmt.println(...args);
	fmt.printf("%s:%d:%s()", file, location.line, location.procedure);
	fmt.printf("\n\n");
}

//
// Strings
//

MAX_C_STR_LENGTH :: 1024;
to_c_string :: proc(str: string) -> [MAX_C_STR_LENGTH]byte {
	assert(len(str) < MAX_C_STR_LENGTH);
	result: [MAX_C_STR_LENGTH]byte;
	mem.copy(&result[0], &str[0], len(str));
	result[len(str)] = 0;
	return result;
}

find_from_right :: proc(str: string, c: rune) -> (int, bool) {
	u := cast(u8)c;
	for i := len(str)-1; i >= 0; i -= 1 {
		if str[i] == u {
			return i, true;
		}
	}

	return 0, false;
}

find_from_left :: proc(str: string, c: rune) -> (int, bool) {
	u := cast(u8)c;
	for i := len(str)-1; i >= 0; i -= 1 {
		if str[i] == u {
			return i, true;
		}
	}

	return 0, false;
}