package allocators

import "core:fmt"
import "core:mem"

panic_allocator :: proc() -> mem.Allocator {
	return {panic_allocator_proc, nil};
}

panic_allocator_proc :: proc(allocator_data: rawptr, mode: mem.Allocator_Mode,
                             size, alignment: int,
                             old_memory: rawptr, old_size: int,
                             flags: u64 = 0, loc := #caller_location) -> rawptr {

	panic(fmt.tprint("No allocations allowed: ", loc));
}