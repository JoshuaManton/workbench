package platform

import "core:fmt"
import "core:sort"
import "core:strings"
import "core:mem"
import "core:os"
import "core:sys/win32"

import "../gpu"
import "../logging"
import "../math"
import "../external/imgui"
import "../external/stb"

foreign import "system:kernel32.lib"
foreign kernel32 {
    @(link_name="SetLastError") set_last_error :: proc(error: i32) ---;
}

foreign import "system:user32.lib"
foreign user32 {
    @(link_name="SetCapture")     set_capture     :: proc(h: win32.Hwnd) -> win32.Hwnd ---;
    @(link_name="ReleaseCapture") release_capture :: proc() -> win32.Bool ---;
}

Window_Platform_Data :: struct {
    window_handle:  win32.Hwnd,
    device_context: win32.Hdc,
    render_context: win32.Hglrc,
}

update_platform_os :: proc() {
    message: win32.Msg;
    for win32.peek_message_a(&message, nil, 0, 0, win32.PM_REMOVE) {
        win32.translate_message(&message);
        win32.dispatch_message_a(&message);
    }
}

platform_render :: proc() {
    LOG_WINDOWS_ERROR();
    defer LOG_WINDOWS_ERROR();
    assert(main_window.platform_data.device_context != nil);
    win32.swap_buffers(main_window.platform_data.device_context);
}

create_window :: proc(name: string, width, height: int) -> (Window, bool) {
    defer LOG_WINDOWS_ERROR();

    //
    instance := cast(win32.Hinstance)win32.get_module_handle_a(nil);
    if instance == nil {
        logln("Error getting instance handle: ", get_and_clear_last_win32_error());
        return {}, false;
    }

    //
    window_class: win32.Wnd_Class_Ex_A;
    window_class.size = size_of(win32.Wnd_Class_Ex_A);
    window_class.style = win32.CS_OWNDC | win32.CS_HREDRAW | win32.CS_VREDRAW;
    window_class.wnd_proc = wnd_proc;
    window_class.instance = instance;
    window_class.cursor = win32.load_cursor_a(nil, win32.IDC_ARROW);
    window_class.class_name = cstring("HenloWindowClass");
    class := win32.register_class_ex_a(&window_class);
    if class == 0 {
        logln("Error in register_class_ex_a(): ", get_and_clear_last_win32_error());
        return {}, false;
    }

    //
    window: Window;
    old_window := currently_updating_window;
    currently_updating_window = &window;
    defer currently_updating_window = old_window;

    rect := win32.Rect{0, 0, cast(i32)width, cast(i32)height};
    win32.adjust_window_rect(&rect, win32.WS_OVERLAPPEDWINDOW, false);
    win32.create_window_ex_a(0,
                             window_class.class_name,
                             strings.clone_to_cstring(name, context.temp_allocator),
                             win32.WS_OVERLAPPEDWINDOW | win32.WS_VISIBLE,
                             200, // todo(josh): get the resolution of the monitor and put the window in the center
                             100, // todo(josh): get the resolution of the monitor and put the window in the center
                             rect.right - rect.left,
                             rect.bottom - rect.top,
                             nil,
                             nil,
                             window_class.instance,
                             nil);

    assert(window.platform_data.window_handle != nil);

    return window, true;
}

opengl_module: win32.Hmodule; // amazing

wnd_proc :: proc "c" (window_handle: win32.Hwnd, message: u32, wparam: win32.Wparam, lparam: win32.Lparam) -> win32.Lresult {
    assert(currently_updating_window != nil);

    result: win32.Lresult;

    @static mouse_capture_sum: int;

    switch (message) {
        case win32.WM_CREATE: {
            defer LOG_WINDOWS_ERROR();
            assert(currently_updating_window.platform_data.window_handle == nil);
            currently_updating_window.platform_data.window_handle = window_handle;

            assert(currently_updating_window.platform_data.device_context == nil);
            dc := win32.get_dc(window_handle);
            currently_updating_window.platform_data.device_context = dc;

            // todo(josh): look into what this stuff means
            if !setup_pixel_format(dc) {
                win32.post_quit_message(0);
            }

            rc := win32.create_context(dc);
            currently_updating_window.platform_data.render_context = rc;

            win32.make_current(dc, rc);
            rect: win32.Rect;
            win32.get_client_rect(window_handle, &rect);

            assert(opengl_module == nil);
            opengl_module = win32.load_library_a("opengl32.dll");
            defer {
                win32.free_library(opengl_module);
                opengl_module = nil;
            }

            // todo(josh): fancier context
            // create_context_attribs_arb := cast(win32.Create_Context_Attribs_ARB_Type)win32.get_gl_proc_address("wglChoosePixelFormatARB");
            // logln(create_context_attribs_arb);

            gpu.init(proc(p: rawptr, name: cstring) {
                LOG_WINDOWS_ERROR();

                proc_ptr := win32.get_gl_proc_address(name);

                // Sometimes get_gl_proc_address doesn't work so we fallback to using win32.get_proc_address. Sigh.
                switch transmute(int)cast(uintptr)proc_ptr {
                    case -1, 0, 1, 2, 3: { // holy fuck windows what are you doing to me here
                        proc_ptr = win32.get_proc_address(opengl_module, name);

                        err := get_and_clear_last_win32_error();
                        if err != 0 {
                            if proc_ptr != nil {
                                // if we got it in the fallback, the first one will have set an error. ignore it
                            }
                            else if proc_ptr == nil {
                                logf("failed to load proc %. windows error: %", name, err);
                                panic(fmt.tprint(name));
                            }
                        }
                    }
                }

                assert(proc_ptr != nil);

                LOG_WINDOWS_ERROR();

                (cast(^rawptr)p)^ = proc_ptr;
             });
        }
        case win32.WM_SIZE: {
            defer LOG_WINDOWS_ERROR();
            // todo(josh): figure out what to do with wparam
            switch wparam {
                case 0 /* SIZE_RESTORED  */:
                case 1 /* SIZE_MINIMIZED */:
                case 2 /* SIZE_MAXIMIZED */:
                case 3 /* SIZE_MAXSHOW   */:
                case 4 /* SIZE_MAXHIDE   */:
            }

            width  := win32.LOWORD_L(lparam);
            height := win32.HIWORD_L(lparam);

            logln("New window size: ", width, height);
            currently_updating_window.width  = cast(f32)width;
            currently_updating_window.height = cast(f32)height;
            currently_updating_window.aspect = currently_updating_window.width / currently_updating_window.height;
            currently_updating_window.size   = Vec2{currently_updating_window.width,  currently_updating_window.height};
        }
        case win32.WM_MOUSEMOVE: {
            x := transmute(i16)win32.LOWORD_L(lparam);
            y := transmute(i16)win32.HIWORD_L(lparam);
            old_pos := currently_updating_window.mouse_position_pixel;
            currently_updating_window.mouse_position_pixel = Vec2{cast(f32)x, cast(f32)y};
            currently_updating_window.mouse_position_unit  = currently_updating_window.mouse_position_pixel / currently_updating_window.size;
            currently_updating_window.mouse_position_pixel_delta = currently_updating_window.mouse_position_pixel - old_pos;
        }
        case win32.WM_KEYDOWN, win32.WM_SYSKEYDOWN: { // todo(josh): should we process these separately? the code is the same currently
            defer LOG_WINDOWS_ERROR();
            input := windows_key_mapping[wparam];
            if !g_inputs.inputs_held[input] {
                g_inputs.inputs_down[input] = true;
            }
            g_inputs.inputs_held[input] = true;
        }
        case win32.WM_KEYUP, win32.WM_SYSKEYUP: { // todo(josh): should we process these separately? the code is the same currently
            defer LOG_WINDOWS_ERROR();
            input := windows_key_mapping[wparam];
            g_inputs.inputs_up[input] = true;
            g_inputs.inputs_held[input] = false;
        }
        case win32.WM_CHAR: {
            defer LOG_WINDOWS_ERROR();
            imgui.gui_io_add_input_character(u16(wparam));
        }
        case win32.WM_MOUSEWHEEL: {
            scroll := transmute(i16)win32.HIWORD_W(wparam) / 120; // note(josh): 120 is WHEEL_DELTA in windows
            currently_updating_window.mouse_scroll = cast(f32)scroll;
        }
        case win32.WM_LBUTTONDOWN: {
            if mouse_capture_sum == 0 do set_capture(currently_updating_window.platform_data.window_handle);
            mouse_capture_sum += 1;

            if !g_inputs.inputs_held[.Mouse_Left] {
                g_inputs.inputs_down[.Mouse_Left] = true;
            }
            g_inputs.inputs_held[.Mouse_Left] = true;
        }
        case win32.WM_LBUTTONUP: {
            mouse_capture_sum -= 1;
            if mouse_capture_sum == 0 do release_capture();

            g_inputs.inputs_up[.Mouse_Left]   = true;
            g_inputs.inputs_held[.Mouse_Left] = false;
        }
        case win32.WM_MBUTTONDOWN: {
            if mouse_capture_sum == 0 do set_capture(currently_updating_window.platform_data.window_handle);
            mouse_capture_sum += 1;

            if !g_inputs.inputs_held[.Mouse_Middle] {
                g_inputs.inputs_down[.Mouse_Middle] = true;
            }
            g_inputs.inputs_held[.Mouse_Middle] = true;
        }
        case win32.WM_MBUTTONUP: {
            mouse_capture_sum -= 1;
            if mouse_capture_sum == 0 do release_capture();

            g_inputs.inputs_up[.Mouse_Middle]   = true;
            g_inputs.inputs_held[.Mouse_Middle] = false;
        }
        case win32.WM_RBUTTONDOWN: {
            if mouse_capture_sum == 0 do set_capture(currently_updating_window.platform_data.window_handle);
            mouse_capture_sum += 1;

            if !g_inputs.inputs_held[.Mouse_Right] {
                g_inputs.inputs_down[.Mouse_Right] = true;
            }
            g_inputs.inputs_held[.Mouse_Right] = true;
        }
        case win32.WM_RBUTTONUP: {
            mouse_capture_sum -= 1;
            if mouse_capture_sum == 0 do release_capture();

            g_inputs.inputs_up[.Mouse_Right]   = true;
            g_inputs.inputs_held[.Mouse_Right] = false;
        }
        case win32.WM_ACTIVATEAPP: {
            defer LOG_WINDOWS_ERROR();
            currently_updating_window.is_focused = cast(bool)wparam;
        }
        case win32.WM_CLOSE: {
            defer LOG_WINDOWS_ERROR();
            currently_updating_window.should_close = true;
        }
        case win32.WM_DESTROY: {
            defer LOG_WINDOWS_ERROR();
            gpu.deinit();
        }
        case: {
            LOG_WINDOWS_ERROR();
            defer LOG_WINDOWS_ERROR();
            result = win32.def_window_proc_a(window_handle, message, wparam, lparam);
        }
    }

    LOG_WINDOWS_ERROR();

    return result;
}

setup_pixel_format :: proc(device_context: win32.Hdc) -> bool {
    defer LOG_WINDOWS_ERROR();
    pfd: win32.Pixel_Format_Descriptor;
    pfd.size = size_of(win32.Pixel_Format_Descriptor);
    pfd.version = 1;
    pfd.flags = win32.PFD_DRAW_TO_WINDOW | win32.PFD_SUPPORT_OPENGL | win32.PFD_DOUBLEBUFFER;
    pfd.layer_mask = win32.PFD_MAIN_PLANE;
    pfd.pixel_type = win32.PFD_TYPE_COLORINDEX;
    pfd.color_bits = 8;
    pfd.depth_bits = 16;
    pfd.accum_bits = 0;
    pfd.stencil_bits = 0;

    pixelformat := win32.choose_pixel_format(device_context, &pfd);

    if pixelformat == 0 {
        LOG_WINDOWS_ERROR();
        assert(false, "choose_pixel_format failed");
        return false;
    }

    if win32.set_pixel_format(device_context, pixelformat, &pfd) == false {
        LOG_WINDOWS_ERROR();
        assert(false, "set_pixel_format failed");
        return false;
    }

    return true;
}

get_and_clear_last_win32_error :: proc() -> i32 {
    err := win32.get_last_error();
    set_last_error(0);
    return err;
}

LOG_WINDOWS_ERROR :: proc(loc := #caller_location) -> bool {
    err := get_and_clear_last_win32_error();
    if err == 203 {
        // todo(josh): 203 is the error for ERROR_ENVVAR_NOT_FOUND which I have no idea why we are getting it once per second
        return false;
    }

    if err != 0 {
        logf("win32 error % at %:%", err, loc.file_path, loc.line);
        return true;
    }
    return false;
}

windows_key_mapping := [?]Input{
    0x01 = .Mouse_Left,
    0x02 = .Mouse_Right,
    0x04 = .Mouse_Middle,

    0x08 = .Backspace,
    0x09 = .Tab,

    0x0C = .Clear,
    0x0D = .Enter,

    0x10 = .Shift,
    0x11 = .Control,
    0x12 = .Alt,
    0x13 = .Pause,
    0x14 = .Caps_Lock,

    0x1B = .Escape,

    0x20 = .Space,
    0x21 = .Page_Up,
    0x22 = .Page_Down,
    0x23 = .End,
    0x24 = .Home,
    0x25 = .Left,
    0x26 = .Up,
    0x27 = .Right,
    0x28 = .Down,
    0x29 = .Select,
    0x2A = .Print,
    0x2B = .Execute,
    0x2C = .Print_Screen,
    0x2D = .Insert,
    0x2E = .Delete,
    0x2F = .Help,

    '1' = .NR_1,
    '2' = .NR_2,
    '3' = .NR_3,
    '4' = .NR_4,
    '5' = .NR_5,
    '6' = .NR_6,
    '7' = .NR_7,
    '8' = .NR_8,
    '9' = .NR_9,
    '0' = .NR_0,

    'A' = .A,
    'B' = .B,
    'C' = .C,
    'D' = .D,
    'E' = .E,
    'F' = .F,
    'G' = .G,
    'H' = .H,
    'I' = .I,
    'J' = .J,
    'K' = .K,
    'L' = .L,
    'M' = .M,
    'N' = .N,
    'O' = .O,
    'P' = .P,
    'Q' = .Q,
    'R' = .R,
    'S' = .S,
    'T' = .T,
    'U' = .U,
    'V' = .V,
    'W' = .W,
    'X' = .X,
    'Y' = .Y,
    'Z' = .Z,

    0x5B = .Left_Windows,
    0x5C = .Right_Windows,
    0x5D = .Apps,

    0x5F = .Sleep,

    0x60 = .NP_0,
    0x61 = .NP_1,
    0x62 = .NP_2,
    0x63 = .NP_3,
    0x64 = .NP_4,
    0x65 = .NP_5,
    0x66 = .NP_6,
    0x67 = .NP_7,
    0x68 = .NP_8,
    0x69 = .NP_9,
    0x6A = .Multiply,
    0x6B = .Add,
    0x6C = .Separator,
    0x6D = .Subtract,
    0x6E = .Decimal,
    0x6F = .Divide,
    0x70 = .F1,
    0x71 = .F2,
    0x72 = .F3,
    0x73 = .F4,
    0x74 = .F5,
    0x75 = .F6,
    0x76 = .F7,
    0x77 = .F8,
    0x78 = .F9,
    0x79 = .F10,
    0x7A = .F11,
    0x7B = .F12,

    0x90 = .Num_Lock,
    0x91 = .Scroll_Lock,

    0xBA = .Semicolon,
    0xBB = .Plus,
    0xBC = .Comma,
    0xBD = .Minus,
    0xBE = .Period,
    0xBF = .Forward_Slash,
    0xC0 = .Tilde,
    0xDB = .Left_Square,
    0xDC = .Back_Slash,
    0xDD = .Right_Square,
    0xDE = .Apostrophe,

    // todo(josh)
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
};
