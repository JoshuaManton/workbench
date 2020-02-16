package wbml

import rt "core:runtime"
import "core:mem"
import la "core:math/linalg"
import "core:reflect"

import "../reflection"

import "core:strings"
import "core:fmt"
import "../laas"

// todo(josh): maybe use # directives for quats, unions, and typeids: `foo #quat 1 2 3 4`, `foo #typeid Bar`, `foo #union Bar { bar_field 123 }` :HashDirectives
// todo(josh): handle #no_nil unions :NoNilUnions
// todo(josh): write_value currently does a partial switch. should handle all cases even if its just `unimplemented();` :HandleAllWriteValues

// note(josh): used for mapping typeids to Type_Infos when deserializing
_type_info_table: map[string]^rt.Type_Info;

@(deferred_out=_set_type_info_table)
PUSH_TYPE_INFO_TABLE :: proc(table: map[string]^rt.Type_Info) -> map[string]^rt.Type_Info {
	old := _type_info_table;
	_type_info_table = table;
	return old;
}

_set_type_info_table :: proc(old_table: map[string]^rt.Type_Info) {
	_type_info_table = old_table;
}

serialize :: proc(value: ^$Type) -> string {
	return serialize_ti(value, type_info_of(Type));
}

serialize_ti :: proc(ptr: rawptr, ti: ^rt.Type_Info) -> string {
	sb: strings.Builder;
	serialize_string_builder_ti(ptr, ti, &sb);
	return strings.to_string(sb);
}

serialize_string_builder :: proc(value: ^$Type, sb: ^strings.Builder) {
	ti := type_info_of(Type);
	serialize_with_type_info("", value, ti, sb, 0);
}

serialize_string_builder_ti :: proc(value: rawptr, ti: ^rt.Type_Info, sb: ^strings.Builder) {
	serialize_with_type_info("", value, ti, sb, 0);
}

serialize_with_type_info :: proc(name: string, value: rawptr, ti: ^rt.Type_Info, sb: ^strings.Builder, indent_level: int, loc := #caller_location) {
	assert(ti != nil);
	indent_level := indent_level;

	print_indents :: inline proc(indent_level: int, sb: ^strings.Builder) {
		for i in 0..indent_level-1 {
			sbprint(sb, "\t");
		}
	}

	print_to_buf :: inline proc(sb: ^strings.Builder, args: ..any) {
		sbprint(sb, ..args);
	}

	if name != "" {
		print_to_buf(sb, name, " ");
	}

	do_newline := true;

	// todo(josh): remove this partial and handle all cases!
	#partial
	switch kind in ti.variant {
		case rt.Type_Info_Integer: {
			if kind.signed {
				switch kind.endianness {
					case .Platform: {
						switch ti.size {
							case 1: print_to_buf(sb, (cast(^i8 )value)^);
							case 2: print_to_buf(sb, (cast(^i16)value)^);
							case 4: print_to_buf(sb, (cast(^i32)value)^);
							case 8: print_to_buf(sb, (cast(^i64)value)^);
							case: panic(tprint(ti.size));
						}
					}
					case .Little: {
						switch ti.size {
							case 2: print_to_buf(sb, (cast(^i16le)value)^);
							case 4: print_to_buf(sb, (cast(^i32le)value)^);
							case 8: print_to_buf(sb, (cast(^i64le)value)^);
							case: panic(tprint(ti.size));
						}
					}
					case .Big: {
						switch ti.size {
							case 2: print_to_buf(sb, (cast(^i16be)value)^);
							case 4: print_to_buf(sb, (cast(^i32be)value)^);
							case 8: print_to_buf(sb, (cast(^i64be)value)^);
							case: panic(tprint(ti.size));
						}
					}
				}
			}
			else {
				switch kind.endianness {
					case .Platform: {
						switch ti.size {
							case 1: print_to_buf(sb, (cast(^u8 )value)^);
							case 2: print_to_buf(sb, (cast(^u16)value)^);
							case 4: print_to_buf(sb, (cast(^u32)value)^);
							case 8: print_to_buf(sb, (cast(^u64)value)^);
							case: panic(tprint(ti.size));
						}
					}
					case .Little: {
						switch ti.size {
							case 2: print_to_buf(sb, (cast(^u16le)value)^);
							case 4: print_to_buf(sb, (cast(^u32le)value)^);
							case 8: print_to_buf(sb, (cast(^u64le)value)^);
							case: panic(tprint(ti.size));
						}
					}
					case .Big: {
						switch ti.size {
							case 2: print_to_buf(sb, (cast(^u16be)value)^);
							case 4: print_to_buf(sb, (cast(^u32be)value)^);
							case 8: print_to_buf(sb, (cast(^u64be)value)^);
							case: panic(tprint(ti.size));
						}
					}
				}
			}
		}

		case rt.Type_Info_Float: {
			switch ti.size {
				case 4: print_to_buf(sb, (cast(^f32)value)^);
				case 8: print_to_buf(sb, (cast(^f64)value)^);
				case: panic(tprint(ti.size));
			}
		}

		case rt.Type_Info_Enum: {
			do_newline = false;

			get_str :: proc(i: $T, e: rt.Type_Info_Enum) -> (string, bool) {
				if reflect.is_string(e.base) {
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
			case rune:    str, ok := get_str(v, kind); assert(ok); print_to_buf(sb, str);
			case i8:      str, ok := get_str(v, kind); assert(ok); print_to_buf(sb, str);
			case i16:     str, ok := get_str(v, kind); assert(ok); print_to_buf(sb, str);
			case i32:     str, ok := get_str(v, kind); assert(ok); print_to_buf(sb, str);
			case i64:     str, ok := get_str(v, kind); assert(ok); print_to_buf(sb, str);
			case int:     str, ok := get_str(v, kind); assert(ok); print_to_buf(sb, str);
			case u8:      str, ok := get_str(v, kind); assert(ok); print_to_buf(sb, str);
			case u16:     str, ok := get_str(v, kind); assert(ok); print_to_buf(sb, str);
			case u32:     str, ok := get_str(v, kind); assert(ok); print_to_buf(sb, str);
			case u64:     str, ok := get_str(v, kind); assert(ok); print_to_buf(sb, str);
			case uint:    str, ok := get_str(v, kind); assert(ok); print_to_buf(sb, str);
			case uintptr: str, ok := get_str(v, kind); assert(ok); print_to_buf(sb, str);
			}
		}

		case rt.Type_Info_Boolean: {
			print_to_buf(sb, (cast(^bool)value)^);
		}

		case rt.Type_Info_String: {
			print_to_buf(sb, "\"", (cast(^string)value)^, "\"");
		}

		case rt.Type_Info_Named: {
			if _, ok := kind.base.variant.(rt.Type_Info_Struct); ok {
				// the struct will handle the new line
				do_newline = false;
			}
			serialize_with_type_info("", value, kind.base, sb, indent_level);
		}

		case rt.Type_Info_Struct: {
			print_to_buf(sb, "{\n"); indent_level += 1;
			for name, idx in kind.names {
				tag := kind.tags[idx];
				if strings.contains(tag, "wbml_noserialize") do continue;

				print_indents(indent_level, sb);
				serialize_with_type_info(name, mem.ptr_offset(cast(^byte)value, cast(int)kind.offsets[idx]), kind.types[idx], sb, indent_level);
			}
			indent_level -= 1; print_indents(indent_level, sb); print_to_buf(sb, "}");
		}

		case rt.Type_Info_Type_Id: {
			// :HashDirectives
			ti := type_info_of((cast(^typeid)value)^);
			if ti.id != nil {
				print_to_buf(sb, "\"", ti, "\"");
			}
			else {
				print_to_buf(sb, "nil");
			}
		}

		case rt.Type_Info_Union: {
			// :HashDirectives
			assert(kind.no_nil == false); // :NoNilUnions
			do_newline = false; // recursing into serialize_with_type_info would cause two newlines to be written
			union_ti := reflection.get_union_type_info(any{value, ti.id});
			if union_ti == nil {
				print_to_buf(sb, "nil\n");
			}
			else {
				print_to_buf(sb, ".", tprint(union_ti), " ");
				serialize_with_type_info("", value, union_ti, sb, indent_level);
			}
		}

		case rt.Type_Info_Array: {
			print_to_buf(sb, "[\n"); indent_level += 1;
			{
				for i in 0..kind.count-1 {
					data := mem.ptr_offset(cast(^byte)value, i * kind.elem_size);
					print_indents(indent_level, sb);
					serialize_with_type_info("", data, kind.elem, sb, indent_level);
				}
			}
			indent_level -= 1; print_indents(indent_level, sb); print_to_buf(sb, "]");
		}

		case rt.Type_Info_Dynamic_Array: {
			dyn := transmute(^mem.Raw_Dynamic_Array)value;
			print_to_buf(sb, "[\n"); indent_level += 1;
			{
				for i in 0..dyn.len-1 {
					data := mem.ptr_offset(cast(^byte)dyn.data, i * kind.elem_size);
					print_indents(indent_level, sb);
					serialize_with_type_info("", data, kind.elem, sb, indent_level);
				}
			}
			indent_level -= 1; print_indents(indent_level, sb); print_to_buf(sb, "]");
		}

		case rt.Type_Info_Slice: {
			slice := transmute(^mem.Raw_Slice)value;
			print_to_buf(sb, "[\n"); indent_level += 1;
			{
				for i in 0..slice.len-1 {
					data := mem.ptr_offset(cast(^byte)slice.data, i * kind.elem_size);
					print_indents(indent_level, sb);
					serialize_with_type_info("", data, kind.elem, sb, indent_level);
				}
			}
			indent_level -= 1; print_indents(indent_level, sb); print_to_buf(sb, "]");
		}

		case rt.Type_Info_Map: {
			// todo(josh): support map
			unimplemented();
		}

		case rt.Type_Info_Quaternion: {
			// :HashDirectives
			q := cast(^la.Quaternion)value;
			print_to_buf(sb, "quat ", q.w, q.x, q.y, q.z);
		}

		case: panic(tprint(name, kind));
	}

	if do_newline {
		print_to_buf(sb, "\n");
	}
}



deserialize :: proc{
	deserialize_to_value,
	deserialize_into_pointer,
	deserialize_into_pointer_with_type_info,
};

deserialize_to_value :: inline proc($Type: typeid, data: []u8) -> Type {
	t: Type;
	deserialize_into_pointer(data, &t);
	return t;
}

deserialize_into_pointer :: proc(data: []u8, ptr: ^$Type) {
	ti := type_info_of(Type);

	_lexer := laas.make_lexer(cast(string)data);
	lexer := &_lexer;

	root := parse_value(lexer);
	defer delete_node(root);
	write_value(root, ptr, ti);
}

deserialize_into_pointer_with_type_info :: proc(data: []u8, ptr: rawptr, ti: ^rt.Type_Info) {
	_lexer := laas.make_lexer(cast(string)data);
	lexer := &_lexer;

	root := parse_value(lexer);
	defer delete_node(root);
	write_value(root, ptr, ti);
}

parse_value :: proc(lexer: ^laas.Lexer, is_negative_number := false) -> ^Node {
	eat_newlines(lexer);
	root_token: laas.Token;
	ok := laas.get_next_token(lexer, &root_token);
	if !ok do return nil;

	if symbol, ok := root_token.kind.(laas.Symbol); ok {
		if symbol.value == '-' {
			return parse_value(lexer, !is_negative_number);
		}
	}

	// todo(josh): remove this #partial and handle all cases!
	#partial
	switch value_kind in root_token.kind {
		case laas.Symbol: {
			switch value_kind.value {
				case '{': {
					fields: [dynamic]Object_Field;
					for {
						eat_newlines(lexer);

						// check for end
						{
							next_token: laas.Token;
							ok := laas.peek(lexer, &next_token);
							assert(ok, "end of text from within object");
							if right_curly, ok2 := next_token.kind.(laas.Symbol); ok2 && right_curly.value == '}' {
								laas.eat(lexer);
								break;
							}
						}

						var_name_token: laas.Token;
						ok := laas.get_next_token(lexer, &var_name_token);
						assert(ok, "end of text from within object");

						variable_name, ok2 := var_name_token.kind.(laas.Identifier);
						assert(ok2, tprint(var_name_token));

						value := parse_value(lexer);
						append(&fields, Object_Field{variable_name.value, value});
					}
					return new_clone(Node{Node_Object{fields[:]}});
				}

				case '[': {
					elements: [dynamic]^Node;
					for {
						eat_newlines(lexer);

						// check for end
						{
							next_token: laas.Token;
							ok := laas.peek(lexer, &next_token);
							assert(ok, "end of text from within array");
							if right_square, ok2 := next_token.kind.(laas.Symbol); ok2 && right_square.value == ']' {
								laas.eat(lexer);
								break;
							}
						}

						element := parse_value(lexer);
						append(&elements, element);
					}
					return new_clone(Node{Node_Array{elements[:]}});
				}

				case '.': { // :HashDirectives
					type_token: laas.Token;
					ok := laas.get_next_token(lexer, &type_token);
					assert(ok);
					ident, ok2 := type_token.kind.(laas.Identifier);
					assert(ok2, "Only single identifier types are currently supported for tagged unions");

					value := parse_value(lexer);
					return new_clone(Node{Node_Union{ident.value, value}});
				}

				case: {
					panic(tprint("Unhandled case: ", value_kind.value));
				}
			}
		}

		// primitives
		case laas.String: {
			return new_clone(Node{Node_String{value_kind.value}});
		}

		case laas.Identifier: {
			switch value_kind.value {
				case "true", "True", "TRUE":    return new_clone(Node{Node_Bool{true}});
				case "false", "False", "FALSE": return new_clone(Node{Node_Bool{false}});
				case "nil":                     return new_clone(Node{Node_Nil{}});
				case "quat": { // :HashDirectives
					w := parse_value(lexer); _, wok := w.kind.(Node_Number); assert(wok);
					x := parse_value(lexer); _, xok := x.kind.(Node_Number); assert(xok);
					y := parse_value(lexer); _, yok := y.kind.(Node_Number); assert(yok);
					z := parse_value(lexer); _, zok := z.kind.(Node_Number); assert(zok);
					return new_clone(Node{Node_Quat{w, x, y, z}});
				}
				case: return new_clone(Node{Node_Enum_Value{value_kind.value}});
			}
		}

		case laas.Number: {
			sign : i64 = is_negative_number ? -1 : 1;
			return new_clone(Node{Node_Number{value_kind.int_value * sign, value_kind.unsigned_int_value, value_kind.float_value * cast(f64)sign}});
		}

		case: {
			panic(tprint(value_kind));
		}
	}
	unreachable();
	return nil;
}

write_value :: proc{write_value_poly, write_value_ti};

write_value_poly :: proc(node: ^Node, ptr: ^$Type) {
	ti := type_info_of(Type);
	write_value(node, ptr, ti);
}

write_value_ti :: proc(node: ^Node, ptr: rawptr, ti: ^rt.Type_Info) {
	// :HandleAllWriteValues
	#partial
	switch variant in ti.variant {
		case rt.Type_Info_Named: {
			write_value(node, ptr, variant.base);
		}

		case rt.Type_Info_Struct: {
			object := &node.kind.(Node_Object);
			for field in object.fields {
				for name, idx in variant.names {
					if name == field.name {
						tag := variant.tags[idx];
						if !strings.contains(tag, "wbml_noserialize") {
							field_ptr := mem.ptr_offset(cast(^byte)ptr, cast(int)variant.offsets[idx]);
							field_ti  := variant.types[idx];
							write_value(field.value, field_ptr, field_ti);
						}
					}
				}
			}
		}

		case rt.Type_Info_Array: {
			array := &node.kind.(Node_Array);
			assert(len(array.elements) == variant.count);
			for element, idx in array.elements {
				element_ptr := mem.ptr_offset(cast(^byte)ptr, variant.elem_size * idx);
				write_value(element, element_ptr, variant.elem);
			}
		}

		case rt.Type_Info_Dynamic_Array: {
			array := &node.kind.(Node_Array);
			size_needed := len(array.elements) * variant.elem_size;
			if size_needed > 0 {
				memory := make([]byte, size_needed);
				byte_index: int;
				for element, idx in array.elements {
					assert(byte_index + variant.elem_size <= len(memory));
					write_value(element, &memory[byte_index], variant.elem);
					byte_index += variant.elem_size;
				}

				(cast(^mem.Raw_Dynamic_Array)ptr)^ = mem.Raw_Dynamic_Array{&memory[0], len(array.elements), len(array.elements), {}};
			}
		}

		case rt.Type_Info_Slice: {
			array := &node.kind.(Node_Array);
			size_needed := len(array.elements) * variant.elem_size;
			if size_needed > 0 {
				memory := make([]byte, size_needed);
				byte_index: int;
				for element, idx in array.elements {
					assert(byte_index + variant.elem_size <= len(memory));
					write_value(element, &memory[byte_index], variant.elem);
					byte_index += variant.elem_size;
				}

				(cast(^mem.Raw_Slice)ptr)^ = mem.Raw_Slice{&memory[0], len(array.elements)};
			}
		}

		case rt.Type_Info_Integer: {
			number := &node.kind.(Node_Number);
			if variant.signed {
				switch variant.endianness {
					case .Platform: {
						switch ti.size {
							case 1: (cast(^i8 )ptr)^ = cast(i8) number.int_value;
							case 2: (cast(^i16)ptr)^ = cast(i16)number.int_value;
							case 4: (cast(^i32)ptr)^ = cast(i32)number.int_value;
							case 8: (cast(^i64)ptr)^ =          number.int_value;
							case: panic(tprint(ti.size));
						}
					}
					case .Little: {
						switch ti.size {
							case 2: (cast(^i16le)ptr)^ = cast(i16le)number.int_value;
							case 4: (cast(^i32le)ptr)^ = cast(i32le)number.int_value;
							case 8: (cast(^i64le)ptr)^ = cast(i64le)number.int_value;
							case: panic(tprint(ti.size));
						}
					}
					case .Big: {
						switch ti.size {
							case 2: (cast(^i16be)ptr)^ = cast(i16be)number.int_value;
							case 4: (cast(^i32be)ptr)^ = cast(i32be)number.int_value;
							case 8: (cast(^i64be)ptr)^ = cast(i64be)number.int_value;
							case: panic(tprint(ti.size));
						}
					}
				}
			}
			else {
				switch variant.endianness {
					case .Platform: {
						switch ti.size {
							case 1: (cast(^u8 )ptr)^ = cast(u8) number.uint_value;
							case 2: (cast(^u16)ptr)^ = cast(u16)number.uint_value;
							case 4: (cast(^u32)ptr)^ = cast(u32)number.uint_value;
							case 8: (cast(^u64)ptr)^ =          number.uint_value;
							case: panic(tprint(ti.size));
						}
					}
					case .Little: {
						switch ti.size {
							case 2: (cast(^u16le)ptr)^ = cast(u16le)number.uint_value;
							case 4: (cast(^u32le)ptr)^ = cast(u32le)number.uint_value;
							case 8: (cast(^u64le)ptr)^ = cast(u64le)number.uint_value;
							case: panic(tprint(ti.size));
						}
					}
					case .Big: {
						switch ti.size {
							case 2: (cast(^u16be)ptr)^ = cast(u16be)number.uint_value;
							case 4: (cast(^u32be)ptr)^ = cast(u32be)number.uint_value;
							case 8: (cast(^u64be)ptr)^ = cast(u64be)number.uint_value;
							case: panic(tprint(ti.size));
						}
					}
				}
			}
		}

		case rt.Type_Info_Float: {
			number := &node.kind.(Node_Number);
			switch ti.size {
				case 4: (cast(^f32)ptr)^ = cast(f32)number.float_value;
				case 8: (cast(^f64)ptr)^ =          number.float_value;
				case: panic(tprint(ti.size));
			}
		}

		case rt.Type_Info_String: {
			str := &node.kind.(Node_String);
			if variant.is_cstring {
				(cast(^cstring)ptr)^ = strings.clone_to_cstring(str.value);
			}
			else {
				(cast(^string)ptr)^ = strings.clone(str.value);
			}
		}

		case rt.Type_Info_Boolean: {
			b := &node.kind.(Node_Bool);
			switch ti.size {
				case 1: (cast(^bool)ptr)^ =          b.value;
				case 2: (cast(^b16)ptr)^  = cast(b16)b.value;
				case 4: (cast(^b32)ptr)^  = cast(b32)b.value;
				case 8: (cast(^b64)ptr)^  = cast(b64)b.value;
				case: panic(tprint(ti.size));
			}
		}

		case rt.Type_Info_Type_Id: {
			#partial
			switch node_kind in node.kind {
				case Node_Nil: {
					// note(josh): Do nothing!
				}
				case Node_String: {
					// :HashDirectives
					ti, ok := _type_info_table[node_kind.value];
					assert(ok, fmt.tprint(node_kind.value));
					(cast(^typeid)ptr)^ = ti.id;
				}
				case: panic(tprint(node_kind));
			}
		}

		case rt.Type_Info_Union: {
			#partial
			switch node_kind in node.kind {
				case Node_Nil: {
					// note(josh): Do nothing!
				}
				case Node_Union: {
					for v in variant.variants {
						name := tprint(v);
						if node_kind.variant_name == name {
							reflection.set_union_type_info(any{ptr, ti.id}, v);
							write_value(node_kind.value, ptr, v);
							break;
						}
					}
				}
				case: panic(tprint(node_kind));
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

			e := &node.kind.(Node_Enum_Value);
			a := any{ptr, rt.type_info_base(variant.base).id};
			switch v in a {
			case rune:    val, ok := get_val_for_name(e.value, rune,    variant); assert(ok); (cast(^rune)   ptr)^ = val;
			case i8:      val, ok := get_val_for_name(e.value, i8,      variant); assert(ok); (cast(^i8)     ptr)^ = val;
			case i16:     val, ok := get_val_for_name(e.value, i16,     variant); assert(ok); (cast(^i16)    ptr)^ = val;
			case i32:     val, ok := get_val_for_name(e.value, i32,     variant); assert(ok); (cast(^i32)    ptr)^ = val;
			case i64:     val, ok := get_val_for_name(e.value, i64,     variant); assert(ok); (cast(^i64)    ptr)^ = val;
			case int:     val, ok := get_val_for_name(e.value, int,     variant); assert(ok); (cast(^int)    ptr)^ = val;
			case u8:      val, ok := get_val_for_name(e.value, u8,      variant); assert(ok); (cast(^u8)     ptr)^ = val;
			case u16:     val, ok := get_val_for_name(e.value, u16,     variant); assert(ok); (cast(^u16)    ptr)^ = val;
			case u32:     val, ok := get_val_for_name(e.value, u32,     variant); assert(ok); (cast(^u32)    ptr)^ = val;
			case u64:     val, ok := get_val_for_name(e.value, u64,     variant); assert(ok); (cast(^u64)    ptr)^ = val;
			case uint:    val, ok := get_val_for_name(e.value, uint,    variant); assert(ok); (cast(^uint)   ptr)^ = val;
			case uintptr: val, ok := get_val_for_name(e.value, uintptr, variant); assert(ok); (cast(^uintptr)ptr)^ = val;
			}
		}

		case rt.Type_Info_Quaternion: {
			assert(ti.size == 16);
			qnode := node.kind.(Node_Quat);
			q := cast(^la.Quaternion)ptr;
			q.w = cast(f32)qnode.w.kind.(Node_Number).float_value;
			q.x = cast(f32)qnode.x.kind.(Node_Number).float_value;
			q.y = cast(f32)qnode.y.kind.(Node_Number).float_value;
			q.z = cast(f32)qnode.z.kind.(Node_Number).float_value;
		}

		case: panic(tprint(variant));
	}
}

delete_node :: proc(node: ^Node) {
	switch kind in node.kind {
		case Node_Number:     // do nothing
		case Node_Bool:       // do nothing
		case Node_Nil:        // do nothing
		case Node_String:     // do nothing, strings are slices from source text
		case Node_Enum_Value: // do nothing, strings are slices from source text

		case Node_Object: {
			for f in kind.fields {
				delete_node(f.value);
			}
			delete(kind.fields);
		}
		case Node_Array: {
			for e in kind.elements {
				delete_node(e);
			}
			delete(kind.elements);
		}
		case Node_Union: {
			delete_node(kind.value);
		}
		case Node_Quat: {
			delete_node(kind.w);
			delete_node(kind.x);
			delete_node(kind.y);
			delete_node(kind.z);
		}
		case: {
			panic(tprint(kind));
		}
	}
	free(node);
}

eat_newlines :: proc(lexer: ^laas.Lexer, loc := #caller_location) {
	token: laas.Token;
	for {
		ok := laas.peek(lexer, &token);
		if !ok do return;

		if _, is_newline := token.kind.(laas.New_Line); is_newline {
			laas.eat(lexer);
		}
		else {
			return;
		}
	}
}

Node :: struct {
	kind: union {
		Node_Number,
		Node_Bool,
		Node_String,
		Node_Nil,
		Node_Enum_Value,
		Node_Object,
		Node_Array,
		Node_Union,
		Node_Quat,
	},
}

Node_Number :: struct {
	int_value: i64,
	uint_value: u64,
	float_value: f64,
}

Node_String :: struct {
	value: string, // note(josh): slice of source text
}

Node_Bool :: struct {
	value: bool,
}

Node_Enum_Value :: struct {
	value: string, // note(josh): slice of source text
}

Node_Nil :: struct {
}

Node_Object :: struct {
	fields: []Object_Field,
}
Object_Field :: struct {
	name: string, // note(josh): slice of source text
	value: ^Node,
}

Node_Array :: struct {
	elements: []^Node,
}

Node_Union :: struct {
	variant_name: string, // note(josh): slice of source text
	value: ^Node,
}

Node_Quat :: struct {
	w, x, y, z: ^Node,
}



tprint :: fmt.tprint;
sbprint :: fmt.sbprint;