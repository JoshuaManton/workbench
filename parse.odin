package workbench

import "core:strconv";

parse_int :: inline proc(str: string) -> int do return cast(int)strconv.parse_i64(str);
parse_i8  :: inline proc(str: string) -> i8  do return cast(i8) strconv.parse_i64(str);
parse_i16 :: inline proc(str: string) -> i16 do return cast(i16)strconv.parse_i64(str);
parse_i32 :: inline proc(str: string) -> i32 do return cast(i32)strconv.parse_i64(str);
parse_i64 :: inline proc(str: string) -> i64 do return cast(i64)strconv.parse_i64(str);

parse_uint :: inline proc(str: string) -> uint do return cast(uint)strconv.parse_u64(str);
parse_u8   :: inline proc(str: string) -> u8   do return cast(u8)  strconv.parse_u64(str);
parse_u16  :: inline proc(str: string) -> u16  do return cast(u16) strconv.parse_u64(str);
parse_u32  :: inline proc(str: string) -> u32  do return cast(u32) strconv.parse_u64(str);
parse_u64  :: inline proc(str: string) -> u64  do return cast(u64) strconv.parse_u64(str);

parse_f32  :: inline proc(str: string) -> f32 do return strconv.parse_f32(str);
parse_f64  :: inline proc(str: string) -> f64 do return strconv.parse_f64(str);

parse_bool :: inline proc(str: string) -> bool { val, ok := strconv.parse_bool(str); assert(ok); return val; }