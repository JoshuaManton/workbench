package workbench

import "core:fmt"

Static_List :: struct(Type: typeid, Cap: int) {
	data: []Type,

	count: int,
	array: [Cap]Type,
}

append :: proc(using list: $T/^Static_List($Type, $Cap), thing: Type) -> ^Type {
	assert(count < Cap);
	count += 1;
	data = array[:count];
	data[count-1] = thing;
	result := &list.data[count-1];
	return result;
}

pop :: proc(using list: $T/^Static_List($Type, $Cap)) -> (Type, bool) {
	if count == 0 do return {}, false;
	thing := array[count-1];
	count -= 1;
	data = array[:count];
	return thing, true;
}

clear :: proc(using list: $T/^Static_List($Type, $Cap)) {
	count = 0;
	data = {};
}
