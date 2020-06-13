package allocators

import "core:fmt"
import "core:mem"

Arena :: struct {
    memory: []byte,
    cur_offset: int,
    panic_on_oom: bool,
}

init_arena :: proc(arena: ^Arena, backing: []byte) {
    assert(arena.memory == nil);
    assert(len(backing) > 0);
    arena^ = {};
    arena.memory = backing;
}

make_arena :: proc(backing: []byte, panic_on_oom: bool) -> Arena {
    arena: Arena;
    arena.memory = backing;
    arena.panic_on_oom = panic_on_oom;
    return arena;
}

delete_arena_memory :: proc(arena: ^Arena) {
    delete(arena.memory);
    arena.memory = {};
}

@(deferred_out=pop_temp_region)
ARENA_TEMP_REGION :: proc(arena: ^Arena) -> (^Arena, int) {
    return arena, arena.cur_offset;
}
pop_temp_region :: proc(arena: ^Arena, temp_start: int) {
    arena.cur_offset = temp_start;
}



arena_allocator :: proc(arena: ^Arena) -> mem.Allocator {
    return mem.Allocator{arena_allocator_proc, arena};
}

arena_alloc :: proc(arena: ^Arena, size: int, alignment: int) -> rawptr {
    // Don't allow allocations of zero size. This would likely return a
    // pointer to a different allocation, causing many problems.
    if size == 0 {
        return nil;
    }

    // todo(josh): The `align_forward()` call and the `start + size` below
    // that could overflow if the `size` or `align` parameters are super huge

    start := mem.align_forward_int(arena.cur_offset, alignment);

    // Don't allow allocations that would extend past the end of the arena.
    if (start + size) > len(arena.memory) {
        if arena.panic_on_oom {
            panic("Arena out of memory");
        }
        return nil;
    }

    arena.cur_offset = start + size;
    ptr := &arena.memory[start];
    mem.zero(ptr, size);
    return ptr;
}

arena_free_all :: proc(arena: ^Arena) {
    arena.cur_offset = 0;
}

arena_allocator_proc :: proc(allocator_data: rawptr, mode: mem.Allocator_Mode,
                            size, alignment: int,
                            old_memory: rawptr, old_size: int,
                            flags: u64 = 0, loc := #caller_location) -> rawptr {

    arena := cast(^Arena)allocator_data;

    switch mode {
        case .Alloc: {
            return arena_alloc(arena, size, alignment);
        }
        case .Free: {
            return nil;
        }
        case .Free_All: {
            arena_free_all(arena);
            return nil;
        }
        case .Resize: {
            new_memory := arena_allocator_proc(allocator_data, .Alloc, size, alignment, old_memory, old_size, flags, loc);
            mem.copy(new_memory, old_memory, min(old_size, size));
            return new_memory;
        }
        case: panic(fmt.tprint(mode));
    }
    unreachable();
}