package console

using import "../external/imgui"
	import "core:fmt"
	import "core:strings"
	import "core:math"
	import "core:runtime"
	import "core:mem"
	import "../laas"


when ODIN_DEBUG {
    foreign import cimgui "../external/imgui/external/cimgui_debug.lib";
} else {
    foreign import "../external/imgui/external/cimgui.lib";
} 

Console :: struct {
	buffer		: ^TextBuffer,
	commands	: Commands,
	scroll_lock : bool
}

Commands :: struct {
	input			: []u8,
	mapping			: map[string]proc(),
	history			: [dynamic]string,
	history_index 	: int,
	history_count	: int,
}

new_console :: proc(input_size: int = 256, default_commands: bool = true) -> ^Console {
	console := Console{
		text_buffer_create(),
		Commands{
			make([]u8, input_size),
			make(map[string]proc()),
			make([dynamic]string, 0, 32),
			0,
			0
		},
		true
	};

	if default_commands do setup_default_commands(&console);

	return new_clone(console);
}

setup_default_commands :: proc(console: ^Console) {
	assert(console != nil);

	console.commands.mapping["clear"] = proc() {
		fmt.println("Trying to clear console");

		c := context;

		console := cast(^Console) c.user_data.data;

		text_buffer_clear(console.buffer);
	};
}

bind_command :: proc(using console: ^Console, cmd: string, callback: proc()) {

	if cmd in commands.mapping do fmt.println("Duplicate command:", cmd);

	commands.mapping[cmd] = callback;
}

append_log :: proc(using console: ^Console, log: string) {
	assert(console != nil);

	as_c_string := strings.new_cstring(log);

	im_text_buffer_appendf(buffer, as_c_string);
}

_internal_append :: inline  proc(console: ^Console, args: ..any) {

	c_string := strings.new_cstring(fmt.tprintln(..args));

	im_text_buffer_appendf(console.buffer, c_string);
}

_on_submit :: proc "c"(data : ^TextEditCallbackData) -> i32 {

	assert(_active_console != nil);

	switch data.event_flag {
	case Input_Text_Flags.CallbackCompletion:
		fmt.println("CallbackCompletion Invoked");
	case Input_Text_Flags.CallbackHistory:
		fmt.println("CallbackHistory Invoked");

		using _active_console.commands;

		prev_index := history_index;

		switch data.event_key {
			case Key.UpArrow:
				// Move `cursor` up if possible
				if history_index >= history_count do break;

				history_index += 1;
			case Key.DownArrow:
				// Move `cursor` down if possible
				if prev_index <= 0 do break;

				history_index -= 1;
		}

		if prev_index != history_index {

			hist := history_index == 0 ? "" :history[history_count - history_index];

			arr := cast([]u8)hist;

			slice := mem.slice_ptr(data.buf, cast(int)data.buf_size);

			copy(slice, arr);

			slice[len(arr)] = 0;

			hist_len := cast(i32)len(arr);

			data.cursor_pos = hist_len;
			data.selection_start = hist_len;
			data.selection_end = hist_len;

			data.buf_text_len = hist_len;

			data.buf_dirty = true;
		}
	}

	return 0;
}

// Todo(Ben) - Make thread safe
// This exists so that we can interact with the console during the input_text callback
_active_console: ^Console;

update_console_window :: proc(using console: ^Console) {
	assert(console != nil);
	assert(_active_console == nil, "Active console is non-nil, probably a threading issue in the console update.");

	_active_console = console;
	defer _active_console = nil;

	set_next_window_size(Vec2{520, 600}, Set_Cond.FirstUseEver);

	io := get_io();

	defer end();
	if begin("Console") {

		{
			footer_height := get_style().item_spacing.y + get_frame_height_with_spacing();
			begin_child("ScrollingLog", Vec2{0, -footer_height}, true, Window_Flags.HorizontalScrollbar);

			str := text_buffer_c_str(buffer);
			im_text_unformatted(str);

			if io.mouse_wheel > 0 && is_window_hovered() {
				console.scroll_lock = false;
			}

			if console.scroll_lock {
				set_scroll_here(1);
			}

			end_child();
		}
		
		separator();

		{
			using Input_Text_Flags;

			// OnSubmit uses the _active_console
			if input_text("Input", commands.input, EnterReturnsTrue | CallbackCompletion | CallbackHistory, _on_submit) {
				_process_input(console);
			}

			same_line();

			checkbox("ScrollLock", &console.scroll_lock);
		}
	}
}

_process_input :: proc(using console: ^Console) {

	assert(console != nil);

	c_input := cast(cstring) &commands.input[0];

	if c_input != "" {

		_internal_append(console, ">", cast(string) c_input);

		// Lex the input, the first token should be the command name
		// All other tokens should be passed into the command proc
		// Todo(Ben) Acutally lex input into structs, to pass as args to the commands.
		lex := laas.make_lexer(cast(string) c_input);

		token: laas.Token;

		if !laas.get_next_token(&lex, &token) {
			fmt.println("That's not ok then");
			return;
		}
		
		_execute_command(console, token.slice_of_text);

		for {
			if !laas.get_next_token(&lex, &token) do break;

			fmt.println(token);
		}

		// Reset the cstring, by setting the first character back to zero
		commands.input[0] = '\x00';
	}
}

_execute_command :: proc(using console: ^Console, cmd: string, args: ..string) {

	callback, ok := commands.mapping[cmd];

	append(&commands.history, strings.new_string(cmd));
	commands.history_count += 1;
	commands.history_index = 0;

	if !ok {
		_internal_append(console, "Unrecognized command:", cmd);
		return;
	}

	context.user_data = any{rawptr(console), typeid_of(Console)};
	
	callback();
}

@(default_calling_convention="c")
foreign cimgui {
	@(link_name = "ImGuiTextBuffer_appendf")  im_text_buffer_appendf :: proc(buffer : ^TextBuffer, fmt_ : cstring) ---;
}