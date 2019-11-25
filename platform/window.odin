package workbench

using import        "core:fmt"
      import        "core:sort"
      import        "core:strings"
      import        "core:mem"
      import        "core:os"
      import        "core:sys/win32"

      import "../gpu"

using import "../math"

      import imgui  "../external/imgui"

      import stb    "../external/stb"
      import        "../external/glfw"

Window :: glfw.Window_Handle;

window_is_focused := true;

current_window_width:  f32;
current_window_height: f32;
current_aspect_ratio:  f32;
current_window_size: Vec2;

mouse_scroll: f32;
mouse_screen_position:       Vec2;
mouse_screen_position_delta: Vec2;
mouse_unit_position:         Vec2;

 // set in callbacks
_new_ortho_matrix:  Mat3;
_new_window_width:  f32;
_new_window_height: f32;
_new_aspect_ratio:  f32;
_new_mouse_scroll: f32;
_new_mouse_screen_position: Vec2;
_new_window_is_focused := true;

init_platform :: proc(out_window: ^Window, window_name: string, _window_width, _window_height: int) -> bool {
	window_width := cast(i32)_window_width;
	window_height := cast(i32)_window_height;

	glfw_size_callback :: proc"c"(window: glfw.Window_Handle, w, h: i32) {
		_new_window_width  = cast(f32)w;
		_new_window_height = cast(f32)h;
		_new_aspect_ratio = cast(f32)w / cast(f32)h;
	}

	glfw_cursor_callback :: proc"c"(window: glfw.Window_Handle, x, y: f64) {
		_new_mouse_screen_position = Vec2{cast(f32)x, cast(f32)current_window_height - cast(f32)y};
	}

	glfw_scroll_callback :: proc"c"(window: glfw.Window_Handle, x, y: f64) {
		_new_mouse_scroll = cast(f32)y;
	}

	glfw_character_callback :: proc"c"(window: glfw.Window_Handle, codepoint: u32) {
		imgui.gui_io_add_input_character(u16(codepoint));
	}

	glfw_error_callback :: proc"c"(error: i32, desc: cstring) {
		fmt.printf("GLFW Error: %d:\n    %s\n", error, cast(string)cast(cstring)desc);
	}

	// setup glfw
	glfw.SetErrorCallback(glfw_error_callback);

	if glfw.Init() == 0 do return false;
	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, gpu.OPENGL_VERSION_MAJOR);
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, gpu.OPENGL_VERSION_MINOR);
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE);
	window := glfw.CreateWindow(window_width, window_height, window_name, nil, nil);
	if window == nil do return false;

	video_mode := glfw.GetVideoMode(glfw.GetPrimaryMonitor());
	glfw.SetWindowPos(window, video_mode.width / 2 - window_width / 2, video_mode.height / 2 - window_height / 2);

	glfw.MakeContextCurrent(window);
	glfw.SwapInterval(1);

	glfw.SetCursorPosCallback(window, glfw_cursor_callback);
	glfw.SetWindowSizeCallback(window, glfw_size_callback);

	glfw.SetKeyCallback(window, _glfw_key_callback);
	glfw.SetMouseButtonCallback(window, _glfw_mouse_button_callback);

	glfw.SetCharCallback(window, glfw_character_callback);

	// :GlfwJoystickPollEventsCrash
	// this is crashing when I call PollEvents when I unplug a controller for some reason
	// glfw.SetJoystickCallback(window, _glfw_joystick_callback);

	// Set initial size of window
	glfw_size_callback(window, window_width, window_height);

	// Setup glfw callbacks
	glfw.SetScrollCallback(window, glfw_scroll_callback);

	out_window^ = window;
	return true;
}

update_platform :: proc() {
	update_input();

	// Update vars from callbacks
	current_window_width   = _new_window_width;
	current_window_height  = _new_window_height;
	current_aspect_ratio   = _new_aspect_ratio;
	current_window_size    = Vec2{current_window_width, current_window_height};
	mouse_scroll          = _new_mouse_scroll;
	_new_mouse_scroll     = 0;
	mouse_screen_position_delta = _new_mouse_screen_position - mouse_screen_position;
	mouse_screen_position = _new_mouse_screen_position;
	mouse_unit_position   = mouse_screen_position / Vec2{cast(f32)current_window_width, cast(f32)current_window_height};
	window_is_focused = _new_window_is_focused;
}
