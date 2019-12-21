package workbench

Static_List :: struct(Type: typeid, Cap: int) {
	data: []Type,

	count: int,
	array: [Cap]Type,
}

append :: proc(using list: $T/^Static_List($Type, $Cap), thing: Type) -> ^Type {
	assert(count < Cap);
	list.data[count] = thing;
	result := &list.data[count];
	count += 1;
	data = list.array[:count];
	return result;
}

