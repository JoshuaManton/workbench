package basic

import "core:os"
import "core:strings"
import "core:fmt"
import "core:mem"
import rt "core:runtime"
import "../math"

when os.OS == "linux" {
	get_all_filepaths_recursively :: proc(path: string) -> []string {
		unimplemented();
	}

	get_all_filepaths :: proc(path: string) -> []string {
		unimplemented();
	}

	Path :: struct {
		path: string,
		file_name: string,
		is_directory: bool,
		parent_dir: string,
		extension: string,
	}

	get_all_paths :: proc(path: string) -> []Path {
		unimplemented();
	}
}