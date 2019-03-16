package workbench

get_file_extension :: proc(file: string) -> (string, bool) { // "filename.txt" -> ".txt"
	if idx, ok := find_from_right(file, '.'); ok {
		extension := file[idx:];
		return extension, true;
	}
	return "", false;
}

get_file_directory :: proc(file: string) -> (string, bool) { // "path/to/filename.txt" -> "path/to/"
	if idx, ok := find_from_right(file, '/'); ok {
		dirpath := file[:idx+1];
		return dirpath, true;
	}
	return "", false;
}