package workbench

import "core:os"

Catalog_Item :: struct {
	path: string,
	last_write_time: os.File_Time,

	userdata: rawptr, // note(josh): is freed on unsubscribe
	callback: proc(rawptr, []u8),
}

all_items: [dynamic]Catalog_Item;

catalog_subscribe :: inline proc(filepath: string, userdata: ^$T, callback: proc(^T, []u8)) {
	assert(callback != nil);

	data, ok := os.read_entire_file(filepath);
	assert(ok);

	time := os.last_write_time_by_name(filepath);
	item := Catalog_Item{filepath, time, userdata, cast(proc(rawptr, []u8))callback};

	append(&all_items, item);
	callback(userdata, data);
}

catalog_unsubscribe :: inline proc(item: Catalog_Item, callback: proc(^$T, string)) {
	for sub, i in item.subscribers {
		if sub.callback == callback {
			free(sub.userdata);
			remove_at(&item.subscribers, i);
			return;
		}
	}
}

when DEVELOPER {

_update_catalog :: proc() {
	for _, i in all_items {
		item := all_items[i];
		new_write_time := os.last_write_time_by_name(item.path);

		if new_write_time > item.last_write_time {
			data, ok := os.read_entire_file(item.path);
			assert(ok);

			item.last_write_time = new_write_time;
			item.callback(item.userdata, data);

			logln("new contents for ", item.path);
		}
	}
}

} // end `when DEVELOPER`
