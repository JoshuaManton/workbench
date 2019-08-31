package workbench

import "core:fmt"

using import "../basic"

logln :: proc(args: ..any, location := #caller_location) {
	file := file_from_path(location.file_path);

	fmt.print(pretty_location(location));
	fmt.print(..args);
	fmt.print('\n');

	// Currently doing a renderer refactor/wb cleanup, disabling this for now
	//
	// if wb, ok := context.derived.(WB_Context); ok {
	// 	wb.logger_proc(str);
	// }
}
