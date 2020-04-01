package profiler

import "core:fmt"
import "core:hash"
import rt "core:runtime"

import "../math"

import "shared:workbench/external/imgui"

Profiler :: struct {
	is_recording: bool,

	get_time_proc: proc() -> f64,
	all_sections: map[u64]Section_Statistics,
}

Section_Statistics :: struct {
	name: string,
	total_time:   f64,
	num_times:    i32,
	average_time: f64,
	max_time:     f64,
}

Timed_Section_Info :: struct {
	id: u64,
	profiler: ^Profiler,
	start_time: f64,
}

make_profiler :: proc(get_time_proc: proc() -> f64) -> Profiler {
	return Profiler{false, get_time_proc, {}};
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

				// imgui.im_slider_int("num samples", &section.slice_size, 1, len(section.all_times), nil);
				// imgui.plot_lines("time (ms)", &section.all_times[0], section.slice_size);
				imgui.columns(2);
				imgui.text("average");
				imgui.next_column();
				imgui.text(tprintf("%.8f", section.average_time));
				imgui.next_column();
				imgui.text("total");
				imgui.next_column();
				imgui.text(tprintf("%.8f", section.total_time));
				imgui.next_column();
				imgui.text("max");
				imgui.next_column();
				imgui.text(tprintf("%.8f", section.max_time));
				imgui.columns(1);
			}
		}
	}
	imgui.end();
}

profiler_new_frame :: proc(profiler: ^Profiler) {
}

clear_profiler :: proc(using profiler: ^Profiler) {
	clear(&all_sections);
}

destroy_profiler :: proc(using profiler: ^Profiler) {
	delete(all_sections);
}

@(deferred_out=END_TIMED_SECTION)
TIMED_SECTION :: proc(profiler: ^Profiler, name := "", loc := #caller_location) -> (Timed_Section_Info, bool) {
	if profiler.get_time_proc != nil {
		//"No `get_time_proc` was set before calling TIMED_SECTION()."
		return {}, false;
	}

	if !profiler.is_recording {
		return {0, profiler, 0}, false;
	}

	if loc.hash notin profiler.all_sections {
		profiler.all_sections[loc.hash] = Section_Statistics{
			name          = (name == "" ? loc.procedure : name),
			total_time    = 0,
			num_times     = 0,
			average_time  = 0,
		};
	}

	start_time := profiler.get_time_proc();
	return {loc.hash, profiler, start_time}, true;
}

END_TIMED_SECTION :: proc(using info: Timed_Section_Info, _valid: bool) {
	if !_valid do return;

	assert(profiler.get_time_proc != nil, "No `get_time_proc` was set before calling END_TIMED_SECTION().");

	end_time := profiler.get_time_proc();

	section_info, ok := profiler.all_sections[id];
	if ok {
		using section_info;

		time_taken := end_time - start_time;
		total_time += time_taken;
		num_times += 1;
		average_time = total_time / cast(f64)num_times;
		max_time = max(max_time, time_taken);

		profiler.all_sections[id] = section_info;
	}
}

main :: proc() {

}




tprint :: fmt.tprint;
tprintf :: fmt.tprintf;