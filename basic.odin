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

remove :: proc[remove_value, remove_ptr, remove_by_index];
remove_value :: proc(array: ^[dynamic]$T, to_remove: ^T) {
	for i in 0..len(array) {
		item := &array[i];
		if item == to_remove {
			array[i] = array[len(array)-1];
			pop(array);
			return;
		}
	}
}
remove_ptr :: proc(array: ^[dynamic]^$T, to_remove: ^T) {
	for i in 0..len(array) {
		item := array[i];
		if item == to_remove {
			array[i] = array[len(array)-1];
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
// Strings
//

is_digit :: proc[is_digit_u8, is_digit_rune];
is_digit_u8 :: inline proc(r: u8) -> bool { return '0' <= r && r <= '9' }
is_digit_rune :: inline proc(r: rune) -> bool { return '0' <= r && r <= '9' }

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

string_starts_with :: proc(str: string, start: string) -> bool {
	if len(str) > len(start) do return false;
	for _, i in start {
		if str[i] != start[i] do return false;
	}

	return true;
}

split_by_lines :: proc(str: string, _array : ^[dynamic]string = nil) -> [dynamic]string {
	array_ptr := _array;
	array: [dynamic]string;

	if array_ptr == nil {
		array = make([dynamic]string, 0, 100);
		array_ptr = &array;
	}

	start := -1;
	for i in 0..len(str) {
		if str[i] == '\n' || str[i] == '\r' {
			if start != -1 {
				append(array_ptr, cast(string)str[start..i]);
			}
			start = -1;
		}
		else {
			if start == -1 {
				start = i;
			}
		}
	}

	return array_ptr^;
}