package workbench

using import "core:runtime"
import "core:fmt"

import "console"

pretty_location :: inline proc(location: Source_Code_Location) -> string {
	file := file_from_path(location.file_path);
	return fmt.tprintf("%s.%s():%d", file, location.procedure, location.line);
}

logln :: proc(args: ..any, location := #caller_location) {
	file := file_from_path(location.file_path);
	fmt.printf("\n");
	fmt.printf("<%s.%s():%d> ", file, location.procedure, location.line);
	fmt.print(..args);
	fmt.printf("\n");

	console.append_log(..args);
}
