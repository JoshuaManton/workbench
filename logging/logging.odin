package logging

import "core:fmt"
import "../basic"

logln :: proc(args: ..any, location := #caller_location) {
	fmt.print(basic.pretty_location(location), ' ');
	fmt.print(..args);
	fmt.print('\n');
}

logf :: proc(f: string, args: ..any, location := #caller_location) {
	fmt.print(basic.pretty_location(location), ' ');

	// todo(josh): escaping?
	last_end: int;
	num_percents: int;
	for b, idx in f {
		if b == '%' && num_percents < len(args) {
			str := f[last_end:idx];
			fmt.print(str);
			fmt.print(args[num_percents]);
			num_percents += 1;
			last_end = idx+1;
		}
	}
	last := f[last_end:len(f)];
	fmt.print(last);
	fmt.print('\n');
}