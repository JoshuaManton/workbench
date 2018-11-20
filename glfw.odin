package workbench

using import        "core:math"
using import        "core:fmt"
      import        "core:sort"
      import        "core:strings"
      import        "core:mem"
      import        "core:os"
      import        "core:sys/win32"

      import odingl "external/gl"
      import imgui  "external/imgui"

      import stb    "external/stb"
      import        "external/glfw"

main_window: glfw.Window_Handle;

window_is_focused := true;

current_window_width:  f32;
current_window_height: f32;
current_aspect_ratio:  f32;

cursor_scroll: f32;
cursor_world_position:  Vec2;
cursor_screen_position: Vec2;
cursor_unit_position:   Vec2;

frame_count: u64;
time: f32;
precise_time: f64;
lossy_delta_time: f32;
precise_lossy_delta_time: f64;

 // set in callbacks
_new_ortho_matrix:  Mat3;
_new_window_width:  f32;
_new_window_height: f32;
_new_aspect_ratio:  f32;
_new_cursor_scroll: f32;
_new_cursor_screen_position: Vec2;
_new_window_is_focused := true;

_init_glfw :: proc(window_name: string, _window_width, _window_height: int, _opengl_version_major, _opengl_version_minor: int) {
	window_width := cast(i32)_window_width;
	window_height := cast(i32)_window_height;
	opengl_version_major := cast(i32)_opengl_version_major;
	opengl_version_minor := cast(i32)_opengl_version_minor;

	glfw_size_callback :: proc"c"(window: glfw.Window_Handle, w, h: i32) {
		_new_window_width  = cast(f32)w;
		_new_window_height = cast(f32)h;
		_new_aspect_ratio = cast(f32)w / cast(f32)h;
	}

	glfw_cursor_callback :: proc"c"(window: glfw.Window_Handle, x, y: f64) {
		_new_cursor_screen_position = Vec2{cast(f32)x, cast(f32)current_window_height - cast(f32)y};
	}

	glfw_scroll_callback :: proc"c"(window: glfw.Window_Handle, x, y: f64) {
		_new_cursor_scroll = cast(f32)y;
	}

	glfw_character_callback :: proc"c"(window: glfw.Window_Handle, codepoint: u32) {
		imgui.gui_io_add_input_character(u16(codepoint));
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

	glfw.SetCharCallback(main_window, glfw_character_callback);

	// :GlfwJoystickPollEventsCrash
	// this is crashing when I call PollEvents when I unplug a controller for some reason
	// glfw.SetJoystickCallback(main_window, _glfw_joystick_callback);

	// Set initial size of window
	glfw_size_callback(main_window, window_width, window_height);

	// Setup glfw callbacks
	glfw.SetScrollCallback(main_window, glfw_scroll_callback);
}

_update_glfw :: proc() {
	// Update vars from callbacks
	current_window_width   = _new_window_width;
	current_window_height  = _new_window_height;
	current_aspect_ratio   = _new_aspect_ratio;
	cursor_scroll          = _new_cursor_scroll;
	_new_cursor_scroll     = 0;
	cursor_screen_position = _new_cursor_screen_position;
	cursor_unit_position   = cursor_screen_position / Vec2{cast(f32)current_window_width, cast(f32)current_window_height};
	window_is_focused = _new_window_is_focused;

	// ortho
	{
		top    : f32 =  1 * camera_size + camera_position.y;
		bottom : f32 = -1 * camera_size + camera_position.y;
		left   : f32 = -1 * current_aspect_ratio * camera_size + camera_position.x;
		right  : f32 =  1 * current_aspect_ratio * camera_size + camera_position.x;
		orthographic_projection_matrix = ortho3d(left, right, bottom, top, -1, 1);
	}

	perspective_projection_matrix  = perspective(to_radians(camera_size), current_aspect_ratio, 0.01, 1000);

	view_matrix = identity(Mat4);
	view_matrix = translate(view_matrix, Vec3{-camera_position.x, -camera_position.y, -camera_position.z});

	normalize_camera_rotation();

	qx := axis_angle(Vec3{1,0,0}, to_radians(360 - camera_rotation.x));
	qy := axis_angle(Vec3{0,1,0}, to_radians(360 - camera_rotation.y));
	// todo(josh): z axis
	// qz := axis_angle(Vec3{0,0,1}, to_radians(360 - camera_rotation.z));
	orientation := quat_mul(qx, qy);
	orientation = quat_norm(orientation);
	rotation_matrix := quat_to_mat4(orientation);
	view_matrix = mul(rotation_matrix, view_matrix);

	model_matrix = identity(Mat4);

	// Unit space
	{
		unit_to_viewport_matrix = translate(identity(Mat4), Vec3{-1, -1, 0});
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
