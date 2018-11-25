package console

using import "../external/imgui"
	import "core:fmt"
	import "core:strings"
	import "core:math"
	import "../lexer"

buffer := text_buffer_create();

_console_input := make([]u8, 256);

append_log :: proc(args : ..any) {

	// TODO - no alloc plz
	as_c_string := strings.new_cstring(fmt.tprintln(args));

	im_text_buffer_append(buffer, as_c_string);
}

_on_submit :: proc "c"(data : ^TextEditCallbackData) -> i32 {
	fmt.println("Callback Invoked");
	return 0;
}

update_console_window :: proc() {

	set_next_window_size(Vec2{520, 600}, Set_Cond.FirstUseEver);

	if begin("Console") {

		// Reads the buffer into a string, then writes it into the widget unformatted
		{
			footer_height := get_style().item_spacing.y + get_frame_height_with_spacing();
			begin_child("ScrollingLog", Vec2{0, -footer_height}, true, Window_Flags.HorizontalScrollbar);
			
			str := text_buffer_c_str(buffer);
			im_text_unformatted(str);

			set_scroll_here(1);
			end_child();
		}

		separator();

		{
			using Input_Text_Flags;

			if input_text("Input", _console_input, EnterReturnsTrue | CallbackCompletion | CallbackHistory, _on_submit) {

				c_input := cast(cstring) &_console_input[0];

				if c_input != "" {
					lex := lexer.make_lexer(cast(string) c_input);
					input := trim_whitespace(cast(string) c_input);

					fake_buffer: [32]string;

					for {
						token, ok := lexer.get_next_token(&lex);

						if !ok do break;

						fmt.println(token);
					}

					buffer := split_by_rune(input, ' ', &fake_buffer);
					
					_execute_command(buffer[0], buffer[1:]);

					// Reset the cstring, by setting the first character back to zero
					_console_input[0] = '\x00';
				}
			}
		}
	}
	end();
}

_execute_command :: proc(cmd: string, args: []string) {
	fmt.println("Executing command:", cmd, "args:", args);
}

is_whitespace :: inline proc(c: byte) -> bool {
	switch c {
		case ' ':  return true;
		case '\r': return true;
		case '\n': return true;
		case '\t': return true;
	}

	return false;
} 

trim_whitespace :: proc(text: string) -> string {

	if len(text) == 0 do return text;
	start := 0;
	for is_whitespace(text[start]) do start += 1;
	end := len(text);
	for is_whitespace(text[end - 1]) do end -= 1;

	new_str := text[start:end];

	return new_str;
}

split_by_rune :: proc(str: string, split_on: rune, buffer: ^[$N]string) -> []string {
	cur_slice := 0;
	start := 0;
	for b, i in str {
		if b == split_on {
			assert(cur_slice < len(buffer));
			section := str[start:i];
			buffer[cur_slice] = section;
			cur_slice += 1;
			start = i + 1;
		}
	}

	assert(cur_slice < len(buffer));
	section := str[start:];
	buffer[cur_slice] = section;
	cur_slice += 1;

	return buffer[:cur_slice];
}