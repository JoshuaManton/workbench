import "core:raw.odin"
import "core:mem.odin"
import "core:fmt.odin"

export "shared:odin-stb/stb_image.odin"

import "types.odin"

load :: proc[load_wrapper, stbi.load];

load_wrapper :: inline proc(filename: cstring) -> ([]types.Colori, i32, i32) {
	stbi.set_flip_vertically_on_load(0);
	w, h, num_channels: i32;
	image_data := stbi.load((cast(^raw.Cstring)&filename).data, &w, &h, &num_channels, 4);
	assert(num_channels == 4);
	slice := mem.slice_ptr(image_data, cast(int)(w * h));
	pixels := (cast(^[]types.Colori)&slice)^;

	return pixels, w, h;
}
