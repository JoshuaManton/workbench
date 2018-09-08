package workbench

import "core:os"

when DEVELOPER {

Subscriber :: struct {
	userdata: rawptr,
	callback: Catalog_Callback,
}

Catalog_Item :: struct {
	path: string,
	text: string,
	last_write_time: os.File_Time,

	subscribers: [dynamic]Subscriber,
}

Catalog_Callback :: proc(rawptr, string, bool);
Catalog_Item_Handle :: int;

cur_catalog_item_handle: int = 1;
all_items: [1024]Catalog_Item;

catalog_add :: proc(path: string) -> (Catalog_Item_Handle, bool) {
	time     := os.last_write_time_by_name(path);
	text, ok := os.read_entire_file(path);
	if !ok do return -1, false;

	item := Catalog_Item{path, cast(string)text, time, nil};
	handle := cur_catalog_item_handle;
	all_items[handle] = item;
	cur_catalog_item_handle += 1;
	assert(cur_catalog_item_handle < 1024);
	return handle, true;
}

catalog_get :: inline proc(handle: Catalog_Item_Handle) -> ^Catalog_Item {
	assert(cur_catalog_item_handle != 0);
	return &all_items[handle];
}

catalog_subscribe :: inline proc(handle: Catalog_Item_Handle, userdata: rawptr, callback: Catalog_Callback) {
	item := catalog_get(handle);
	append(&item.subscribers, Subscriber{userdata, callback});
	callback(userdata, item.text, true);
}

catalog_unsubscribe :: inline proc(handle: Catalog_Item_Handle, callback: Catalog_Callback) {
	item := catalog_get(handle);
	for sub, i in item.subscribers {
		if sub.callback == callback {
			remove_at(&item.subscribers, i);
			return;
		}
	}
}

_update_catalog :: proc() {
	for _, i in all_items {
		item := &all_items[i];
		new_write_time := os.last_write_time_by_name(item.path);

		if new_write_time > item.last_write_time {
			data, ok := os.read_entire_file(item.path);
			assert(ok);

			delete(item.text);
			item.text = cast(string)data;
			item.last_write_time = new_write_time;

			// todo(josh): should add checks to make sure we dont modify the list while calling subscribers
			sub_idx := len(item.subscribers)-1;
			for sub_idx >= 0 {
				defer sub_idx -= 1;
				sub := item.subscribers[sub_idx];
				sub.callback(sub.userdata, item.text, false);
			}

			logln("new contents for ", item.path);
		}
	}
}

} // end `when DEVELOPER`
