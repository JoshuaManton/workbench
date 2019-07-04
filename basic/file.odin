package workbench

// "path/to/filename.txt" -> "filename"
get_file_name :: proc(filepath: string) -> (string, bool) {
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