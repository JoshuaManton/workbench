package math

F32_DIG        :: 6;
F32_EPSILON    :: 1.192092896e-07;
F32_GUARD      :: 0;
F32_MANT_DIG   :: 24;
F32_MAX        :: 3.402823466e+38;
F32_MAX_10_EXP :: 38;
F32_MAX_EXP    :: 128;
F32_MIN        :: 1.175494351e-38;
F32_MIN_10_EXP :: -37;
F32_MIN_EXP    :: -125;
F32_NORMALIZE  :: 0;
F32_RADIX      :: 2;
F32_ROUNDS     :: 1;

F64_DIG        :: 15;                       // # of decimal digits of precision
F64_EPSILON    :: 2.2204460492503131e-016;  // smallest such that 1.0+F64_EPSILON != 1.0
F64_MANT_DIG   :: 53;                       // # of bits in mantissa
F64_MAX        :: 1.7976931348623158e+308;  // max value
F64_MAX_10_EXP :: 308;                      // max decimal exponent
F64_MAX_EXP    :: 1024;                     // max binary exponent
F64_MIN        :: 2.2250738585072014e-308;  // min positive value
F64_MIN_10_EXP :: -307;                     // min decimal exponent
F64_MIN_EXP    :: -1021;                    // min binary exponent
F64_RADIX      :: 2;                        // exponent radix
F64_ROUNDS     :: 1;                        // addition rounding: near

TAU          :: 6.28318530717958647692528676655900576;
PI           :: 3.14159265358979323846264338327950288;

E            :: 2.71828182845904523536;
SQRT_TWO     :: 1.41421356237309504880168872420969808;
SQRT_THREE   :: 1.73205080756887729352744634150587236;
SQRT_FIVE    :: 2.23606797749978969640917366873127623;

LOG_TWO      :: 0.693147180559945309417232121458176568;
LOG_TEN      :: 2.30258509299404568401799145468436421;

EPSILON      :: 1.19209290e-7;

τ :: TAU;
π :: PI;

Vec2 :: distinct [2]f32;
Vec3 :: distinct [3]f32;
Vec4 :: distinct [4]f32;

Vec2i :: distinct [2]int;
Vec3i :: distinct [3]int;
Vec4i :: distinct [4]int;

// Column major
Mat2 :: distinct [2][2]f32;
Mat3 :: distinct [3][3]f32;
Mat4 :: distinct [4][4]f32;

Quat :: struct {
	x: f32 `imgui_range="-1":"1"`, y: f32 `imgui_range="-1":"1"`, z: f32 `imgui_range="-1":"1"`, w: f32 `imgui_range="-1":"1"`,
}

QUAT_IDENTITY := Quat{x = 0, y = 0, z = 0, w = 1};

sqr_magnitude :: inline proc(a: $T/[$N]$E) -> f32 do return dot(a, a);
magnitude :: inline proc(a: $T/[$N]$E) -> f32 do return sqrt(dot(a, a));

move_towards :: proc{move_towards_vec, move_towards_f32};

move_towards_vec :: proc(a, b: $T/[$N]$E, step: f32) -> T {
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

distance :: inline proc(x, y: $T/[$N]$E) -> E {
	sqr_dist := sqr_distance(x, y);
	return sqrt(sqr_dist);
}

sqr_distance :: inline proc(x, y: $T/[$N]$E) -> E {
	diff := x - y;
	sum: E;
	for i in 0..<N {
		sum += sqr(diff[i]);
	}
	return sum;
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
	return current;
}

degrees_to_vector :: inline proc(degrees: f32) -> Vec2 {
	radians := to_radians(degrees);
	vec := Vec2{cos(radians), sin(radians)};
	return vec;
}

translate :: proc(m: Mat4, v: Vec3) -> Mat4 {
	m := m;
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

quaternion_to_euler :: proc(q: Quat) -> Vec3 {
	sqw := q.w * q.w;
	sqx := q.x * q.x;
	sqy := q.y * q.y;
	sqz := q.z * q.z;

	rotxrad := cast(f32)atan2(f64(2.0 * ( q.y * q.z + q.x * q.w )) , f64( -sqx - sqy + sqz + sqw ));
	rotyrad := cast(f32)asin(-2.0 * ( q.x * q.z - q.y * q.w ));
	rotzrad := cast(f32)atan2(f64(2.0 * ( q.x * q.y + q.z * q.w )) , f64(  sqx - sqy - sqz + sqw ));

	x := to_degrees(rotxrad);
	y := to_degrees(rotyrad);
	z := to_degrees(rotzrad);
	return Vec3{x, y, z};
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

slerp :: proc(q1: Quat, q2: Quat, t: f32) -> Quat {
	q1 := q1;
	d := dot(q1, q2);
	if d < 0 {
		q1.x = -q1.x;
		q1.y = -q1.y;
		q1.z = -q1.z;
		q1.w = -q1.w;
		d = -d;
	}

	theta  := abs(acos(d));
	halft  := t / 2;
	st     := sin(theta);
	sut    := sin(halft * theta);
	sout   := sin((1-halft)*theta);
	coeff1 := sout / st;
	coeff2 := sut / st;

	x := coeff1 * q1.x + coeff2 * q2.x;
	y := coeff1 * q1.y + coeff2 * q2.y;
	z := coeff1 * q1.z + coeff2 * q2.z;
	w := coeff1 * q1.w + coeff2 * q2.w;

	return Quat{x, y, z, w};
}

asin :: proc(x: f32) -> f32 {
	return cast(f32)atan(cast(f64)(x/sqrt(1-(x*x))));
	// return x*(1+x*x*(1/6+ x*x*(3/(2*4*5) + x*x*((1*3*5)/(2*4*6*7)))));
}

acos :: proc(x: f32) -> f32 {
	// todo(josh): this approximation has a potential error of about 10 degrees according to stack overflow, maybe look into a more accurate implementation
	// return (-0.69813170079773212 * x * x - 0.87266462599716477) * x + 1.5707963267948966;

	a := 1.43+0.59*x; a = (a+(2+2*x)/a)/2;
	b := 1.65-1.41*x; b = (b+(2-2*x)/b)/2;
	c := 0.88-0.77*x; c = (c+(2-a)/c)/2;
	return (8*(c+(2-a)/c)-(b+(2-2*x)/b))/6;
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
	Morebits :: 6.123233995736765886130e-17; // pi/2 = PIO2 + Morebits
	Tan3pio8 :: 2.41421356237309504880;      // tan(3*pi/8)

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



mat4_inverse :: proc(m: Mat4) -> Mat4 {
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




@(default_calling_convention="c")
foreign _ {
	@(link_name="llvm.sqrt.f32")
	sqrt_f32 :: proc(x: f32) -> f32 ---;
	@(link_name="llvm.sqrt.f64")
	sqrt_f64 :: proc(x: f64) -> f64 ---;

	@(link_name="llvm.sin.f32")
	sin_f32 :: proc(θ: f32) -> f32 ---;
	@(link_name="llvm.sin.f64")
	sin_f64 :: proc(θ: f64) -> f64 ---;

	@(link_name="llvm.cos.f32")
	cos_f32 :: proc(θ: f32) -> f32 ---;
	@(link_name="llvm.cos.f64")
	cos_f64 :: proc(θ: f64) -> f64 ---;

	@(link_name="llvm.pow.f32")
	pow_f32 :: proc(x, power: f32) -> f32 ---;
	@(link_name="llvm.pow.f64")
	pow_f64 :: proc(x, power: f64) -> f64 ---;

	@(link_name="llvm.fmuladd.f32")
	fmuladd_f32 :: proc(a, b, c: f32) -> f32 ---;
	@(link_name="llvm.fmuladd.f64")
	fmuladd_f64 :: proc(a, b, c: f64) -> f64 ---;

	@(link_name="llvm.log.f32")
	log_f32 :: proc(x: f32) -> f32 ---;
	@(link_name="llvm.log.f64")
	log_f64 :: proc(x: f64) -> f64 ---;

	@(link_name="llvm.exp.f32")
	exp_f32 :: proc(x: f32) -> f32 ---;
	@(link_name="llvm.exp.f64")
	exp_f64 :: proc(x: f64) -> f64 ---;
}

log :: proc{log_f32, log_f64};
exp :: proc{exp_f32, exp_f64};

tan_f32 :: proc "c" (θ: f32) -> f32 { return sin(θ)/cos(θ); }
tan_f64 :: proc "c" (θ: f64) -> f64 { return sin(θ)/cos(θ); }

lerp :: proc(a, b: $T, t: $E) -> (x: T) { return a*(1-t) + b*t; }

unlerp_f32 :: proc(a, b, x: f32) -> (t: f32) { return (x-a)/(b-a); }
unlerp_f64 :: proc(a, b, x: f64) -> (t: f64) { return (x-a)/(b-a); }


sign_f32 :: proc(x: f32) -> f32 { return x >= 0 ? +1 : -1; }
sign_f64 :: proc(x: f64) -> f64 { return x >= 0 ? +1 : -1; }

copy_sign_f32 :: proc(x, y: f32) -> f32 {
	ix := transmute(u32)x;
	iy := transmute(u32)y;
	ix &= 0x7fff_ffff;
	ix |= iy & 0x8000_0000;
	return transmute(f32)ix;
}

copy_sign_f64 :: proc(x, y: f64) -> f64 {
	ix := transmute(u64)x;
	iy := transmute(u64)y;
	ix &= 0x7fff_ffff_ffff_ffff;
	ix |= iy & 0x8000_0000_0000_0000;
	return transmute(f64)ix;
}


sqrt      :: proc{sqrt_f32, sqrt_f64};
sin       :: proc{sin_f32, sin_f64};
cos       :: proc{cos_f32, cos_f64};
tan       :: proc{tan_f32, tan_f64};
pow       :: proc{pow_f32, pow_f64};
fmuladd   :: proc{fmuladd_f32, fmuladd_f64};
sign      :: proc{sign_f32, sign_f64};
copy_sign :: proc{copy_sign_f32, copy_sign_f64};


round_f32 :: proc(x: f32) -> f32 { return x >= 0 ? floor(x + 0.5) : ceil(x - 0.5); }
round_f64 :: proc(x: f64) -> f64 { return x >= 0 ? floor(x + 0.5) : ceil(x - 0.5); }
round :: proc{round_f32, round_f64};

floor_f32 :: proc(x: f32) -> f32 {
	if x == 0 || is_nan(x) || is_inf(x) {
		return x;
	}
	if x < 0 {
		d, fract := modf(-x);
		if fract != 0.0 {
			d = d + 1;
		}
		return -d;
	}
	d, _ := modf(x);
	return d;
}
floor_f64 :: proc(x: f64) -> f64 {
	if x == 0 || is_nan(x) || is_inf(x) {
		return x;
	}
	if x < 0 {
		d, fract := modf(-x);
		if fract != 0.0 {
			d = d + 1;
		}
		return -d;
	}
	d, _ := modf(x);
	return d;
}
floor :: proc{floor_f32, floor_f64};

ceil_f32 :: proc(x: f32) -> f32 { return -floor_f32(-x); }
ceil_f64 :: proc(x: f64) -> f64 { return -floor_f64(-x); }
ceil :: proc{ceil_f32, ceil_f64};

remainder_f32 :: proc(x, y: f32) -> f32 { return x - round(x/y) * y; }
remainder_f64 :: proc(x, y: f64) -> f64 { return x - round(x/y) * y; }
remainder :: proc{remainder_f32, remainder_f64};

mod_f32 :: proc(x, y: f32) -> (n: f32) {
	z := abs(y);
	n = remainder(abs(x), z);
	if sign(n) < 0 {
		n += z;
	}
	return copy_sign(n, x);
}
mod_f64 :: proc(x, y: f64) -> (n: f64) {
	z := abs(y);
	n = remainder(abs(x), z);
	if sign(n) < 0 {
		n += z;
	}
	return copy_sign(n, x);
}
mod :: proc{mod_f32, mod_f64};

// TODO(bill): These need to implemented with the actual instructions
modf_f32 :: proc(x: f32) -> (int: f32, frac: f32) {
	shift :: 32 - 8 - 1;
	mask  :: 0xff;
	bias  :: 127;

	if x < 1 {
		switch {
		case x < 0:
			int, frac = modf(-x);
			return -int, -frac;
		case x == 0:
			return x, x;
		}
		return 0, x;
	}

	i := transmute(u32)x;
	e := uint(i>>shift)&mask - bias;

	if e < 32-9 {
		i &~= 1<<(32-9-e) - 1;
	}
	int = transmute(f32)i;
	frac = x - int;
	return;
}
modf_f64 :: proc(x: f64) -> (int: f64, frac: f64) {
	shift :: 64 - 11 - 1;
	mask  :: 0x7ff;
	bias  :: 1023;

	if x < 1 {
		switch {
		case x < 0:
			int, frac = modf(-x);
			return -int, -frac;
		case x == 0:
			return x, x;
		}
		return 0, x;
	}

	i := transmute(u64)x;
	e := uint(i>>shift)&mask - bias;

	if e < 64-12 {
		i &~= 1<<(64-12-e) - 1;
	}
	int = transmute(f64)i;
	frac = x - int;
	return;
}
modf :: proc{modf_f32, modf_f64};

is_nan_f32 :: inline proc(x: f32) -> bool { return x != x; }
is_nan_f64 :: inline proc(x: f64) -> bool { return x != x; }
is_nan :: proc{is_nan_f32, is_nan_f64};

is_finite_f32 :: inline proc(x: f32) -> bool { return !is_nan(x-x); }
is_finite_f64 :: inline proc(x: f64) -> bool { return !is_nan(x-x); }
is_finite :: proc{is_finite_f32, is_finite_f64};

is_inf_f32 :: proc(x: f32, sign := 0) -> bool {
	return sign >= 0 && x > F32_MAX || sign <= 0 && x < -F32_MAX;
}
is_inf_f64 :: proc(x: f64, sign := 0) -> bool {
	return sign >= 0 && x > F64_MAX || sign <= 0 && x < -F64_MAX;
}
// If sign > 0,  is_inf reports whether f is positive infinity
// If sign < 0,  is_inf reports whether f is negative infinity
// If sign == 0, is_inf reports whether f is either   infinity
is_inf :: proc{is_inf_f32, is_inf_f64};



to_radians :: proc(degrees: f32) -> f32 { return degrees * TAU / 360; }
to_degrees :: proc(radians: f32) -> f32 { return radians * 360 / TAU; }




mul :: proc{
	mat3_mul,
	mat4_mul, mat4_mul_vec4, mat4_mul_vec3,
	quat_mul, quat_mulf,
};

div :: proc{quat_div, quat_divf};

inverse :: proc{mat4_inverse, quat_inverse};
dot     :: proc{vec_dot, quat_dot};
cross   :: proc{cross2, cross3};

vec_dot :: proc(a, b: $T/[$N]$E) -> E {
	res: E;
	for i in 0..<N {
		res += a[i] * b[i];
	}
	return res;
}

cross2 :: proc(a, b: $T/[2]$E) -> E {
	return a[0]*b[1] - a[1]*b[0];
}

cross3 :: proc(a, b: $T/[3]$E) -> T {
	i := swizzle(a, 1, 2, 0) * swizzle(b, 2, 0, 1);
	j := swizzle(a, 2, 0, 1) * swizzle(b, 1, 2, 0);
	return T(i - j);
}


length :: proc(v: $T/[$N]$E) -> E { return sqrt(dot(v, v)); }

norm :: proc(v: $T/[$N]$E) -> T { return v / length(v); }

norm0 :: proc(v: $T/[$N]$E) -> T {
	m := length(v);
	return m == 0 ? 0 : v/m;
}



identity :: proc($T: typeid/[$N][N]$E) -> T {
	m: T;
	for i in 0..<N do m[i][i] = E(1);
	return m;
}

transpose :: proc(m: $M/[$N][N]f32) -> M {

	nm : M;

	for j in 0..<N {
		for i in 0..<N {
			nm[i][j] = m[j][i];
			nm[j][i] = m[i][j];
		}
	}
	return nm;
}

mat3_mul :: proc(a, b: Mat3) -> Mat3 {
	c: Mat3;
	for j in 0..<3 {
		for i in 0..<3 {
			c[j][i] = a[0][i]*b[j][0] +
			          a[1][i]*b[j][1] +
			          a[2][i]*b[j][2];
		}
	}
	return c;
}

mat4_mul :: proc(a, b: Mat4) -> Mat4 {
	c: Mat4;
	for j in 0..<4 {
		for i in 0..<4 {
			c[j][i] = a[0][i]*b[j][0] +
			          a[1][i]*b[j][1] +
			          a[2][i]*b[j][2] +
			          a[3][i]*b[j][3];
		}
	}
	return c;
}

mat4_mul_vec4 :: proc(m: Mat4, v: Vec4) -> Vec4 {
	return Vec4{
		m[0][0]*v[0] + m[1][0]*v[1] + m[2][0]*v[2] + m[3][0]*v[3],
		m[0][1]*v[0] + m[1][1]*v[1] + m[2][1]*v[2] + m[3][1]*v[3],
		m[0][2]*v[0] + m[1][2]*v[1] + m[2][2]*v[2] + m[3][2]*v[3],
		m[0][3]*v[0] + m[1][3]*v[1] + m[2][3]*v[2] + m[3][3]*v[3],
	};
}

mat4_mul_vec3 :: proc(m: Mat4, v: Vec3) -> Vec3 {
	ret := mat4_mul_vec4(m, Vec4{v.x, v.y, v.z, 1});
	return Vec3{ret.x, ret.y, ret.z};
}

// mat4_inverse :: proc(m: Mat4) -> Mat4 {
// 	o: Mat4;

// 	sf00 := m[2][2] * m[3][3] - m[3][2] * m[2][3];
// 	sf01 := m[2][1] * m[3][3] - m[3][1] * m[2][3];
// 	sf02 := m[2][1] * m[3][2] - m[3][1] * m[2][2];
// 	sf03 := m[2][0] * m[3][3] - m[3][0] * m[2][3];
// 	sf04 := m[2][0] * m[3][2] - m[3][0] * m[2][2];
// 	sf05 := m[2][0] * m[3][1] - m[3][0] * m[2][1];
// 	sf06 := m[1][2] * m[3][3] - m[3][2] * m[1][3];
// 	sf07 := m[1][1] * m[3][3] - m[3][1] * m[1][3];
// 	sf08 := m[1][1] * m[3][2] - m[3][1] * m[1][2];
// 	sf09 := m[1][0] * m[3][3] - m[3][0] * m[1][3];
// 	sf10 := m[1][0] * m[3][2] - m[3][0] * m[1][2];
// 	sf11 := m[1][1] * m[3][3] - m[3][1] * m[1][3];
// 	sf12 := m[1][0] * m[3][1] - m[3][0] * m[1][1];
// 	sf13 := m[1][2] * m[2][3] - m[2][2] * m[1][3];
// 	sf14 := m[1][1] * m[2][3] - m[2][1] * m[1][3];
// 	sf15 := m[1][1] * m[2][2] - m[2][1] * m[1][2];
// 	sf16 := m[1][0] * m[2][3] - m[2][0] * m[1][3];
// 	sf17 := m[1][0] * m[2][2] - m[2][0] * m[1][2];
// 	sf18 := m[1][0] * m[2][1] - m[2][0] * m[1][1];


// 	o[0][0] = +(m[1][1] * sf00 - m[1][2] * sf01 + m[1][3] * sf02);
// 	o[0][1] = -(m[1][0] * sf00 - m[1][2] * sf03 + m[1][3] * sf04);
// 	o[0][2] = +(m[1][0] * sf01 - m[1][1] * sf03 + m[1][3] * sf05);
// 	o[0][3] = -(m[1][0] * sf02 - m[1][1] * sf04 + m[1][2] * sf05);

// 	o[1][0] = -(m[0][1] * sf00 - m[0][2] * sf01 + m[0][3] * sf02);
// 	o[1][1] = +(m[0][0] * sf00 - m[0][2] * sf03 + m[0][3] * sf04);
// 	o[1][2] = -(m[0][0] * sf01 - m[0][1] * sf03 + m[0][3] * sf05);
// 	o[1][3] = +(m[0][0] * sf02 - m[0][1] * sf04 + m[0][2] * sf05);

// 	o[2][0] = +(m[0][1] * sf06 - m[0][2] * sf07 + m[0][3] * sf08);
// 	o[2][1] = -(m[0][0] * sf06 - m[0][2] * sf09 + m[0][3] * sf10);
// 	o[2][2] = +(m[0][0] * sf11 - m[0][1] * sf09 + m[0][3] * sf12);
// 	o[2][3] = -(m[0][0] * sf08 - m[0][1] * sf10 + m[0][2] * sf12);

// 	o[3][0] = -(m[0][1] * sf13 - m[0][2] * sf14 + m[0][3] * sf15);
// 	o[3][1] = +(m[0][0] * sf13 - m[0][2] * sf16 + m[0][3] * sf17);
// 	o[3][2] = -(m[0][0] * sf14 - m[0][1] * sf16 + m[0][3] * sf18);
// 	o[3][3] = +(m[0][0] * sf15 - m[0][1] * sf17 + m[0][2] * sf18);

// 	ood := 1.0 / (m[0][0] * o[0][0] +
// 	              m[0][1] * o[0][1] +
// 	              m[0][2] * o[0][2] +
// 	              m[0][3] * o[0][3]);

// 	o[0][0] *= ood;
// 	o[0][1] *= ood;
// 	o[0][2] *= ood;
// 	o[0][3] *= ood;
// 	o[1][0] *= ood;
// 	o[1][1] *= ood;
// 	o[1][2] *= ood;
// 	o[1][3] *= ood;
// 	o[2][0] *= ood;
// 	o[2][1] *= ood;
// 	o[2][2] *= ood;
// 	o[2][3] *= ood;
// 	o[3][0] *= ood;
// 	o[3][1] *= ood;
// 	o[3][2] *= ood;
// 	o[3][3] *= ood;

// 	return o;
// }


mat4_translate :: proc(v: Vec3) -> Mat4 {
	m := identity(Mat4);
	m[3][0] = v[0];
	m[3][1] = v[1];
	m[3][2] = v[2];
	m[3][3] = 1;
	return m;
}

mat4_rotate :: proc(v: Vec3, angle_radians: f32) -> Mat4 {
	c := cos(angle_radians);
	s := sin(angle_radians);

	a := norm(v);
	t := a * (1-c);

	rot := identity(Mat4);

	rot[0][0] = c + t[0]*a[0];
	rot[0][1] = 0 + t[0]*a[1] + s*a[2];
	rot[0][2] = 0 + t[0]*a[2] - s*a[1];
	rot[0][3] = 0;

	rot[1][0] = 0 + t[1]*a[0] - s*a[2];
	rot[1][1] = c + t[1]*a[1];
	rot[1][2] = 0 + t[1]*a[2] + s*a[0];
	rot[1][3] = 0;

	rot[2][0] = 0 + t[2]*a[0] + s*a[1];
	rot[2][1] = 0 + t[2]*a[1] - s*a[0];
	rot[2][2] = c + t[2]*a[2];
	rot[2][3] = 0;

	return rot;
}

mat4_scale_vec3 :: proc(m: Mat4, v: Vec3) -> Mat4 {
	mm := m;
	mm[0][0] *= v[0];
	mm[1][1] *= v[1];
	mm[2][2] *= v[2];
	return mm;
}

mat4_scale_f32 :: proc(m: Mat4, s: f32) -> Mat4 {
	mm := m;
	mm[0][0] *= s;
	mm[1][1] *= s;
	mm[2][2] *= s;
	return mm;
}

mat4_scale :: proc{mat4_scale_vec3, mat4_scale_f32};


look_at :: proc(eye, centre, up: Vec3) -> Mat4 {
	f := norm(centre - eye);
	s := norm(cross(f, up));
	u := cross(s, f);

	return Mat4{
		{+s.x, +u.x, -f.x, 0},
		{+s.y, +u.y, -f.y, 0},
		{+s.z, +u.z, -f.z, 0},
		{-dot(s, eye), -dot(u, eye), dot(f, eye), 1},
	};
}

perspective :: proc(fovy, aspect, near, far: f32) -> Mat4 {
	m: Mat4;
	tan_half_fovy := tan(0.5 * fovy);

	m[0][0] = 1.0 / (aspect*tan_half_fovy);
	m[1][1] = 1.0 / (tan_half_fovy);
	m[2][2] = -(far + near) / (far - near);
	m[2][3] = -1.0;
	m[3][2] = -2.0*far*near / (far - near);
	return m;
}


ortho3d :: proc(left, right, bottom, top, near, far: f32) -> Mat4 {
	m := identity(Mat4);
	m[0][0] = +2.0 / (right - left);
	m[1][1] = +2.0 / (top - bottom);
	m[2][2] = -2.0 / (far - near);
	m[3][0] = -(right + left)   / (right - left);
	m[3][1] = -(top   + bottom) / (top   - bottom);
	m[3][2] = -(far + near) / (far - near);
	return m;
}


// Quaternion operations

conj :: proc(q: Quat) -> Quat {
	return Quat{-q.x, -q.y, -q.z, q.w};
}

quat_mul :: proc(q0, q1: Quat) -> Quat {
	d: Quat;
	d.x = q0.w * q1.x + q0.x * q1.w + q0.y * q1.z - q0.z * q1.y;
	d.y = q0.w * q1.y - q0.x * q1.z + q0.y * q1.w + q0.z * q1.x;
	d.z = q0.w * q1.z + q0.x * q1.y - q0.y * q1.x + q0.z * q1.w;
	d.w = q0.w * q1.w - q0.x * q1.x - q0.y * q1.y - q0.z * q1.z;
	return d;
}

quat_mulf :: proc(q: Quat, f: f32) -> Quat { return Quat{q.x*f, q.y*f, q.z*f, q.w*f}; }
quat_divf :: proc(q: Quat, f: f32) -> Quat { return Quat{q.x/f, q.y/f, q.z/f, q.w/f}; }

quat_div     :: proc(q0, q1: Quat) -> Quat { return mul(q0, quat_inverse(q1)); }
quat_inverse :: proc(q: Quat) -> Quat { return div(conj(q), dot(q, q)); }
quat_dot     :: proc(q0, q1: Quat) -> f32 { return q0.x*q1.x + q0.y*q1.y + q0.z*q1.z + q0.w*q1.w; }

quat_norm :: proc(q: Quat) -> Quat {
	m := sqrt(dot(q, q));
	return div(q, m);
}

axis_angle :: proc(axis: Vec3, angle_radians: f32) -> Quat {
	v := norm(axis) * sin(0.5*angle_radians);
	w := cos(0.5*angle_radians);
	return Quat{v.x, v.y, v.z, w};
}

euler_angles :: proc(pitch, yaw, roll: f32) -> Quat {
	p := axis_angle(Vec3{1, 0, 0}, pitch);
	y := axis_angle(Vec3{0, 1, 0}, yaw);
	r := axis_angle(Vec3{0, 0, 1}, roll);
	return mul(mul(y, p), r);
}

quat_to_mat4 :: proc(q: Quat) -> Mat4 {
	a := quat_norm(q);
	xx := a.x*a.x; yy := a.y*a.y; zz := a.z*a.z;
	xy := a.x*a.y; xz := a.x*a.z; yz := a.y*a.z;
	wx := a.w*a.x; wy := a.w*a.y; wz := a.w*a.z;

	m := identity(Mat4);

	m[0][0] = 1 - 2*(yy + zz);
	m[0][1] =     2*(xy + wz);
	m[0][2] =     2*(xz - wy);

	m[1][0] =     2*(xy - wz);
	m[1][1] = 1 - 2*(xx + zz);
	m[1][2] =     2*(yz + wx);

	m[2][0] =     2*(xz + wy);
	m[2][1] =     2*(yz - wx);
	m[2][2] = 1 - 2*(xx + yy);
	return m;
}

mat4_to_quat :: proc(m: Mat4) -> Quat {
	w := sqrt(1 + m[0][0] + m[1][1] + m[2][2]) / 2;
	w4 := w * 4;
	x := (m[2][1] - m[1][2]) / w4;
	y := (m[0][2] - m[2][0]) / w4;
	z := (m[1][0] - m[0][1]) / w4;
	return Quat{x,y,z,w};
}