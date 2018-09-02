package workbench

using import "core:math"
using import "core:fmt"

Alphanum :: struct {
	value: f32,
	exponent: int,
}

alphanum_raw_value :: inline proc(a: Alphanum) -> f32 {
	raw_value := pow(a.value, (cast(f32)a.exponent * 1000));
	return raw_value;
}

alphanum_normalize :: proc(a: Alphanum) -> Alphanum {
	for a.value >= 1000 {
		a.value -= 1000;
		a.exponent += 1;
	}
	return a;
}

alphanum_add :: proc(a, b: Alphanum) -> Alphanum {
	raw_value := alphanum_raw_value(a) + alphanum_raw_value(b);
	new_exponent := 0;
	raw_result := Alphanum{raw_value, new_exponent};
	new_result := alphanum_normalize(raw_result);
	return new_result;
}

// alphanum_print :: proc(a: Alphanum) {
// 	sb: String_Buffer;
// 	defer delete(sb);

// 	sbprint(&sb, a.value);
// 	exp := a.exponent;
// 	for a.exponent > 26 {
// 		sbprint(&sb, 'a' + a.value);
// 	}

// 	logln(to_string(sb));
// }

_test_alphabetical_notation :: proc() {
	// a := Alphanum{500, 0};
	// b := Alphanum{1500, 0};
	// // b := Alphanum{1000, 0};

	// alphanum_print(alphanum_normalize(a));
	// alphanum_print(alphanum_normalize(b));

	// logln(alphanum_raw_value(a));
	// logln(alphanum_raw_value(b));
}