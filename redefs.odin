package workbench

import "core:fmt"

tprint :: fmt.tprint;
println :: fmt.println;
sbprint :: fmt.sbprint;

import "logging"

logln :: logging.logln;
logf :: logging.logf;
pretty_print :: logging.pretty_print;

import "profiler"

TIMED_SECTION :: profiler.TIMED_SECTION;

import "math"

TAU :: math.TAU;
PI :: math.PI;

Vec2 :: math.Vec2;
Vec3 :: math.Vec3;
Vec4 :: math.Vec4;
Mat4 :: math.Mat4;
Quat :: math.Quat;

pow :: math.pow;
ortho3d :: math.ortho3d;
perspective :: math.perspective;
translate :: math.translate;
mat4_scale :: math.mat4_scale;
mat4_inverse :: math.mat4_inverse;
quat_to_mat4 :: math.quat_to_mat4;
to_radians :: math.to_radians;
mul :: math.mul;
length :: math.length;
magnitude :: math.magnitude;
norm :: math.norm;
dot :: math.dot;
acos :: math.acos;
cos :: math.cos;
sin :: math.sin;
sqrt :: math.sqrt;
slerp :: math.slerp;
quat_norm :: math.quat_norm;
round :: math.round;
quaternion_forward :: math.quaternion_forward;
quaternion_back :: math.quaternion_back;
quaternion_up :: math.quaternion_up;
quaternion_down :: math.quaternion_down;
quaternion_left :: math.quaternion_left;
quaternion_right :: math.quaternion_right;
axis_angle :: math.axis_angle;
identity :: math.identity;
inverse :: math.inverse;
lerp :: math.lerp;
quat_look_at :: math.quat_look_at;
quat_mul_vec3 :: math.quat_mul_vec3;
mod :: math.mod;

import "types"

Colorf :: types.Colorf;
Maybe :: types.Maybe;
getval :: types.getval;

import "basic"

to_vec2 :: basic.to_vec2;
to_vec3 :: basic.to_vec3;
to_vec4 :: basic.to_vec4;