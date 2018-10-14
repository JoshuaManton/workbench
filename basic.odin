package workbench

      import "core:fmt"
      import "core:mem"

//
// Arrays
//

get_by_name :: proc(array: []$T, name: string) -> ^T {
	for _, i in array {
		thing := &array[i];
		if thing.name == name do return thing;
	}
	return nil;
}
get_by_id :: proc(array: []$T, id: string) -> ^T {
	for _, i in array {
		thing := &array[i];
		if thing.id == id do return thing;
	}
	return nil;
}

inst :: proc[inst_no_value, inst_value];
inst_no_value :: inline proc(array: ^[dynamic]$T) -> ^T {
	length := append(array, T{});
	return &array[length-1];
}
inst_value :: inline proc(array: ^[dynamic]$T, value: T) -> ^T {
	length := append(array, value);
	return &array[length-1];
}

remove :: proc[remove_value, remove_ptr];
remove_value :: proc(array: ^[dynamic]$T, to_remove: ^T) {
	for _, i in array {
		item := &array[i];
		if item == to_remove {
			array[i] = array[len(array)-1];
			pop(array);
			return;
		}
	}
}
remove_ptr :: proc(array: ^[dynamic]^$T, to_remove: ^T) {
	for _, i in array {
		item := array[i];
		if item == to_remove {
			array[i] = array[len(array)-1];
			pop(array);
			return;
		}
	}
}
remove_at :: proc(array: ^[dynamic]$T, to_remove: int) {
	array[to_remove] = array[len(array)-1];
	pop(array);
}
remove_all :: proc(array: ^[dynamic]$T, to_remove: T) {
	assert(false, "this proc seems weird");
	// not sure about this, I think we skip elements when we copy from the end into a remove element
	for item, index in array {
		if item == to_remove {
			array[index] = array[len(array)-1];
			pop(array);
		}
	}
}

last :: proc[last_dyn, last_slice, last_array];
last_dyn   :: inline proc(list: [dynamic]$T) -> ^T do return &list[len(list)-1];
last_slice :: inline proc(list: []$T)        -> ^T do return &list[len(list)-1];
last_array :: inline proc(list: [$N]$T)      -> ^T do return &list[N-1];

//
// Equals
//

equals :: proc[equals_vec2i, equals_colori];

equals_vec2i :: inline proc(a, b: Vec2i) -> bool {
	return a.x == b.x && a.y == b.y;
}

equals_colori :: inline proc(a, b: Colori) -> bool {
	return a.r == b.r && a.g == b.g && a.b == b.b && a.a == b.a;
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
	for is_whitespace(text[start]) do end -= 1;

	new_str := text[start:end];
	return new_str;
}

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
	if len(str) < len(start) do return false;
	for _, i in start {
		if str[i] != start[i] do return false;
	}

	return true;
}

split_by_rune :: proc(str: string, split_on: rune, buffer: ^[$N]string) -> []string {
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

split_by_lines :: proc(str: string) -> [dynamic]string {
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

	return array;
}

file_from_path :: proc(path: string) -> string {
	file := path;
	start := 0;
	end := len(file);

	if last_slash_idx, ok := find_from_right(file, '\\'); ok {
		start = last_slash_idx;
	}

	if dot, ok := find_from_right(file, '.'); ok {
		end = dot;
	}

	file = file[start+1:end];

	return file;
}