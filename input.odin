package workbench

import "shared:workbench/glfw"

Key    :: glfw.Key;
Mouse  :: glfw.Mouse;
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

Axis_State :: struct {
	axis: Axis,
	value: f32,
}

Key_Press :: struct {
	input: union { Key, Mouse },
}

Controller_State :: struct {
	connected: bool,

	held: []u8,
	down: []u8,
	up:   []u8,
	axes: []f32,
}

_held := make([dynamic]Key_Press, 0, 5);
_down := make([dynamic]Key_Press, 0, 5);
_up   := make([dynamic]Key_Press, 0, 5);

_held_mid_frame := make([dynamic]Key_Press, 0, 5);
_down_mid_frame := make([dynamic]Key_Press, 0, 5);
_up_mid_frame   := make([dynamic]Key_Press, 0, 5);

controllers: [glfw.JOYSTICK_LAST+1]Controller_State;

_input_update :: proc() {
	glfw.PollEvents();

	// Clear old inputs
	{
		clear(&_held);
		clear(&_down);
		clear(&_up);
	}

	// Add joystick inputs
	{
		// Buttons
		{
			for _controller_idx in 0..len(controllers) {
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

				for button_idx in 0..len(buttons) {
					value := buttons[button_idx];
					button := cast(Button)button_idx;

					is_held_now := value == 1;
					was_held_last_frame := get_button(cast(i32)controller_idx, button);

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
		for held in _held_mid_frame {
			append(&_held, held);
		}
		for down in _down_mid_frame {
			append(&_down, down);
		}
		for up in _up_mid_frame {
			append(&_up, up);
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
// 		for controller_idx in 0..len(controllers) {
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
// 		for controller_idx in 0..len(controllers) {
// 			controller := &controllers[controller_idx];
// 			if controller.id == id {
// 				remove_by_index(&controllers, controller_idx);
// 				return;
// 			}
// 		}
// 	}
// }

// this callback CAN be called during a frame, outside of the glfw.PollEvents() call, on some platforms
// so we need to save presses in a separate buffer and copy them over to have consistent behaviour
_glfw_key_callback :: proc"c"(window: glfw.Window_Handle, key: Key, scancode: i32, action: glfw.Action, mods: i32) {
	when false
	{
		fmt.println("------------------------------");
		fmt.println("len of held", len(_held), len(_held_mid_frame));
		fmt.println("len of up",   len(_up),   len(_up_mid_frame));
		fmt.println("len of down", len(_down), len(_down_mid_frame));

		fmt.println("cap of held", cap(_held), cap(_held_mid_frame));
		fmt.println("cap of up",   cap(_up),   cap(_up_mid_frame));
		fmt.println("cap of down", cap(_down), cap(_down_mid_frame));
	}

	switch action {
		case glfw.Action.Press: {
			append(&_held_mid_frame, Key_Press{key});
			append(&_down_mid_frame, Key_Press{key});
		}
		case glfw.Action.Release: {
			idx := -1;
			for held, i in _held_mid_frame {
				if held.input.(Key) == key {
					idx = i;
					break;
				}
			}
			assert(idx != -1);
			remove_by_index(&_held_mid_frame, idx);
			append(&_up_mid_frame, Key_Press{key});
		}
	}
}

_glfw_mouse_button_callback :: proc"c"(window: glfw.Window_Handle, button: Mouse, action: glfw.Action, mods: i32) {
	switch action {
		case glfw.Action.Press: {
			append(&_held_mid_frame, Key_Press{button});
			append(&_down_mid_frame, Key_Press{button});
		}
		case glfw.Action.Release: {
			idx := -1;
			for held, i in _held_mid_frame {
				if held.input.(Mouse) == button {
					idx = i;
					break;
				}
			}
			assert(idx != -1);
			remove_by_index(&_held_mid_frame, idx);
			append(&_up_mid_frame, Key_Press{button});
		}
	}
}

get_mouse :: inline proc(mouse: Mouse) -> bool {
	for held in _held {
		if mouse_held, ok := held.input.(Mouse); ok && mouse_held == mouse {
			return true;
		}
	}
	return false;
}

get_mouse_down :: inline proc(mouse: Mouse) -> bool {
	for down in _down {
		if mouse_down, ok := down.input.(Mouse); ok && mouse_down == mouse {
			return true;
		}
	}
	return false;
}

get_mouse_up :: inline proc(mouse: Mouse) -> bool {
	for up in _up {
		if mouse_up, ok := up.input.(Mouse); ok && mouse_up == mouse {
			return true;
		}
	}
	return false;
}

get_key :: inline proc(key: Key) -> bool {
	for held in _held {
		if key_held, ok := held.input.(Key); ok && key_held == key {
			return true;
		}
	}
	return false;
}

get_key_down :: inline proc(key: Key) -> bool {
	for down in _down {
		if key_down, ok := down.input.(Key); ok && key_down == key {
			return true;
		}
	}
	return false;
}

get_key_up :: inline proc(key: Key) -> bool {
	for up in _up {
		if key_up, ok := up.input.(Key); ok && key_up == key {
			return true;
		}
	}
	return false;
}

get_button :: inline proc(id: i32, button: Button) -> bool {
	controller := controllers[id];
	if !controller.connected do return false;

	return controller.held[cast(int)button] == 1;
}

get_button_down :: inline proc(id: i32, button: Button) -> bool {
	controller := controllers[id];
	if !controller.connected do return false;

	return controller.down[cast(int)button] == 1;
}

get_button_up :: inline proc(id: i32, button: Button) -> bool {
	controller := controllers[id];
	if !controller.connected do return false;

	return controller.up[cast(int)button] == 1;
}

get_axis :: inline proc(id: i32, axis: Axis) -> f32 {
	controller := controllers[id];
	if !controller.connected do return 0;

	return controller.axes[cast(int)axis];
}