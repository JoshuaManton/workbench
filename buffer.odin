package workbench

Buffer :: struct(T: typeid, N: int) {
	next: int,
	data: [N]Buffer_Element(T),
}
Buffer_Element :: struct(T: typeid) {
	active: bool,
	value:  T,
}

buffer_add :: proc(using buffer: ^$B/Buffer, thing: B.T) -> ^Buffer_Element(B.T) {
	data[next] = {true, thing};
	next += 1;
	return &data[next-1];
}

buffer_remove_at :: proc(using buffer: ^$B/Buffer, idx: int) {
	data[idx] = data[next-1];
	next -= 1;
}