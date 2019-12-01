package pool

using import "core:fmt"

using import "../math"

// todo(josh): I don't even know if this works anymore, but make it use the new iterator feature in odin

Pool :: struct(T: typeid, POOL_BATCH_SIZE: int) {
	batches: [dynamic]Pool_Batch(T, POOL_BATCH_SIZE),
}

Pool_Batch :: struct(T: typeid, POOL_BATCH_SIZE: int) {
	empties: [POOL_BATCH_SIZE]bool,
	list:    ^[POOL_BATCH_SIZE]T,
}

Pool_Element_Entry :: struct {
	batch_idx: int,
	elem_idx:  int,
}

taken_elements_map: map[rawptr]Pool_Element_Entry;

pool_get :: proc(using pool: ^$P/Pool) -> ^P.T {
	for _, batch_idx in batches {
		batch := &batches[batch_idx];
		for item, idx in batch.list {
			is_empty := batch.empties[idx] == true;
			if !is_empty {
				ptr := &batch.list[idx];
				batch.empties[idx] = true;
				taken_elements_map[ptr] = Pool_Element_Entry{batch_idx, idx};
				assert(ptr != nil);
				return ptr;
			}
		}
	}
	append(&batches, Pool_Batch(P.T, P.POOL_BATCH_SIZE){{}, new([P.POOL_BATCH_SIZE]P.T)});
	batch_idx := len(batches)-1;
	batch := &batches[batch_idx];
	ptr := &batch.list[0];
	batch.empties[0] = true;
	taken_elements_map[ptr] = Pool_Element_Entry{batch_idx, 0};
	assert(ptr != nil);
	return ptr;
}

pool_return :: proc(using pool: ^$P/Pool, thing: ^P.T) {
	entry, ok := taken_elements_map[thing];
	if !ok {
		return;
	}

	batches[entry.batch_idx].list[entry.elem_idx] = {};
	batches[entry.batch_idx].empties[entry.elem_idx] = false;
}

pool_delete :: proc(using pool: $P/Pool) {
	for _, batch_idx in batches {
		batch := &batches[batch_idx];
		free(batch);
	}
	delete(batches);
}

main :: proc() {
	{
		pool: Pool(int, 64);
		defer pool_delete(pool);

		assert(len(pool.batches) == 0);
		value1 := pool_get(&pool);
		assert(len(pool.batches) == 1);
		value2 := pool_get(&pool);
		value3 := pool_get(&pool);

		value1^ = 1;
		value2^ = 2;
		value3^ = 3;

		pool_return(&pool, value2);

		assert(value1^ == 1);
		assert(value2^ == 0); // since we returned it
		assert(value3^ == 3);

		pool_return(&pool, value1);
		pool_return(&pool, value3);
	}

	{
		pool: Pool(int, 64);
		defer pool_delete(pool);

		values: [dynamic]^int;
		defer delete(values);

		for i in 0..(64*2)-1 {
			value := pool_get(&pool);
			value^ = i;
			append(&values, value);
		}

		assert(len(values) == 6);
		assert(len(pool.batches) == 2);

		assert(pool.batches[0].list[0] == 0);
		assert(pool.batches[0].list[2] == 2);
		assert(pool.batches[1].list[1] == 4);

		pool_return(&pool, values[0]);
		pool_return(&pool, values[2]);
		pool_return(&pool, values[4]);

		assert(pool.batches[0].list[0] == 0);
		assert(pool.batches[0].list[2] == 0);
		assert(pool.batches[1].list[1] == 0);
	}
}