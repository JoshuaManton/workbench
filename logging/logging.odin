package workbench

import "core:fmt"

using import "../basic"

logln :: proc(args: ..any, location := #caller_location) {
	file, ok := get_file_name(location.file_path);
	assert(ok);

	fmt.print(pretty_location(location));
	fmt.print(..args);
	fmt.print('\n');

	// Currently doing a renderer refactor/wb cleanup, disabling this for now
	//
	// if wb, ok := context.derived.(WB_Context); ok {
	// 	wb.logger_proc(str);
	// }
}
