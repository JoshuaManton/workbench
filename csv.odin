package workbench

using import        "core:math"
using import        "core:fmt"
      import        "core:sort"
      import        "core:strings"
      import        "core:mem"
      import        "core:os"
      import        "core:sys/win32"

Csv_Row :: struct {
	values: [dynamic]string,
}

parse_csv_from_file :: proc($Record: typeid, filepath: string) -> [dynamic]Record {
	bytes, ok := os.read_entire_file(filepath);
	if !ok do return nil;

	defer delete(bytes);
	records := parse_csv(Record, cast(string)bytes[:]);
	return records;
}

parse_csv :: proc($Record: typeid, text: string) -> [dynamic]Record {
	// todo(josh): @Optimization probably
	text = trim_whitespace(text);

	lines: [dynamic]Csv_Row;

	cur_row: Csv_Row;
	value_so_far: [dynamic]byte;
	defer delete(value_so_far);

	text_idx := 0;
	for text_idx < len(text) {
		defer text_idx += 1;
		c := text[text_idx];
		value_str := cast(string)value_so_far[:];

		if c == '\\' {
			text_idx += 1;
			append(&value_so_far, text[text_idx]);
		}
		else if c == '"' {
			text_idx += 1;
			for text[text_idx] != '"' {
				append(&value_so_far, text[text_idx]);
				text_idx += 1;
			}
			text_idx += 1;

			value_str = cast(string)value_so_far[:];
			append(&cur_row.values, value_str);
			value_so_far = {}; // @Leak
			continue;
		}
		else if c == ',' {
			append(&cur_row.values, value_str);
			value_so_far = {}; // @Leak
			continue;
		}
		else if c == '\r' || c == '\n' {
			for text[text_idx] == '\r' || text[text_idx] == '\n' {
				text_idx += 1;
			}
			text_idx -= 1;
			append(&cur_row.values, value_str);
			append(&lines, cur_row);
			cur_row = {}; // @Leak
			value_so_far = {}; // @Leak
			continue;
		}

		append(&value_so_far, c);
	}

	value_str := cast(string)value_so_far[:];
	append(&cur_row.values, value_str);
	append(&lines, cur_row);
	cur_row = {}; // @Leak
	value_so_far = {}; // @Leak

	headers := lines[0];
	record_ti := type_info_of(Record);
	records: [dynamic]Record;
	for row in lines[1:] {
		record: Record;
		for field_name, column_idx in headers.values {
			str_value := row.values[column_idx];
			field_info, ok := get_struct_field_info(Record, field_name); assert(ok, aprintln("Type", type_info_of(Record), "doesn't have a field called", field_name));
			a: any;
			a.id = field_info.t.id;
			switch kind in a {
				case string:
					set_struct_field(&record, field_info, str_value);

				case int:
					value := parse_int(str_value);
					set_struct_field(&record, field_info, value);
				case i8:
					value := parse_i8(str_value);
					set_struct_field(&record, field_info, value);
				case i16:
					value := parse_i16(str_value);
					set_struct_field(&record, field_info, value);
				case i32:
					value := parse_i32(str_value);
					set_struct_field(&record, field_info, value);
				case i64:
					value := parse_i64(str_value);
					set_struct_field(&record, field_info, value);

				case uint:
					value := parse_uint(str_value);
					set_struct_field(&record, field_info, value);
				case u8:
					value := parse_u8(str_value);
					set_struct_field(&record, field_info, value);
				case u16:
					value := parse_u16(str_value);
					set_struct_field(&record, field_info, value);
				case u32:
					value := parse_u32(str_value);
					set_struct_field(&record, field_info, value);
				case u64:
					value := parse_u64(str_value);
					set_struct_field(&record, field_info, value);

				case f32:
					value := parse_f32(str_value);
					set_struct_field(&record, field_info, value);
				case f64:
					value := parse_f64(str_value);
					set_struct_field(&record, field_info, value);

				case bool:
					value := parse_bool(str_value);
					set_struct_field(&record, field_info, value);

				case:
					assert(false, aprintln("Unsupported record field member type:", field_info.t));
			}
		}

		append(&records, record);
	}

	return records;
}

// this is kind of a weird super-specific thing but we'll see
// maybe we will end up having this kind of thing for fonts
// and textures? :thinking:
csv_catalog_subscribe :: proc(item: ^Catalog_Item, $Record: typeid, list: ^[dynamic]$T) {
	catalog_subscribe(item, list, proc(_userdata: rawptr, text: string, first: bool) {
		list := cast(^[dynamic]T)_userdata;
		records := parse_csv(Record, text);
		if first {
			for record in records {
				defn: T;
				defn.wb__record = record;
				append(list, defn);
			}
		}
		else {
			for record in records {
				found := false;
				for _, i in list {
					defn := &list[i];
					if defn.name != record.name {
						continue;
					}
					found = true;
					defn.wb__record = record;
					break;
				}
				if !found {
					defn: T;
					defn.wb__record = record;
					append(list, defn);
				}
			}
		}
	});
}

when DEVELOPER {
	_test_csv :: proc() {
		WEAPONS_CSV_TEXT ::
`weapon_name,physical_damage,fire_damage,lightning_damage,strength_scaling,dexterity_scaling,fire_scaling,lightning_scaling,enchanted
"Longsword",100,,,10,10,,,false
Fire Sword,60,60,,7,7,7,,false
"Sword of Light, The",,,150,5,5,,5,true`;

		Weapon_Record :: struct {
			weapon_name: string,
			enchanted: bool,

			physical_damage:  int,
			fire_damage:      int,
			lightning_damage: int,

			strength_scaling:  f32,
			dexterity_scaling: f32,
			fire_scaling:      f32,
			lightning_scaling: f32,
		}

		weapons := parse_csv(Weapon_Record, WEAPONS_CSV_TEXT);

		assert(weapons[0].weapon_name == "Longsword");
		assert(weapons[0].physical_damage == 100);
		assert(weapons[0].enchanted == false);

		assert(weapons[1].weapon_name == "Fire Sword");
		assert(weapons[1].fire_damage == 60);
		assert(weapons[1].fire_scaling == 7);

		assert(weapons[2].weapon_name == "Sword of Light, The");
		assert(weapons[2].physical_damage == 0);
		assert(weapons[2].enchanted == true);
	}
}
