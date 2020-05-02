package platform

import "../external/imgui"

import "../basic"

/*

INPUT API

get_input      :: proc(input: Input) -> bool
get_input_down :: proc(input: Input) -> bool
get_input_up   :: proc(input: Input) -> bool

*/

inputs_held: [Input]bool;
inputs_down: [Input]bool;
inputs_up:   [Input]bool;

get_input :: proc(input: Input, consume := false) -> bool {
    // man this is gross. it's so that if you have an imgui text field highlighted inputs don't get sent to the game
    io := imgui.get_io();
    is_mouse := is_mouse_input(input);
    if (is_mouse && io.want_capture_mouse) || (!is_mouse && io.want_capture_keyboard) {
        return false;
    }

    res := inputs_held[input];
    if consume do inputs_held[input] = false;
    return res;
}

get_input_down :: proc(input: Input, consume := false) -> bool {
    // man this is gross. it's so that if you have an imgui text field highlighted inputs don't get sent to the game
    io := imgui.get_io();
    is_mouse := is_mouse_input(input);
    if (is_mouse && io.want_capture_mouse) || (!is_mouse && io.want_capture_keyboard) {
        return false;
    }

    res := inputs_down[input];
    if consume do inputs_down[input] = false;
    return res;
}

get_input_up :: proc(input: Input, consume := false) -> bool {
    // man this is gross. it's so that if you have an imgui text field highlighted inputs don't get sent to the game
    io := imgui.get_io();
    is_mouse := is_mouse_input(input);
    if (is_mouse && io.want_capture_mouse) || (!is_mouse && io.want_capture_keyboard) {
        return false;
    }

    res := inputs_up[input];
    if consume do inputs_up[input] = false;
    return res;
}

_get_global_input :: proc(input: Input, consume := false) -> bool {
    res := inputs_held[input];
    if consume do inputs_held[input] = false;
    return res;
}

_get_global_input_down :: proc(input: Input, consume := false) -> bool {
    res := inputs_down[input];
    if consume do inputs_down[input] = false;
    return res;
}

_get_global_input_up :: proc(input: Input, consume := false) -> bool {
    res := inputs_up[input];
    if consume do inputs_up[input] = false;
    return res;
}

is_mouse_input :: proc(input: Input) -> bool {
    #partial
    switch input {
        case .Mouse_Left, .Mouse_Right, .Mouse_Middle: return true;
    }
    return false;
}

Input :: enum {
    None,

    Mouse_Left,
    Mouse_Right,
    Mouse_Middle,

    Backspace,
    Tab,

    Clear, // ?
    Enter,

    Shift,
    Control,
    Alt,
    Pause,
    Caps_Lock,

    Escape,
    Space,
    Page_Up,
    Page_Down,
    End,
    Home,

    Up,
    Down,
    Left,
    Right,

    Select, // ?
    Print, // ? it's not Print_Screen, so what is it?
    Execute, // ?
    Print_Screen,
    Insert,
    Delete,
    Help, // ?

    NR_1, NR_2, NR_3, NR_4, NR_5, NR_6, NR_7, NR_8, NR_9, NR_0,
    A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q, R, S, T, U, V, W, X, Y, Z,

    Left_Windows,
    Right_Windows,
    Apps, // ?

    Sleep,

    NP_0, NP_1, NP_2, NP_3, NP_4, NP_5, NP_6, NP_7, NP_8, NP_9,

    Multiply,
    Add,
    Separator, // Comma?
    Subtract,
    Decimal, // Period?
    Divide, // Forward_Slash?

    F1, F2, F3, F4, F5, F6, F7, F8, F9, F10, F11, F12,

    Num_Lock,
    Scroll_Lock,

    Semicolon,
    Plus,
    Comma,
    Minus,
    Period,
    Forward_Slash,
    Tilde,
    Left_Square,
    Back_Slash,
    Right_Square,
    Apostrophe,

// todo(josh): check these out
// #define VK_OEM_1          0xBA   // ';:' for US
// #define VK_OEM_PLUS       0xBB   // '+' any country
// #define VK_OEM_COMMA      0xBC   // ',' any country
// #define VK_OEM_MINUS      0xBD   // '-' any country
// #define VK_OEM_PERIOD     0xBE   // '.' any country
// #define VK_OEM_2          0xBF   // '/?' for US
// #define VK_OEM_3          0xC0   // '`~' for US
// #define VK_OEM_4          0xDB  //  '[{' for US
// #define VK_OEM_5          0xDC  //  '\|' for US
// #define VK_OEM_6          0xDD  //  ']}' for US
// #define VK_OEM_7          0xDE  //  ''"' for US
// #define VK_OEM_8          0xDF

// todo(josh): gamepad
// #define VK_GAMEPAD_A                         0xC3
// #define VK_GAMEPAD_B                         0xC4
// #define VK_GAMEPAD_X                         0xC5
// #define VK_GAMEPAD_Y                         0xC6
// #define VK_GAMEPAD_RIGHT_SHOULDER            0xC7
// #define VK_GAMEPAD_LEFT_SHOULDER             0xC8
// #define VK_GAMEPAD_LEFT_TRIGGER              0xC9
// #define VK_GAMEPAD_RIGHT_TRIGGER             0xCA
// #define VK_GAMEPAD_DPAD_UP                   0xCB
// #define VK_GAMEPAD_DPAD_DOWN                 0xCC
// #define VK_GAMEPAD_DPAD_LEFT                 0xCD
// #define VK_GAMEPAD_DPAD_RIGHT                0xCE
// #define VK_GAMEPAD_MENU                      0xCF
// #define VK_GAMEPAD_VIEW                      0xD0
// #define VK_GAMEPAD_LEFT_THUMBSTICK_BUTTON    0xD1
// #define VK_GAMEPAD_RIGHT_THUMBSTICK_BUTTON   0xD2
// #define VK_GAMEPAD_LEFT_THUMBSTICK_UP        0xD3
// #define VK_GAMEPAD_LEFT_THUMBSTICK_DOWN      0xD4
// #define VK_GAMEPAD_LEFT_THUMBSTICK_RIGHT     0xD5
// #define VK_GAMEPAD_LEFT_THUMBSTICK_LEFT      0xD6
// #define VK_GAMEPAD_RIGHT_THUMBSTICK_UP       0xD7
// #define VK_GAMEPAD_RIGHT_THUMBSTICK_DOWN     0xD8
// #define VK_GAMEPAD_RIGHT_THUMBSTICK_RIGHT    0xD9
// #define VK_GAMEPAD_RIGHT_THUMBSTICK_LEFT     0xDA
}





// todo(josh): do we need any of this?!?!

/*

//
// Internal
//

_held := make([dynamic]Input, 0, 5);
_down := make([dynamic]Input, 0, 5);
_up   := make([dynamic]Input, 0, 5);

_held_imgui := make([dynamic]Input, 0, 5);
_down_imgui := make([dynamic]Input, 0, 5);
_up_imgui   := make([dynamic]Input, 0, 5);

_held_mid_frame := make([dynamic]Input, 0, 5);
_down_mid_frame := make([dynamic]Input, 0, 5);
_up_mid_frame   := make([dynamic]Input, 0, 5);

@private
update_input :: proc() {
	// Clear old inputs
	{
		clear(&_held);
		clear(&_down);
		clear(&_up);

		clear(&_held_imgui);
		clear(&_down_imgui);
		clear(&_up_imgui);
	}

	// Flush new inputs into the buffers for this frame
	{
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

wb_button_press :: proc(button: $Input_Type) {
	append(&_held_mid_frame, cast(Input)button);
	append(&_down_mid_frame, cast(Input)button);
}
wb_button_release :: proc(button: $Input_Type) {
	// we sometimes get a release with no press/hold
	for held, idx in _held_mid_frame {
		if held == cast(Input)button {
			unordered_remove(&_held_mid_frame, idx);
			break;
		}
	}
	append(&_up_mid_frame, cast(Input)button);
}
*/


/*
// this callback CAN be called during a frame, outside of the glfw.PollEvents() call, on some platforms
// so we need to save presses in a separate buffer and copy them over to have consistent behaviour
_glfw_key_callback :: proc"c"(window: glfw.Window_Handle, key: glfw.Key, scancode: i32, action: glfw.Action, mods: i32) {
	#partial
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
	#partial
	switch action {
		case glfw.Action.Press: {
			wb_button_press(button);
		}
		case glfw.Action.Release: {
			wb_button_release(button);
		}
	}
}
*/



/*
// copypasted from glfw, Key and Mouse combined
Input :: enum i32 {
    Mouse_Button_1 = 0,
    Mouse_Button_2 = 1,
    Mouse_Button_3 = 2,
    Mouse_Button_4 = 3,
    Mouse_Button_5 = 4,
    Mouse_Button_6 = 5,
    Mouse_Button_7 = 6,
    Mouse_Button_8 = 7,

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
*/