package workbench

using import        "core:math"
using import        "core:fmt"
      import        "core:sort"
      import        "core:strings"
      import        "core:mem"
      import        "core:os"
      import        "core:sys/win32"

      import odingl "shared:odin-gl"

      import stb    "shared:workbench/stb"
      import        "shared:workbench/glfw"

main_window: glfw.Window_Handle;

current_window_width:  f32;
current_window_height: f32;
current_aspect_ratio:  f32;

cursor_scroll: f32;
cursor_world_position:  Vec2;
cursor_screen_position: Vec2;
cursor_unit_position:   Vec2;

frame_count: u64;
time: f32;
lossy_delta_time: f32;
fps_to_draw: f32;

 // set in callbacks
_new_ortho_matrix:  Mat3;
_new_window_width:  f32;
_new_window_height: f32;
_new_aspect_ratio:  f32;
_new_cursor_scroll: f32;
_new_cursor_screen_position: Vec2;

_init_glfw :: proc(window_name: string, _window_width, _window_height: int, _opengl_version_major, _opengl_version_minor: int) {
	window_width := cast(i32)_window_width;
	window_height := cast(i32)_window_height;
	opengl_version_major := cast(i32)_opengl_version_major;
	opengl_version_minor := cast(i32)_opengl_version_minor;

	glfw_size_callback :: proc"c"(main_window: glfw.Window_Handle, w, h: i32) {
		_new_window_width  = cast(f32)w;
		_new_window_height = cast(f32)h;
		_new_aspect_ratio = cast(f32)w / cast(f32)h;
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

_update_glfw :: proc(dt: f32) {
	// Update vars from callbacks
	current_window_width   = _new_window_width;
	current_window_height  = _new_window_height;
	current_aspect_ratio   = _new_aspect_ratio;
	cursor_scroll          = _new_cursor_scroll;
	_new_cursor_scroll     = 0;
	cursor_screen_position = _new_cursor_screen_position;
	cursor_unit_position   = cursor_screen_position / Vec2{cast(f32)current_window_width, cast(f32)current_window_height};

	if !is_perspective {
		top    : f32 =  1;
		bottom : f32 = -1;
		left   : f32 = -1 * current_aspect_ratio;
		right  : f32 =  1 * current_aspect_ratio;

		projection_matrix = ortho3d(left, right, bottom, top, -1, 1);
	}
	else {
		projection_matrix = perspective(to_radians(camera_size), current_aspect_ratio, 0.001, 1000);
		// view_matrix       = look_at(camera_position, Vec3{}, Vec3{0, 1, 0});
		view_matrix       = translate(identity(Mat4), camera_position);
		model_matrix      = identity(Mat4);
	}

	// Unit space
	{
		unit_to_viewport_matrix = translate(identity(Mat4), Vec3{-5, -5, 0});
		unit_to_viewport_matrix = scale(unit_to_viewport_matrix, 2);

		unit_to_pixel_matrix = scale(identity(Mat4), Vec3{cast(f32)current_window_width, cast(f32)current_window_height, 0});
	}

	// Pixel space
	{
		pixel_to_viewport_matrix = scale(identity(Mat4), Vec3{1.0 / cast(f32)current_window_width, 1.0 / cast(f32)current_window_height, 0});
		pixel_to_viewport_matrix = translate(pixel_to_viewport_matrix, Vec3{-1, -1, 0});
		pixel_to_viewport_matrix = scale(pixel_to_viewport_matrix, 2);
	}

	// Viewport space
	{
		viewport_to_pixel_matrix = identity(Mat4);
		viewport_to_pixel_matrix = translate(viewport_to_pixel_matrix, Vec3{1, 1, 0});
		viewport_to_pixel_matrix = scale(viewport_to_pixel_matrix, Vec3{cast(f32)current_window_width/2, cast(f32)current_window_height/2, 0});

		viewport_to_unit_matrix = identity(Mat4);
		viewport_to_unit_matrix = translate(viewport_to_unit_matrix, Vec3{1, 1, 0});
		viewport_to_unit_matrix = scale(viewport_to_unit_matrix, 0.5);
	}

	// cursor_world_position  = screen_to_world(cursor_screen_position);
}

window_should_close :: inline proc(window: glfw.Window_Handle) -> bool {
	return glfw.WindowShouldClose(window);
}