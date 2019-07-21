package workbench

import "core:mem"
import "core:fmt"

import "shared:workbench/external/stb"

using import "types"

load_wrapper :: inline proc(_filename: cstring) -> ([]Colori, i32, i32) {
	filename := _filename;
	stb.set_flip_vertically_on_load(0);
	w, h, num_channels: i32;
	image_data := stb.load((cast(^mem.Raw_Cstring)&filename).data, &w, &h, &num_channels, 4);
	assert(num_channels == 4);
	slice := mem.slice_ptr(image_data, cast(int)(w * h));
	pixels := (cast(^[]Colori)&slice)^;

	return pixels, w, h;
}
