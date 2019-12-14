package workbench

using import "math"

      import "platform"
      import "gpu"

do_camera_movement :: proc(camera: ^Camera, dt: f32, normal_speed: f32, fast_speed: f32, slow_speed: f32) {
	speed := normal_speed;

	if platform.get_input(.Left_Shift) {
		speed = fast_speed;
	}
	else if platform.get_input(.Left_Alt) {
		speed = slow_speed;
	}

    up      := quaternion_up(camera.rotation);
    forward := quaternion_forward(camera.rotation);
	right   := quaternion_right(camera.rotation);

    down := -up;
    back := -forward;
    left := -right;

	if platform.get_input(.E) { camera.position += up      * speed * dt; }
	if platform.get_input(.Q) { camera.position += down    * speed * dt; }
	if platform.get_input(.W) { camera.position += forward * speed * dt; }
	if platform.get_input(.S) { camera.position += back    * speed * dt; }
	if platform.get_input(.A) { camera.position += left    * speed * dt; }
	if platform.get_input(.D) { camera.position += right   * speed * dt; }

	rotate_vector: Vec3;
	if platform.get_input(.Mouse_Right) {
		MOUSE_ROTATE_SENSITIVITY :: 0.1;
		delta := platform.mouse_screen_position_delta;
		delta *= MOUSE_ROTATE_SENSITIVITY;
		rotate_vector = Vec3{delta.y, -delta.x, platform.mouse_scroll};
	}
	else {
		KEY_ROTATE_SENSITIVITY :: 1;
		if platform.get_input(.J) do rotate_vector.y =  KEY_ROTATE_SENSITIVITY;
		if platform.get_input(.L) do rotate_vector.y = -KEY_ROTATE_SENSITIVITY;
		if platform.get_input(.I) do rotate_vector.x =  KEY_ROTATE_SENSITIVITY;
		if platform.get_input(.K) do rotate_vector.x = -KEY_ROTATE_SENSITIVITY;
	}

	camera.rotation = rotate_quat_by_degrees(camera.rotation, rotate_vector);
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