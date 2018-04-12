import "core:fmt.odin"
import "basic.odin"

logln :: proc(args: ...any, location := #caller_location) {
	file := location.file_path;
	last_slash_idx, ok := basic.find_from_right(file, '\\');
	if ok {
		file = file[last_slash_idx+1..len(location.file_path)];
	}

	fmt.println(...args);
	fmt.printf("%s:%d:%s()", file, location.line, location.procedure);
	fmt.printf("\n\n");
}