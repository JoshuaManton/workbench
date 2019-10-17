package workbench

      import "core:intrinsics"
      import "core:sys/win32"

      import "core:mem"
      import "core:hash"
using import "core:fmt"

using import "../logging"

Hashtable :: struct(Key: typeid, Value: typeid) {
	key_headers: []Key_Header(Key),
	values: []Key_Value(Key, Value),
	count: int,
}

Key_Header :: struct(Key: typeid) {
	filled: bool,
	key: Key,
}

Key_Value :: struct(Key: typeid, Value: typeid) {
	filled: bool,
	hash: u64,
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
	if f64(count) >= f64(len(key_headers))*0.75 {
		old_key_headers := key_headers;
		old_values := values;
		old_length := len(old_key_headers);
		old_count := count;

		INITIAL_SIZE :: 31;
		new_len := next_power_of_2(INITIAL_SIZE + old_length);
		key_headers = make([]Key_Header(Key), new_len);
		values = make([]Key_Value(Key, Value), new_len);
		count = 0;

		for header_idx in 0..<old_length {
			old_key_header := &old_key_headers[header_idx];
			if old_key_header.filled {
				insert(table, old_key_header.key, old_values[header_idx].value);
			}
		}

		delete(old_key_headers);
		delete(old_values);
	}

	key_value_index: int = -1;
	h := hash_key(key);
	search_block: {
		len_indices := cast(u64)len(key_headers);
		hash_idx := h % len_indices;
		for idx := hash_idx; idx < len_indices; idx += 1 {
			value_ptr := &values[idx];
			if !value_ptr.filled {
				key_value_index = cast(int)idx;
				break search_block;
			}
		}
		for idx : u64 = 0; idx < hash_idx; idx += 1 {
			value_ptr := &values[idx];
			if !value_ptr.filled {
				key_value_index = cast(int)idx;
				break;
			}
		}
	}
	assert(key_value_index >= 0);

	values[key_value_index] = {true, h, value};
	key_headers[key_value_index] = {true, key};
	count += 1;
}

get :: proc(using table: ^Hashtable($Key, $Value), key: Key) -> (Value, bool) {
	header, index := get_key_header(table, key, false);
	if header == nil do return {}, false;
	return values[index].value, true;
}

get_key_header :: proc(using table: ^Hashtable($Key, $Value), key: Key, $log: bool) -> (^Key_Header(Key), u64) { // note(josh): can return nil
	h := hash_key(key);
	when log {
		// logln(h);
	}
	len_key_headers := cast(u64)len(key_headers);
	hash_idx := h % len_key_headers;
	for idx := hash_idx; idx < len_key_headers; idx += 1 {
		header := &key_headers[idx];
		if !header.filled {
			return nil, 0;
		}
		if header.key == key {
			return header, idx;
		}
	}
	for idx : u64 = 0; idx < hash_idx; idx += 1 {
		header := &key_headers[idx];
		if !header.filled {
			return nil, 0;
		}
		if header.key == key {
			return header, idx;
		}
	}
	unreachable(); // todo(josh): is this actually unreachable?
	return nil, 0;
}

hash_key :: proc(key: $Key) -> u64 {
	key := key;
	T :: intrinsics.type_core_type(Key);
	SIZE :: size_of(T);
	when intrinsics.type_is_integer(T) {
		     when SIZE == 1 do return ~u64(transmute(u8 )key);
		else when SIZE == 2 do return ~u64(transmute(u16)key);
		else when SIZE == 4 do return ~u64(transmute(u32)key);
		else when SIZE == 8 do return ~u64(transmute(u64)key);
		else do #assert(false, "Unhandled integer size");
	}
	else when intrinsics.type_is_rune(T) {
		val := u64(transmute(rune)key);
		return ~val;
	}
	else when intrinsics.type_is_pointer(T) {
		val := u64(uintptr((^rawptr)(&key)^));
		return ~val;
	}
	else when intrinsics.type_is_float(T) {
		// todo(josh): better float hash. but also you shouldn't be using a float as a key to a hashmap
		slice := mem.slice_ptr(cast(^byte)&key, SIZE);
		return hash.fnv64(slice);
		//      when SIZE == 4 do return ~u64(transmute(u32)key);
		// else when SIZE == 8 do return ~u64(transmute(u64)key);
		// else do #assert(false, "Unhandled float size");
	}
	else when intrinsics.type_is_string(T) {
		#assert(T == string);
		return hash.fnv64(cast([]u8)key);
	}
	else {
		#assert(false, "Unhandled map key type");
	}
	unreachable();
	return {};
}

remove :: proc(using table: ^Hashtable($Key, $Value), key: Key) {
	key_header, key_value_idx := get_key_header(table, key, true);
	if key_header == nil do return;
	key_value := &values[key_value_idx];
	len_values := cast(u64)len(values);
	hash_idx := key_value.hash % len_values;
	last_thing_that_hashed_to_the_same_idx: ^Key_Value(Key, Value);
	last_thing_index: u64;
	search_block: {
		for idx := key_value_idx+1; idx < len_values; idx += 1 {
			value := &values[idx];
			if !value.filled {
				break search_block;
			}
			if value.hash % len_values == hash_idx {
				last_thing_that_hashed_to_the_same_idx = value;
				last_thing_index = idx;
			}
		}
		for idx : u64 = 0; idx < hash_idx; idx += 1 {
			value := &values[idx];
			if !value.filled {
				break search_block;
			}
			if value.hash % len_values == hash_idx {
				last_thing_that_hashed_to_the_same_idx = value;
				last_thing_index = idx;
			}
		}
	}

	if last_thing_that_hashed_to_the_same_idx != nil {
		key_header^ = key_headers[last_thing_index];
		key_value^ = last_thing_that_hashed_to_the_same_idx^;
		key_headers[last_thing_index].filled = false;
		last_thing_that_hashed_to_the_same_idx.filled = false;
	}
	else {
		key_header.filled = false;
		key_value.filled = false;
	}
}

main :: proc() {
	freq := get_freq();

	// NUM_ELEMS :: 10;
	NUM_ELEMS :: 1024 * 10000;

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
		lookup_start := get_time();
		for i in 0..NUM_ELEMS {
			val, ok := get(&my_table, i);
			assert(ok); assert(val == i * 3);
		}
		lookup_end := get_time();
		logln("My map retrieving ", NUM_ELEMS, " elements:   ", (lookup_end-lookup_start)/freq, "s");
	}

	{
		lookup_start := get_time();
		for i in 0..NUM_ELEMS {
			val, ok := odin_table[i];
			assert(ok); assert(val == i * 3);
		}
		lookup_end := get_time();
		logln("Odin map retrieving ", NUM_ELEMS, " elements: ", (lookup_end-lookup_start)/freq, "s");
	}

	{
		iterate_start := get_time();
		for header, idx in my_table.key_headers {
			if !header.filled do continue;
			key := header.key;
			value := my_table.values[idx].value;
			assert(value == key * 3);
		}
		iterate_end := get_time();
		logln("My map iterating ", NUM_ELEMS, " elements:   ", (iterate_end-iterate_start)/freq, "s");
	}

	{
		iterate_start := get_time();
		for key, value in odin_table {
			assert(value == key * 3);
		}
		iterate_end := get_time();
		logln("Odin map iterating ", NUM_ELEMS, " elements: ", (iterate_end-iterate_start)/freq, "s");
	}

	{
		removal_start := get_time();
		for i in 0..NUM_ELEMS {
			remove(&my_table, i);
		}
		removal_end := get_time();
		logln("My map removing ", NUM_ELEMS, " elements:   ", (removal_end-removal_start)/freq, "s");
	}

	{
		removal_start := get_time();
		for i in 0..NUM_ELEMS {
			delete_key(&odin_table, i);
		}
		removal_end := get_time();
		logln("Odin map removing ", NUM_ELEMS, " elements: ", (removal_end-removal_start)/freq, "s");
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