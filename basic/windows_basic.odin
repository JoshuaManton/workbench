package basic

import "core:os"
import "core:strings"
import "core:fmt"
import "core:mem"
import rt "core:runtime"
import "../math"

when os.OS == "windows" {
	import "core:sys/win32"

	get_all_filepaths_recursively :: proc(path: string) -> []string {
		results: [dynamic]string;
		path_c := strings.clone_to_cstring(path);
		defer delete(path_c);
		recurse(path_c, &results);

		recurse :: proc(path: cstring, results: ^[dynamic]string) {
			query_path := strings.clone_to_cstring(fmt.tprint(path, "/*.*"));
			defer delete(query_path);

			ffd: win32.Find_Data_A;
			hnd := win32.find_first_file_a(query_path, &ffd);
			defer win32.find_close(hnd);

			if hnd == win32.INVALID_HANDLE {
				fmt.println(pretty_location(#location()), "Path not found: ", query_path);
				return;
			}

			for {
				file_name := cast(cstring)&ffd.file_name[0];

				if file_name != "." && file_name != ".." {
					if (ffd.file_attributes & win32.FILE_ATTRIBUTE_DIRECTORY) > 0 {
						nested_path := strings.clone_to_cstring(fmt.tprint(path, "/", cast(cstring)&ffd.file_name[0]));
						defer delete(nested_path);
						recurse(nested_path, results);
					}
					else {
						str := strings.clone(fmt.tprint(path, "/", file_name));
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

	get_all_filepaths :: proc(path: string) -> []string {
		results: [dynamic]string;

		path_c := strings.clone_to_cstring(path);
		defer delete(path_c);

		query_path := strings.clone_to_cstring(fmt.tprint(path, "/*.*"));
		defer delete(query_path);

		ffd: win32.Find_Data_A;
		hnd := win32.find_first_file_a(query_path, &ffd);
		defer win32.find_close(hnd);

		if hnd == win32.INVALID_HANDLE {
			fmt.println(pretty_location(#location()), "Path not found: ", query_path);
			return nil;
		}

		for {
			file_name := cast(cstring)&ffd.file_name[0];

			if file_name != "." && file_name != ".." {
				if (ffd.file_attributes & win32.FILE_ATTRIBUTE_DIRECTORY) == 0 {
					str := strings.clone(fmt.tprint(path, "/", file_name));
					append(&results, str);
				}
			}

			if !win32.find_next_file_a(hnd, &ffd) {
				break;
			}
		}

		return results[:];
	}

	Path :: struct {
		path: string,
		file_name: string,
		is_directory: bool,
		parent_dir: string,
		extension: string,
	}

	get_all_paths :: proc(path: string) -> []Path {
		results: [dynamic]Path;
		path_c := strings.clone_to_cstring(path);
		defer delete(path_c);

		query_path := strings.clone_to_cstring(fmt.tprint(path, "/*.*"));
		defer delete(query_path);

		ffd: win32.Find_Data_A;
		hnd := win32.find_first_file_a(query_path, &ffd);
		defer win32.find_close(hnd);

		if hnd == win32.INVALID_HANDLE {
			fmt.println(pretty_location(#location()), "Path not found: ", query_path);
			return {};
		}

		for {
			file_name := cast(cstring)&ffd.file_name[0];

			if file_name != "." && file_name != ".." {
				is_dir := false;
				if (ffd.file_attributes & win32.FILE_ATTRIBUTE_DIRECTORY) > 0 {
					is_dir = true;
				}

				str := strings.clone(fmt.tprint(path, "/", file_name));
				extension, eok := get_file_extension(str);
				append(&results, Path{
					str,
					fmt.tprint(file_name),
					is_dir,
					path,
					extension
				});
			}

			if !win32.find_next_file_a(hnd, &ffd) {
				break;
			}
		}

		return results[:];
	}
}