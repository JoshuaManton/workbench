package pool

using import "core:math"

EMPTY_BUCKET :: 0b1111111111111111111111111111111111111111111111111111111111111111;

Pool :: struct(T: typeid, POOL_BATCH_SIZE: int) {
	batches: [dynamic]Pool_Batch(T, POOL_BATCH_SIZE),
}

Pool_Batch :: struct(T: typeid, POOL_BATCH_SIZE: int) {
	empties: u64,
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
		if batch.empties == EMPTY_BUCKET {
			continue;
		}
		for elem_idx in 0..64 { // 64 is the number of bits
			is_empty := (batch.empties & (1 << cast(u64)elem_idx)) > 0;
			if !is_empty {
				ptr := &batch.list[elem_idx];
				batch.empties |= (1 << cast(u64)elem_idx);
				taken_elements_map[ptr] = Pool_Element_Entry{batch_idx, elem_idx};
				return ptr;
			}
		}
	}
	append(&batches, Pool_Batch(P.T, P.POOL_BATCH_SIZE){0, new([P.POOL_BATCH_SIZE]P.T)});
	batch_idx := len(batches)-1;
	batch := &batches[batch_idx];
	ptr := &batch.list[0];
	taken_elements_map[ptr] = Pool_Element_Entry{batch_idx, 0};
	batch.empties |= 1;
	return ptr;
}

pool_return :: proc(using pool: ^$P/Pool, thing: ^P.T) {
	entry, ok := taken_elements_map[thing];
	if !ok {
		return;
	}

	batches[entry.batch_idx].list[entry.elem_idx] = {};
	batches[entry.batch_idx].empties &= ~(1 << cast(u64)entry.elem_idx);
}

pool_delete :: proc(using pool: $P/Pool) {
	for _, batch_idx in batches {
		batch := &batches[batch_idx];
		free(batch.list);
	}
	delete(batches);
}

// todo(josh) these tests only work with N__ == 3 but we can't do that because of an odin bug related to constant named polymorphic parameters
_test_pool :: proc() {
// 	{
// 		pool: Pool(int, N__);
// 		defer pool_delete(pool);

// 		assert(len(pool.batches) == 0);
// 		value1 := pool_get(&pool);
// 		assert(len(pool.batches) == 1);
// 		value2 := pool_get(&pool);
// 		value3 := pool_get(&pool);

// 		value1^ = 1;
// 		value2^ = 2;
// 		value3^ = 3;

// 		pool_return(&pool, value2);

// 		assert(value1^ == 1);
// 		assert(value2^ == 0); // since we returned it
// 		assert(value3^ == 3);

// 		pool_return(&pool, value1);
// 		pool_return(&pool, value3);
// 	}

// 	{
// 		pool: Pool(int, N__);
// 		defer pool_delete(pool);

// 		values: [dynamic]^int;
// 		defer delete(values);

// 		for i in 0..(N__*2)-1 {
// 			value := pool_get(&pool);
// 			value^ = i;
// 			append(&values, value);
// 		}

// 		assert(len(values) == 6);
// 		assert(len(pool.batches) == 2);

// 		assert(pool.batches[0].list[0] == 0);
// 		assert(pool.batches[0].list[2] == 2);
// 		assert(pool.batches[1].list[1] == 4);

// 		pool_return(&pool, values[0]);
// 		pool_return(&pool, values[2]);
// 		pool_return(&pool, values[4]);

// 		assert(pool.batches[0].list[0] == 0);
// 		assert(pool.batches[0].list[2] == 0);
// 		assert(pool.batches[1].list[1] == 0);
// 	}
}