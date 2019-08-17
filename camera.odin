package workbench

using import "core:math"

      import "platform"
      import "gpu"
      import wbm "math"

do_camera_movement :: proc(camera: ^gpu.Camera, speed: f32, fast : f32 = -1, slow : f32 = -1) {
	speed := speed;
	fast := fast;
	slow := slow;

	if fast < 0 do fast = speed;
	if slow < 0 do slow = speed;

	if platform.get_input(.Left_Shift) {
		speed = fast;
	}
	else if platform.get_input(.Left_Alt) {
		speed = slow;
	}

    up      := wbm.quaternion_up(camera.rotation);
    forward := wbm.quaternion_forward(camera.rotation);
	right   := wbm.quaternion_right(camera.rotation);

    down := -up;
    back := -forward;
    left := -right;

	if platform.get_input(.E) { camera.position += up      * speed * fixed_delta_time; }
	if platform.get_input(.Q) { camera.position += down    * speed * fixed_delta_time; }
	if platform.get_input(.W) { camera.position += forward * speed * fixed_delta_time; }
	if platform.get_input(.S) { camera.position += back    * speed * fixed_delta_time; }
	if platform.get_input(.A) { camera.position += left    * speed * fixed_delta_time; }
	if platform.get_input(.D) { camera.position += right   * speed * fixed_delta_time; }

	if platform.get_input(.Mouse_Right) {
		SENSITIVITY :: 0.1;
		delta := platform.mouse_screen_position_delta;
		delta *= SENSITIVITY;
		degrees := Vec3{delta.y, -delta.x, platform.mouse_scroll};
		camera.rotation = rotate_quat_by_degrees(camera.rotation, degrees);
	}
}

rotate_quat_by_degrees :: proc(q: Quat, degrees: Vec3) -> Quat {
	x := axis_angle(Vec3{1, 0, 0}, to_radians(degrees.x));
	y := axis_angle(Vec3{0, 1, 0}, to_radians(degrees.y));
	z := axis_angle(Vec3{0, 0, 1}, to_radians(degrees.z));
	result := mul(y, q);
	result  = mul(result, x);
	result  = mul(result, z);
	return quat_norm(result);
}