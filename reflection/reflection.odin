package reflection

      import rt "core:runtime"
      import "core:strings"
      import "core:strconv"
using import "core:fmt"

      import "core:mem"

get_union_type_info :: proc(v : any) -> ^rt.Type_Info {
    if tag := get_union_tag(v); tag > 0 {
        info := rt.type_info_base(type_info_of(v.id)).variant.(rt.Type_Info_Union);

        return info.variants[tag - 1];
    }

    return nil;
}

get_union_tag :: proc(v : any) -> i64 {
    info, ok := rt.type_info_base(type_info_of(v.id)).variant.(rt.Type_Info_Union);
    assert(ok, tprint(v));
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

    assert(tag >= 0);
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
    assert(ok, tprint(v));
    tag_ptr := uintptr(v.data) + info.tag_offset;
    tag_any := any{rawptr(tag_ptr), info.tag_type.id};

    switch i in tag_any {
        case u8:  (^u8 )(tag_any.data)^ = u8 (tag);
        case u16: (^u16)(tag_any.data)^ = u16(tag);
        case u32: (^u32)(tag_any.data)^ = u32(tag);
        case u64: (^u64)(tag_any.data)^ = u64(tag);
        case i8:  (^i8 )(tag_any.data)^ = i8 (tag);
        case i16: (^i16)(tag_any.data)^ = i16(tag);
        case i32: (^i32)(tag_any.data)^ = i32(tag);
        case i64: (^i64)(tag_any.data)^ = i64(tag);
        case: panic(fmt.tprint("Invalid union tag type: ", i));
    }
}



set_ptr_value_from_string :: proc(ptr: rawptr, ti: ^rt.Type_Info, value_string: string, allocator := context.allocator) {
    // todo(josh): handle more cases
    // #complete
    switch ti_kind in ti.variant {
        case rt.Type_Info_String: {
            (cast(^string)ptr)^ = strings.clone(value_string, allocator);
        }

        case rt.Type_Info_Integer: {
            if ti_kind.signed {
                i64_value := strconv.parse_i64(value_string);
                #complete
                switch ti_kind.endianness {
                    case .Platform: {
                        switch ti.size {
                            case 1: (cast(^i8 )ptr)^ = cast(i8 )i64_value;
                            case 2: (cast(^i16)ptr)^ = cast(i16)i64_value;
                            case 4: (cast(^i32)ptr)^ = cast(i32)i64_value;
                            case 8: (cast(^i64)ptr)^ = cast(i64)i64_value;
                            case: panic(tprint(ti.size));
                        }
                    }
                    case .Little: {
                        switch ti.size {
                            case 2: (cast(^i16le)ptr)^ = cast(i16le)i64_value;
                            case 4: (cast(^i32le)ptr)^ = cast(i32le)i64_value;
                            case 8: (cast(^i64le)ptr)^ = cast(i64le)i64_value;
                            case: panic(tprint(ti.size));
                        }
                    }
                    case .Big: {
                        switch ti.size {
                            case 2: (cast(^i16be)ptr)^ = cast(i16be)i64_value;
                            case 4: (cast(^i32be)ptr)^ = cast(i32be)i64_value;
                            case 8: (cast(^i64be)ptr)^ = cast(i64be)i64_value;
                            case: panic(tprint(ti.size));
                        }
                    }
                    case: panic(tprint(ti_kind.endianness));
                }
            }
            else {
                u64_value := strconv.parse_u64(value_string);
                #complete
                switch ti_kind.endianness {
                    case .Platform: {
                        switch ti.size {
                            case 1: (cast(^u8)ptr)^  = cast(u8 )u64_value;
                            case 2: (cast(^u16)ptr)^ = cast(u16)u64_value;
                            case 4: (cast(^u32)ptr)^ = cast(u32)u64_value;
                            case 8: (cast(^u64)ptr)^ = cast(u64)u64_value;
                            case: panic(tprint(ti.size));
                        }
                    }
                    case .Little: {
                        switch ti.size {
                            case 2: (cast(^u16le)ptr)^ = cast(u16le)u64_value;
                            case 4: (cast(^u32le)ptr)^ = cast(u32le)u64_value;
                            case 8: (cast(^u64le)ptr)^ = cast(u64le)u64_value;
                            case: panic(tprint(ti.size));
                        }
                    }
                    case .Big: {
                        switch ti.size {
                            case 2: (cast(^u16be)ptr)^ = cast(u16be)u64_value;
                            case 4: (cast(^u32be)ptr)^ = cast(u32be)u64_value;
                            case 8: (cast(^u64be)ptr)^ = cast(u64be)u64_value;
                            case: panic(tprint(ti.size));
                        }
                    }
                    case: panic(tprint(ti_kind.endianness));
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
            get_val_for_name :: proc(name: string, e: rt.Type_Info_Enum) -> rt.Type_Info_Enum_Value {
                for enum_member_name, idx in e.names {
                    if enum_member_name == name {
                        return e.values[idx];
                    }
                }
                panic(tprint("Couldn't find enum member '", name, "' in enum '", e, "'."));
                return {};
            }

            a := any{ptr, rt.type_info_base(ti_kind.base).id};
            switch v in a {
            case rune:    val := get_val_for_name(value_string, ti_kind); (cast(^rune)   ptr)^ = val.(rune);
            case i8:      val := get_val_for_name(value_string, ti_kind); (cast(^i8)     ptr)^ = val.(i8);
            case i16:     val := get_val_for_name(value_string, ti_kind); (cast(^i16)    ptr)^ = val.(i16);
            case i32:     val := get_val_for_name(value_string, ti_kind); (cast(^i32)    ptr)^ = val.(i32);
            case i64:     val := get_val_for_name(value_string, ti_kind); (cast(^i64)    ptr)^ = val.(i64);
            case int:     val := get_val_for_name(value_string, ti_kind); (cast(^int)    ptr)^ = val.(int);
            case u8:      val := get_val_for_name(value_string, ti_kind); (cast(^u8)     ptr)^ = val.(u8);
            case u16:     val := get_val_for_name(value_string, ti_kind); (cast(^u16)    ptr)^ = val.(u16);
            case u32:     val := get_val_for_name(value_string, ti_kind); (cast(^u32)    ptr)^ = val.(u32);
            case u64:     val := get_val_for_name(value_string, ti_kind); (cast(^u64)    ptr)^ = val.(u64);
            case uint:    val := get_val_for_name(value_string, ti_kind); (cast(^uint)   ptr)^ = val.(uint);
            case uintptr: val := get_val_for_name(value_string, ti_kind); (cast(^uintptr)ptr)^ = val.(uintptr);
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
}