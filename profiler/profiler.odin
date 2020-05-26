package profiler

import "core:fmt"
import "core:sort"
import "core:time"
import "core:mem"
import "core:strings"

import "../external/imgui"
import "../allocators"
import "../logging"
import "../basic"

Frame_Info :: struct {
	root_section: ^Section_Info,
}

Section_Info :: struct {
	name: string,
	calls: int,
	time_taken: time.Duration,
	parent: ^Section_Info,
	unaccounted_for: time.Duration,
	children: [dynamic]^Section_Info,
}

profiler_full_frame_times: []f32;
profiler_arena: allocators.Arena;
profiler_allocator: mem.Allocator;
profiler_frame_data: []Frame_Info;
current_profiler_frame: int;

turn_profiler_on:  bool;
turn_profiler_off: bool;
clear_profiler: bool;

current_section: ^Section_Info;
profiler_running: bool;

init_profiler :: proc() {
	NUM_FRAMES :: 600;
	profiler_frame_data = make([]Frame_Info, NUM_FRAMES);
	profiler_full_frame_times = make([]f32, NUM_FRAMES);

	allocators.init_arena(&profiler_arena, make([]byte, mem.megabytes(10)));
	profiler_allocator = allocators.arena_allocator(&profiler_arena);

	// profiler_running = true;
}

deinit_profiler :: proc() {
	delete(profiler_arena.memory);
}

profiler_new_frame :: proc() {
	if turn_profiler_on {
		profiler_running = true;
	}
	if turn_profiler_off {
		profiler_running = false;
	}
	if clear_profiler {
		free_all(profiler_allocator);
		current_profiler_frame = 0;
	}

	turn_profiler_on = false;
	turn_profiler_off = false;
	clear_profiler = false;

	if profiler_running {
		last_frame := profiler_frame_data[current_profiler_frame];
		if last_frame.root_section != nil {
			profiler_full_frame_times[current_profiler_frame] = cast(f32)time.duration_seconds(last_frame.root_section.time_taken);
		}
		current_profiler_frame = (current_profiler_frame + 1) % len(profiler_frame_data);
	}
}

draw_profiler_window :: proc() {
	TREE_FLAGS :: imgui.Tree_Node_Flags.OpenOnArrow | imgui.Tree_Node_Flags.OpenOnDoubleClick;

	if imgui.begin("Profiler") {
		if imgui.button("Start") do turn_profiler_on  = true; imgui.same_line();
		if imgui.button("Stop")  do turn_profiler_off = true; imgui.same_line();
		if imgui.button("Clear") do clear_profiler    = true; imgui.same_line();

		imgui.text(tprintf("Memory Usage: %.1f / %.1fMB", cast(f32)profiler_arena.cur_offset / 1024 / 1024, cast(f32)len(profiler_arena.memory) / 1024 / 1024));

    	@static selected_frame: i32;
		frame_select_delta: i32;
		if imgui.button("<") do frame_select_delta = -1; imgui.same_line();
		if imgui.button(">") do frame_select_delta =  1; imgui.same_line();
		selected_frame = clamp(selected_frame + frame_select_delta, 0, cast(i32)len(profiler_full_frame_times)-1);

		pos := imgui.get_cursor_pos();
    	imgui.plot_lines("##Frame times", &profiler_full_frame_times[0], cast(i32)len(profiler_full_frame_times), 0, nil, 0);
		imgui.set_cursor_pos(pos);
    	imgui.slider_int("frame", &selected_frame, 0, cast(i32)len(profiler_full_frame_times)-1);
    	imgui.same_line();
    	imgui.text(tprint(selected_frame));

		frame := profiler_frame_data[selected_frame];
		if frame.root_section != nil {
			imgui.columns(5);
			draw_section(frame.root_section);
			imgui.columns(1);
		}

		draw_section :: proc(info: ^Section_Info) {
			flags := TREE_FLAGS;

			if len(info.children) == 0 {
                flags |= imgui.Tree_Node_Flags.Leaf;
            }

            is_open := imgui.tree_node_ext(info.name, flags);
			imgui.next_column();
			imgui.text(fmt.tprint("calls: ", info.calls));
			imgui.next_column();
			imgui.text(fmt.tprintf("time: %.8fs", time.duration_seconds(info.time_taken)));
			imgui.next_column();
			if info.parent != nil {
				imgui.text(fmt.tprintf("percent: %.2f", time.duration_seconds(info.time_taken) / time.duration_seconds(info.parent.time_taken) * 100));
			}
			imgui.next_column();
			imgui.text(fmt.tprintf("unaccounted: %.8fs", time.duration_seconds(info.unaccounted_for)));
			imgui.next_column();

            if is_open {
    			sort.quick_sort_proc(info.children[:], proc(x, y: ^Section_Info) -> int {
    				if x.time_taken == y.time_taken {
    					return strings.compare(x.name, y.name);
    				}
    				return x.time_taken - y.time_taken < 0 ? 1 : -1;
    			});

            	for child in info.children {
					draw_section(child);
				}
                imgui.tree_pop();

				// imgui.unindent();
            }
		}
	}
	imgui.end();
}

Timed_Section :: struct {
	start: time.Time,
	info: ^Section_Info,
	old_info: ^Section_Info,
}

@(deferred_out=end_timed_section)
TIMED_SECTION :: proc(name_override: string = "", loc := #caller_location) -> Timed_Section {
	return start_timed_section(name_override, loc);
}

start_timed_section :: proc(name_override: string = "", loc := #caller_location) -> Timed_Section {
	if !profiler_running do return {};

	context.allocator = profiler_allocator;

	section_name := name_override == "" ? loc.procedure : name_override;

	info: ^Section_Info;
	if current_section != nil {
		for child in current_section.children {
			if child.name == section_name {
				info = child;
				break;
			}
		}
	}

	if info == nil {
		info = new(Section_Info);
		if info == nil {
			logln("Ran out of memory in profiler allocator.");
			profiler_running = false;
			return {};
		}

		// init the info
		info^ = {};
		info.name = section_name;
		info.calls = 0;
		info.time_taken = {};
		info.parent = current_section;
		clear(&info.children);

		if current_section != nil {
			append(&current_section.children, info);
		}
	}

	if current_section == nil {
		profiler_frame_data[current_profiler_frame].root_section = info;
	}

	old := current_section;
	current_section = info;
	return Timed_Section{time.now(), info, old};
}

end_timed_section :: proc(using timed_section: Timed_Section) {
	if !profiler_running do return;

	end := time.now();
	info.time_taken += time.diff(start, end);
	info.calls += 1;

	current_section = old_info;

	time_of_children: time.Duration;
	for child in info.children {
		time_of_children += child.time_taken;
	}

	info.unaccounted_for += info.time_taken - time_of_children;
}

// Allocation profiler
Allocation_Profiler :: struct {
	enabled: bool,
	snapshot: [dynamic]Allocation_Info,
}

Allocation_Info :: struct {
	path: string,
	// sizes: []int,
	total_count: int,
	total_size: int,
}

alloc_profiler: Allocation_Profiler;

draw_allocation_profiler :: proc(_tracker: rawptr) {
	allocation_tracker := cast(^allocators.Allocation_Tracker)_tracker;

	if imgui.begin("Allocation Profiler", nil) {
		if imgui.button("Take Snapshot") {
			for ai in alloc_profiler.snapshot do delete(ai.path);
			clear(&alloc_profiler.snapshot);

			outer: for ptr, info in allocation_tracker.allocations {
				path := info.location.file_path == "" ? tprint("BROKEN_FILE_PATH: proc(", info.location.procedure, ")") : basic.pretty_location(info.location);

				for alloc_info in &alloc_profiler.snapshot {
					if alloc_info.path == path {
						alloc_info.total_count += 1;
						alloc_info.total_size += info.size;
						continue outer;
					}
				}

				append(&alloc_profiler.snapshot, Allocation_Info { strings.clone(path), 1, info.size });
			}

			sort.quick_sort_proc(alloc_profiler.snapshot[:], proc(a,b: Allocation_Info) -> int {
				return a.total_size <= b.total_size ? 1 : -1;

			});
		}

		for info in alloc_profiler.snapshot {
			if imgui.collapsing_header(info.path) {
				imgui.indent();
				defer imgui.unindent();

				imgui.text(tprint("Total Count: ", info.total_count));
				imgui.text(tprint("Total Size: ", info.total_size));
			}
		}

	} imgui.end();
}

// if platform.get_input_down(.F8, true) {
// 	context.temp_allocator = default_temp_allocator;
// 	for ptr, info in allocation_tracker.allocations {
// 		fmt.println(ptr, info.size, info.location.file_path == "" ? tprint("BROKEN FILE PATH: proc = ", info.location.procedure) : basic.pretty_location(info.location));
// 	}
// }

logln :: logging.logln;
tprint :: fmt.tprint;
tprintf :: fmt.tprintf;