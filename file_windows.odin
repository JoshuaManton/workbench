/*
 *  @Name:     file_windows
 *
 *  @Author:   Mikkel Hjortshoej
 *  @Email:    hoej@northwolfprod.com
 *  @Creation: 29-10-2017 20:14:21
 *
 *  @Last By:   Mikkel Hjortshoej
 *  @Last Time: 01-08-2018 23:10:11 UTC+1
 *
 *  @Description:
 *
 */

 // TODO(jake) support multiple platforms

package workbench;

import "core:fmt";
import "core:strings";
import "core:sys/win32";
import "basic";

odin_to_wchar_string :: proc(str : string, loc := #caller_location) -> win32.Wstring {
    cstr := basic.TEMP_CSTRING(str);

    olen := i32(len(str) * size_of(byte));
    wlen := win32.multi_byte_to_wide_char(win32.CP_UTF8, 0, cstr, olen, nil, 0);
    buf := make([]u16, int(wlen * size_of(u16) + 1));
    ptr := win32.Wstring(&buf[0]);
    win32.multi_byte_to_wide_char(win32.CP_UTF8, 0, cstr, olen, ptr, wlen);

    return ptr;
}

delete_file :: proc(path : string) -> bool {
    wc_str := odin_to_wchar_string(path); defer free(wc_str);
    res := win32.delete_file_w(wc_str);
    return bool(res);
}

is_path_valid :: proc(str : string) -> bool {
    wc_str := odin_to_wchar_string(str); defer free(wc_str);
    attr := win32.get_file_attributes_w(wc_str);
    return i32(attr) != win32.INVALID_FILE_ATTRIBUTES;
}

is_directory :: proc(str : string) -> bool {
    wc_str := odin_to_wchar_string(str); defer free(wc_str);
    attr := win32.get_file_attributes_w(wc_str);

    if i32(attr) == win32.INVALID_FILE_ATTRIBUTES {
        fmt.println(win32.get_last_error());
        return false;
    }

    return (attr & win32.FILE_ATTRIBUTE_DIRECTORY) == win32.FILE_ATTRIBUTE_DIRECTORY;
}

create_directory :: proc(name : string) -> bool {
    wc_str := odin_to_wchar_string(name); defer free(wc_str);
    res := win32.create_directory_w(wc_str, nil);
    return bool(res);
}

//NOTE(Hoej): skips . and ..
//TODO(Hoej): Full path doesn't really mean full path atm
//            It really just means prepend dir_path to the filename
//NOTE(Hoej): Only ASCII
get_all_entries_strings_in_directory :: proc(_dir_path : string, full_path : bool = false) -> []string {
    dir_path := _dir_path;
    path_buf : [win32.MAX_PATH]u8;

    if(dir_path[len(dir_path)-1] != '/' && dir_path[len(dir_path)-1] != '\\') {
        dir_path = fmt.bprintf(path_buf[:], "%s%r", dir_path, '\\');
    }
    fmt.bprintf(path_buf[:], "%s%r", dir_path, '*');

    find_data := win32.Find_Data_A{};
    file_handle := win32.find_first_file_a(cstring(&path_buf[0]), &find_data);

    skip_dot :: proc(c_str : []u8) -> bool {
        len := len(cstring(&c_str[0]));
        f := string(c_str[:len]);

        return f == "." || f == "..";
    }

    copy_file_name :: proc(c_str : cstring, path : string, full_path : bool) -> string {
        if !full_path {
            str := string(c_str);
            return strings.clone(str);
        } else {
            pathBuf := make([]u8, win32.MAX_PATH);
            return fmt.bprintf(pathBuf[:], "%s%s", path, string(c_str));
        }
    }

    count := 0;
    //Count
    if file_handle != win32.INVALID_HANDLE {
        if !skip_dot(find_data.file_name[:]) {
            count += 1;
        }

        for win32.find_next_file_a(file_handle, &find_data) == true {
            if skip_dot(find_data.file_name[:]) {
                continue;
            }
            count += 1;
        }
    }

    //copy file names
    result := make([]string, count);
    i := 0;
    file_handle = win32.find_first_file_a(cstring(&path_buf[0]), &find_data);
    if file_handle != win32.INVALID_HANDLE {
        if !skip_dot(find_data.file_name[:]) {
            result[i] = copy_file_name(cstring(&find_data.file_name[0]), dir_path, full_path);
            i += 1;
        }

        for win32.find_next_file_a(file_handle, &find_data) == true {
            if skip_dot(find_data.file_name[:]) {
                continue;
            }
            result[i] = copy_file_name(cstring(&find_data.file_name[0]), dir_path, full_path);
            i += 1;
        }
    }

    win32.find_close(file_handle);
    return result;
}

get_file_size :: proc(path : string) -> int {
    wc_str := odin_to_wchar_string(path); defer free(wc_str);
    out : i64;
    h := win32.create_file_w(wc_str,
                             win32.FILE_GENERIC_READ,
                             win32.FILE_SHARE_READ | win32.FILE_SHARE_WRITE,
                             nil,
                             win32.OPEN_EXISTING,
                             win32.FILE_ATTRIBUTE_NORMAL,
                             nil);
    win32.get_file_size_ex(h, &out);
    win32.close_handle(h);
    return int(out);
}