package math

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

move_towards :: proc{move_towards_vec2, move_towards_vec3, move_towards_f32};

move_towards_vec2 :: proc(a, b: Vec2, step: f32) -> Vec2 {
	direction := b - a;
	mag := magnitude(direction);

	if mag <= step || mag == 0 {
		return b;
	}

	return a + direction / mag * step;
}

move_towards_vec3 :: proc(a, b: Vec3, step: f32) -> Vec3 {
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
rotate_vector :: proc(v: Vec3, k: Vec3, _theta: f32) -> Vec3 {
	theta := _theta;
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

translate :: proc(_m: Mat4, v: Vec3) -> Mat4 {
	m := _m;
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
	qz := axis_angle(Vec3{0,0,1}, to_radians(v.z));
	orientation := quat_mul(qy, qx);
	orientation = quat_mul(qz, orientation);
	orientation = quat_norm(orientation);
	return orientation;
}

direction_to_quaternion :: proc(v: Vec3) -> Quat {
	assert(length(v) != 0);
	angle : f32 = cast(f32)atan2(cast(f64)v.x, cast(f64)v.z); // Note: I expected atan2(z,x) but OP reported success with atan2(x,z) instead! Switch around if you see 90° off.
	qx : f32 = 0;
	qy : f32 = cast(f32)1 * sin(angle/2);
	qz : f32 = 0;
	qw : f32 = cast(f32)cos(angle/2);
	return Quat{qx, qy, qz, qw};
}

// note(josh): rotates the vector by the quaternion
quat_mul_vec3 :: proc(quat: Quat, vec: Vec3) -> Vec3 {
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

atan2 :: proc(y, x: f64) -> f64 {
    // special cases
    switch {
    case is_nan(y) || is_nan(x):
        return x;
    case y == 0:
        if x >= 0 && !(transmute(u64)x & 0x80000000 > 0) {
            return copy_sign(0, y);
        }
        return copy_sign(PI, y);
    case x == 0:
        return copy_sign(PI/2, y);
    case is_inf(x, 0):
        if is_inf(x, 1) {
            switch {
            case is_inf(y, 0):
                return copy_sign(PI/4, y);
            case:
                return copy_sign(0, y);
            }
        }
        switch {
        case is_inf(y, 0):
            return copy_sign(3*PI/4, y);
        case:
            return copy_sign(PI, y);
        }
    case is_inf(y, 0):
        return copy_sign(PI/2, y);
    }

    // Call atan and determine the quadrant.
    q := atan(y / x);
    if x < 0 {
        return q <= 0 ? q + PI : q - PI;
    }
    return q;
}

// is_inf :: proc(f: f64, sign: int) -> bool {
//     return sign >= 0 && f >= max(f64) || sign <= 0 && f < -max(f64);
// }

copysign :: proc(x, y: f64) -> f64 {
    s_ign :: 1 << 63;
    a := transmute(u64)x;
    b := transmute(u64)y;
    return transmute(f64)(a&~sign | y&~sign);
}

// xatan evaluates a series valid in the range [0, 0.66].
xatan :: proc(x: f64) -> f64 {
	P0 :: -8.750608600031904122785e-01;
	P1 :: -1.615753718733365076637e+01;
	P2 :: -7.500855792314704667340e+01;
	P3 :: -1.228866684490136173410e+02;
	P4 :: -6.485021904942025371773e+01;
	Q0 :: +2.485846490142306297962e+01;
	Q1 :: +1.650270098316988542046e+02;
	Q2 :: +4.328810604912902668951e+02;
	Q3 :: +4.853903996359136964868e+02;
	Q4 :: +1.945506571482613964425e+02;

	z := x * x;
	z = z * ((((P0*z+P1)*z+P2)*z+P3)*z + P4) / (((((z+Q0)*z+Q1)*z+Q2)*z+Q3)*z + Q4);
	z = x*z + x;
	return z;
}

// satan reduces its argument (known to be positive)
// to the range [0, 0.66] and calls xatan.
satan :: proc(x: f64) -> f64 {
	Morebits := 6.123233995736765886130e-17; // pi/2 = PIO2 + Morebits
	Tan3pio8 := 2.41421356237309504880;      // tan(3*pi/8)

	if x <= 0.66 {
		return xatan(x);
	}
	if x > Tan3pio8 {
		return PI/2 - xatan(1/x) + Morebits;
	}
	return PI/4 + xatan((x-1)/(x+1)) + 0.5*Morebits;
}

// Atan returns the arctangent, in radians, of x.
//
// Special cases are:
//      Atan(±0) = ±0
//      Atan(±Inf) = ±Pi/2

atan :: proc(x: f64) -> f64 {
	if x == 0 {
		return x;
	}
	if x > 0 {
		return satan(x);
	}
	return -satan(-x);
}



mat4_inverse_ :: proc(m: Mat4) -> Mat4 {
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