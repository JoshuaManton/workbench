package logging

import "core:fmt"
import "core:mem"
import "core:reflect"
import "core:strings"
import rt "core:runtime" // todo(josh): remove after pretty_print

import "../basic"

logln :: proc(args: ..any, location := #caller_location) {
    fmt.print(basic.pretty_location(location), ' ');
    fmt.print(..args);
    fmt.print('\n');
}

logf :: proc(f: string, args: ..any, location := #caller_location) {
    fmt.print(basic.pretty_location(location), ' ');

    // todo(josh): escaping?
    last_end: int;
    num_percents: int;
    for b, idx in f {
        if b == '%' && num_percents < len(args) {
            str := f[last_end:idx];
            fmt.print(str);
            fmt.print(args[num_percents]);
            num_percents += 1;
            last_end = idx+1;
        }
    }
    last := f[last_end:len(f)];
    fmt.print(last);
    fmt.print('\n');
}

println :: fmt.println;
sbprint :: fmt.sbprint;
tprint  :: fmt.tprint;

pretty_print :: proc(thing: any) {
    sb: strings.Builder;
    defer strings.destroy_builder(&sb);
    pretty_sbprint(&sb, thing);
    println(strings.to_string(sb));
}

pretty_sbprint :: proc(sb: ^strings.Builder, thing: any) {
    print_value(sb, thing.data, type_info_of(thing.id), 0);

    print_value :: proc(sb: ^strings.Builder, data: rawptr, ti: ^rt.Type_Info, indent_level: int) {
        do_indent :: proc(sb: ^strings.Builder, indent_level: int) {
            for i in 0..<indent_level do sbprint(sb, "    ");
        }

        indent_level := indent_level;

        switch kind in ti.variant {
            case rt.Type_Info_Named: print_value(sb, data, kind.base, indent_level);
            case rt.Type_Info_Integer: {
                if kind.signed {
                    switch kind.endianness {
                        case .Little: {
                            switch ti.size {
                                case 1: fmt.sbprint(sb, (cast(^i8   )data)^);
                                case 2: fmt.sbprint(sb, (cast(^i16le)data)^);
                                case 4: fmt.sbprint(sb, (cast(^i32le)data)^);
                                case 8: fmt.sbprint(sb, (cast(^i64le)data)^);
                                case: panic(tprint(ti.size));
                            }
                        }
                        case .Big: {
                            switch ti.size {
                                case 1: fmt.sbprint(sb, (cast(^i8   )data)^);
                                case 2: fmt.sbprint(sb, (cast(^i16be)data)^);
                                case 4: fmt.sbprint(sb, (cast(^i32be)data)^);
                                case 8: fmt.sbprint(sb, (cast(^i64be)data)^);
                                case: panic(tprint(ti.size));
                            }
                        }
                        case .Platform: {
                            switch ti.size {
                                case 1: fmt.sbprint(sb, (cast(^i8 )data)^);
                                case 2: fmt.sbprint(sb, (cast(^i16)data)^);
                                case 4: fmt.sbprint(sb, (cast(^i32)data)^);
                                case 8: fmt.sbprint(sb, (cast(^i64)data)^);
                                case: panic(tprint(ti.size));
                            }
                        }
                        case: panic(tprint(kind.endianness));
                    }
                }
                else {
                    switch kind.endianness {
                        case .Little: {
                            switch ti.size {
                                case 1: fmt.sbprint(sb, (cast(^u8   )data)^);
                                case 2: fmt.sbprint(sb, (cast(^u16le)data)^);
                                case 4: fmt.sbprint(sb, (cast(^u32le)data)^);
                                case 8: fmt.sbprint(sb, (cast(^u64le)data)^);
                                case: panic(tprint(ti.size));
                            }
                        }
                        case .Big: {
                            switch ti.size {
                                case 1: fmt.sbprint(sb, (cast(^u8   )data)^);
                                case 2: fmt.sbprint(sb, (cast(^u16be)data)^);
                                case 4: fmt.sbprint(sb, (cast(^u32be)data)^);
                                case 8: fmt.sbprint(sb, (cast(^u64be)data)^);
                                case: panic(tprint(ti.size));
                            }
                        }
                        case .Platform: {
                            switch ti.size {
                                case 1: fmt.sbprint(sb, (cast(^u8 )data)^);
                                case 2: fmt.sbprint(sb, (cast(^u16)data)^);
                                case 4: fmt.sbprint(sb, (cast(^u32)data)^);
                                case 8: fmt.sbprint(sb, (cast(^u64)data)^);
                                case: panic(tprint(ti.size));
                            }
                        }
                        case: panic(tprint(kind.endianness));
                    }
                }
            }
            case rt.Type_Info_Rune: fmt.sbprint(sb, (cast(^rune)data)^);
            case rt.Type_Info_Float: {
                switch ti.size {
                    case 4: sbprint(sb, (cast(^f32)data)^);
                    case 8: sbprint(sb, (cast(^f64)data)^);
                    case: panic(tprint(ti.size));
                }
            }
            case rt.Type_Info_Struct: {
                sbprint(sb, "{\n");
                indent_level += 1;
                for name, idx in kind.names {
                    type := kind.types[idx];
                    offset := kind.offsets[idx];

                    // print name
                    do_indent(sb, indent_level);
                    sbprint(sb, name, ": ");

                    // print type
                    sbprint(sb, type);

                    // print value
                    sbprint(sb, " = ");
                    print_value(sb, mem.ptr_offset(cast(^byte)data, cast(int)offset), type, indent_level);

                    sbprint(sb, ",\n");

                }
                indent_level -= 1;
                do_indent(sb, indent_level);
                sbprint(sb, "}");
            }
            case rt.Type_Info_Boolean: {
                switch ti.size {
                    case 1: sbprint(sb, (cast(^b8 )data)^);
                    case 2: sbprint(sb, (cast(^b16)data)^);
                    case 4: sbprint(sb, (cast(^b32)data)^);
                    case 8: sbprint(sb, (cast(^b64)data)^);
                    case: panic(tprint(ti.size));
                }
            }
            case rt.Type_Info_String: {
                if kind.is_cstring do sbprint(sb, '"', (cast(^cstring)data)^, '"');
                else               do sbprint(sb, '"', (cast(^string )data)^, '"');
            }
            case rt.Type_Info_Pointer: {
                // todo(josh): do we want to recurse maybe just once?
                sbprint(sb, (cast(^rawptr)data)^);
            }
            case rt.Type_Info_Relative_Pointer: {
                sbprint(sb, (cast(^rawptr)data)^);
            }
            case rt.Type_Info_Relative_Slice: {
                unimplemented();
            }
            case rt.Type_Info_Procedure: sbprint(sb, (cast(^rawptr)data)^);
            case rt.Type_Info_Type_Id: sbprint(sb, (cast(^typeid)data)^);
            case rt.Type_Info_Array: {
                sbprint(sb, "[\n");
                indent_level += 1;
                for idx in 0..<kind.count {
                    offset := idx * kind.elem.size;
                    do_indent(sb, indent_level);
                    sbprint(sb, "[", idx, "]", " = ");
                    print_value(sb, mem.ptr_offset(cast(^byte)data, offset), kind.elem, indent_level);
                    sbprint(sb, ",\n");
                }
                indent_level -= 1;
                do_indent(sb, indent_level);
                sbprint(sb, "]");
            }
            case rt.Type_Info_Slice: {
                sbprint(sb, "[\n");
                indent_level += 1;
                raw_slice := cast(^mem.Raw_Slice)data;
                for idx in 0..<raw_slice.len {
                    offset := idx * kind.elem.size;
                    do_indent(sb, indent_level);
                    sbprint(sb, "[", idx, "]", " = ");
                    print_value(sb, mem.ptr_offset(cast(^byte)raw_slice.data, offset), kind.elem, indent_level);
                    sbprint(sb, ",\n");
                }
                indent_level -= 1;
                do_indent(sb, indent_level);
                sbprint(sb, "]");
            }
            case rt.Type_Info_Enumerated_Array: {
                sbprint(sb, "[\n");
                indent_level += 1;
                for idx in 0..<kind.count {
                    offset := idx * kind.elem.size;
                    do_indent(sb, indent_level);
                    // todo(josh): the enum string thing doesn't work
                    sbprint(sb, "[", reflect.enum_string(any{data, kind.index.id}), "]", " = ");
                    print_value(sb, mem.ptr_offset(cast(^byte)data, offset), kind.elem, indent_level);
                    sbprint(sb, ",\n");
                }
                indent_level -= 1;
                do_indent(sb, indent_level);
                sbprint(sb, "]");
            }
            case rt.Type_Info_Dynamic_Array: {
                sbprint(sb, "[\n");
                indent_level += 1;
                raw_dyn := cast(^mem.Raw_Dynamic_Array)data;
                for idx in 0..<raw_dyn.len {
                    offset := idx * kind.elem.size;
                    do_indent(sb, indent_level);
                    sbprint(sb, "[", idx, "]", " = ");
                    print_value(sb, mem.ptr_offset(cast(^byte)raw_dyn.data, offset), kind.elem, indent_level);
                    sbprint(sb, ",\n");
                }
                indent_level -= 1;
                do_indent(sb, indent_level);
                sbprint(sb, "]");
            }
            case rt.Type_Info_Union: {
                tag_ti := get_union_type_info(any{data, ti.id});
                sbprint(sb, "(", tag_ti.id, ") ");
                print_value(sb, data, tag_ti, indent_level);
            }
            case rt.Type_Info_Enum: sbprint(sb, reflect.enum_string(any{data, ti.id}));
            case rt.Type_Info_Any:  sbprint(sb, "(", (cast(^any)data)^.id, ") ", (cast(^any)data)^);

            case rt.Type_Info_Map:         sbprint(sb, "{{Type_Info_Map not supported}}");
            case rt.Type_Info_Bit_Field:   sbprint(sb, "{{Type_Info_Bit_Field not supported}}");
            case rt.Type_Info_Bit_Set:     sbprint(sb, "{{Type_Info_Bit_Set not supported}}");
            case rt.Type_Info_Complex:     sbprint(sb, "{{Type_Info_Complex not supported}}");
            case rt.Type_Info_Quaternion:  sbprint(sb, "{{Type_Info_Quaternion not supported}}");
            case rt.Type_Info_Opaque:      sbprint(sb, "{{Type_Info_Opaque not supported}}");
            case rt.Type_Info_Simd_Vector: sbprint(sb, "{{Type_Info_Simd_Vector not supported}}");
            case rt.Type_Info_Tuple:       sbprint(sb, "{{Type_Info_Tuple not supported}}");
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
            if !ok do panic(tprint(v));

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
    }
}