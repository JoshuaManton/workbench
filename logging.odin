package workbench

using import "core:runtime"
import "core:fmt"

log_back: proc(log: string);

pretty_location :: inline proc(location: Source_Code_Location) -> string {
	file := file_from_path(location.file_path);
	return fmt.tprintf("%s.%s():%d", file, location.procedure, location.line);
}

logln :: proc(args: ..any, location := #caller_location) {
	file := file_from_path(location.file_path);

	str := fmt.tprintf("<%s.%s():%d> %s\n", file, location.procedure, location.line, fmt.tprint(..args));
	fmt.print(str);

	if log_back != nil {
		log_back(str);
	}
}
