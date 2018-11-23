package console

using import "../external/imgui"
	import "core:fmt"
	import "core:strings"

buffer: ^TextBuffer;

append_log :: proc(args : ..any) {

	if buffer == nil {
		buffer = text_buffer_create();
		_console_input = make([]u8, 128);
	}

	// TODO - no alloc plz
	as_c_string := strings.new_cstring(fmt.tprintln(args));

	im_text_buffer_append(buffer, as_c_string);
}

_on_submit :: proc "c"(data : ^TextEditCallbackData) -> i32 {
	fmt.println("Text edited");
	return 0;
}

_console_input : []u8;

update_console_window :: proc() {

	if begin("Console") {
		defer end();

		if buffer == nil {
			return;
		}

		// Reads the buffer into a string, then writes it into the widget unformatted
		{	// Log Window
			begin_child("Log");
			
			str := text_buffer_c_str(buffer);
			im_text_unformatted(str);

			set_scroll_here(1);
			end_child();
		}
		{
			using Input_Text_Flags;

			if input_text("Input", _console_input, CallbackAlways | EnterReturnsTrue, _on_submit) {
				fmt.println("Input returned true");
			}
		}
	}
}