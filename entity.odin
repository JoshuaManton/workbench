package workbench

using import "core:runtime"
using import "core:math"
using import "core:fmt"

Entity_ID :: i64;

_Entity_ID_Internal :: struct {
	index:      i32,
	generation: i32,
}

encode_entity_id :: inline proc(index, generation: i32) -> Entity_ID {
	return cast(Entity_ID)transmute(i64)_Entity_ID_Internal{index, generation};
}

decode_entity_id :: inline proc(id: Entity_ID) -> (index, generation: i32) {
	internal := transmute(_Entity_ID_Internal)id;
	return internal.index, internal.generation;
}



Entity :: struct {
	id: Entity_ID,
	dead: bool,
}

all_entities: [dynamic]Entity;

make_entity :: proc() -> Entity_ID {
	for _, i in all_entities {
		e := &all_entities[i];
		if e.dead {
			i, g := decode_entity_id(e.id);
			g += 1;
			e.id = encode_entity_id(i, g);
			e.dead = false;
			return e.id;
		}
	}

	id := cast(i64)len(all_entities);
	append(&all_entities, Entity{id, false});
	return id;
}
destroy_entity :: proc(id: Entity_ID, loc := #caller_location) {
	i, _ := decode_entity_id(id);
	entity := &all_entities[i];
	assert(entity.dead == false, tprint("Tried to destroy dead entity ", id, " from: ", loc));
	if entity.id == id {
		entity.dead = true;
	}
}

get_entity :: inline proc(id: Entity_ID) -> ^Entity {
	i, _ := decode_entity_id(id);
	entity := &all_entities[i];
	return entity;
}
