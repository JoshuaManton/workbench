package workbench

using import "core:fmt"
      import "core:os"

Catalog_Item_ID :: int;

Catalog_Item :: struct {
	path: string,
	last_write_time: os.File_Time,

	userdata: rawptr, // note(josh): is freed on unsubscribe
	callback: proc(rawptr, []u8),
}

all_catalog_items: map[Catalog_Item_ID]Catalog_Item;
last_catalog_item_id: Catalog_Item_ID;

catalog_subscribe :: inline proc(filepath: string, userdata: ^$T, callback: proc(^T, []u8)) -> Catalog_Item_ID {
	assert(callback != nil);

	data, ok := os.read_entire_file(filepath);
	assert(ok);

	time, errno := os.last_write_time_by_name(filepath); assert(errno == os.ERROR_NONE);
	item := Catalog_Item{filepath, time, userdata, cast(proc(rawptr, []u8))callback};

	last_catalog_item_id += 1;
	_, ok2 := all_catalog_items[last_catalog_item_id];
	assert(!ok2, tprint("already had item with id ", last_catalog_item_id));
	all_catalog_items[last_catalog_item_id] = item;
	callback(userdata, data);

	return last_catalog_item_id;
}

catalog_unsubscribe :: inline proc(id: Catalog_Item_ID) {
	item, ok := all_catalog_items[id];
	if !ok do return;

	if item.userdata != nil do free(item.userdata);
	delete_key(&all_catalog_items, id);
}

when DEVELOPER {

_update_catalog :: proc() {
	for id, item in all_catalog_items {

		new_write_time, errno := os.last_write_time_by_name(item.path); assert(errno == os.ERROR_NONE);

		if new_write_time > item.last_write_time {
			data, ok := os.read_entire_file(item.path);
			assert(ok, tprint("Couldn't read file: ", item.path));

			new_item := item;
			new_item.last_write_time = new_write_time;
			item.callback(item.userdata, data);
			all_catalog_items[id] = new_item;

			logln("new contents for ", item.path);
		}
	}
}

} // end `when DEVELOPER`
