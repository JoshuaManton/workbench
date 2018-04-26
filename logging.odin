import "core:fmt.odin"
import "basic.odin"

log :: proc(args: ...any, location := #caller_location) {
	file := location.file_path;
	start := 0;
	end := len(file);

	if last_slash_idx, ok := basic.find_from_right(file, '\\'); ok {
		start = last_slash_idx;
	}

	if dot, ok := basic.find_from_right(file, '.'); ok {
		end = dot;
	}

	file = file[start+1..end];

	fmt.printf("<%s.%s():%d> ", file, location.procedure, location.line);
	fmt.print(...args);
	fmt.printf("\n");
}