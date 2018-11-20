package workbench

using import "core:math"
      import "core:fmt"

// todo(josh): there is currently an assertion failure in the compiler related
// to the builtin min() and max() procs. remove these when that is fixed
_min :: inline proc(a, b: $T) -> T {
	if a < b do return a;
	return b;
}

_max :: inline proc(a, b: $T) -> T {
	if a > b do return a;
	return b;
}