package workbench

import "core:fmt"

using import "core:runtime"

using import "../basic"

pretty_location :: inline proc(location: Source_Code_Location) -> string {
	file := file_from_path(location.file_path);
	return fmt.tprintf("%s.%s():%d", file, location.procedure, location.line);
}

logln :: proc(args: ..any, location := #caller_location) {
	file := file_from_path(location.file_path);

	str := fmt.tprintf("<%s.%s():%d> %s\n", file, location.procedure, location.line, fmt.tprint(..args));
	fmt.print(str);

	// Currently doing a renderer refactor/wb cleanup, disabling this for now
	//
	// if wb, ok := context.derived.(WB_Context); ok {
	// 	wb.logger_proc(str);
	// }
}
