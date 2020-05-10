package platform

import "../math"
import "../logging"
import "../profiler"
import "../external/imgui"

//
// Windowing
//

Window :: struct {
    platform_data: Window_Platform_Data,

    should_close: bool,
    is_focused: bool,

    width:  f32,
    height: f32,
    aspect: f32,
    size:   Vec2,

    mouse_scroll:               f32,
    mouse_position_pixel:       Vec2,
    mouse_position_pixel_delta: Vec2,
    mouse_position_unit:        Vec2,
}

main_window: Window;
currently_updating_window: ^Window;

init_platform :: proc(window_name: string, window_width, window_height: int) -> bool {
    profiler.TIMED_SECTION();

    g_inputs = new(Inputs);

    window, wok := create_window(window_name, window_width, window_height);
    if !wok do return false;
    assert(wok);
    assert(window.platform_data.window_handle != nil);

    main_window = window;

    // update once to get everything ready
    update_platform();

    assert(main_window.width != 0);
    assert(main_window.height != 0);

    return true;
}

update_platform :: proc() {
    profiler.TIMED_SECTION();

    g_inputs.inputs_down = {};
    g_inputs.inputs_up   = {};
    main_window.mouse_scroll = {};
    main_window.mouse_position_pixel_delta = {};

    assert(currently_updating_window == nil);
    currently_updating_window = &main_window;
    defer currently_updating_window = nil;

    update_platform_os();
}



//
// Input
//

Inputs :: struct {
    inputs_held: [Input]bool,
    inputs_down: [Input]bool,
    inputs_up:   [Input]bool,
}

block_keys:  bool;
block_mouse: bool;
g_inputs: ^Inputs;

get_input :: proc(input: Input, consume := false) -> bool {
    is_mouse := is_mouse_input(input);
    if (is_mouse && block_mouse) || (!is_mouse && block_keys) do return false;
    res := g_inputs.inputs_held[input];
    if consume do g_inputs.inputs_held[input] = false;
    return res;
}

get_input_down :: proc(input: Input, consume := false) -> bool {
    is_mouse := is_mouse_input(input);
    if (is_mouse && block_mouse) || (!is_mouse && block_keys) do return false;
    res := g_inputs.inputs_down[input];
    if consume do g_inputs.inputs_down[input] = false;
    return res;
}

get_input_up :: proc(input: Input, consume := false) -> bool {
    is_mouse := is_mouse_input(input);
    if (is_mouse && block_mouse) || (!is_mouse && block_keys) do return false;
    res := g_inputs.inputs_up[input];
    if consume do g_inputs.inputs_up[input] = false;
    return res;
}

_get_global_input :: proc(input: Input, consume := false) -> bool {
    res := g_inputs.inputs_held[input];
    if consume do g_inputs.inputs_held[input] = false;
    return res;
}

_get_global_input_down :: proc(input: Input, consume := false) -> bool {
    res := g_inputs.inputs_down[input];
    if consume do g_inputs.inputs_down[input] = false;
    return res;
}

_get_global_input_up :: proc(input: Input, consume := false) -> bool {
    res := g_inputs.inputs_up[input];
    if consume do g_inputs.inputs_up[input] = false;
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



logln :: logging.logln;
logf :: logging.logf;

Vec2 :: math.Vec2;
Vec3 :: math.Vec3;
Vec4 :: math.Vec4;
Mat3 :: math.Mat3;

