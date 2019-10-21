package workbench

import w32 "core:sys/win32"

// todo(josh): rewrite this using queryperformancecounter probably

Stopwatch :: struct {
	started: bool,
	start_time: u32,
	elapsed_time: u32,
}

start_new :: inline proc() -> Stopwatch {
	sw: Stopwatch;
	start(&sw);
	return sw;
}

start :: inline proc(sw: ^Stopwatch) {
	assert(sw.started == false, "Cannot start stopwatch that is already running.");
	sw.started = true;
	sw.start_time = w32.time_get_time();
}

stop :: inline proc(sw: ^Stopwatch) {
	assert(sw.started == true, "Cannot stop stopwatch that is not running.");
	sw.started = false;
	end_time := w32.time_get_time();
	sw.elapsed_time += (end_time - sw.start_time);
}