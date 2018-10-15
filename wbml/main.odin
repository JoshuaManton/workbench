package wbml

import "core:runtime"
import "core:mem"

using import "core:fmt"
using import "../lexer"

import wb "shared:workbench"

deserialize :: proc($Type: typeid, text: string) -> Type {
	_lexer := lexer.Lexer{text, {}};
	lexer := &_lexer;

	Type_Wrapper :: struct {
		t: Type,
	}

	w: Type_Wrapper;
	fi, ok := wb.get_struct_field_info(type_info_of(Type_Wrapper), "t");
	assert(ok);

	data : rawptr = &w.t;

	for {
		token, ok := get_next_token(lexer);
		if !ok do break;

		done := recurse(token, lexer, data, fi);
		if done do break;
	}

	return w.t;
}

recurse :: proc(token: Token, lexer: ^Lexer, data: rawptr, fi: wb.Field_Info) -> (done: bool) {
	switch kind in token.kind {
		case Token_Identifier: {
			field_fi, ok := wb.get_struct_field_info(fi.ti, kind.value);
			assert(ok, tprint(field_fi, kind.value));

			field_ptr := mem.ptr_offset(cast(^byte)data, field_fi.offset);

			value_token, ok3 := get_next_token(lexer);
			assert(ok3);
			parse_and_set_value(value_token, lexer, field_ptr, field_fi);
		}

		case: {
			panic(tprint(kind));
		}
	}

	return false;
}

parse_and_set_value :: proc(value_token: Token, lexer: ^Lexer, data: rawptr, fi: wb.Field_Info) {
	switch value_kind in value_token.kind {
		case Token_Identifier: {
			switch value_kind.value {
				case "true", "True", "TRUE":    (cast(^bool)data)^ = true;
				case "false", "False", "FALSE": (cast(^bool)data)^ = false;
				case: {
					assert(false, value_kind.value);
				}
			}
		}

		case Token_Number: {
			switch num_kind in fi.ti.variant {
				case runtime.Type_Info_Integer: {
					if num_kind.signed {
						switch fi.ti.size {
							case 1: (cast(^i8)data)^  = cast(i8) value_kind.int_value;
							case 2: (cast(^i16)data)^ = cast(i16)value_kind.int_value;
							case 4: (cast(^i32)data)^ = cast(i32)value_kind.int_value;
							case 8: (cast(^i64)data)^ =          value_kind.int_value;
							case: panic(tprint(fi.ti.size));
						}
					}
					else {
						switch fi.ti.size {
							case 1: (cast(^u8)data)^  = cast(u8) value_kind.unsigned_int_value;
							case 2: (cast(^u16)data)^ = cast(u16)value_kind.unsigned_int_value;
							case 4: (cast(^u32)data)^ = cast(u32)value_kind.unsigned_int_value;
							case 8: (cast(^u64)data)^ =          value_kind.unsigned_int_value;
							case: panic(tprint(fi.ti.size));
						}
					}
				}
				case runtime.Type_Info_Float: {
					switch fi.ti.size {
						case 4: (cast(^f32)data)^ = cast(f32)value_kind.float_value;
						case 8: (cast(^f64)data)^ =          value_kind.float_value;
						case: panic(tprint(fi.ti.size));
					}
				}
				// case runtime.Type_Info_String: {
				// 	(cast(^string)data)^ = value_kind.string_value;
				// }
				case: {
					assert(false, tprint(num_kind));
				}
			}
		}

		case Token_String: {
			(cast(^string)data)^ = value_kind.value;
		}

		case Token_Symbol: {
			switch value_kind.value {
				case '{': {
					for {
						new_token, ok4 := get_next_token(lexer);
						if !ok4 do assert(false, "End of text from within struct");

						if symbol, is_symbol := new_token.kind.(Token_Symbol); is_symbol {
							if symbol.value == '}' do break;
							assert(false, tprint("Symbol token in struct: ", symbol));
						}

						done := recurse(new_token, lexer, data, fi);
						if done do break;
					}
				}
				case '[': {
					switch array_kind in fi.ti.variant {
						case runtime.Type_Info_Array: {
							i: int;
							for {
								defer i += 1;
								if i > array_kind.count {
									assert(false, "Too many array elements");
								}

								array_value_token, ok := get_next_token(lexer);
								if !ok do assert(false, "End of text from within array");

								if symbol, is_symbol := array_value_token.kind.(Token_Symbol); is_symbol {
									if symbol.value == ']' do break;
									if symbol.value != '{' {
										assert(false, tprint("Symbol token in array: ", symbol));
									}
								}

								parse_and_set_value(array_value_token, lexer, mem.ptr_offset(cast(^byte)data, array_kind.elem_size * i), wb.Field_Info{"array_index", array_kind.elem, 0});
							}
						}
						case runtime.Type_Info_Dynamic_Array: {
							memory := make([]byte, 1024);
							byte_index := 0;

							i: int;
							for {
								defer i += 1;

								array_value_token, ok := get_next_token(lexer);
								if !ok do assert(false, "End of text from within array");

								if symbol, is_symbol := array_value_token.kind.(Token_Symbol); is_symbol {
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

								parse_and_set_value(array_value_token, lexer, &memory[byte_index], wb.Field_Info{"array_index", array_kind.elem, 0});
								byte_index += array_kind.elem_size;
							}

							(cast(^mem.Raw_Dynamic_Array)data)^ = mem.Raw_Dynamic_Array{&memory[0], i-1, len(memory), {}};
						}
						case runtime.Type_Info_Slice: {
							memory := make([]byte, 1024);
							byte_index := 0;

							i: int;
							for {
								defer i += 1;

								array_value_token, ok := get_next_token(lexer);
								if !ok do assert(false, "End of text from within array");

								if symbol, is_symbol := array_value_token.kind.(Token_Symbol); is_symbol {
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

								parse_and_set_value(array_value_token, lexer, &memory[byte_index], wb.Field_Info{"array_index", array_kind.elem, 0});
								byte_index += array_kind.elem_size;
							}

							(cast(^mem.Raw_Slice)data)^ = mem.Raw_Slice{&memory[0], i-1};
						}
						case: panic(tprint(array_kind));
					}
				}
			}
		}
	}
}

main :: proc() {
	Foo :: struct {
		some_int: int,
		some_string: string,
		some_float: f64,
		some_bool: bool,
		some_nested_thing: struct {
			asd: f32,
			some_array: [4]string,
			dyn_array: [dynamic]bool,
			slice: []struct {
				x, y: f64,
			},
			qwe: string,
			super_nested: struct {
				blah: bool,
			},
		}
	}

	foo := deserialize(Foo,
`
some_int 123
some_string "henlo lizer"
some_float 123.4
some_bool true
some_nested_thing {
	asd 321.3
	qwe "wow"
	super_nested {
		blah true
	}
	some_array [
		"asd"
		"fff"
		"ffwww"
		"as"
	]
	dyn_array [
		true
		false
		false
		true
	]
	slice [
		{
			x 12
			y 21
		}
		{
			x 42
			y 23
		}
	]
}
`);
}