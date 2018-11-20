package console

import "../external/imgui"
import "core:fmt"
import "core:strings"

buffer: ^imgui.TextBuffer;

append_log :: proc(args : ..any) {

	if buffer == nil {
		buffer = imgui.text_buffer_create();
		_console_input = make([]u8, 128);
	}

	// TODO - no alloc plz
	as_c_string := strings.new_cstring(fmt.tprintln(args));

	imgui.im_text_buffer_append(buffer, as_c_string);
}

_on_submit :: proc "c"(data : ^imgui.TextEditCallbackData) -> i32 {
	fmt.println("Text edited");
	return 0;
}

_console_input : []u8;

update_console_window :: proc() {

	if imgui.begin("Console") {
		defer imgui.end();

		if buffer == nil {
			return;
		}

		// Reads the buffer into a string, then writes it into the widget unformatted
		{	// Log Window
			imgui.begin_child("Log");
			defer imgui.end_child();
			
			str := imgui.text_buffer_c_str(buffer);
			imgui.im_text_unformatted(str);

			imgui.set_scroll_here(1);
		}

		imgui.input_text("Input", _console_input, nil, _on_submit);
	}
}