package basic

      import "core:sys/win32"
      import "core:strings"
using import "core:fmt"
      import "core:mem"
      import rt "core:runtime"
using import "../math"

//
// Arrays
//

instantiate :: proc{instantiate_no_value, instantiate_value};
instantiate_no_value :: inline proc(array: ^[dynamic]$E) -> ^E {
	length := append(array, E{});
	return &array[length-1];
}
instantiate_value :: inline proc(array: ^[dynamic]$E, value: E) -> ^E {
	append(array, value);
	return &array[len(array)-1];
}

array_contains :: proc(array: []$E, val: E) -> bool {
	for elem in array {
		if elem == val {
			return true;
		}
	}
	return false;
}

unordered_remove_value :: proc(array: ^[dynamic]$E, to_remove: E) {
	for item, idx in array {
		if item == to_remove {
			array[idx] = array[len(array)-1];
			pop(&array);
			return;
		}
	}
}
remove_ptr :: proc(array: ^[dynamic]^$E, to_remove: ^E) {
	for _, i in array {
		item := array[i];
		if item == to_remove {
			array[i] = array[len(array)-1];
			pop(array);
			return;
		}
	}
}

last :: inline proc(slice: []$E) -> ^E {
	return &slice[len(slice)-1];
}

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

// "path/to/filename.txt" -> "filename.txt"
get_file_name_and_extension :: proc(filepath: string) -> (string, bool) {
	if slash_idx, ok := find_from_right(filepath, '/'); ok {
		filename := filepath[slash_idx+1:];
		return filename, true;
	}
	return "", false;
}

// "path/to/filename.txt" -> "path/to"
get_file_directory :: proc(filepath: string) -> (string, bool) {
	if idx, ok := find_from_right(filepath, '/'); ok {
		dirpath := filepath[:idx];
		return dirpath, true;
	}
	return "", false;
}

get_all_filepaths_recursively :: proc(path: string) -> []string {
	results: [dynamic]string;
	path_c := strings.clone_to_cstring(path);
	defer delete(path_c);
	recurse(path_c, &results);

	recurse :: proc(path: cstring, results: ^[dynamic]string) {
		query_path := strings.clone_to_cstring(tprint(path, "/*.*"));
		defer delete(query_path);

		ffd: win32.Find_Data_A;
		hnd := win32.find_first_file_a(query_path, &ffd);
		defer win32.find_close(hnd);

		if hnd == win32.INVALID_HANDLE {
			println(pretty_location(#location()), "Path not found: ", query_path);
			return;
		}

		for {
			file_name := cast(cstring)&ffd.file_name[0];

			if file_name != "." && file_name != ".." {
				if (ffd.file_attributes & win32.FILE_ATTRIBUTE_DIRECTORY) > 0 {
					nested_path := strings.clone_to_cstring(tprint(path, "/", cast(cstring)&ffd.file_name[0]));
					defer delete(nested_path);
					recurse(nested_path, results);
				}
				else {
					str := strings.clone(tprint(path, "/", file_name));
					append(results, str);
				}
			}

			if !win32.find_next_file_a(hnd, &ffd) {
				break;
			}
		}
	}

	return results[:];
}

Path :: struct {
	path: string,
	file_name: string,
	is_directory: bool,
}

get_all_paths :: proc(path: string) -> []Path {
	results: [dynamic]Path;
	path_c := strings.clone_to_cstring(path);
	defer delete(path_c);

	query_path := strings.clone_to_cstring(tprint(path, "/*.*"));
	defer delete(query_path);

	ffd: win32.Find_Data_A;
	hnd := win32.find_first_file_a(query_path, &ffd);
	defer win32.find_close(hnd);

	if hnd == win32.INVALID_HANDLE {
		println(pretty_location(#location()), "Path not found: ", query_path);
		return {};
	}

	for {
		file_name := cast(cstring)&ffd.file_name[0];

		if file_name != "." && file_name != ".." {
			is_dir := false;
			if (ffd.file_attributes & win32.FILE_ATTRIBUTE_DIRECTORY) > 0 {
				is_dir = true;
			}

			str := strings.clone(tprint(path, "/", file_name));
			append(&results, Path{ str, tprint(file_name), is_dir});
		}

		if !win32.find_next_file_a(hnd, &ffd) {
			break;
		}
	}

	return results[:];
}

//
// Location
//

pretty_location :: inline proc(location: rt.Source_Code_Location) -> string {
	file, ok := get_file_name(location.file_path);
	assert(ok);
	return fmt.tprintf("<%s.%s():%d> ", file, location.procedure, location.line);
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
	for is_whitespace(text[end-1]) do end -= 1;

	new_str := text[start:end];
	return new_str;
}

is_digit :: proc{is_digit_u8, is_digit_rune};
is_digit_u8 :: inline proc(r: u8) -> bool { return '0' <= r && r <= '9' }
is_digit_rune :: inline proc(r: rune) -> bool { return '0' <= r && r <= '9' }

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
	lower := transmute([]u8)fmt.tprint(str);
	for r, i in lower {
		switch r {
			case 'A'..'Z': {
				lower[i] += 'a'-'A';
			}
		}
	}
	return transmute(string)lower;
}

string_ends_with :: proc(str: string, end: string) -> bool {
	if len(str) < len(end) do return false;
	j := len(str)-1;
	for i := len(end)-1; i >= 0; i -= 1 {
		if str[j] != end[i] do return false;
		j -= 1;
	}
	return true;
}

@(deferred_out=_free_temp_cstring)
TEMP_CSTRING :: proc(str: string) -> cstring {
	cstr := strings.clone_to_cstring(str);
	return cstr;
}
_free_temp_cstring :: proc(cstr: cstring) {
	delete(cstr);
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