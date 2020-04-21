package allocators

import "core:fmt"
import rt "core:runtime"
import "core:mem"
import "core:os"

Allocation_Tracker :: struct {
	backing: mem.Allocator,
	allocations: map[rawptr]Allocation_Info,
}

Allocation_Info :: struct {
	location: rt.Source_Code_Location,
	size: int,
}

init_allocation_tracker :: proc(tracker: ^Allocation_Tracker) -> mem.Allocator {
	tracker^ = Allocation_Tracker{context.allocator, {}};
	return mem.Allocator{allocation_tracker_proc, tracker};
}

destroy_allocation_tracker :: proc(tracker: ^Allocation_Tracker) {
	delete(tracker.allocations);
	tracker^ = {};
}

allocation_tracker_proc :: proc(allocator_data: rawptr, mode: mem.Allocator_Mode,
                                size, alignment: int,
                                old_memory: rawptr, old_size: int,
                                flags: u64 = 0, loc := #caller_location) -> rawptr {

	tracker := cast(^Allocation_Tracker)allocator_data;
	assert(tracker.backing.procedure != nil);
	context.allocator = tracker.backing;
	context.temp_allocator = {};

	switch mode {
		case .Alloc: {
			ptr := tracker.backing.procedure(allocator_data, mode, size, alignment, old_memory, old_size, flags, loc);
			assert(ptr notin tracker.allocations);
			tracker.allocations[ptr] = Allocation_Info{loc, size};
			return ptr;
		}
		case .Free: {
			assert(old_memory in tracker.allocations);
			delete_key(&tracker.allocations, old_memory);
			return tracker.backing.procedure(allocator_data, mode, size, alignment, old_memory, old_size, flags, loc);
		}
		case .Free_All: {
			return tracker.backing.procedure(allocator_data, mode, size, alignment, old_memory, old_size, flags, loc);
		}
		case .Resize: {
			if old_memory != nil {
				assert(old_memory in tracker.allocations);
				delete_key(&tracker.allocations, old_memory);
			}

			ptr := tracker.backing.procedure(allocator_data, mode, size, alignment, old_memory, old_size, flags, loc);
			tracker.allocations[ptr] = Allocation_Info{loc, size};
			return ptr;
		}
	}
	unreachable();
	return nil;
}