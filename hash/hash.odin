package workbench

      import "core:/sys/win32"

      import "core:mem"
      import "core:hash"
using import "core:fmt"

using import "../logging"

Hashtable :: struct(Key: typeid, Value: typeid) {
	key_values: []Key_Value(Key, Value),
	free_places: int,
}

Key_Value :: struct(Key: typeid, Value: typeid) {
	filled: bool,
	hash: u64,
	key: Key,
	value: Value,
}

next_power_of_2 :: proc(n: int) -> int {
	if (n <= 0) {
		return 0;
	}
	n := n;
	n -= 1;
	n |= n >> 1;
	n |= n >> 2;
	n |= n >> 4;
	n |= n >> 8;
	n |= n >> 16;
	n |= n >> 32;
	n += 1;
	return n;
}

insert :: proc(using table: ^Hashtable($Key, $Value), key: Key, value: Value) #no_bounds_check {
	key := key;

	if f64(free_places) <= f64(len(key_values))*0.25 {
		old_key_values := key_values;
		old_length  := len(old_key_values);

		INITIAL_SIZE :: 32;
		new_len := next_power_of_2(INITIAL_SIZE + old_length);
		key_values = make([]Key_Value(Key, Value), new_len);
		free_places = new_len;

		for key_val in old_key_values {
			if key_val.filled {
				insert(table, key_val.key, key_val.value);
			}
		}

		delete(old_key_values);
	}

	key_value: ^Key_Value(Key, Value);
	key_bytes := mem.slice_ptr(cast(^byte)&key, size_of(Key));
	h := hash.fnv64(key_bytes);
	{
		len_indices := cast(u64)len(key_values);
		hash_idx := h % len_indices;
		for idx in hash_idx..<len_indices {
			pair := &key_values[idx];
			if !pair.filled {
				key_value = pair;
				break;
			}
		}
		if key_value == nil {
			for idx in 0..<hash_idx {
				pair := &key_values[idx];
				if !pair.filled {
					key_value = pair;
					break;
				}
			}
		}
		assert(key_value != nil);
	}

	key_value^ = {true, h, key, value};
	free_places -= 1;
}

get :: proc(using table: ^Hashtable($Key, $Value), key: Key) -> (Value, bool) {
	key_value, _ := get_key_value(table, key);
	if key_value == nil do return {}, false;
	return key_value.value, true;
}

get_key_value :: proc(using table: ^Hashtable($Key, $Value), key: Key) -> (^Key_Value(Key, Value), u64) { // note(josh): can return nil
	key := key;
	key_bytes := mem.slice_ptr(cast(^byte)&key, size_of(Key));
	h := hash.fnv64(key_bytes);
	len_key_values := cast(u64)len(key_values);
	hash_idx := h % len_key_values;
	key_value: ^Key_Value(Key, Value);
	key_value_idx: u64;
	for idx in hash_idx..<len_key_values {
		pair := &key_values[idx];
		if !pair.filled {
			return nil, 0;
		}
		else {
			if pair.key == key {
				key_value = pair;
				key_value_idx = idx;
				break;
			}
		}
	}
	if key_value == nil {
		for idx in 0..<hash_idx {
			pair := &key_values[idx];
			if !pair.filled {
				return nil, 0;
			}
			else {
				if pair.key == key {
					key_value = pair;
					key_value_idx = idx;
					break;
				}
			}
		}
	}
	return key_value, key_value_idx;
}

remove :: proc(using table: ^Hashtable($Key, $Value), key: Key) {
	key_value, key_value_idx := get_key_value(table, key);
	if key_value == nil do return;
	len_key_values := cast(u64)len(key_values);
	hash_idx := key_value.hash % len_key_values;
	last_thing_that_hashed_to_the_same_idx: ^Key_Value(Key, Value);
	found_empty_slot := false;
	for idx in (key_value_idx+1)..<len_key_values {
		value := &key_values[idx];
		if !value.filled {
			found_empty_slot = true;
			break;
		}
		if value.hash % len_key_values == hash_idx {
			last_thing_that_hashed_to_the_same_idx = value;
		}
	}
	if !found_empty_slot {
		for idx in 0..<hash_idx {
			value := &key_values[idx];
			if !value.filled {
				break;
			}
			if value.hash % len_key_values == hash_idx {
				last_thing_that_hashed_to_the_same_idx = value;
			}
		}
	}
	if last_thing_that_hashed_to_the_same_idx != nil {
		key_value^ = last_thing_that_hashed_to_the_same_idx^;
		last_thing_that_hashed_to_the_same_idx.filled = false;
	}
	else {
		key_value.filled = false;
	}
}

main :: proc() {
	freq := get_freq();

	// NUM_ELEMS :: 10;
	NUM_ELEMS :: 1024 * 1000;

	my_table: Hashtable(int, int);
	{
		insert_start := get_time();
		for i in 0..NUM_ELEMS {
			insert(&my_table, i, i * 3);
		}
		insert_end := get_time();
		logln("My map inserting ", NUM_ELEMS, " elements:   ", (insert_end-insert_start)/freq, "s");
	}

	odin_table: map[int]int;
	{
		insert_start := get_time();
		for i in 0..NUM_ELEMS {
			odin_table[i] = i * 3;
		}
		insert_end := get_time();
		logln("Odin map inserting ", NUM_ELEMS, " elements: ", (insert_end-insert_start)/freq, "s");
	}

	{
		removal_start := get_time();
		for i in 0..NUM_ELEMS {
			if i % 3 == 0 {
				remove(&my_table, i);
			}
		}
		removal_end := get_time();
		logln("My map removing ", NUM_ELEMS, " elements:   ", (removal_end-removal_start)/freq, "s");
	}

	{
		removal_start := get_time();
		for i in 0..NUM_ELEMS {
			if i % 3 == 0 {
				delete_key(&odin_table, i);
			}
		}
		removal_end := get_time();
		logln("Odin map removing ", NUM_ELEMS, " elements: ", (removal_end-removal_start)/freq, "s");
	}

	{
		lookup_start := get_time();
		for i in 0..NUM_ELEMS {
			val, ok := get(&my_table, i);
			if ok do assert(val == i * 3);
		}
		lookup_end := get_time();
		logln("My map retrieving ", NUM_ELEMS, " elements:   ", (lookup_end-lookup_start)/freq, "s");
	}

	{
		lookup_start := get_time();
		for i in 0..NUM_ELEMS {
			val, ok := odin_table[i];
			if ok do assert(val == i * 3);
		}
		lookup_end := get_time();
		logln("Odin map retrieving ", NUM_ELEMS, " elements: ", (lookup_end-lookup_start)/freq, "s");
	}
}

get_time :: inline proc() -> f64 {
	res: i64;
	win32.query_performance_counter(&res);
	return cast(f64)res;
}

get_freq :: inline proc() -> f64 {
	freq: i64;
	win32.query_performance_frequency(&freq);
	return cast(f64)freq;
}