package workbench;

import "core:os"
import "core:fmt";
import "core:strings";
import "core:sys/unix";
import "basic";

delete_file :: proc(path : string) -> bool {
    return false;
}

is_path_valid :: proc(str : string) -> bool {
    return false;
}

is_directory :: proc(str : string) -> bool {
    return false;
}

create_directory :: proc(name : string) -> bool {
    return false;
}

//NOTE(Hoej): skips . and ..
//TODO(Hoej): Full path doesn't really mean full path atm
//            It really just means prepend dir_path to the filename
//NOTE(Hoej): Only ASCII
get_all_entries_strings_in_directory :: proc(_dir_path : string, full_path : bool = false) -> []string {
    return {};
}

get_file_size :: proc(path : string) -> int {
    return 0;
}
