package workbench

Rolling_Average :: struct(TYPE: typeid, NUM_SAMPLES: int) {
	buffer: [NUM_SAMPLES]TYPE,
	index: int,
	has_filled_buffer: bool,
}

rolling_average_push_sample :: proc(using ra: ^$RA/Rolling_Average, sample: RA.TYPE) {
	assert(ra != nil);
	buffer[index] = sample;
	index = (index + 1) % len(buffer);
	if index == 0 do has_filled_buffer = true;
}

rolling_average_get_value :: proc(using ra: ^$RA/Rolling_Average) -> RA.TYPE {
	value: RA.TYPE;
	count: int;
	for sample, i in buffer {
		if !ra.has_filled_buffer {
			if i >= index do break;
		}
		value += sample;
		count += 1;
	}

	if count >= 1 {
		value /= cast(RA.TYPE)count;
	}

	return value;
}
