package allocators

import "core:mem"

Pool :: struct {
	memory: []byte,
	occupancy: []bool,
	chunk_size_aligned: int,
	freelist: [dynamic]Pool_Chunk,
	high_water_mark: int,
	last_allocated_chunk: Pool_Chunk,
}
Pool_Chunk :: struct {
	index: int,
	generation: int,
}

pool_init :: proc(using pool: ^Pool, chunk_size, num_chunks: int) {
	assert(memory == nil);
	chunk_size_aligned = mem.align_forward_int(chunk_size, mem.DEFAULT_ALIGNMENT);
	memory = make([]byte, chunk_size_aligned * num_chunks);
	occupancy = make([]bool, num_chunks);
}

pool_allocator :: proc(pool: ^Pool) -> mem.Allocator {
	return mem.Allocator{pool_allocator_proc, pool};
}

pool_allocator_proc :: proc(allocator_data: rawptr, mode: mem.Allocator_Mode,
                            size, alignment: int,
                            old_memory: rawptr, old_size: int,
                            flags: u64 = 0, loc := #caller_location) -> rawptr {

	using pool := cast(^Pool)allocator_data;

	switch mode {
		case .Alloc: {
			assert(memory != nil);
			chunk: Pool_Chunk;
			if len(freelist) > 0 {
				chunk = pop(&freelist);
			}
			else {
				chunk = Pool_Chunk{high_water_mark, 0};
				high_water_mark += 1;
			}
			assert(occupancy[chunk.index] == false);
			occupancy[chunk.index] = true;
			chunk.generation += 1;
			last_allocated_chunk = chunk;
			return &memory[chunk.index * chunk_size_aligned];
		}
		case .Free: {
			assert(chunk_size_aligned != 0);
			assert(uintptr(old_memory) >= uintptr(&memory[0]));
			assert(uintptr(old_memory) < uintptr(#no_bounds_check &memory[len(memory)]));
			offset := (int(uintptr(old_memory)) - int(uintptr(&memory[0])));
			assert(offset % chunk_size_aligned == 0);
			index := offset / chunk_size_aligned;
			assert(occupancy[index] == true);
			occupancy[index] = false;
			ptr := &memory[index * chunk_size_aligned];
			mem.zero(ptr, chunk_size_aligned);
			append(&freelist, Pool_Chunk{index, });
		}
		case .Free_All: {
			unimplemented();
		}
		case .Resize: {
			unimplemented();
		}
	}
	unreachable();
	return nil;
}

pool_free :: proc(using pool: ^Pool, chunk: Pool_Chunk) {
}

Pool_Iterator :: struct {
	pool: ^Pool,
	index: int,
	chunk_index: int,
}

pool_iterator :: proc(using pool: ^Pool) -> Pool_Iterator {
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