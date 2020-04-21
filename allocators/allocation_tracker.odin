package allocators

import "core:fmt"
import rt "core:runtime"
import "core:mem"
import "core:os"

Allocation_Tracker :: struct {
	backing: mem.Allocator,
	infos: [dynamic]Allocation_Info,
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
	delete(tracker.infos);
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
   			os.write_string(os.stdout, fmt.tprint("allocation: ", size, " at ", loc, "\n"));
			ptr := tracker.backing.procedure(allocator_data, mode, size, alignment, old_memory, old_size, flags, loc);
			return ptr;
		}
		case .Free: {
			return tracker.backing.procedure(allocator_data, mode, size, alignment, old_memory, old_size, flags, loc);
		}
		case .Free_All: {
			return tracker.backing.procedure(allocator_data, mode, size, alignment, old_memory, old_size, flags, loc);
		}
		case .Resize: {
   			os.write_string(os.stdout, fmt.tprint("resize allocation: ", size, " at ", loc, "\n"));
			ptr := tracker.backing.procedure(allocator_data, mode, size, alignment, old_memory, old_size, flags, loc);
			return ptr;
		}
	}
	unreachable();
	return nil;
}