package workbench

using import        "core:math"
using import        "core:fmt"
      import        "core:sort"
      import        "core:strings"
      import        "core:mem"
      import        "core:os"

using import        "basic"
using import        "logging"
using import        "reflection"

// todo(josh): rewrite this probably
// todo(josh): rewrite this probably
// todo(josh): rewrite this probably

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

parse_csv :: proc($Record: typeid, _text: string) -> [dynamic]Record {
	// todo(josh): @Optimization probably
	text := _text;
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
		for header_name, column_idx in headers.values {
			str_value := row.values[column_idx];

			selectors := strings.split(header_name, ".");
			defer delete(selectors);

			offset: int;
			ti := type_info_of(Record);
			field_info: Field_Info;
			fiok: bool;
			for selector in selectors {
				field_info, fiok = get_struct_field_info(ti, selector);
				assert(fiok, tprint("Type ", ti, " doesn't have a field called ", selector));
				ti = field_info.ti;
				offset += field_info.offset;
			}

			ptr_to_field := mem.ptr_offset(cast(^byte)&record, offset);
			set_ptr_value_from_string(ptr_to_field, field_info.ti, str_value);
		}

		append(&records, record);
	}

	return records;
}

// this is kind of a weird super-specific thing but we'll see
// maybe we will end up having this kind of thing for fonts
// and textures? :thinking:
// todo(josh): csv_catalog_UNsubscribe ????
csv_catalog_subscribe :: proc(item: ^Catalog_Item, $Record: typeid, list: ^[dynamic]$T, callback: proc() = nil) {
	List_And_Callback :: struct {
		list: ^[dynamic]T,
		callback: proc(),
	};

	catalog_subscribe(item, /* @Alloc */ new_clone(List_And_Callback{list, callback}), proc(using list_callback: ^List_And_Callback, text: string) {
		records := parse_csv(Record, text);
		if len(list) == 0 {
			for record in records {
				t: T;
				t.wb__record = record;
				append(list, t);
			}
		}
		else {
			for record in records {
				found := false;
				for _, i in list {
					defn := &list[i];
					if defn.id != record.id {
						continue;
					}
					found = true;
					defn.wb__record = record;
					break;
				}
				if !found {
					t: T;
					t.wb__record = record;
					append(list, t);
				}
			}
		}

		if callback != nil {
			callback();
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
		};

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
