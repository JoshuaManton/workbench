package workbench

Buffer :: struct(T: typeid, N: int) {
	next: int,
	data: [N]T,
}

buffer_add :: proc(using buffer: ^$B/Buffer, thing: B.T) -> ^B.T {
	data[next] = {true, thing};
	next += 1;
	return &data[next-1];
}

buffer_remove_at :: proc(using buffer: ^$B/Buffer, idx: int) {
	data[idx] = data[next-1];
	next -= 1;
}