package profiler

using import    "core:fmt"
      import    "core:hash"
      import rt "core:runtime"

using import "../math"

      import imgui "shared:workbench/external/imgui"

Profiler :: struct {
	is_recording: bool,
	was_cleared: bool,

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

_Timed_Section_Info :: struct {
	id: u64,
	profiler: ^Profiler,
	start_time: f64,
	location: rt.Source_Code_Location,
}

make_profiler :: proc(get_time_proc: proc() -> f64) -> Profiler {
	return Profiler{false, false, get_time_proc, {}, {}};
}

profiler_imgui_window :: proc(profiler: ^Profiler) {
	if imgui.begin("Profiler") {
		if imgui.button((profiler.is_recording ? "Stop" : "Play")) {
			profiler.is_recording = !profiler.is_recording;
		}
		imgui.same_line();
		if imgui.button("Clear") {
			clear_profiler(profiler);
		}

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
	profiler.was_cleared = false;
}

clear_profiler :: proc(using profiler: ^Profiler) {
	was_cleared = true;
	clear(&this_frame_sections);
	clear(&all_sections);
}

destroy_profiler :: proc(using profiler: ^Profiler) {
	delete(this_frame_sections);
	delete(all_sections);
}

@(deferred_out=END_TIMED_SECTION)
TIMED_SECTION :: proc(profiler: ^Profiler, name := "", loc := #caller_location) -> (_Timed_Section_Info, bool) {
	assert(profiler.get_time_proc != nil, "No `get_time_proc` was set before calling TIMED_SECTION().");

	if !profiler.is_recording {
		return {0, profiler, 0, loc}, false;
	}

	h: u64;
	if name == "" {
		h = loc.hash;
	}
	else {
		h = hash.fnv64(transmute([]byte)name);
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
	return {h, profiler, start_time, loc}, true;
}

END_TIMED_SECTION :: proc(using info: _Timed_Section_Info, _valid: bool) {
	if !_valid do return;
	if profiler.was_cleared do return;

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

main :: proc() {

}