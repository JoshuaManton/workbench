package console

import "../external/imgui"
import "core:fmt"
import "core:strings"

buffer: ^imgui.TextBuffer;
//offset_vector: ^imgui.

append_log :: proc(args : ..any) {

	if buffer == nil {
		buffer = imgui.text_buffer_create();
	}

	// TODO - no alloc plz
	as_c_string := strings.new_cstring(fmt.tprintln(args));

	imgui.im_text_buffer_append(buffer, as_c_string);
}

update_console_window :: proc() {

	if imgui.begin("Console") {
		defer imgui.end();

		if buffer == nil {
			return;
		}

		// Reads the buffer into a string, then writes it into the widget unformatted
		str := imgui.text_buffer_c_str(buffer);
		imgui.im_text_unformatted(str);

		imgui.set_scroll_here(1);
	}
}