package workbench

using import "core:math"



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