package workbench

import "core:os"

Subscriber :: struct {
	userdata: rawptr,
	callback: proc(rawptr, []u8),
}

Catalog_Item :: struct {
	path: string,
	data: []u8,
	last_write_time: os.File_Time,

	subscribers: [dynamic]Subscriber,
}

all_items: [dynamic]^Catalog_Item;

// todo(josh): Handle system for Catalog_Items
catalog_add :: proc(path: string) -> ^Catalog_Item {
	time     := os.last_write_time_by_name(path);
	data, ok := os.read_entire_file(path);
	if !ok do return nil;

	item := new_clone(Catalog_Item{path, data, time, nil}); // @Alloc
	append(&all_items, item);
	return item;
}

catalog_subscribe :: inline proc(item: ^Catalog_Item, userdata: $T, callback: proc(T, []u8)) {
	append(&item.subscribers, Subscriber{userdata, cast(proc(rawptr, string))callback});
	callback(userdata, item.data);
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

			delete(item.data);
			item.data = data;
			item.last_write_time = new_write_time;

			// todo(josh): should add checks to make sure we dont modify the list while calling subscribers
			sub_idx := len(item.subscribers)-1;
			for sub_idx >= 0 {
				defer sub_idx -= 1;
				sub := item.subscribers[sub_idx];
				sub.callback(sub.userdata, item.data);
			}

			logln("new contents for ", item.path);
		}
	}
}

} // end `when DEVELOPER`
