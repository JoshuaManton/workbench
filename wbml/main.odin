package wbml

import rt "core:runtime"
import "core:mem"
import "core:strings"
import "core:types"

using import "core:fmt"
using import "../laas"

main :: proc() {
	// alloc_callback :: proc(loc: rt.Source_Code_Location) {
	// 	fmt.println(loc);
	// }
	// mem.alloc_callback = alloc_callback;
	// defer mem.alloc_callback = nil;

	run_tests();
}

serialize :: proc(value: ^$Type) -> string {
	serialize_one_thing :: proc(name: string, value: rawptr, ti: ^rt.Type_Info, sb: ^String_Buffer, indent_level: int) {
		print_indents :: inline proc(indent_level: int, sb: ^String_Buffer) {
			for i in 0..indent_level-1 {
				sbprint(sb, "\t");
			}
		}

		print_to_buff :: inline proc(sb: ^String_Buffer, args: ..any) {
			sbprint(sb, ..args);
		}

		if name != "" {
			print_to_buff(sb, name, " ");
		}

		do_newline := true;
		switch kind in ti.variant {
			case rt.Type_Info_Integer: {
				if kind.signed {
					switch ti.size {
						case 1: print_to_buff(sb, (cast(^i8 )value)^);
						case 2: print_to_buff(sb, (cast(^i16)value)^);
						case 4: print_to_buff(sb, (cast(^i32)value)^);
						case 8: print_to_buff(sb, (cast(^i64)value)^);
						case: panic(tprint(ti.size));
					}
				}
				else {
					switch ti.size {
						case 1: print_to_buff(sb, (cast(^u8 )value)^);
						case 2: print_to_buff(sb, (cast(^u16)value)^);
						case 4: print_to_buff(sb, (cast(^u32)value)^);
						case 8: print_to_buff(sb, (cast(^u64)value)^);
						case: panic(tprint(ti.size));
					}
				}
			}

			case rt.Type_Info_Float: {
				switch ti.size {
					case 4: print_to_buff(sb, (cast(^f32)value)^);
					case 8: print_to_buff(sb, (cast(^f64)value)^);
					case: panic(tprint(ti.size));
				}
			}

			case rt.Type_Info_Enum: {
				do_newline = false;

				get_str :: proc(i: $T, e: rt.Type_Info_Enum) -> (string, bool) {
					if types.is_string(e.base) {
						for val, idx in e.values {
							if v, ok := val.(T); ok && v == i {
								return e.names[idx], true;
							}
						}
					} else if len(e.values) == 0 {
						return "", true;
					} else {
						for val, idx in e.values {
							if v, ok := val.(T); ok && v == i {
								return e.names[idx], true;
							}
						}
					}
					return "", false;
				}

				a := any{value, rt.type_info_base(kind.base).id};
				switch v in a {
				case rune:    str, ok := get_str(v, kind); assert(ok); print_to_buff(sb, str);
				case i8:      str, ok := get_str(v, kind); assert(ok); print_to_buff(sb, str);
				case i16:     str, ok := get_str(v, kind); assert(ok); print_to_buff(sb, str);
				case i32:     str, ok := get_str(v, kind); assert(ok); print_to_buff(sb, str);
				case i64:     str, ok := get_str(v, kind); assert(ok); print_to_buff(sb, str);
				case int:     str, ok := get_str(v, kind); assert(ok); print_to_buff(sb, str);
				case u8:      str, ok := get_str(v, kind); assert(ok); print_to_buff(sb, str);
				case u16:     str, ok := get_str(v, kind); assert(ok); print_to_buff(sb, str);
				case u32:     str, ok := get_str(v, kind); assert(ok); print_to_buff(sb, str);
				case u64:     str, ok := get_str(v, kind); assert(ok); print_to_buff(sb, str);
				case uint:    str, ok := get_str(v, kind); assert(ok); print_to_buff(sb, str);
				case uintptr: str, ok := get_str(v, kind); assert(ok); print_to_buff(sb, str);
				}
			}

			case rt.Type_Info_Boolean: {
				print_to_buff(sb, (cast(^bool)value)^);
			}

			case rt.Type_Info_String: {
				print_to_buff(sb, "\"", (cast(^string)value)^, "\"");
			}

			case rt.Type_Info_Named: {
				serialize_one_thing("", value, kind.base, sb, indent_level);
			}

			case rt.Type_Info_Struct: {
				print_to_buff(sb, "{\n"); indent_level += 1;
				for name, idx in kind.names {
					print_indents(indent_level, sb);
					serialize_one_thing(name, mem.ptr_offset(cast(^byte)value, cast(int)kind.offsets[idx]), kind.types[idx], sb, indent_level);
				}
				indent_level -= 1; print_indents(indent_level, sb); print_to_buff(sb, "}");
			}

			case rt.Type_Info_Array: {
				print_to_buff(sb, "[\n"); indent_level += 1;
				{
					for i in 0..kind.count-1 {
						data := mem.ptr_offset(cast(^byte)value, i * kind.elem_size);
						print_indents(indent_level, sb);
						serialize_one_thing("", data, kind.elem, sb, indent_level);
					}
				}
				indent_level -= 1; print_indents(indent_level, sb); print_to_buff(sb, "]");
			}

			case rt.Type_Info_Dynamic_Array: {
				dyn := transmute(^mem.Raw_Dynamic_Array)value;
				print_to_buff(sb, "[\n"); indent_level += 1;
				{
					for i in 0..dyn.len-1 {
						data := mem.ptr_offset(cast(^byte)dyn.data, i * kind.elem_size);
						print_indents(indent_level, sb);
						serialize_one_thing("", data, kind.elem, sb, indent_level);
					}
				}
				indent_level -= 1; print_indents(indent_level, sb); print_to_buff(sb, "]");
			}

			case rt.Type_Info_Slice: {
				dyn := transmute(^mem.Raw_Slice)value;
				print_to_buff(sb, "[\n"); indent_level += 1;
				{
					for i in 0..dyn.len-1 {
						data := mem.ptr_offset(cast(^byte)dyn.data, i * kind.elem_size);
						print_indents(indent_level, sb);
						serialize_one_thing("", data, kind.elem, sb, indent_level);
					}
				}
				indent_level -= 1; print_indents(indent_level, sb); print_to_buff(sb, "]");
			}

			case: panic(tprint(kind));
		}

		if do_newline {
			print_to_buff(sb, "\n");
		}
	}

	sb: String_Buffer;
	ti := type_info_of(Type);
	serialize_one_thing("", value, ti, &sb, 0);

	return to_string(sb);
}

deserialize :: proc{deserialize_to_value, deserialize_into_pointer};

deserialize_to_value :: inline proc($Type: typeid, text: string) -> Type {
	t: Type;
	deserialize_into_pointer(text, &t);
	return t;
}

deserialize_into_pointer :: proc(text: string, ptr: ^$Type) {
	ti := type_info_of(Type);

	_lexer := laas.Lexer{text, 0, 0, 0, nil};
	lexer := &_lexer;

	token: Token;
	ok := get_next_token(lexer, &token);
	if !ok do panic("empty text");

	parse_value(lexer, token, ptr, ti);
}

parse_value :: proc(lexer: ^Lexer, parent_token: Token, data: rawptr, ti: ^rt.Type_Info) {
	switch value_kind in parent_token.kind {
		case laas.Symbol: {
			switch value_kind.value {
				case '{': {
					token: Token;
					for get_next_token(lexer, &token) {
						if right_curly, ok2 := token.kind.(laas.Symbol); ok2 && right_curly.value == '}' {
							break;
						}

						variable_name, ok2 := token.kind.(laas.Identifier);
						assert(ok2);
						field_ptr : rawptr = nil;
						field_ti  : ^rt.Type_Info = nil;
						struct_kind: ^rt.Type_Info_Struct;
						switch ti_kind in &ti.variant {
							case rt.Type_Info_Named:  struct_kind = &ti_kind.base.variant.(rt.Type_Info_Struct);
							case rt.Type_Info_Struct: struct_kind = ti_kind;
							case: panic(tprint(ti_kind));
						}
						assert(struct_kind != nil);
						for name, i in struct_kind.names {
							if name == variable_name.value {
								field_ptr = mem.ptr_offset(cast(^byte)data, cast(int)struct_kind.offsets[i]);
								field_ti  = struct_kind.types[i];
								break;
							}
						}
						assert(field_ptr != nil, tprint("couldn't find name ", variable_name.value));

						value_token: Token;
						ok3 := get_next_token(lexer, &value_token); assert(ok3);
						parse_value(lexer, value_token, field_ptr, field_ti);
					}
				}
				case '[': {
					switch array_kind in ti.variant {
						case rt.Type_Info_Array: {
							i: int;
							for {
								defer i += 1;
								if i > array_kind.count {
									assert(false, "Too many array elements");
								}

								array_value_token: Token;
								ok := get_next_token(lexer, &array_value_token);
								if !ok do assert(false, "End of text from within array");

								if symbol, is_symbol := array_value_token.kind.(laas.Symbol); is_symbol {
									if symbol.value == ']' do break;
									if symbol.value != '{' {
										assert(false, tprint("Symbol token in array: ", symbol));
									}
								}

								parse_value(lexer, array_value_token, mem.ptr_offset(cast(^byte)data, array_kind.elem_size * i), array_kind.elem);
							}
						}
						case rt.Type_Info_Dynamic_Array: {
							memory := make([]byte, 1024);
							byte_index := 0;

							i: int;
							for {
								defer i += 1;

								array_value_token: Token;
								ok := get_next_token(lexer, &array_value_token);
								if !ok do assert(false, "End of text from within array");

								if symbol, is_symbol := array_value_token.kind.(laas.Symbol); is_symbol {
									if symbol.value == ']' do break;
									if symbol.value != '{' {
										assert(false, tprint("Symbol token in array: ", symbol));
									}
								}

								if byte_index + array_kind.elem_size > len(memory) {
									old_mem := memory;
									memory = make([]byte, len(old_mem) * 2);
									mem.copy(&memory[0], &old_mem[0], len(old_mem));
									delete(old_mem);
								}

								parse_value(lexer, array_value_token, &memory[byte_index], array_kind.elem);
								byte_index += array_kind.elem_size;
							}

							(cast(^mem.Raw_Dynamic_Array)data)^ = mem.Raw_Dynamic_Array{&memory[0], i, len(memory) / array_kind.elem_size, {}};
						}
						case rt.Type_Info_Slice: {
							memory := make([]byte, 1024);
							byte_index := 0;

							i: int;
							for {
								defer i += 1;

								array_value_token: Token;
								ok := get_next_token(lexer, &array_value_token);
								if !ok do assert(false, "End of text from within array");

								if symbol, is_symbol := array_value_token.kind.(laas.Symbol); is_symbol {
									if symbol.value == ']' do break;
									if symbol.value != '{' {
										assert(false, tprint("Symbol token in array: ", symbol));
									}
								}

								if byte_index + array_kind.elem_size > len(memory) {
									old_mem := memory;
									memory = make([]byte, len(old_mem) * 2);
									mem.copy(&memory[0], &old_mem[0], len(old_mem));
									delete(old_mem);
								}

								parse_value(lexer, array_value_token, &memory[byte_index], array_kind.elem);
								byte_index += array_kind.elem_size;
							}

							(cast(^mem.Raw_Slice)data)^ = mem.Raw_Slice{&memory[0], i};
						}
						case: panic(tprint(array_kind));
					}
				}
			}
		}

		// primitives
		case laas.String: {
			(cast(^string)data)^ = strings.new_string(value_kind.value);
		}

		case laas.Identifier: {
			switch kind in ti.variant {
				case rt.Type_Info_Boolean: {
					switch value_kind.value {
						case "true", "True", "TRUE":    (cast(^bool)data)^ = true;
						case "false", "False", "FALSE": (cast(^bool)data)^ = false;
						case: {
							assert(false, value_kind.value);
						}
					}
				}

				case rt.Type_Info_Named: {
					parse_value(lexer, parent_token, data, kind.base);
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

					a := any{data, rt.type_info_base(kind.base).id};
					switch v in a {
					case rune:    val, ok := get_val_for_name(value_kind.value, rune,    kind); assert(ok); (cast(^rune)   data)^ = val;
					case i8:      val, ok := get_val_for_name(value_kind.value, i8,      kind); assert(ok); (cast(^i8)     data)^ = val;
					case i16:     val, ok := get_val_for_name(value_kind.value, i16,     kind); assert(ok); (cast(^i16)    data)^ = val;
					case i32:     val, ok := get_val_for_name(value_kind.value, i32,     kind); assert(ok); (cast(^i32)    data)^ = val;
					case i64:     val, ok := get_val_for_name(value_kind.value, i64,     kind); assert(ok); (cast(^i64)    data)^ = val;
					case int:     val, ok := get_val_for_name(value_kind.value, int,     kind); assert(ok); (cast(^int)    data)^ = val;
					case u8:      val, ok := get_val_for_name(value_kind.value, u8,      kind); assert(ok); (cast(^u8)     data)^ = val;
					case u16:     val, ok := get_val_for_name(value_kind.value, u16,     kind); assert(ok); (cast(^u16)    data)^ = val;
					case u32:     val, ok := get_val_for_name(value_kind.value, u32,     kind); assert(ok); (cast(^u32)    data)^ = val;
					case u64:     val, ok := get_val_for_name(value_kind.value, u64,     kind); assert(ok); (cast(^u64)    data)^ = val;
					case uint:    val, ok := get_val_for_name(value_kind.value, uint,    kind); assert(ok); (cast(^uint)   data)^ = val;
					case uintptr: val, ok := get_val_for_name(value_kind.value, uintptr, kind); assert(ok); (cast(^uintptr)data)^ = val;
					}
				}

				case: {
					assert(false, tprint(kind));
				}
			}
		}

		case laas.Number: {
			switch num_kind in ti.variant {
				case rt.Type_Info_Integer: {
					if num_kind.signed {
						switch ti.size {
							case 1: (cast(^i8)data)^  = cast(i8) value_kind.int_value;
							case 2: (cast(^i16)data)^ = cast(i16)value_kind.int_value;
							case 4: (cast(^i32)data)^ = cast(i32)value_kind.int_value;
							case 8: (cast(^i64)data)^ =          value_kind.int_value;
							case: panic(tprint(ti.size));
						}
					}
					else {
						switch ti.size {
							case 1: (cast(^u8)data)^  = cast(u8) value_kind.unsigned_int_value;
							case 2: (cast(^u16)data)^ = cast(u16)value_kind.unsigned_int_value;
							case 4: (cast(^u32)data)^ = cast(u32)value_kind.unsigned_int_value;
							case 8: (cast(^u64)data)^ =          value_kind.unsigned_int_value;
							case: panic(tprint(ti.size));
						}
					}
				}
				case rt.Type_Info_Float: {
					switch ti.size {
						case 4: (cast(^f32)data)^ = cast(f32)value_kind.float_value;
						case 8: (cast(^f64)data)^ =          value_kind.float_value;
						case: panic(tprint(ti.size));
					}
				}
				case: {
					assert(false, tprint(num_kind));
				}
			}
		}
	}
}

run_tests :: proc() {
	Int_Enum :: enum int {
		Foo,
		Bar,
		Baz,
	}

	Byte_Enum :: enum u8 {
		Qwe,
		Asd,
		Zxc,
	}

	Nightmare :: struct {
		some_int: int,
		some_string: string,
		some_float: f64,
		some_bool: bool,
		enum1: Int_Enum,
		enum2: Byte_Enum,
		some_nested_thing: struct {
			asd: f32,
			super_nested: struct {
				blah: string,
			},
			some_array: [4]string,
			dyn_array: [dynamic]bool,
			slice: []struct {
				x, y: f64,
			},
		}
	}

	source :=
`{
	some_int 123
	some_string "henlo lizer"
	some_float 123.400
	some_bool true
	enum1 Baz
	enum2 Asd
	some_nested_thing {
		asd 432.500
		super_nested {
			blah "super nested string"
		}
		some_array [
			"123"
			"qwe"
			"asd"
			"zxc"
		]
		dyn_array [
			true
			false
			false
			true
		]
		slice [
			{
				x 12.000
				y 34.000
			}
			{
				x 43.000
				y 21.000
			}
		]
	}
}`;

	a := deserialize(Nightmare, source);

	assert(a.some_int == 123, tprint(a.some_int));
	assert(a.some_string == "henlo lizer", tprint(a.some_string));
	assert(a.some_float == 123.4, tprint(a.some_float));
	assert(a.some_bool == true, tprint(a.some_bool));

	assert(a.some_nested_thing.asd == 432.500, tprintf("%.8f", a.some_nested_thing.asd));
	assert(a.some_nested_thing.super_nested.blah == "super nested string", tprint(a.some_nested_thing.super_nested.blah));

	assert(len(a.some_nested_thing.some_array) == 4, tprint(len(a.some_nested_thing.some_array)));
	assert(a.some_nested_thing.some_array[0] == "123", tprint(a.some_nested_thing.some_array[0]));
	assert(a.some_nested_thing.some_array[1] == "qwe", tprint(a.some_nested_thing.some_array[1]));
	assert(a.some_nested_thing.some_array[2] == "asd", tprint(a.some_nested_thing.some_array[2]));
	assert(a.some_nested_thing.some_array[3] == "zxc", tprint(a.some_nested_thing.some_array[3]));

	assert(len(a.some_nested_thing.dyn_array) == 4, tprint(len(a.some_nested_thing.dyn_array)));
	assert(a.some_nested_thing.dyn_array[0] == true, tprint(a.some_nested_thing.dyn_array[0]));
	assert(a.some_nested_thing.dyn_array[1] == false, tprint(a.some_nested_thing.dyn_array[1]));
	assert(a.some_nested_thing.dyn_array[2] == false, tprint(a.some_nested_thing.dyn_array[2]));
	assert(a.some_nested_thing.dyn_array[3] == true, tprint(a.some_nested_thing.dyn_array[3]));

	assert(len(a.some_nested_thing.slice) == 2, tprint(len(a.some_nested_thing.slice)));
	assert(a.some_nested_thing.slice[0].x == 12, tprint(a.some_nested_thing.slice[0].x));
	assert(a.some_nested_thing.slice[0].y == 34, tprint(a.some_nested_thing.slice[0].y));
	assert(a.some_nested_thing.slice[1].x == 43, tprint(a.some_nested_thing.slice[1].x));
	assert(a.some_nested_thing.slice[1].y == 21, tprint(a.some_nested_thing.slice[1].y));

	a_text := serialize(&a);
	defer delete(a_text);
	println(a_text);
	b := deserialize(Nightmare, a_text);

	assert(a.some_int == b.some_int);
	assert(a.some_string == b.some_string);
	assert(a.some_float == b.some_float);
	assert(a.some_bool == b.some_bool);

	assert(a.some_nested_thing.asd == b.some_nested_thing.asd);
	assert(a.some_nested_thing.super_nested.blah == b.some_nested_thing.super_nested.blah);

	assert(len(a.some_nested_thing.some_array) == len(b.some_nested_thing.some_array));
	assert(len(a.some_nested_thing.some_array) == 4);
	assert(a.some_nested_thing.some_array[0] == b.some_nested_thing.some_array[0]);
	assert(a.some_nested_thing.some_array[1] == b.some_nested_thing.some_array[1]);
	assert(a.some_nested_thing.some_array[2] == b.some_nested_thing.some_array[2]);
	assert(a.some_nested_thing.some_array[3] == b.some_nested_thing.some_array[3]);

	assert(len(a.some_nested_thing.dyn_array) == len(b.some_nested_thing.dyn_array));
	assert(len(a.some_nested_thing.dyn_array) == 4);
	assert(a.some_nested_thing.dyn_array[0] == b.some_nested_thing.dyn_array[0]);
	assert(a.some_nested_thing.dyn_array[1] == b.some_nested_thing.dyn_array[1]);
	assert(a.some_nested_thing.dyn_array[2] == b.some_nested_thing.dyn_array[2]);
	assert(a.some_nested_thing.dyn_array[3] == b.some_nested_thing.dyn_array[3]);

	assert(len(a.some_nested_thing.slice) == len(b.some_nested_thing.slice));
	assert(len(a.some_nested_thing.slice) == 2);
	assert(a.some_nested_thing.slice[0].x == b.some_nested_thing.slice[0].x);
	assert(a.some_nested_thing.slice[0].y == b.some_nested_thing.slice[0].y);
	assert(a.some_nested_thing.slice[1].x == b.some_nested_thing.slice[1].x);
	assert(a.some_nested_thing.slice[1].y == b.some_nested_thing.slice[1].y);

	println("Tests done!");
}
