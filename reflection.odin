package workbench

using import "core:runtime"

      import "core:mem"
      import "core:fmt"

Field_Info :: struct {
    name:   string,
    t:      ^Type_Info,
    offset: int,
}

get_struct_field_info :: proc(T: type, field_name: string) -> (Field_Info, bool) {
    ti := &type_info_base(type_info_of(T)).variant.(Type_Info_Struct);
    for name, i in ti.names {
        if name == field_name {
            t := ti.types[i];
            offset := ti.offsets[i];
            return Field_Info{name, t, cast(int)offset}, true;
        }
    }
    return Field_Info{}, false;
}

set_struct_field :: proc(thing: ^$T, info: Field_Info, value: $S) {
    when DEVELOPER {
        ti := &type_info_base(type_info_of(T)).variant.(Type_Info_Struct);
        found: bool;
        for name, i in ti.names {
            if name == info.name {
                assert(ti.types[i] == info.t, fmt.aprintln("Type", type_info_of(T), "has a field", name, "but the type is", ti.types[i], "instead of the expected", type_info_of(S)));
                assert(cast(int)ti.offsets[i] == info.offset, fmt.aprintln("Type", type_info_of(T), "has a field", name, "but the offset is", ti.offsets[i], "instead of the expected", info.offset));
                found = true;
            }
        }
        if !found do assert(false, fmt.aprintln("Type", type_info_of(T), "doesn't have a field called", info.name));
    }
    field_ptr := mem.ptr_offset(cast(^byte)thing, info.offset);
    mem.copy(field_ptr, &value, size_of(S));
}

get_union_type_info :: proc(v : any) -> ^Type_Info {
    if tag := get_union_tag(v); tag > 0 {
        info := type_info_base(type_info_of(v.typeid)).variant.(Type_Info_Union);

        return info.variants[tag - 1];
    }

    return nil;
}

get_union_tag :: proc(v : any) -> i64 {
    info, ok := type_info_base(type_info_of(v.typeid)).variant.(Type_Info_Union);
    tag_ptr := uintptr(v.data) + info.tag_offset;
    tag_any := any{rawptr(tag_ptr), info.tag_type.id};

    tag: i64 = -1;
    switch i in tag_any {
        case u8:   tag = i64(i);
        case u16:  tag = i64(i);
        case u32:  tag = i64(i);
        case u64:  tag = i64(i);
        case i8:   tag = i64(i);
        case i16:  tag = i64(i);
        case i32:  tag = i64(i);
        case i64:  tag = i64(i);
        case: panic(fmt.aprint("Invalid union tag type: ", i));
    }

    assert(tag > 0);
    return tag;
}

set_union_type_info :: proc(v : any, type_info : ^Type_Info) {
    info := type_info_base(type_info_of(v.typeid)).variant.(Type_Info_Union);

    for variant, i in info.variants {
        if variant == type_info {
            set_union_tag(v, i64(i + 1));
            return;
        }
    }

    panic(fmt.aprint("Union type", v, "doesn't contain type", type_info));
}

set_union_tag :: proc(v : any, tag : i64) {
    info, ok := type_info_base(type_info_of(v.typeid)).variant.(Type_Info_Union);
    tag_ptr := uintptr(v.data) + info.tag_offset;
    tag_any := any{rawptr(tag_ptr), info.tag_type.id};

    switch i in tag_any {
        case u8:  (^u8) (tag_any.data)^ = u8(tag);
        case u16: (^u16)(tag_any.data)^ = u16(tag);
        case u32: (^u32)(tag_any.data)^ = u32(tag);
        case u64: (^u64)(tag_any.data)^ = u64(tag);
        case i8:  (^i8) (tag_any.data)^ = i8(tag);
        case i16: (^i16)(tag_any.data)^ = i16(tag);
        case i32: (^i32)(tag_any.data)^ = i32(tag);
        case i64: (^i64)(tag_any.data)^ = i64(tag);
        case: panic(fmt.aprint("Invalid union tag type: ", i));
    }
}
