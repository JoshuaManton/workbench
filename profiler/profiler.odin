package profiler

using import "core:fmt"
using import "core:math"

import    "core:hash"
import rt "core:runtime"

import imgui "shared:workbench/external/imgui"

Profiler :: struct {
	get_time_proc: proc() -> f64,
	this_frame_sections: map[u64]Section_Statistics,
	all_sections: map[u64]Section_Statistics,
}

Section_Statistics :: struct {
	name: string,

	all_times:    [1024]f32,
	cur_time_idx: i32,
	slice_size:   i32,

	total_time:   f64,
	num_times:    i32,
	average_time: f64,
}

Timed_Section_Info :: struct {
	id: u64,
	profiler: ^Profiler,
	start_time: f64,
	location: rt.Source_Code_Location,
}

make_profiler :: proc(get_time_proc: proc() -> f64) -> Profiler {
	return Profiler{get_time_proc, {}, {}};
}

profiler_imgui_window :: proc(profiler: ^Profiler) {
	if imgui.begin("Profiler") {
		for id, _ in profiler.all_sections {
			imgui.push_id(tprint(id)); defer imgui.pop_id();

			section := profiler.all_sections[id];
			defer profiler.all_sections[id] = section;

			if imgui.collapsing_header(section.name) {
				imgui.indent();
				defer imgui.unindent();

				imgui.im_slider_int("num samples", &section.slice_size, 1, len(section.all_times), nil);
				imgui.plot_lines("time (ms)", &section.all_times[0], section.slice_size);
				imgui.columns(2);
				imgui.text("average");
				imgui.next_column();
				imgui.text(tprintf("%.8f", section.average_time));
				imgui.columns(1);
			}
		}
	}
	imgui.end();
}

profiler_new_frame :: proc(profiler: ^Profiler) {

}

destroy_profiler :: proc(using profiler: ^Profiler) {
	delete(all_sections);
	delete(this_frame_sections);
}

@(deferred=END_TIMED_SECTION)
TIMED_SECTION :: proc(profiler: ^Profiler, name := "", loc := #caller_location) -> Timed_Section_Info {
	assert(profiler.get_time_proc != nil, "No `get_time_proc` was set before calling TIMED_SECTION().");

	h: u64;
	if name == "" {
		bytes := transmute([size_of(rt.Source_Code_Location)]byte)loc;
		h = hash_bytes(bytes[:]);
	}
	else {
		h = hash_bytes(cast([]byte)name);
	}

	if h notin profiler.all_sections {
		profiler.all_sections[h] = Section_Statistics{
			name          = (name == "" ? loc.procedure : name),
			all_times     = {},
			cur_time_idx  = 0,
			slice_size    = 256,
			total_time    = 0,
			num_times     = 0,
			average_time  = 0,
		};
	}

	start_time := profiler.get_time_proc();
	return {h, profiler, start_time, loc};
}

END_TIMED_SECTION :: proc(using info: Timed_Section_Info) {
	assert(profiler.get_time_proc != nil, "No `get_time_proc` was set before calling END_TIMED_SECTION().");
	end_time := profiler.get_time_proc();

	section_info, ok := profiler.all_sections[id];
	assert(ok);

	using section_info;

	time_taken := end_time - start_time;
	all_times[cur_time_idx] = cast(f32)time_taken;
	cur_time_idx = (cur_time_idx + 1) % slice_size;
	total_time += time_taken;
	num_times += 1;
	average_time = total_time / cast(f64)num_times;

	profiler.all_sections[id] = section_info;
}

hash_bytes :: inline proc(bytes: []byte) -> u64 {
	h: u64 = 0xcbf29ce484222325;
	for b in bytes {
		h = (h * 0x100000001b3) ~ u64(b);
	}
	return h;
}

main :: proc() {

}