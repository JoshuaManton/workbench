package workbench

using import        "core:math"
using import        "core:fmt"
      import        "core:os"

      import odingl "external/gl"
      import stb    "external/stb"

//
// Textures and sprites
//

ATLAS_DIM :: 2048;
PIXELS_PER_WORLD_UNIT :: 24;

Texture_Atlas :: struct {
	id: Texture,
	atlas_x: i32,
	atlas_y: i32,
	biggest_height: i32,
}

create_atlas :: inline proc() -> ^Texture_Atlas {
	texture := gen_texture();
	bind_texture2d(texture);
	odingl.TexImage2D(odingl.TEXTURE_2D, 0, odingl.RGBA, ATLAS_DIM, ATLAS_DIM, 0, odingl.RGBA, odingl.UNSIGNED_BYTE, nil);

	data := new_clone(Texture_Atlas{texture, 0, 0, 0});

	return data;
}

destroy_atlas :: inline proc(atlas: ^Texture_Atlas) {
	delete_texture(atlas.id);
	free(atlas);
}

load_sprite :: proc(texture: ^Texture_Atlas, filepath: string) -> (Sprite, bool) {
	stb.set_flip_vertically_on_load(1);
	sprite_width, sprite_height, channels: i32;
	pixel_data := stb.load(&filepath[0], &sprite_width, &sprite_height, &channels, 0);
	if pixel_data == nil {
		logln("Couldn't load sprite: ", filepath);
		return Sprite{}, false;
	}

	defer stb.image_free(pixel_data);

	bind_texture2d(texture.id);

	if texture.atlas_x + sprite_width > ATLAS_DIM {
		texture.atlas_y += texture.biggest_height;
		texture.biggest_height = 0;
		texture.atlas_x = 0;
	}

	if sprite_height > texture.biggest_height do texture.biggest_height = sprite_height;
	odingl.TexSubImage2D(odingl.TEXTURE_2D, 0, texture.atlas_x, texture.atlas_y, sprite_width, sprite_height, odingl.RGBA, odingl.UNSIGNED_BYTE, pixel_data);
	odingl.TexParameteri(odingl.TEXTURE_2D, odingl.TEXTURE_WRAP_S, odingl.MIRRORED_REPEAT);
	odingl.TexParameteri(odingl.TEXTURE_2D, odingl.TEXTURE_WRAP_T, odingl.MIRRORED_REPEAT);
	odingl.TexParameteri(odingl.TEXTURE_2D, odingl.TEXTURE_MIN_FILTER, odingl.NEAREST);
	odingl.TexParameteri(odingl.TEXTURE_2D, odingl.TEXTURE_MAG_FILTER, odingl.NEAREST);
	bottom_left_x := cast(f32)texture.atlas_x / ATLAS_DIM;
	bottom_left_y := cast(f32)texture.atlas_y / ATLAS_DIM;

	width_fraction  := cast(f32)sprite_width / ATLAS_DIM;
	height_fraction := cast(f32)sprite_height / ATLAS_DIM;

	coords := [4]Vec2 {
		{bottom_left_x,                  bottom_left_y},
		{bottom_left_x,                  bottom_left_y + height_fraction},
		{bottom_left_x + width_fraction, bottom_left_y + height_fraction},
		{bottom_left_x + width_fraction, bottom_left_y},
	};

	texture.atlas_x += sprite_width;

	sprite := Sprite{coords, cast(f32)sprite_width / PIXELS_PER_WORLD_UNIT, cast(f32)sprite_height / PIXELS_PER_WORLD_UNIT, texture.id};
	return sprite, true;
}

load_texture :: proc(filepath: string) -> Texture
{
	width, height, channels: i32;
	pixel_data := stb.load(&filepath[0], &width, &height, &channels, 0);
	if pixel_data == nil {
		logln("Couldn't load texture: ", filepath);
		return 0;
	}
	defer stb.image_free(pixel_data);

	tex := gen_texture();
	bind_texture2d(tex);

	odingl.TexImage2D(odingl.TEXTURE_2D, 0, odingl.RGB, width, height, 0, odingl.RGB, odingl.UNSIGNED_BYTE, pixel_data);
	
	odingl.TexParameteri(odingl.TEXTURE_2D, odingl.TEXTURE_MIN_FILTER, odingl.NEAREST);
	odingl.TexParameteri(odingl.TEXTURE_2D, odingl.TEXTURE_MAG_FILTER, odingl.NEAREST);
	odingl.TexParameteri(odingl.TEXTURE_2D, odingl.TEXTURE_WRAP_T, odingl.CLAMP_TO_EDGE);
	odingl.TexParameteri(odingl.TEXTURE_2D, odingl.TEXTURE_WRAP_S, odingl.CLAMP_TO_EDGE);

	return tex;
}

//
// Fonts
//

Font :: struct {
	dim: int,
	size: f32,
	chars: []stb.Baked_Char,
	id: Texture,
}

font_default: ^Font;

load_font :: proc(path: string, size: f32) -> (^Font, bool) {
	data, ok := os.read_entire_file(path);
	if !ok {
		logln("Couldn't open font: ", path);
		return nil, false;
	}
	defer delete(data);

	pixels: []u8;
	chars:  []stb.Baked_Char;
	dim := 128;

	// @InfiniteLoop
	for {
		pixels = make([]u8, dim * dim);
		ret: int;
		chars, ret = stb.bake_font_bitmap(data, 0, size, pixels, dim, dim, 0, 128);
		if ret < 0 {
			delete(pixels);
			dim *= 2;
		}
		else {
			break;
		}
	}

	texture := gen_texture();
	bind_texture2d(texture);
	odingl.TexParameteri(odingl.TEXTURE_2D, odingl.TEXTURE_MIN_FILTER, odingl.LINEAR);
	odingl.TexParameteri(odingl.TEXTURE_2D, odingl.TEXTURE_MAG_FILTER, odingl.LINEAR);
	odingl.TexImage2D(odingl.TEXTURE_2D, 0, odingl.RGBA, cast(i32)dim, cast(i32)dim, 0, odingl.RED, odingl.UNSIGNED_BYTE, &pixels[0]);

	font := new_clone(Font{dim, size, chars, texture});
	return font, true;
}

destroy_font :: inline proc(font: ^Font) {
	delete(font.chars);
	delete_texture(font.id);
	free(font);
}