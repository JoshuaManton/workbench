package workbench

import "core:fmt"
import "../basic"

ln :: proc(args: ..any, location := #caller_location) {
	file, ok := basic.get_file_name(location.file_path);
	assert(ok);

	fmt.print(basic.pretty_location(location));
	fmt.print(..args);
	fmt.print('\n');

	// Currently doing a renderer refactor/wb cleanup, disabling this for now
	//
	// if wb, ok := context.derived.(WB_Context); ok {
	// 	wb.logger_proc(str);
	// }
}
