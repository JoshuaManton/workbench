package workbench

import "core:fmt"
import "core:sort"
import "core:time"
import "core:mem"
import "core:strings"

import "../external/imgui"
import "../allocators"
import "../platform"
import "../logging"

Frame_Info :: struct {
	root_section: ^Section_Info,
}

Section_Info :: struct {
	name: string,
	calls: int,
	time_taken: time.Duration,
	children: [dynamic]^Section_Info,
}

profiler_full_frame_times: []f32;
profiler_arena: allocators.Arena;
profiler_allocator: mem.Allocator;
profiler_frame_data: []Frame_Info;
current_profiler_frame: int;

current_section: ^Section_Info;
profiler_running: bool;

init_profiler :: proc() {
	profiler_frame_data = make([]Frame_Info, 2000);
	profiler_full_frame_times = make([]f32, 2000);

	allocators.init_arena(&profiler_arena, make([]byte, 10 * 1024 * 1024));
	profiler_allocator = allocators.arena_allocator(&profiler_arena);
}

deinit_profiler :: proc() {
	delete(profiler_arena.memory);
}

profiler_new_frame :: proc() {
	if platform.get_input(.F5) {
		profiler_running = true;
	}
	if platform.get_input(.F6) {
		profiler_running = false;
	}
	if platform.get_input(.F7) {
		free_all(profiler_allocator);
		current_profiler_frame = 0;
	}

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
		imgui.label_text("Profiler memory", tprint(profiler_arena.cur_offset, " / ", len(profiler_arena.memory)));

    	imgui.plot_lines("Frame times", &profiler_full_frame_times[0], cast(i32)len(profiler_full_frame_times), 0, nil, 0);

    	@static selected_frame: i32;
    	imgui.slider_int("frame", &selected_frame, 0, cast(i32)len(profiler_full_frame_times)-1);

		frame := profiler_frame_data[selected_frame];
		if frame.root_section != nil {
			imgui.columns(3);
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
			imgui.text(fmt.tprintf("time: %.8f", time.duration_seconds(info.time_taken)));
			imgui.next_column();
			imgui.text(fmt.tprint("calls: ", info.calls));
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

@(deferred_out=end_timed_section)
TIMED_SECTION :: proc(name_override: string = "", loc := #caller_location) -> (time.Time, ^Section_Info, ^Section_Info) {
	if !profiler_running do return {}, nil, nil;

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
			return {}, nil, nil;
		}

		// init the info
		info^ = {};
		info.name = section_name;
		info.calls = 0;
		info.time_taken = {};
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
	return time.now(), info, old;
}

end_timed_section :: proc(start: time.Time, info, old: ^Section_Info) {
	if !profiler_running do return;

	end := time.now();
	info.time_taken += time.diff(start, end);
	info.calls += 1;

	current_section = old;
}

logln :: logging.logln;
tprint :: fmt.tprint;