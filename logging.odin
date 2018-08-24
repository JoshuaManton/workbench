package workbench

import "core:fmt"

logln :: proc(args: ..any, location := #caller_location) {
	file := file_from_path(location.file_path);
	fmt.printf("\n");
	fmt.printf("<%s.%s():%d> ", file, location.procedure, location.line);
	fmt.print(..args);
	fmt.printf("\n");
}
