import "core:fmt.odin"
import "core:mem.odin"
import "core:math.odin"

//
// Array stuff
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
// Math
//

sqr_magnitude :: inline proc(a: math.Vec2) -> f32 do return math.dot(a, a);
magnitude :: inline proc(a: math.Vec2) -> f32 do return math.sqrt(math.dot(a, a));

move_toward :: proc(x, y: math.Vec2, step: f32) -> math.Vec2 {
	a := y - x;
	mag := magnitude(a);

	if mag <= step || mag == 0 {
		return y;
	}

	return x + a / mag * step;
}

distance :: inline proc(x, y: $T) -> f32 {
	diff := x - y;
	return math.sqrt(sqr(diff.x) + sqr(diff.y));
}

sqr :: inline proc(x: $T) -> T {
	return x * x;
}

sqr_distance :: inline proc(x, y: $T) -> f32 {
	diff := x - y;
	return sqr(diff.x) + sqr(diff.y);
}

//
// Logging
//

logln :: proc[logln1, logln2, logln3, logln4, logln5, logln6, logln7];
logln1 :: proc(arg1: any, location := #caller_location) {
	_logln(location, arg1);
}
logln2 :: proc(arg1: any, arg2: any, location := #caller_location) {
	_logln(location, arg1, arg2);
}
logln3 :: proc(arg1: any, arg2: any, arg3: any, location := #caller_location) {
	_logln(location, arg1, arg2, arg3);
}
logln4 :: proc(arg1: any, arg2: any, arg3: any, arg4: any, location := #caller_location) {
	_logln(location, arg1, arg2, arg3, arg4);
}
logln5 :: proc(arg1: any, arg2: any, arg3: any, arg4, arg5: any, location := #caller_location) {
	_logln(location, arg1, arg2, arg3, arg4, arg5);
}
logln6 :: proc(arg1: any, arg2: any, arg3: any, arg4, arg5, arg6: any, location := #caller_location) {
	_logln(location, arg1, arg2, arg3, arg4, arg5, arg6);
}
logln7 :: proc(arg1: any, arg2: any, arg3: any, arg4, arg5, arg6, arg7: any, location := #caller_location) {
	_logln(location, arg1, arg2, arg3, arg4, arg5, arg6, arg7);
}
_logln :: proc(location: Source_Code_Location, args: ...any) {
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