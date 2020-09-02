package allocators

import "core:fmt"
import "core:mem"

Dynamic_Arena :: struct {
    arenas: [dynamic]Arena,
    current_arena: int,
    arena_size: int, // todo(josh): we don't _really_ need this, we could just check len(arenas[0].memory)
}

init_dynamic_arena :: proc(dynamic_arena: ^Dynamic_Arena, arena_size: int) {
    assert(dynamic_arena.arenas == nil);
    assert(arena_size != 0);
    dynamic_arena^ = {};
    dynamic_arena.arenas = make([dynamic]Arena, 4);
    dynamic_arena.arena_size = arena_size;
    init_arena(&dynamic_arena.arenas[0], make([]byte, arena_size), false);
}

destroy_dynamic_arena :: proc(dynamic_arena: ^Dynamic_Arena) {
    for arena in &dynamic_arena.arenas {
        delete_arena_memory(&arena);
    }
    delete(dynamic_arena.arenas);
    dynamic_arena^ = {};
}

dynamic_arena_allocator :: proc(dynamic_arena: ^Dynamic_Arena) -> mem.Allocator {
    return mem.Allocator{dynamic_arena_allocator_proc, dynamic_arena};
}



dynamic_arena_alloc :: proc(dynamic_arena: ^Dynamic_Arena, size: int, alignment: int) -> rawptr {
    // Don't allow allocations of zero size. This would likely return a
    // pointer to a different allocation, causing many problems.
    if size == 0 {
        return nil;
    }

    arena := &dynamic_arena.arenas[dynamic_arena.current_arena];
    result := arena_alloc(arena, size, alignment);
    if result == nil {
        new_arena: Arena;
        init_arena(&new_arena, make([]byte, dynamic_arena.arena_size), false);
        append(&dynamic_arena.arenas, new_arena);
        dynamic_arena.current_arena += 1;

        arena := &dynamic_arena.arenas[dynamic_arena.current_arena];
        result = arena_alloc(arena, size, alignment);
        if result == nil {
            // todo(josh): should we just fall back to the default allocator in this case?
            panic("arena_alloc returned nil twice. maybe you are trying to allocate something bigger than the arena size?");
        }
    }

    return result;
}

dynamic_arena_free_all :: proc(dynamic_arena: ^Dynamic_Arena) {
    for arena in &dynamic_arena.arenas {
        arena_free_all(&arena);
    }
    dynamic_arena.current_arena = 0;
}

dynamic_arena_allocator_proc :: proc(allocator_data: rawptr, mode: mem.Allocator_Mode,
                            size, alignment: int,
                            old_memory: rawptr, old_size: int,
                            flags: u64 = 0, loc := #caller_location) -> rawptr {

    dynamic_arena := cast(^Dynamic_Arena)allocator_data;

    switch mode {
        case .Alloc: {
            return dynamic_arena_alloc(dynamic_arena, size, alignment);
        }
        case .Free: {
            return nil;
        }
        case .Free_All: {
            dynamic_arena_free_all(dynamic_arena);
            return nil;
        }
        case .Resize: {
            new_memory := dynamic_arena_allocator_proc(allocator_data, .Alloc, size, alignment, old_memory, old_size, flags, loc);
            mem.copy(new_memory, old_memory, min(old_size, size));
            return new_memory;
        }
        case .Query_Features: {
            unimplemented();
        }
        case .Query_Info: {
            unimplemented();
        }
        case: panic(fmt.tprint(mode));
    }
    unreachable();
}