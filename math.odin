package workbench

using import "core:math"

sin01 :: inline proc(t: f32) -> f32 {
	result := (sin(t)+1)/2;
	return result;
}

Vec2i :: distinct [2]int;
Vec3i :: distinct [3]int;
Vec4i :: distinct [4]int;

sqr_magnitude :: inline proc(a: $T/[$N]$E) -> f32 do return dot(a, a);
magnitude :: inline proc(a: $T/[$N]$E) -> f32 do return sqrt(dot(a, a));

move_towards :: proc[move_towards_vec2, move_towards_f32];

move_towards_vec2 :: proc(a, b: Vec2, step: f32) -> Vec2 {
	direction := b - a;
	mag := magnitude(direction);

	if mag <= step || mag == 0 {
		return b;
	}

	return a + direction / mag * step;
}

move_towards_f32 :: proc(a, b: f32, step: f32) -> f32 {
	result := a;
	if a > b {
		result -= step;
		if result < b {
			result = b;
		}
	}
	else if a < b {
		result += step;
		if result > b {
			result = b;
		}
	}

	return result;
}


rotate_vec2_degrees :: proc(vec: Vec2, degrees: f32) -> Vec2 {
	s := sin(to_radians(degrees));
	c := cos(to_radians(degrees));

	tx := vec.x;
	ty := vec.y;
	x := (c * tx) - (s * ty);
	y := (s * tx) + (c * ty);

	return Vec2{x, y};
}
rotate_vector :: proc(v: Vec3, k: Vec3, theta: f32) -> Vec3 {
	theta = to_radians(theta);
    cos_theta := cos(theta);
    sin_theta := sin(theta);
    rotated := (v * cos_theta) + (cross(k, v) * sin_theta) + (k * dot(k, v)) * (1 - cos_theta);
    return rotated;
}




project :: inline proc(vec, normal: $T/[$N]$E) -> T {
    num := dot(normal, normal);
    if (num < F32_EPSILON) {
        return T{};
    }

    return normal * dot(vec, normal) / num;
}




clamp :: inline proc(_a, min, max: f32) -> f32 {
	a := _a;
	if a < min do a = min;
	if a > max do a = max;
	return a;
}






remap :: proc(x: $T, a, b, c, d: T) -> T {
    return c * (cast(T)1 - (x - a)/(b - a)) + d * ((x - a)/(b - a));
}








sqr :: inline proc(x: $T) -> T {
	return x * x;
}

distance :: inline proc(x, y: $T) -> f32 {
	diff := x - y;
	return sqrt(sqr(diff.x) + sqr(diff.y));
}

sqr_distance :: inline proc(x, y: $T) -> f32 {
	diff := x - y;
	return sqr(diff.x) + sqr(diff.y);
}

minv :: inline proc(args: ..$T) -> T {
	assert(len(args) > 0);
	current := args[0];
	for arg in args {
		if arg < current {
			current = arg;
		}
	}

	return current;
}

maxv :: inline proc(args: ..$T) -> T {
	assert(len(args) > 0);
	current := args[0];
	for arg in args {
		if arg > current {
			current = arg;
		}
	}
}

degrees_to_vector :: inline proc(degrees: f32) -> Vec2 {
	radians := to_radians(degrees);
	vec := Vec2{cos(radians), sin(radians)};
	return vec;
}

to_vec2 :: inline proc(a: $T/[$N]$E) -> Vec2 {
	result: Vec2;
	idx := 0;
	for idx < len(a) && idx < len(result) {
		result[idx] = a[idx];
		idx += 1;
	}
	return result;
}

to_vec3 :: inline proc(a: $T/[$N]$E) -> Vec3 {
	result: Vec3;
	idx := 0;
	for idx < len(a) && idx < len(result) {
		result[idx] = a[idx];
		idx += 1;
	}
	return result;
}

to_vec4 :: inline proc(a: $T/[$N]$E) -> Vec4 {
	result: Vec4;
	idx := 0;
	for idx < len(a) && idx < len(result) {
		result[idx] = a[idx];
		idx += 1;
	}
	return result;
}

translate :: proc(m: Mat4, v: Vec3) -> Mat4 {
	m[3][0] += v[0];
	m[3][1] += v[1];
	m[3][2] += v[2];
	return m;
}











quaternion_forward :: inline proc(quat: Quat) -> Vec3 {
	return quat_mul_vec3(quat, {0, 0, -1});
}
quaternion_back :: inline proc(quat: Quat) -> Vec3 {
	return -quaternion_forward(quat);
}
quaternion_right :: inline proc(quat: Quat) -> Vec3 {
	return quat_mul_vec3(quat, {1, 0, 0});
}
quaternion_left :: inline proc(quat: Quat) -> Vec3 {
	return -quaternion_right(quat);
}
quaternion_up :: inline proc(quat: Quat) -> Vec3 {
	return quat_mul_vec3(quat, {0, 1, 0});
}
quaternion_down :: inline proc(quat: Quat) -> Vec3 {
	return -quaternion_up(quat);
}

degrees_to_quaternion :: proc(v: Vec3) -> Quat {
	qx := axis_angle(Vec3{1,0,0}, to_radians(v.x));
	qy := axis_angle(Vec3{0,1,0}, to_radians(v.y));
	// todo(josh): z axis
	// qz := axis_angle(Vec3{0,0,1}, to_radians(v.z));
	orientation := quat_mul(qy, qx);
	orientation = quat_norm(orientation);
	return orientation;
}

// note(josh): rotates the vector by the quaternion
quat_mul_vec3 :: proc(quat: Quat, vec: Vec3) -> Vec3{
	num := quat.x * 2;
	num2 := quat.y * 2;
	num3 := quat.z * 2;
	num4 := quat.x * num;
	num5 := quat.y * num2;
	num6 := quat.z * num3;
	num7 := quat.x * num2;
	num8 := quat.x * num3;
	num9 := quat.y * num3;
	num10 := quat.w * num;
	num11 := quat.w * num2;
	num12 := quat.w * num3;
	result: Vec3;
	result.x = (1 - (num5 + num6)) * vec.x + (num7 - num12) * vec.y + (num8 + num11) * vec.z;
	result.y = (num7 + num12) * vec.x + (1 - (num4 + num6)) * vec.y + (num9 - num10) * vec.z;
	result.z = (num8 - num11) * vec.x + (num9 + num10) * vec.y + (1 - (num4 + num5)) * vec.z;
	return result;
}

_mat4_inverse :: proc(m: Mat4) -> Mat4 {
	o: Mat4;

	sf00 := m[2][2] * m[3][3] - m[3][2] * m[2][3];
	sf01 := m[2][1] * m[3][3] - m[3][1] * m[2][3];
	sf02 := m[2][1] * m[3][2] - m[3][1] * m[2][2];
	sf03 := m[2][0] * m[3][3] - m[3][0] * m[2][3];
	sf04 := m[2][0] * m[3][2] - m[3][0] * m[2][2];
	sf05 := m[2][0] * m[3][1] - m[3][0] * m[2][1];
	sf06 := m[1][2] * m[3][3] - m[3][2] * m[1][3];
	sf07 := m[1][1] * m[3][3] - m[3][1] * m[1][3];
	sf08 := m[1][1] * m[3][2] - m[3][1] * m[1][2];
	sf09 := m[1][0] * m[3][3] - m[3][0] * m[1][3];
	sf10 := m[1][0] * m[3][2] - m[3][0] * m[1][2];
	sf11 := m[1][1] * m[3][3] - m[3][1] * m[1][3];
	sf12 := m[1][0] * m[3][1] - m[3][0] * m[1][1];
	sf13 := m[1][2] * m[2][3] - m[2][2] * m[1][3];
	sf14 := m[1][1] * m[2][3] - m[2][1] * m[1][3];
	sf15 := m[1][1] * m[2][2] - m[2][1] * m[1][2];
	sf16 := m[1][0] * m[2][3] - m[2][0] * m[1][3];
	sf17 := m[1][0] * m[2][2] - m[2][0] * m[1][2];
	sf18 := m[1][0] * m[2][1] - m[2][0] * m[1][1];


	o[0][0] = +(m[1][1] * sf00 - m[1][2] * sf01 + m[1][3] * sf02);
	o[0][1] = -(m[0][1] * sf00 - m[0][2] * sf01 + m[0][3] * sf02);
	o[0][2] = +(m[0][1] * sf06 - m[0][2] * sf07 + m[0][3] * sf08);
	o[0][3] = -(m[0][1] * sf13 - m[0][2] * sf14 + m[0][3] * sf15);

	o[1][0] = -(m[1][0] * sf00 - m[1][2] * sf03 + m[1][3] * sf04);
	o[1][1] = +(m[0][0] * sf00 - m[0][2] * sf03 + m[0][3] * sf04);
	o[1][2] = -(m[0][0] * sf06 - m[0][2] * sf09 + m[0][3] * sf10);
	o[1][3] = +(m[0][0] * sf13 - m[0][2] * sf16 + m[0][3] * sf17);

	o[2][0] = +(m[1][0] * sf01 - m[1][1] * sf03 + m[1][3] * sf05);
	o[2][1] = -(m[0][0] * sf01 - m[0][1] * sf03 + m[0][3] * sf05);
	o[2][2] = +(m[0][0] * sf11 - m[0][1] * sf09 + m[0][3] * sf12);
	o[2][3] = -(m[0][0] * sf14 - m[0][1] * sf16 + m[0][3] * sf18);

	o[3][0] = -(m[1][0] * sf02 - m[1][1] * sf04 + m[1][2] * sf05);
	o[3][1] = +(m[0][0] * sf02 - m[0][1] * sf04 + m[0][2] * sf05);
	o[3][2] = -(m[0][0] * sf08 - m[0][1] * sf10 + m[0][2] * sf12);
	o[3][3] = +(m[0][0] * sf15 - m[0][1] * sf17 + m[0][2] * sf18);


	ood := 1.0 / (m[0][0] * o[0][0] +
	              m[0][1] * o[1][0] +
	              m[0][2] * o[2][0] +
	              m[0][3] * o[3][0]);

	o[0][0] *= ood;
	o[0][1] *= ood;
	o[0][2] *= ood;
	o[0][3] *= ood;
	o[1][0] *= ood;
	o[1][1] *= ood;
	o[1][2] *= ood;
	o[1][3] *= ood;
	o[2][0] *= ood;
	o[2][1] *= ood;
	o[2][2] *= ood;
	o[2][3] *= ood;
	o[3][0] *= ood;
	o[3][1] *= ood;
	o[3][2] *= ood;
	o[3][3] *= ood;

	return o;
}