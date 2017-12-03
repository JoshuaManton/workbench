import "shared:sd/math.odin"
import "shared:odin-gl/gl.odin"
import "shared:stb/image.odin"
import "core:mem.odin"

Sprite :: u32;

Sprite_Data :: struct {
	position: math.Vector2,
	scale: math.Vector2,
}

camera_size : i32 = 10;

sprites: [dynamic]Sprite_Data;

load_sprite :: proc(filepath: string) -> Sprite {
	MAX_PATH_LENGTH :: 1024;

	assert(len(filepath) <= MAX_PATH_LENGTH - 1);
	filepath_c: [MAX_PATH_LENGTH]byte;
	mem.copy(&filepath_c[0], &filepath[0], len(filepath));
	filepath_c[len(filepath)] = 0;

	image.set_flip_vertically_on_load(1);
	w, h, channels: i32;
	texture_data := image.load(&filepath_c[0], &w, &h, &channels, 0);

	texture_id: u32;
	gl.GenTextures(1, &texture_id);
	gl.BindTexture(gl.TEXTURE_2D, texture_id);
	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, w, h, 0, gl.RGBA, gl.UNSIGNED_BYTE, texture_data);
	gl.GenerateMipmap(gl.TEXTURE_2D);

	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.MIRRORED_REPEAT);
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.MIRRORED_REPEAT);
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);

	return cast(Sprite)texture_id;
}

submit_sprite :: proc(sprite: Sprite, position, scale: math.Vector2) {
	append(&sprites, Sprite_Data{position, scale});
}