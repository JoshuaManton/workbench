package allocators

import "core:mem"

Pool_Allocator :: struct {
	memory: []byte,
	occupancy: []bool,
	generations: []int,
	chunk_size_aligned: int,
	freelist: [dynamic]int,
	high_water_mark: int,
	last_allocated_chunk: Pool_Chunk,
}
Pool_Chunk :: struct {
	index: int,
	generation: int,
}

init_pool_allocator :: proc(using pool: ^Pool_Allocator, chunk_size, num_chunks: int) {
	assert(memory == nil);
	chunk_size_aligned = mem.align_forward_int(chunk_size, mem.DEFAULT_ALIGNMENT);
	memory = make([]byte, chunk_size_aligned * num_chunks);
	occupancy = make([]bool, num_chunks);
	generations = make([]int, num_chunks);
}

pool_allocator :: proc(pool: ^Pool_Allocator) -> mem.Allocator {
	return mem.Allocator{pool_allocator_proc, pool};
}

pool_allocator_proc :: proc(allocator_data: rawptr, mode: mem.Allocator_Mode,
                            size, alignment: int,
                            old_memory: rawptr, old_size: int,
                            flags: u64 = 0, loc := #caller_location) -> rawptr {

	using pool := cast(^Pool_Allocator)allocator_data;

	#partial switch mode {
		case .Alloc: {
			assert(memory != nil);
			index := -1;
			if len(freelist) > 0 {
				index = pop(&freelist);
			}
			else {
				index = high_water_mark;
				high_water_mark += 1;
			}
			assert(index >= 0);
			assert(occupancy[index] == false);
			occupancy[index] = true;
			generations[index] += 1;
			last_allocated_chunk = Pool_Chunk{index, generations[index]};
			ptr := &memory[index * chunk_size_aligned];
			mem.zero(ptr, chunk_size_aligned);
			return ptr;
		}
		case .Free: {
			assert(chunk_size_aligned > 0);
			assert(uintptr(old_memory) >= uintptr(&memory[0]));
			assert(uintptr(old_memory) < uintptr(#no_bounds_check &memory[len(memory)]));
			offset := (int(uintptr(old_memory)) - int(uintptr(&memory[0])));
			assert(offset % chunk_size_aligned == 0);
			index := offset / chunk_size_aligned;
			assert(occupancy[index] == true);
			occupancy[index] = false;
			append(&freelist, index);
		}
		case .Free_All: {
			unimplemented();
		}
		case .Resize: {
			unimplemented();
		}
	}
	unreachable();
}

Pool_Iterator :: struct {
	pool: ^Pool_Allocator,
	index: int,
	chunk_index: int,
}

pool_iterator :: proc(using pool: ^Pool_Allocator) -> Pool_Iterator {
	return Pool_Iterator{pool, 0, -1};
}

pool_get_next :: proc(using iter: ^Pool_Iterator) -> (rawptr, int, bool) {
	chunk_index += 1;
	for chunk_index < pool.high_water_mark && pool.occupancy[chunk_index] == false {
		if chunk_index >= pool.high_water_mark do return nil, index, false;
		if pool.occupancy[chunk_index] {
			break;
		}
		else {
			chunk_index += 1;
		}
	}
	ptr := &pool.memory[chunk_index * pool.chunk_size_aligned];
	idx := index;
	index += 1;
	return ptr, idx, true;
}