package allocators

import "core:fmt"
import "core:mem"

Frame_Allocator :: struct {
	memory: []byte,
	cur_offset: int,
}

init_frame_allocator :: proc(using frame_allocator: ^Frame_Allocator, backing: []byte) {
	assert(frame_allocator.memory == nil);
	frame_allocator^= {};
	frame_allocator.memory = backing;
}

destroy_frame_allocator :: proc(using frame_allocator: ^Frame_Allocator) {
	delete(memory);
	frame_allocator^ = {};
}

frame_allocator :: proc(using frame_allocator: ^Frame_Allocator) -> mem.Allocator {
	return mem.Allocator{frame_allocator_proc, frame_allocator};
}

frame_allocator_proc :: proc(allocator_data: rawptr, mode: mem.Allocator_Mode,
                            size, alignment: int,
                            old_memory: rawptr, old_size: int,
                            flags: u64 = 0, loc := #caller_location) -> rawptr {

	frame := cast(^Frame_Allocator)allocator_data;

	switch mode {
		case .Alloc: {
			assert(frame.cur_offset+size <= len(frame.memory), "frame_allocator ran out of memory");
			offset := mem.align_forward_uintptr(uintptr(frame.cur_offset), uintptr(alignment));
			ptr := &frame.memory[offset];
			mem.zero(ptr, size);
			frame.cur_offset = int(offset) + size;
			return ptr;
		}
		case .Free: {
			return nil;
		}
		case .Free_All: {
			frame.cur_offset = 0;
			return nil;
		}
		case .Resize: {
			new_memory := frame_allocator_proc(allocator_data, .Alloc, size, alignment, old_memory, old_size, flags, loc);
			mem.copy(new_memory, old_memory, min(old_size, size));
			return new_memory;
		}
		case: panic(fmt.tprint(mode));
	}
	unreachable();
	return nil;
}