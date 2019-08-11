package basic

      import "core:fmt"
      import "core:mem"
using import "core:math"

//
// Arrays
//

instantiate :: proc{instantiate_no_value, instantiate_value};
instantiate_no_value :: inline proc(array: ^[dynamic]$T) -> ^T {
	length := append(array, T{});
	return &array[length-1];
}
instantiate_value :: inline proc(array: ^[dynamic]$T, value: T) -> ^T {
	append(array, value);
	return &array[len(array)-1];
}

array_contains :: proc(array: $T/[]$E, val: E) -> bool {
	for elem in array {
		if elem == val {
			return true;
		}
	}
	return false;
}

// get_by_name :: proc(array: []$T, name: string) -> ^T {
// 	for _, i in array {
// 		thing := &array[i];
// 		if thing.name == name do return thing;
// 	}
// 	return nil;
// }
// get_by_id :: proc(array: []$T, id: string) -> ^T {
// 	for _, i in array {
// 		thing := &array[i];
// 		if thing.id == id do return thing;
// 	}
// 	return nil;
// }

// remove :: proc{remove_value, remove_ptr};
// remove_value :: proc(array: ^[dynamic]$T, to_remove: ^T) {
// 	for _, i in array {
// 		item := &array[i];
// 		if item == to_remove {
// 			array[i] = array[len(array)-1];
// 			pop(array);
// 			return;
// 		}
// 	}
// }
// remove_ptr :: proc(array: ^[dynamic]^$T, to_remove: ^T) {
// 	for _, i in array {
// 		item := array[i];
// 		if item == to_remove {
// 			array[i] = array[len(array)-1];
// 			pop(array);
// 			return;
// 		}
// 	}
// }

last :: proc{last_dyn, last_slice, last_array};
last_dyn   :: inline proc(list: [dynamic]$T) -> ^T do return &list[len(list)-1];
last_slice :: inline proc(list: []$T)        -> ^T do return &list[len(list)-1];
last_array :: inline proc(list: [$N]$T)      -> ^T do return &list[N-1];

//
// Paths
//

// "path/to/filename.txt" -> "filename"
get_file_name :: proc(_filepath: string) -> (string, bool) {
	filepath := _filepath;
	if slash_idx, ok := find_from_right(filepath, '/'); ok {
		filepath = filepath[slash_idx+1:];
	}

	if dot_idx, ok := find_from_left(filepath, '.'); ok {
		name := filepath[:dot_idx];
		return name, true;
	}
	return "", false;
}

// "filename.txt" -> "txt"
get_file_extension :: proc(filepath: string) -> (string, bool) {
	if idx, ok := find_from_right(filepath, '.'); ok {
		extension := filepath[idx+1:];
		return extension, true;
	}
	return "", false;
}

// "path/to/filename.txt" -> "path/to/"
get_file_directory :: proc(filepath: string) -> (string, bool) {
	if idx, ok := find_from_right(filepath, '/'); ok {
		dirpath := filepath[:idx+1];
		return dirpath, true;
	}
	return "", false;
}

//
// Enums
//

enum_length :: inline proc($Enum_Type: typeid) -> int {
	info := type_info_base(type_info_of(Enum_Type));
	return len(info.variant.(Type_Info_Enum).names);
}

enum_names :: inline proc($Enum_Type: typeid) -> []string {
	info := type_info_base(type_info_of(Enum_Type));
	return info.variant.(Type_Info_Enum).names;
}

//
// Strings
//

is_whitespace :: inline proc(c: byte) -> bool {
	switch c {
		case ' ':  return true;
		case '\r': return true;
		case '\n': return true;
		case '\t': return true;
	}

	return false;
}

trim_whitespace :: proc(text: string) -> string {
	if len(text) == 0 do return text;
	start := 0;
	for is_whitespace(text[start]) do start += 1;
	end := len(text);
	for is_whitespace(text[end - 1]) do end -= 1;

	new_str := text[start:end];
	return new_str;
}

is_digit :: proc{is_digit_u8, is_digit_rune};
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
	if len(str) < len(start) do return false;
	for _, i in start {
		if str[i] != start[i] do return false;
	}

	return true;
}

// note(josh): returned string is tprint'ed, save manually on user-side if persistence is needed
string_to_lower :: proc(str: string) -> string {
	lower := fmt.tprint(str);
	for r, i in lower {
		switch r {
			case 'A'..'Z': {
				lower[i] += 'a'-'A';
			}
		}
	}
	return lower;
}

split_by_rune :: proc(str: string, split_on: rune, _buffer: ^[$N]string) -> []string {
	buffer := _buffer;
	cur_slice := 0;
	start := 0;
	for b, i in str {
		if b == split_on {
			assert(cur_slice < len(buffer));
			section := str[start:i];
			buffer[cur_slice] = section;
			cur_slice += 1;
			start = i + 1;
		}
	}

	assert(cur_slice < len(buffer));
	section := str[start:];
	buffer[cur_slice] = section;
	cur_slice += 1;

	return buffer[:cur_slice];
}

split_by_lines :: proc(str: string) -> []string /* @Alloc */ {
	array: [dynamic]string;
	start := -1;
	for _, i in str {
		if str[i] == '\n' || str[i] == '\r' {
			if start != -1 {
				append(&array, cast(string)str[start:i]);
			}
			start = -1;
		}
		else {
			if start == -1 {
				start = i;
			}
		}
	}

	return array[:];
}

file_from_path :: proc(path: string) -> string {
	file := path;
	start := 0;
	end := len(file);

	if last_slash_idx, ok := find_from_right(file, '/'); ok {
		start = last_slash_idx;
	}

	if dot, ok := find_from_right(file, '.'); ok {
		end = dot;
	}

	file = file[start+1:end];

	return file;
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