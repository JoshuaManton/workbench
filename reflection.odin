package workbench

using import "core:runtime"

      import "core:fmt"

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
