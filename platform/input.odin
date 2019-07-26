package workbench

import "../external/glfw"
import "../external/imgui"

using import "../basic"

/*

INPUT API

get_input      :: proc(input: Input) -> bool
get_input_down :: proc(input: Input) -> bool
get_input_up   :: proc(input: Input) -> bool

get_button      :: proc(controller_index: int, button: Button) -> bool
get_button_down :: proc(controller_index: int, button: Button) -> bool
get_button_up   :: proc(controller_index: int, button: Button) -> bool

get_axis :: proc(controller_index: int, axis: Axis) -> f32

*/

get_input :: inline proc(input: Input) -> bool {
	for held in _held {
		if held == input {
			return true;
		}
	}
	return false;
}

get_input_imgui :: inline proc(input: Input) -> bool {
	for held in _held_imgui {
		if held == input {
			return true;
		}
	}
	return false;
}

get_input_down :: inline proc(input: Input) -> bool {
	for down in _down {
		if down == input {
			return true;
		}
	}
	return false;
}

get_input_up :: inline proc(input: Input) -> bool {
	for up in _up {
		if up == input {
			return true;
		}
	}
	return false;
}

get_button :: inline proc(controller_index: int, button: Button) -> bool {
	controller := controllers[controller_index];
	if !controller.connected do return false;

	return controller.held[cast(int)button] == 1;
}

get_button_down :: inline proc(controller_index: int, button: Button) -> bool {
	controller := controllers[controller_index];
	if !controller.connected do return false;

	return controller.down[cast(int)button] == 1;
}

get_button_up :: inline proc(controller_index: int, button: Button) -> bool {
	controller := controllers[controller_index];
	if !controller.connected do return false;

	return controller.up[cast(int)button] == 1;
}

get_axis :: inline proc(controller_index: int, axis: Axis) -> f32 {
	controller := controllers[controller_index];
	if !controller.connected do return 0;

	return controller.axes[cast(int)axis];
}

Button :: enum {
	A = 0,
	B,
	X,
	Y,
	L1,
	R1,
	Select,
	Start,
	L3,
	R3,
	Dpad_Up,
	Dpad_Right,
	Dpad_Down,
	Dpad_Left,
}

Axis :: enum {
	L3X = 0,
	L3Y,
	R3X,
	R3Y,
	L2,
	R2,
}

is_mouse_input :: inline proc(input: Input) -> bool {
	return input >= Input.Mouse_Button_1 && input <= Input.Mouse_Button_8;
}

// copypasted from glfw, Key and Mouse combined
Input :: enum i32 {

    /* The unknown key */
    Unknown = -1,

    /* Mouse buttons */
    Mouse_Button_1 = 0,
    Mouse_Button_2 = 1,
    Mouse_Button_3 = 2,
    Mouse_Button_4 = 3,
    Mouse_Button_5 = 4,
    Mouse_Button_6 = 5,
    Mouse_Button_7 = 6,
    Mouse_Button_8 = 7,

    /* Mousebutton aliases */
    Mouse_Last   = Mouse_Button_8,
    Mouse_Left   = Mouse_Button_1,
    Mouse_Right  = Mouse_Button_2,
    Mouse_Middle = Mouse_Button_3,

/** Printable keys **/

/* Named printable keys */
    Space         = 32,
    Apostrophe    = 39,  /* ' */
    Comma         = 44,  /* , */
    Minus         = 45,  /* - */
    Period        = 46,  /* . */
    Slash         = 47,  /* / */
    Semicolon     = 59,  /* ; */
    Equal         = 61,  /* :: */
    Left_Bracket  = 91,  /* [ */
    Backslash     = 92,  /* \ */
    Right_Bracket = 93,  /* ] */
    Grave_Accent  = 96,  /* ` */
    World_1       = 161, /* non-US #1 */
    World_2       = 162, /* non-US #2 */

/* Alphanumeric characters */
    NR_0 = 48,
    NR_1 = 49,
    NR_2 = 50,
    NR_3 = 51,
    NR_4 = 52,
    NR_5 = 53,
    NR_6 = 54,
    NR_7 = 55,
    NR_8 = 56,
    NR_9 = 57,

    A = 65,
    B = 66,
    C = 67,
    D = 68,
    E = 69,
    F = 70,
    G = 71,
    H = 72,
    I = 73,
    J = 74,
    K = 75,
    L = 76,
    M = 77,
    N = 78,
    O = 79,
    P = 80,
    Q = 81,
    R = 82,
    S = 83,
    T = 84,
    U = 85,
    V = 86,
    W = 87,
    X = 88,
    Y = 89,
    Z = 90,


/** Function keys **/

/* Named non-printable keys */
    Escape       = 256,
    Enter        = 257,
    Tab          = 258,
    Backspace    = 259,
    Insert       = 260,
    Delete       = 261,
    Right        = 262,
    Left         = 263,
    Down         = 264,
    Up           = 265,
    Page_Up      = 266,
    Page_Down    = 267,
    Home         = 268,
    End          = 269,
    Caps_Lock    = 280,
    Scroll_Lock  = 281,
    Num_Lock     = 282,
    Print_Screen = 283,
    Pause        = 284,

/* Function keys */
    F1  = 290,
    F2  = 291,
    F3  = 292,
    F4  = 293,
    F5  = 294,
    F6  = 295,
    F7  = 296,
    F8  = 297,
    F9  = 298,
    F10 = 299,
    F11 = 300,
    F12 = 301,
    F13 = 302,
    F14 = 303,
    F15 = 304,
    F16 = 305,
    F17 = 306,
    F18 = 307,
    F19 = 308,
    F20 = 309,
    F21 = 310,
    F22 = 311,
    F23 = 312,
    F24 = 313,
    F25 = 314,

/* Keypad numbers */
    KP_0 = 320,
    KP_1 = 321,
    KP_2 = 322,
    KP_3 = 323,
    KP_4 = 324,
    KP_5 = 325,
    KP_6 = 326,
    KP_7 = 327,
    KP_8 = 328,
    KP_9 = 329,

/* Keypad named function keys */
    KP_Decimal  = 330,
    KP_Divide   = 331,
    KP_Multiply = 332,
    KP_Subtract = 333,
    KP_Add      = 334,
    KP_Enter    = 335,
    KP_Equal    = 336,

/* Modifier keys */
    Left_Shift    = 340,
    Left_Control  = 341,
    Left_Alt      = 342,
    Left_Super    = 343,
    Right_Shift   = 344,
    Right_Control = 345,
    Right_Alt     = 346,
    Right_Super   = 347,
    Key_Menu      = 348,

    Last = Key_Menu,
}

//
// Internal
//

Controller_ID :: int;

Axis_State :: struct {
	axis: Axis,
	value: f32,
}

Controller_State :: struct {
	connected: bool,

	held: []u8,
	down: []u8,
	up:   []u8,
	axes: []f32,
}

_held := make([dynamic]Input, 0, 5);
_down := make([dynamic]Input, 0, 5);
_up   := make([dynamic]Input, 0, 5);

_held_imgui := make([dynamic]Input, 0, 5);
_down_imgui := make([dynamic]Input, 0, 5);
_up_imgui   := make([dynamic]Input, 0, 5);

_held_mid_frame := make([dynamic]Input, 0, 5);
_down_mid_frame := make([dynamic]Input, 0, 5);
_up_mid_frame   := make([dynamic]Input, 0, 5);

controllers: [glfw.JOYSTICK_LAST+1]Controller_State;

@private
update_input :: proc() {
	glfw.PollEvents();

	// Clear old inputs
	{
		clear(&_held);
		clear(&_down);
		clear(&_up);

		clear(&_held_imgui);
		clear(&_down_imgui);
		clear(&_up_imgui);
	}

	// Add joystick inputs
	{
		// Buttons
		{
			for _, _controller_idx in controllers {
				controller_idx := cast(i32)_controller_idx;
				controller := &controllers[controller_idx];

				was_connected := controller.connected;
				controller.connected = glfw.JoystickPresent(controller_idx);
				if !controller.connected {
					continue;
				}

				buttons        := glfw.GetJoystickButtons(controller_idx);
				controller.axes = glfw.GetJoystickAxes(controller_idx);

				if !was_connected {
					// TODO: could speed this up such that it doesn't allocate if you unplug then plug back in, as long as the number of buttons stays the same
					controller.held = make([]u8, len(buttons));
					controller.down = make([]u8, len(buttons));
					controller.up   = make([]u8, len(buttons));
				}

				for _, button_idx in buttons {
					value := buttons[button_idx];
					button := cast(Button)button_idx;

					is_held_now := value == 1;
					was_held_last_frame := get_button(_controller_idx, button);

					// Important that this is after the `get_button()` call above because us adding
					// it to `held` would affect the call to `get_button()`
					controller.held[button_idx] = value;
					controller.down[button_idx] = 0;
					controller.up[button_idx]   = 0;

					if is_held_now && !was_held_last_frame {
						controller.down[button_idx] = 1;
					}
					else if !is_held_now && was_held_last_frame {
						controller.up[button_idx] = 1;
					}
				}
			}
		}
	}

	// Flush new inputs into the buffers for this frame
	{
		// todo: @InputCleanup: Just request the data every frame, what we do now
		// with the callbacks and stuff is gross
		// if glfw.GetMouseButton(main_window, glfw.Mouse.Left) == glfw.Action.Press {
		// 	append(&_held, Key_Press{Mouse.Left});
		// }
		// if glfw.GetMouseButton(main_window, glfw.Mouse.Right) == glfw.Action.Press {
		// 	append(&_held, Key_Press{Mouse.Right});
		// }
		// if glfw.GetMouseButton(main_window, glfw.Mouse.Middle) == glfw.Action.Press {
		// 	append(&_held, Key_Press{Mouse.Middle});
		// }

		io := imgui.get_io();

		for held in _held_mid_frame {
			is_mouse := is_mouse_input(held);

			if (is_mouse && io.want_capture_mouse) || (!is_mouse && io.want_capture_keyboard) {
				append(&_held_imgui, held);
			}
			else {
				append(&_held, held);
			}
		}
		for down in _down_mid_frame {
			is_mouse := is_mouse_input(down);

			if (is_mouse && io.want_capture_mouse) || (!is_mouse && io.want_capture_keyboard) {
				append(&_down_imgui, down);
			}
			else {
				append(&_down, down);
			}
		}
		for up in _up_mid_frame {
			is_mouse := is_mouse_input(up);

			if (is_mouse && io.want_capture_mouse) || (!is_mouse && io.want_capture_keyboard) {
				append(&_up_imgui, up);
			}
			else {
				append(&_up, up);
			}

		}
	}

	// Clear intermediary buffers. We don't clear `_held_mid_frame` because that is handled in the key callback when we get a `release` event
	clear(&_down_mid_frame);
	clear(&_up_mid_frame);
}

// :GlfwJoystickPollEventsCrash in wb.odin
// _glfw_joystick_callback :: proc"c"(id: i32, event: i32)  {
// 	if event == glfw.CONNECTED {
// 		// Make sure that controller doesn't already exist
// 		for _, controller_idx in controllers {
// 			controller := &controllers[controller_idx];
// 			if controller.id == id {
// 				assert(false);
// 			}
// 		}

// 		controller: Connected_Controller;
// 		controller.id = id;
// 		controller.axes = glfw.GetJoystickAxes(id);
// 		append(&controllers, controller);
// 	}

// 	if event == glfw.DISCONNECTED {
// 		for _, controller_idx in controllers {
// 			controller := &controllers[controller_idx];
// 			if controller.id == id {
// 				remove_at(&controllers, controller_idx);
// 				return;
// 			}
// 		}
// 	}
// }

wb_button_press :: proc(button: $Input_Type) {
	append(&_held_mid_frame, cast(Input)button);
	append(&_down_mid_frame, cast(Input)button);
}
wb_button_release :: proc(button: $Input_Type) {
	idx := -1;
	for held, i in _held_mid_frame {
		if held == cast(Input)button {
			idx = i;
			break;
		}
	}
	// idx being -1 means that we got a release but no press, which sometimes happens
	if idx != -1 {
		unordered_remove(&_held_mid_frame, idx);
	}
	append(&_up_mid_frame, cast(Input)button);
}

// this callback CAN be called during a frame, outside of the glfw.PollEvents() call, on some platforms
// so we need to save presses in a separate buffer and copy them over to have consistent behaviour
_glfw_key_callback :: proc"c"(window: glfw.Window_Handle, key: glfw.Key, scancode: i32, action: glfw.Action, mods: i32) {
	switch action {
		case glfw.Action.Press: {
			wb_button_press(cast(Input)key);
		}
		case glfw.Action.Release: {
			wb_button_release(cast(Input)key);
		}
	}
}

_glfw_mouse_button_callback :: proc"c"(window: glfw.Window_Handle, button: glfw.Mouse, action: glfw.Action, mods: i32) {
	switch action {
		case glfw.Action.Press: {
			wb_button_press(button);
		}
		case glfw.Action.Release: {
			wb_button_release(button);
		}
	}
}

