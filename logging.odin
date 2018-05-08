import "core:fmt.odin"
import "basic.odin"

log :: proc(args: ...any, location := #caller_location) {
	file := basic.file_from_path(location.file_path);
	fmt.printf("<%s.%s():%d> ", file, location.procedure, location.line);
	fmt.print(...args);
	fmt.printf("\n");
}
