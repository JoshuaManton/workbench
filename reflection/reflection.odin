package reflection

      import rt "core:runtime"
      import "core:strings"
      import "core:strconv"
using import "core:fmt"

      import "core:mem"

Field_Info :: struct {
    name:   string,
    ti:     ^rt.Type_Info,
    offset: int,
}

get_struct_field_info :: proc{get_struct_field_info_poly, get_struct_field_info_ti};
get_struct_field_info_poly :: proc($T: typeid, field_name: string) -> (Field_Info, bool) {
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
get_struct_field_info_ti :: proc(_ti: ^rt.Type_Info, field_name: string) -> (Field_Info, bool) {
    ti := &rt.type_info_base(_ti).variant.(rt.Type_Info_Struct);
    for name, i in ti.names {
        if name == field_name {
            t := ti.types[i];
            offset := ti.offsets[i];
            return Field_Info{name, t, cast(int)offset}, true;
        }
    }
    return Field_Info{}, false;
}

set_struct_field :: proc{set_struct_field_poly, set_struct_field_raw};
set_struct_field_poly :: proc(thing: ^$T, info: Field_Info, value: $S, loc := #caller_location) {
    when DEVELOPER {
        ti := &type_info_base(type_info_of(T)).variant.(Type_Info_Struct);
        found: bool;
        for name, i in ti.names {
            if name == info.name {
                assert(ti.types[i] == info.ti, tprint("Type ", type_info_of(T), " has a field ", name, " but the type is ", ti.types[i], " instead of the expected ", type_info_of(S)));
                assert(cast(int)ti.offsets[i] == info.offset, tprint("Type ", type_info_of(T), " has a field ", name, " but the offset is ", ti.offsets[i], " instead of the expected ", info.offset));
                found = true;
            }
        }
        if !found do assert(false, tprint("Type ", type_info_of(T), " doesn't have a field called ", info.name, ". Caller: ", loc));
    }
    field_ptr := mem.ptr_offset(cast(^byte)thing, info.offset);
    mem.copy(field_ptr, &value, size_of(S));
}
set_struct_field_raw :: proc(thing: rawptr, info: Field_Info, value: $S, loc := #caller_location) {
    when DEVELOPER {
        ti := &type_info_base(type_info_of(T)).variant.(Type_Info_Struct);
        found: bool;
        for name, i in ti.names {
            if name == info.name {
                assert(ti.types[i] == info.ti, tprint("Type ", type_info_of(T), " has a field ", name, " but the type is ", ti.types[i], " instead of the expected ", type_info_of(S)));
                assert(cast(int)ti.offsets[i] == info.offset, tprint("Type ", type_info_of(T), " has a field ", name, " but the offset is ", ti.offsets[i], " instead of the expected ", info.offset));
                found = true;
            }
        }
        if !found do assert(false, tprint("Type ", type_info_of(T), " doesn't have a field called ", info.name, ". Caller: ", loc));
    }
    field_ptr := mem.ptr_offset(cast(^byte)thing, info.offset);
    mem.copy(field_ptr, &value, size_of(S));
}


get_union_type_info :: proc(v : any) -> ^rt.Type_Info {
    if tag := get_union_tag(v); tag > 0 {
        info := rt.type_info_base(type_info_of(v.id)).variant.(rt.Type_Info_Union);

        return info.variants[tag - 1];
    }

    return nil;
}

get_union_tag :: proc(v : any) -> i64 {
    info, ok := rt.type_info_base(type_info_of(v.id)).variant.(rt.Type_Info_Union);
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
        case: panic(fmt.tprint("Invalid union tag type: ", i));
    }

    assert(tag > 0);
    return tag;
}

set_union_type_info :: proc(v : any, type_info : ^rt.Type_Info) {
    info := rt.type_info_base(type_info_of(v.id)).variant.(rt.Type_Info_Union);

    for variant, i in info.variants {
        if variant == type_info {
            set_union_tag(v, i64(i + 1));
            return;
        }
    }

    panic(fmt.tprint("Union type", v, "doesn't contain type", type_info));
}

set_union_tag :: proc(v : any, tag : i64) {
    info, ok := rt.type_info_base(type_info_of(v.id)).variant.(rt.Type_Info_Union);
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
        case: panic(fmt.tprint("Invalid union tag type: ", i));
    }
}



set_ptr_value_from_string :: proc(ptr: rawptr, ti: ^rt.Type_Info, value_string: string) {
    // #complete
    switch ti_kind in ti.variant {
        case rt.Type_Info_String: {
            (cast(^string)ptr)^ = strings.clone(value_string);
        }

        case rt.Type_Info_Integer: {
            if ti_kind.signed {
                switch ti.size {
                    case 1: (cast(^i8)ptr)^  = cast(i8 )strconv.parse_i64(value_string);
                    case 2: (cast(^i16)ptr)^ = cast(i16)strconv.parse_i64(value_string);
                    case 4: (cast(^i32)ptr)^ = cast(i32)strconv.parse_i64(value_string);
                    case 8: (cast(^i64)ptr)^ = cast(i64)strconv.parse_i64(value_string);
                    case: panic(tprint(ti.size));
                }
            }
            else {
                switch ti.size {
                    case 1: (cast(^u8)ptr)^  = cast(u8 )strconv.parse_u64(value_string);
                    case 2: (cast(^u16)ptr)^ = cast(u16)strconv.parse_u64(value_string);
                    case 4: (cast(^u32)ptr)^ = cast(u32)strconv.parse_u64(value_string);
                    case 8: (cast(^u64)ptr)^ = cast(u64)strconv.parse_u64(value_string);
                    case: panic(tprint(ti.size));
                }
            }
        }

        case rt.Type_Info_Float: {
            switch ti.size {
                case 4: (cast(^f32)ptr)^ = strconv.parse_f32(value_string);
                case 8: (cast(^f64)ptr)^ = strconv.parse_f64(value_string);
                case: panic(tprint(ti.size));
            }
        }

        case rt.Type_Info_Boolean: {
            switch value_string {
                case "true", "True", "TRUE":    (cast(^bool)ptr)^ = true;
                case "false", "False", "FALSE": (cast(^bool)ptr)^ = false;
                case: {
                    assert(false, value_string);
                }
            }
        }

        case rt.Type_Info_Enum: {
            get_val_for_name :: proc(name: string, $Type: typeid, e: rt.Type_Info_Enum) -> (Type, bool) {
                for enum_member_name, idx in e.names {
                    if enum_member_name == name {
                        return e.values[idx].(Type), true;
                    }
                }
                return Type{}, false;
            }

            a := any{ptr, rt.type_info_base(ti_kind.base).id};
            switch v in a {
            case rune:    val, ok := get_val_for_name(value_string, rune,    ti_kind); assert(ok); (cast(^rune)   ptr)^ = val;
            case i8:      val, ok := get_val_for_name(value_string, i8,      ti_kind); assert(ok); (cast(^i8)     ptr)^ = val;
            case i16:     val, ok := get_val_for_name(value_string, i16,     ti_kind); assert(ok); (cast(^i16)    ptr)^ = val;
            case i32:     val, ok := get_val_for_name(value_string, i32,     ti_kind); assert(ok); (cast(^i32)    ptr)^ = val;
            case i64:     val, ok := get_val_for_name(value_string, i64,     ti_kind); assert(ok); (cast(^i64)    ptr)^ = val;
            case int:     val, ok := get_val_for_name(value_string, int,     ti_kind); assert(ok); (cast(^int)    ptr)^ = val;
            case u8:      val, ok := get_val_for_name(value_string, u8,      ti_kind); assert(ok); (cast(^u8)     ptr)^ = val;
            case u16:     val, ok := get_val_for_name(value_string, u16,     ti_kind); assert(ok); (cast(^u16)    ptr)^ = val;
            case u32:     val, ok := get_val_for_name(value_string, u32,     ti_kind); assert(ok); (cast(^u32)    ptr)^ = val;
            case u64:     val, ok := get_val_for_name(value_string, u64,     ti_kind); assert(ok); (cast(^u64)    ptr)^ = val;
            case uint:    val, ok := get_val_for_name(value_string, uint,    ti_kind); assert(ok); (cast(^uint)   ptr)^ = val;
            case uintptr: val, ok := get_val_for_name(value_string, uintptr, ti_kind); assert(ok); (cast(^uintptr)ptr)^ = val;
            }
        }

        case rt.Type_Info_Named: {
            set_ptr_value_from_string(ptr, ti_kind.base, value_string);
        }

        case rt.Type_Info_Rune: {
            unimplemented(tprint(ti_kind));
        }
        case: {
            assert(false, tprint(ti_kind));
        }
    }




            //     a: any;
            // a = &a;
            // a.id = field_info.ti.id;
            // switch kind in a {
            //     case string:
            //         (cast(^string)ptr_to_field)^ = str_value;

            //     case int:
            //         value := parse_int(str_value);
            //         (cast(^int)ptr_to_field)^ = value;
            //     case i8:
            //         value := parse_i8(str_value);
            //         (cast(^i8)ptr_to_field)^ = value;
            //     case i16:
            //         value := parse_i16(str_value);
            //         (cast(^i16)ptr_to_field)^ = value;
            //     case i32:
            //         value := parse_i32(str_value);
            //         (cast(^i32)ptr_to_field)^ = value;
            //     case i64:
            //         value := parse_i64(str_value);
            //         (cast(^i64)ptr_to_field)^ = value;

            //     case uint:
            //         value := parse_uint(str_value);
            //         (cast(^uint)ptr_to_field)^ = value;
            //     case u8:
            //         value := parse_u8(str_value);
            //         (cast(^u8)ptr_to_field)^ = value;
            //     case u16:
            //         value := parse_u16(str_value);
            //         (cast(^u16)ptr_to_field)^ = value;
            //     case u32:
            //         value := parse_u32(str_value);
            //         (cast(^u32)ptr_to_field)^ = value;
            //     case u64:
            //         value := parse_u64(str_value);
            //         (cast(^u64)ptr_to_field)^ = value;

            //     case f32:
            //         value := parse_f32(str_value);
            //         (cast(^f32)ptr_to_field)^ = value;
            //     case f64:
            //         value := parse_f64(str_value);
            //         (cast(^f64)ptr_to_field)^ = value;

            //     case bool:
            //         value := parse_bool(str_value);
            //         (cast(^bool)ptr_to_field)^ = value;

            //     case:
            //         assert(false, aprintln("Unsupported record field member type:", field_info.ti));
            // }

}