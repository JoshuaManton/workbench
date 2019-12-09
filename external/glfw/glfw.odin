package glfw

import "core:os"
import "core:fmt"
import "../../math"
import "../../basic"
import "core:strings"
import "core:mem"

when os.OS == "windows" do foreign import glfw "glfw3dll.lib";

/*** Structs/types ***/
Window_Handle  :: rawptr;
Monitor_Handle :: rawptr;
Cursor_Handle  :: rawptr;

Vid_Mode :: struct {
    width:        i32,
    height:       i32,
    red_bits:     i32,
    green_bits:   i32,
    blue_bits:    i32,
    refresh_rate: i32,
};

Gamma_Ramp :: struct {
    red, green, blue: ^u16,
    size:              u32,
};

Image :: struct {
    width, height: i32,
    pixels:        ^u8,
};

/*** Procedure type declarations ***/
Window_Iconify_Proc   :: #type proc "c" (window: Window_Handle, iconified: i32);
Window_Refresh_Proc   :: #type proc "c" (window: Window_Handle);
Window_Focus_Proc     :: #type proc "c" (window: Window_Handle, focused: i32);
Window_Close_Proc     :: #type proc "c" (window: Window_Handle);
Window_Size_Proc      :: #type proc "c" (window: Window_Handle, width, height: i32);
Window_Pos_Proc       :: #type proc "c" (window: Window_Handle, xpos, ypos: i32);
Framebuffer_Size_Proc :: #type proc "c" (window: Window_Handle, width, height: i32);
Drop_Proc             :: #type proc "c" (window: Window_Handle, count: i32, paths: ^cstring);
Monitor_Proc          :: #type proc "c" (window: Window_Handle);

Key_Proc              :: #type proc "c" (window: Window_Handle, key: Key, scancode: i32, action: Action, mods: i32);
Mouse_Button_Proc     :: #type proc "c" (window: Window_Handle, button: Mouse, action: Action, mods: i32);
Cursor_Pos_Proc       :: #type proc "c" (window: Window_Handle, xpos,  ypos: f64);
Scroll_Proc           :: #type proc "c" (window: Window_Handle, xoffset, yoffset: f64);
Char_Proc             :: #type proc "c" (window: Window_Handle, codepoint: u32);
Char_Mods_Proc        :: #type proc "c" (window: Window_Handle, codepoint: u32, mods: i32);
Cursor_Enter_Proc     :: #type proc "c" (window: Window_Handle, entered: i32);
Joystick_Proc         :: #type proc "c" (joy, event: i32);

Error_Proc            :: #type proc "c" (error: i32, description: cstring);

/*** Functions ***/
@(default_calling_convention="c")
foreign glfw {
    @(link_name="glfwInit")                             Init      :: proc() -> i32 ---;
    @(link_name="glfwTerminate")                        Terminate :: proc() ---;

                                                        glfwGetVersion :: proc(major, minor, rev: ^i32) ---;

    @(link_name="glfwGetPrimaryMonitor")                GetPrimaryMonitor          :: proc() -> Monitor_Handle ---;
                                                        glfwGetMonitors            :: proc(count: ^i32) -> ^Monitor_Handle ---;
                                                        glfwGetMonitorPos          :: proc(monitor: Monitor_Handle, xpos, ypos: ^i32) ---;
                                                        glfwGetMonitorPhysicalSize :: proc(monitor: Monitor_Handle, widthMM, heightMM: ^i32) ---;

    @(link_name="glfwGetVideoMode")                     GetVideoMode  :: proc(monitor: Monitor_Handle) -> ^Vid_Mode ---;

    @(link_name="glfwSetGamma")                         SetGamma     :: proc(monitor: Monitor_Handle, gamma: f32) ---;
    @(link_name="glfwGetGammaRamp")                     GetGammaRamp :: proc(monitor: Monitor_Handle) -> ^Gamma_Ramp ---;
    @(link_name="glfwSetGammaRamp")                     SetGammaRamp :: proc(monitor: Monitor_Handle, ramp: ^Gamma_Ramp) ---;

                                                        glfwCreateWindow  :: proc "c"(width, height: i32, title: cstring, monitor: Monitor_Handle, share: Window_Handle) -> Window_Handle ---;
    @(link_name="glfwDestroyWindow")                    DestroyWindow     :: proc(window: Window_Handle) ---;

    @(link_name="glfwWindowHint")                       WindowHint         :: proc(hint, value: i32) ---;
    @(link_name="glfwDefaultWindowHints")               DefaultWindowHints :: proc() ---;

                                                        glfwWindowShouldClose  :: proc(window: Window_Handle) -> i32 ---;

    @(link_name="glfwSwapInterval")                     SwapInterval :: proc(interval: i32) ---;
    @(link_name="glfwSwapBuffers")                      SwapBuffers  :: proc(window: Window_Handle) ---;

                                                        glfwSetWindowTitle   :: proc(window: Window_Handle, title: cstring) ---;
    @(link_name="glfwSetWindowIcon")                    SetWindowIcon        :: proc(window: Window_Handle, count: i32, images: ^Image) ---;
    @(link_name="glfwSetWindowPos")                     SetWindowPos         :: proc(window: Window_Handle, xpos, ypos: i32) ---;
    @(link_name="glfwSetWindowSizeLimits")              SetWindowSizeLimits  :: proc(window: Window_Handle, minwidth, minheight, maxwidth, maxheight: i32) ---;
    @(link_name="glfwSetWindowAspectRatio")             SetWindowAspectRatio :: proc(window: Window_Handle, numer, denom: i32) ---;
    @(link_name="glfwSetWindowSize")                    SetWindowSize        :: proc(window: Window_Handle, width, height: i32) ---;
                                                        glfwGetWindowPos         :: proc(window: Window_Handle, xpos, ypos: ^i32) ---;
                                                        glfwGetWindowSize        :: proc(window: Window_Handle, width, height: ^i32) ---;
                                                        glfwGetFramebufferSize   :: proc(window: Window_Handle, width, height: ^i32) ---;
                                                        glfwGetWindowFrameSize   :: proc(window: Window_Handle, left, top, right, bottom: ^i32) ---;

    @(link_name="glfwIconifyWindow")                    IconifyWindow  :: proc(window: Window_Handle) ---;
    @(link_name="glfwRestoreWindow")                    RestoreWindow  :: proc(window: Window_Handle) ---;
    @(link_name="glfwMaximizeWindow")                   MaximizeWindow :: proc(window: Window_Handle) ---;
    @(link_name="glfwShowWindow")                       ShowWindow     :: proc(window: Window_Handle) ---;
    @(link_name="glfwHideWindow")                       HideWindow     :: proc(window: Window_Handle) ---;
    @(link_name="glfwFocusWindow")                      FocusWindow    :: proc(window: Window_Handle) ---;

    @(link_name="glfwGetWindowMonitor")                 GetWindowMonitor     :: proc(window: Window_Handle) ---;
    @(link_name="glfwSetWindowMonitor")                 SetWindowMonitor     :: proc(window: Window_Handle, monitor: Monitor_Handle, xpos, ypos, width, height, refresh_rate: i32) ---;
    @(link_name="glfwGetWindowAttrib")                  GetWindowAttrib      :: proc(window: Window_Handle, attrib: i32) -> i32 ---;
    @(link_name="glfwSetWindowUserPointer")             SetWindowUserPointer :: proc(window: Window_Handle, pointer: rawptr) ---;
    @(link_name="glfwGetWindowUserPointer")             GetWindowUserPointer :: proc(window: Window_Handle) -> rawptr ---;

    @(link_name="glfwPollEvents")                       PollEvents        :: proc() ---;
    @(link_name="glfwWaitEvents")                       WaitEvents        :: proc() ---;
    @(link_name="glfwWaitEventsTimeout")                WaitEventsTimeout :: proc(timeout: f64) ---;
    @(link_name="glfwPostEmptyEvent")                   PostEmptyEvent    :: proc() ---;

    @(link_name="glfwGetInputMode")                     GetInputMode :: proc(window: Window_Handle, mode: i32) -> i32 ---;
    @(link_name="glfwSetInputMode")                     SetInputMode :: proc(window: Window_Handle, mode, value: i32) ---;

    @(link_name="glfwGetMouseButton")                   GetMouseButton     :: proc(window: Window_Handle, button: Mouse) -> Action ---;
                                                        glfwGetCursorPos   :: proc(window: Window_Handle, xpos, ypos: ^f64) ---;
    @(link_name="glfwSetCursorPos")                     SetCursorPos       :: proc(window: Window_Handle, xpos, ypos: f64) ---;

    @(link_name="glfwCreateCursor")                     CreateCursor         :: proc(image: ^Image, xhot, yhot: i32) -> Cursor_Handle ---;
    @(link_name="glfwDestroyCursor")                    DestroyCursor        :: proc(cursor: Cursor_Handle) ---;
    @(link_name="glfwSetCursor")                        SetCursor            :: proc(window: Window_Handle, cursor: Cursor_Handle) ---;
    @(link_name="glfwCreateStandardCursor")             CreateStandardCursor :: proc(shape: i32) -> Cursor_Handle ---;

                                                        glfwGetJoystickAxes    :: proc(joy: i32, count: ^i32) -> ^f32 ---;
                                                        glfwGetJoystickButtons :: proc(joy: i32, count: ^i32) -> ^u8 ---;

    @(link_name="glfwSetClipboardString")               SetClipboardString :: proc(window: Window_Handle, str: cstring) ---;

    @(link_name="glfwGetTime")                          GetTime           :: proc() -> f64 ---;
    @(link_name="glfwSetTime")                          SetTime           :: proc(time: f64) ---;
    @(link_name="glfwGetTimerValue")                    GetTimerValue     :: proc() -> u64 ---;
    @(link_name="glfwGetTimerFrequency")                GetTimerFrequency :: proc() -> u64 ---;

    @(link_name="glfwMakeContextCurrent")               MakeContextCurrent :: proc(window: Window_Handle) ---;
    @(link_name="glfwGetCurrentContext")                GetCurrentContext  :: proc() -> Window_Handle ---;
    @(link_name="glfwGetProcAddress")                   GetProcAddress     :: proc(name : cstring) -> rawptr ---;
    @(link_name="glfwExtensionSupported")               ExtensionSupported :: proc(extension: cstring) -> i32 ---;

    @(link_name="glfwGetRequiredInstanceExtensions")    GetRequiredInstanceExtensions ::  proc(count: ^u32) -> ^cstring ---;

    @(link_name="glfwSetWindowIconifyCallback")         SetWindowIconifyCallback   :: proc(window: Window_Handle, cbfun: Window_Iconify_Proc) -> Window_Iconify_Proc ---;
    @(link_name="glfwSetWindowRefreshCallback")         SetWindowRefreshCallback   :: proc(window: Window_Handle, cbfun: Window_Refresh_Proc) -> Window_Refresh_Proc ---;
    @(link_name="glfwSetWindowFocusCallback")           SetWindowFocusCallback     :: proc(window: Window_Handle, cbfun: Window_Focus_Proc) -> Window_Focus_Proc ---;
    @(link_name="glfwSetWindowCloseCallback")           SetWindowCloseCallback     :: proc(window: Window_Handle, cbfun: Window_Close_Proc) -> Window_Close_Proc ---;
    @(link_name="glfwSetWindowSizeCallback")            SetWindowSizeCallback      :: proc(window: Window_Handle, cbfun: Window_Size_Proc) -> Window_Size_Proc ---;
    @(link_name="glfwSetWindowPosCallback")             SetWindowPosCallback       :: proc(window: Window_Handle, cbfun: Window_Pos_Proc) -> Window_Pos_Proc ---;
    @(link_name="glfwSetFramebufferSizeCallback")       SetFramebufferSizeCallback :: proc(window: Window_Handle, cbfun: Framebuffer_Size_Proc) -> Framebuffer_Size_Proc ---;
    @(link_name="glfwSetDropCallback")                  SetDropCallback            :: proc(window: Window_Handle, cbfun: Drop_Proc) -> Drop_Proc ---;
    @(link_name="glfwSetMonitorCallback")               SetMonitorCallback         :: proc(window: Window_Handle, cbfun: Monitor_Proc) -> Monitor_Proc ---;

    @(link_name="glfwSetKeyCallback")                   SetKeyCallback         :: proc(window: Window_Handle, cbfun: Key_Proc) -> Key_Proc ---;
    @(link_name="glfwSetMouseButtonCallback")           SetMouseButtonCallback :: proc(window: Window_Handle, cbfun: Mouse_Button_Proc) -> Mouse_Button_Proc ---;
    @(link_name="glfwSetCursorPosCallback")             SetCursorPosCallback   :: proc(window: Window_Handle, cbfun: Cursor_Pos_Proc) -> Cursor_Pos_Proc ---;
    @(link_name="glfwSetScrollCallback")                SetScrollCallback      :: proc(window: Window_Handle, cbfun: Scroll_Proc) -> Scroll_Proc ---;
    @(link_name="glfwSetCharCallback")                  SetCharCallback        :: proc(window: Window_Handle, cbfun: Char_Proc) -> Char_Proc ---;
    @(link_name="glfwSetCharModsCallback")              SetCharModsCallback    :: proc(window: Window_Handle, cbfun: Char_Mods_Proc) -> Char_Mods_Proc ---;
    @(link_name="glfwSetCursorEnterCallback")           SetCursorEnterCallback :: proc(window: Window_Handle, cbfun: Cursor_Enter_Proc) -> Cursor_Enter_Proc ---;
    @(link_name="glfwSetJoystickCallback")              SetJoystickCallback    :: proc(window: Window_Handle, cbfun: Joystick_Proc) -> Joystick_Proc ---;

    @(link_name="glfwSetErrorCallback")                 SetErrorCallback :: proc(cbfun: Error_Proc) -> Error_Proc ---;
}

// Odin Wrappers

GetVersion :: proc() -> (major, minor, rev: i32) {
    glfwGetVersion(&major, &minor, &rev);
    return major, minor, rev;
}

GetVersionString :: proc() -> string {
    foreign glfw {
        glfwGetVersionString :: proc "c" () -> cstring ---;
    }
    return string(cstring(glfwGetVersionString()));
}

GetMonitors :: proc() -> []Monitor_Handle {
    count: i32;
    data := glfwGetMonitors(&count);
    return mem.slice_ptr(data, int(count));
}
GetMonitorPos :: proc(monitor: Monitor_Handle) -> (xpos, ypos: i32) {
    glfwGetMonitorPos(monitor, &xpos, &ypos);
    return xpos, ypos;
}
GetMonitorPhysicalSize :: proc(monitor: Monitor_Handle) -> (widthMM, heightMM: i32) {
    glfwGetMonitorPhysicalSize(monitor, &widthMM, &heightMM);
    return widthMM, heightMM;
}

GetMonitorName :: proc(monitor: Monitor_Handle) -> string {
    foreign glfw {
        glfwGetMonitorName :: proc "c" (monitor: Monitor_Handle) -> cstring ---;
    }
    return string(cstring(glfwGetMonitorName(monitor)));
}

CreateWindow :: inline proc(width, height: i32, title: string, monitor: Monitor_Handle, share: Window_Handle) -> Window_Handle {
    return glfwCreateWindow(width, height, basic.TEMP_CSTRING(title), monitor, share);
}

GetClipboardString :: proc(window: Window_Handle) -> string {
    foreign glfw {
        glfwGetClipboardString :: proc "c" (window: Window_Handle) -> cstring ---;
    }
    return string(cstring(glfwGetClipboardString(window)));
}

GetVideoModes :: proc(monitor: Monitor_Handle) -> []Vid_Mode {
    foreign glfw {
        glfwGetVideoModes :: proc "c" (monitor: Monitor_Handle, count: ^i32) -> ^Vid_Mode ---;
    }
    count: i32;
    data := glfwGetVideoModes(monitor, &count);
    return mem.slice_ptr(data, int(count));
}



GetKey :: inline proc(window: Window_Handle, key: Key) -> Action {
    foreign glfw {
        glfwGetKey :: proc "c" (window: Window_Handle, key: Key) -> Action ---;
    }
    return glfwGetKey(window, key);
}
GetKeyName :: proc(key, scancode: i32) -> string {
    foreign glfw {
        glfwGetKeyName :: proc "c" (key, scancode: i32) -> cstring ---;
    }
    return string(cstring(glfwGetKeyName(key, scancode)));
}



GetCursorPos :: proc(window: Window_Handle) -> (xpos, ypos: f64) {
    glfwGetCursorPos(window, &xpos, &ypos);
    return xpos, ypos;
}


WindowShouldClose :: proc(window: Window_Handle) -> bool {
    return glfwWindowShouldClose(window) == TRUE;
}

SetWindowShouldClose :: proc(window: Window_Handle, set: bool) {
    foreign glfw {
        glfwSetWindowShouldClose :: proc "c" (window: Window_Handle, value: i32) ---;
    }
    glfwSetWindowShouldClose(window, set ? 1 : 0);
}
SetWindowTitle :: proc(window: Window_Handle, fmt_string: string, args: ..any) {
    if len(fmt_string) >= 256 {
        SetWindowTitle(window, "Too long title format string");
        return;
    }
    buf: [1024]u8;
    title := fmt.bprintf(buf[:], fmt_string, ..args);
    glfwSetWindowTitle(window, basic.TEMP_CSTRING(title));
}

GetWindowPos :: proc(window: Window_Handle) -> (xpos, ypos: i32) {
    glfwGetWindowPos(window, &xpos, &ypos);
    return xpos, ypos;
}
GetWindowSize :: proc(window: Window_Handle) -> (width, height: i32) {
    glfwGetWindowSize(window, &width, &height);
    return width, height;
}
GetFramebufferSize :: proc(window: Window_Handle) -> (width, height: i32)  {
    glfwGetFramebufferSize(window, &width, &height);
    return width, height;
}
GetWindowFrameSize :: proc(window: Window_Handle) -> (left, top, right, bottom: i32) {
    glfwGetWindowFrameSize(window, &left, &top, &right, &bottom);
    return left, top, right, bottom;
}

JoystickPresent :: proc(joy: i32) -> bool {
    foreign glfw {
        glfwJoystickPresent :: proc "c" (joy: i32) -> i32 ---;
    }
    return glfwJoystickPresent(joy) != 0;
}

VulkanSupported :: proc() -> bool {
    foreign glfw {
        glfwVulkanSupported :: proc "c" () -> i32 ---;
    }
    return glfwVulkanSupported() != 0;
}

GetJoystickAxes :: proc(joy: i32) -> []f32 {
    count: i32;
    data := glfwGetJoystickAxes(joy, &count);
    return mem.slice_ptr(data, int(count));
}

GetJoystickButtons :: proc(joy: i32) -> []u8 {
    count: i32;
    data := glfwGetJoystickButtons(joy, &count);
    return mem.slice_ptr(data, int(count));
}

GetJoystickName :: proc(joy: i32) -> string {
    foreign glfw {
        glfwGetJoystickName :: proc "c" (joy: i32) -> cstring ---;
    }
    return string(cstring(glfwGetJoystickName(joy)));
}



// globals for persistent timing data, placeholder for "static" variables
_TimingStruct :: struct {
    t1, avg_dt, avg_dt2, last_frame_time : f64,
    num_samples, counter: int,
}
persistent_timing_data := _TimingStruct{0.0, 0.0, 0.0, 1.0/60, 60, 0};

calculate_frame_timings :: proc(window: Window_Handle) {
    using persistent_timing_data;
    t2 := GetTime();
    dt := t2-t1;
    t1 = t2;

    avg_dt += dt;
    avg_dt2 += dt*dt;
    counter += 1;

    last_frame_time = dt;

    if counter == num_samples {
        avg_dt  /= f64(num_samples);
        avg_dt2 /= f64(num_samples);
        std_dt := math.sqrt(avg_dt2 - avg_dt*avg_dt);
        ste_dt := std_dt/math.sqrt(f64(num_samples));

        SetWindowTitle(window, "frame timings: avg = %.3fms, std = %.3fms, ste = %.4fms. fps = %.1f\x00", 1e3*avg_dt, 1e3*std_dt, 1e3*ste_dt, 1.0/avg_dt);

        num_samples = int(1.0/avg_dt);
        avg_dt = 0.0;
        avg_dt2 = 0.0;
        counter = 0;
    }
}

init_helper :: proc(resx := 1280, resy := 720, title := "Window title", version_major := 3, version_minor := 3, samples := 0, vsync := false) -> Window_Handle {
    //
    error_callback :: proc"c"(error: i32, desc: cstring) {
        fmt.printf("Error code %d: %s\n", error, desc);
    }
    SetErrorCallback(error_callback);

    //
    if Init() == FALSE do return nil;

    //
    if samples > 0 do WindowHint(SAMPLES, i32(samples));
    WindowHint(CONTEXT_VERSION_MAJOR, i32(version_major));
    WindowHint(CONTEXT_VERSION_MINOR, i32(version_minor));
    WindowHint(OPENGL_PROFILE, OPENGL_CORE_PROFILE);

    //
    window := CreateWindow(i32(resx), i32(resy), title, nil, nil);
    if window == nil do return nil;

    //
    MakeContextCurrent(window);
    SwapInterval(i32(vsync));

    return window;
}

set_proc_address :: proc(p: rawptr, name: cstring) {
    (cast(^rawptr)p)^ = GetProcAddress(name);
}

/*** Constants ***/
/* Versions */
VERSION_MAJOR    :: 3;
VERSION_MINOR    :: 2;
VERSION_REVISION :: 1;

/* Booleans */
TRUE  :: 1;
FALSE :: 0;

/* Button/Key states */
Action :: enum i32 {
    Release = 0,
    Press   = 1,
    Repeat  = 2,
}

Key :: enum i32 {
    /* The unknown key */
    Unknown = -1,

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
    BACKSLASH     = 92,  /* \ */
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

/* Bitmask for modifier keys */
MOD_SHIFT   :: 0x0001;
MOD_CONTROL :: 0x0002;
MOD_ALT     :: 0x0004;
MOD_SUPER   :: 0x0008;

Mouse :: enum i32 {
    /* Mouse buttons */
    Button_1 = 0,
    Button_2 = 1,
    Button_3 = 2,
    Button_4 = 3,
    Button_5 = 4,
    Button_6 = 5,
    Button_7 = 6,
    Button_8 = 7,

    /* Mousebutton aliases */
    Last   = Button_8,
    Left   = Button_1,
    Right  = Button_2,
    Middle = Button_3,
}


/* Joystick buttons */
JOYSTICK_1  :: 0;
JOYSTICK_2  :: 1;
JOYSTICK_3  :: 2;
JOYSTICK_4  :: 3;
JOYSTICK_5  :: 4;
JOYSTICK_6  :: 5;
JOYSTICK_7  :: 6;
JOYSTICK_8  :: 7;
JOYSTICK_9  :: 8;
JOYSTICK_10 :: 9;
JOYSTICK_11 :: 10;
JOYSTICK_12 :: 11;
JOYSTICK_13 :: 12;
JOYSTICK_14 :: 13;
JOYSTICK_15 :: 14;
JOYSTICK_16 :: 15;

JOYSTICK_LAST :: JOYSTICK_16;

/* Error constants */
NOT_INITIALIZED     :: 0x00010001;
NO_CURRENT_CONTEXT  :: 0x00010002;
INVALID_ENUM        :: 0x00010003;
INVALID_VALUE       :: 0x00010004;
OUT_OF_MEMORY       :: 0x00010005;
API_UNAVAILABLE     :: 0x00010006;
VERSION_UNAVAILABLE :: 0x00010007;
PLATFORM_ERROR      :: 0x00010008;
FORMAT_UNAVAILABLE  :: 0x00010009;
NO_WINDOW_CONTEXT   :: 0x0001000A;

/* Window attributes */
FOCUSED      :: 0x00020001;
ICONIFIED    :: 0x00020002;
RESIZABLE    :: 0x00020003;
VISIBLE      :: 0x00020004;
DECORATED    :: 0x00020005;
AUTO_ICONIFY :: 0x00020006;
FLOATING     :: 0x00020007;
MAXIMIZED    :: 0x00020008;

/* Pixel window attributes */
RED_BITS         :: 0x00021001;
GREEN_BITS       :: 0x00021002;
BLUE_BITS        :: 0x00021003;
ALPHA_BITS       :: 0x00021004;
DEPTH_BITS       :: 0x00021005;
STENCIL_BITS     :: 0x00021006;
ACCUM_RED_BITS   :: 0x00021007;
ACCUM_GREEN_BITS :: 0x00021008;
ACCUM_BLUE_BITS  :: 0x00021009;
ACCUM_ALPHA_BITS :: 0x0002100A;
AUX_BUFFERS      :: 0x0002100B;
STEREO           :: 0x0002100C;
SAMPLES          :: 0x0002100D;
SRGB_CAPABLE     :: 0x0002100E;
REFRESH_RATE     :: 0x0002100F;
DOUBLEBUFFER     :: 0x00021010;

/* Context window attributes */
CLIENT_API               :: 0x00022001;
CONTEXT_VERSION_MAJOR    :: 0x00022002;
CONTEXT_VERSION_MINOR    :: 0x00022003;
CONTEXT_REVISION         :: 0x00022004;
CONTEXT_ROBUSTNESS       :: 0x00022005;
OPENGL_FORWARD_COMPAT    :: 0x00022006;
OPENGL_DEBUG_CONTEXT     :: 0x00022007;
OPENGL_PROFILE           :: 0x00022008;
CONTEXT_RELEASE_BEHAVIOR :: 0x00022009;
CONTEXT_NO_ERROR         :: 0x0002200A;
CONTEXT_CREATION_API     :: 0x0002200B;

/* APIs */
NO_API        :: 0;
OPENGL_API    :: 0x00030001;
OPENGL_ES_API :: 0x00030002;

/* Robustness? */
NO_ROBUSTNESS         :: 0;
NO_RESET_NOTIFICATION :: 0x00031001;
LOSE_CONTEXT_ON_RESET :: 0x00031002;

/* OpenGL Profiles */
OPENGL_ANY_PROFILE    :: 0;
OPENGL_CORE_PROFILE   :: 0x00032001;
OPENGL_COMPAT_PROFILE :: 0x00032002;

/* Cursor draw state and whether keys are sticky */
CURSOR               :: 0x00033001;
STICKY_KEYS          :: 0x00033002;
STICKY_MOUSE_BUTTONS :: 0x00033003;

/* Cursor draw state */
CURSOR_NORMAL   :: 0x00034001;
CURSOR_HIDDEN   :: 0x00034002;
CURSOR_DISABLED :: 0x00034003;

/* Behavior? */
ANY_RELEASE_BEHAVIOR   :: 0;
RELEASE_BEHAVIOR_FLUSH :: 0x00035001;
RELEASE_BEHAVIOR_NONE  :: 0x00035002;

/* Context API ? */
NATIVE_CONTEXT_API :: 0x00036001;
EGL_CONTEXT_API    :: 0x00036002;

/* Types of cursors */
ARROW_CURSOR     :: 0x00036001;
IBEAM_CURSOR     :: 0x00036002;
CROSSHAIR_CURSOR :: 0x00036003;
HAND_CURSOR      :: 0x00036004;
HRESIZE_CURSOR   :: 0x00036005;
VRESIZE_CURSOR   :: 0x00036006;

/* Joystick? */
CONNECTED    :: 0x00040001;
DISCONNECTED :: 0x00040002;

/*  */
DONT_CARE :: -1;