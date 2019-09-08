package workbench

import "core:mem"
import rt "core:runtime"
import "core:fmt"

// todo(josh): this doesn't work for some reason. investigate.

Leak_Check_Allocator :: struct {
	backing: mem.Allocator,
	mapping: map[rawptr]rt.Source_Code_Location,
}

leak_check_allocator :: proc(leak_checker: ^Leak_Check_Allocator) -> mem.Allocator {
	leak_checker^ = Leak_Check_Allocator{context.allocator, {}};
	return mem.Allocator{leak_check_allocator_proc, leak_checker};
}


leak_check_allocator_proc :: proc(allocator_data: rawptr, mode: mem.Allocator_Mode,
                             size, alignment: int,
                             old_memory: rawptr, old_size: int, flags: u64, location := #caller_location) -> rawptr {
	leak_checker := cast(^Leak_Check_Allocator)allocator_data;
	assert(leak_checker.backing.procedure != nil);
	context.allocator = leak_checker.backing;

	fmt.println(mode, location);

	#complete
	switch mode {
		case .Alloc: {
			ptr := leak_checker.backing.procedure(allocator_data, mode, size, alignment, old_memory, old_size, flags, location);
			leak_checker.mapping[ptr] = location;
			return ptr;
		}
		case .Free: {
			assert(old_memory in leak_checker.mapping);
			delete_key(&leak_checker.mapping, old_memory);
			return leak_checker.backing.procedure(allocator_data, mode, size, alignment, old_memory, old_size, flags, location);
		}
		case .Free_All: {
			return leak_checker.backing.procedure(allocator_data, mode, size, alignment, old_memory, old_size, flags, location);
		}
		case .Resize: {
			delete_key(&leak_checker.mapping, old_memory);
			ptr := leak_checker.backing.procedure(allocator_data, mode, size, alignment, old_memory, old_size, flags, location);
			leak_checker.mapping[ptr] = location;
			return ptr;
		}
	}
	unreachable();
	return {};
}