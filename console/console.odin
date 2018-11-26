package console

using import "../external/imgui"
	import "core:fmt"
	import "core:strings"
	import "core:math"
	import "../lexer"

Console :: struct {
	buffer		: ^TextBuffer,
	input		: []u8,
	commands	: Commands,
}

Commands :: struct {
	mapping	: map[string]proc(),
	history	: []string,
}


buffer := text_buffer_create();

_console_input := make([]u8, 256);

_commands := make(map[string]proc());

new_console :: proc(input_size: int = 256, history_length: int = 64, default_commands: bool = true) -> ^Console {
	console := Console{
		text_buffer_create(),
		make([]u8, input_size),
		Commands{
			make(map[string]proc()),
			make([]string, history_length),
		},
	};

	if default_commands do setup_default_commands(&console);

	return &console;
}

bind_command :: proc(cmd: string, callback: proc()) {

	if cmd in _commands do fmt.println("Duplicate command:", cmd);

	_commands[cmd] = callback;
}

setup_default_commands :: proc(console: ^Console) {

	using console.commands;

	mapping["clear"] = proc() {
		text_buffer_clear(buffer);
	};
}

append_log :: proc(args : ..any) {

	// TODO - no alloc plz
	as_c_string := strings.new_cstring(fmt.tprintln(..args));

	im_text_buffer_append(buffer, as_c_string);
}

_on_submit :: proc "c"(data : ^TextEditCallbackData) -> i32 {

	switch data.event_flag {
	case Input_Text_Flags.CallbackCompletion:
		fmt.println("CallbackCompletion Invoked");
	case Input_Text_Flags.CallbackHistory:
		fmt.println("CallbackHistory Invoked");
	}

	return 0;
}

update_console_window :: proc() {

	set_next_window_size(Vec2{520, 600}, Set_Cond.FirstUseEver);

	if begin("Console") {
		defer end();

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
				_process_input();
			}
		}
	}
}

_process_input :: proc() {
	c_input := cast(cstring) &_console_input[0];

	if c_input != "" {

		append_log(">", cast(string) c_input);

		// Lex the input, the first token should be the command name
		// All other tokens should be passed into the command proc
		lex := lexer.make_lexer(cast(string) c_input);

		cmd_token, ok := lexer.get_next_token(&lex);

		if !ok {
			fmt.println("That's not ok then");
			return;
		}
		
		_execute_command(cmd_token.slice_of_text);

		for {
			token, ok := lexer.get_next_token(&lex);

			if !ok do break;

			fmt.println(token);
		}

		// Reset the cstring, by setting the first character back to zero
		_console_input[0] = '\x00';
	}
}

_execute_command :: proc(cmd: string, args: ..string) {

	callback, ok := _commands[cmd];

	if !ok {
		append_log("Unrecognized command:", cmd);
		return;
	}

	callback();
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