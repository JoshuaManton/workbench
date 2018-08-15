package workbench

using import        "core:math"
using import        "core:fmt"
      import        "core:sort"
      import        "core:strings"
      import        "core:mem"
      import        "core:os"
      import        "core:sys/win32"
      import coregl "core:opengl"

      import odingl "shared:odin-gl"

      import stb    "shared:workbench/stb"
      import        "shared:workbench/glfw"

init_glfw :: proc(window_name: string, _window_width, _window_height: int, _opengl_version_major, _opengl_version_minor: int) {
	window_width := cast(i32)_window_width;
	window_height := cast(i32)_window_height;
	opengl_version_major := cast(i32)_opengl_version_major;
	opengl_version_minor := cast(i32)_opengl_version_minor;

	glfw_size_callback :: proc"c"(main_window: glfw.Window_Handle, w, h: i32) {
		_new_window_width  = cast(int)w;
		_new_window_height = cast(int)h;
		_new_aspect_ratio = cast(f32)w / cast(f32)h;

		top    : f32 =  1;
		bottom : f32 = -1;
		left   : f32 = -1 * _new_aspect_ratio;
		right  : f32 =  1 * _new_aspect_ratio;

		_new_ortho_matrix = ortho3d(left, right, bottom, top, -1, 1);
	}

	glfw_cursor_callback :: proc"c"(main_window: glfw.Window_Handle, x, y: f64) {
		_new_cursor_screen_position = Vec2{cast(f32)x, cast(f32)current_window_height - cast(f32)y};
	}

	glfw_scroll_callback :: proc"c"(main_window: glfw.Window_Handle, x, y: f64) {
		_new_cursor_scroll = cast(f32)y;
	}

	glfw_error_callback :: proc"c"(error: i32, desc: cstring) {
		fmt.printf("GLFW Error: %d:\n    %s\n", error, cast(string)cast(cstring)desc);
	}

	// setup glfw
	glfw.SetErrorCallback(glfw_error_callback);

	if glfw.Init() == 0 do return;
	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, opengl_version_major);
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, opengl_version_minor);
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE);
	main_window = glfw.CreateWindow(window_width, window_height, window_name, nil, nil);
	if main_window == nil do return;

	video_mode := glfw.GetVideoMode(glfw.GetPrimaryMonitor());
	glfw.SetWindowPos(main_window, video_mode.width / 2 - window_width / 2, video_mode.height / 2 - window_height / 2);

	glfw.MakeContextCurrent(main_window);
	glfw.SwapInterval(1);

	glfw.SetCursorPosCallback(main_window, glfw_cursor_callback);
	glfw.SetWindowSizeCallback(main_window, glfw_size_callback);

	glfw.SetKeyCallback(main_window, _glfw_key_callback);
	glfw.SetMouseButtonCallback(main_window, _glfw_mouse_button_callback);

	// :GlfwJoystickPollEventsCrash
	// this is crashing when I call PollEvents when I unplug a controller for some reason
	// glfw.SetJoystickCallback(main_window, _glfw_joystick_callback);

	// Set initial size of window
	glfw_size_callback(main_window, window_width, window_height);

	// Setup glfw callbacks
	glfw.SetScrollCallback(main_window, glfw_scroll_callback);
}