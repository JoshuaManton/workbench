package workbench

get_file_extension :: proc(file: string) -> (string, bool) {
	if idx, ok := find_from_right(file, '.'); ok {
		extension := file[idx:];
		return extension, true;
	}
	return "", false;
}