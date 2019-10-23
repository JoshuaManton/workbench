package workbench

using import        "core:math"
using import        "core:fmt"
      import        "core:os"
      import rt     "core:runtime"
      import        "core:strings"
      import        "core:mem"

using import "types"
using import "logging"
      import "gpu"

      import stb    "external/stb"
      import ai     "external/assimp"

//
// Textures
//

create_texture_from_png_data :: proc(png_data: []byte) -> Texture {
	width, height, channels: i32;
	pixel_data := stb.load_from_memory(&png_data[0], cast(i32)len(png_data), &width, &height, &channels, 0);
	assert(pixel_data != nil);
	defer stb.image_free(pixel_data);

	color_format : gpu.Internal_Color_Format;
	pixel_format : gpu.Pixel_Data_Format;

	switch channels {
		case 3: {
			color_format = .RGB;
			pixel_format = .RGB;
		}
		case 4: {
			color_format = .RGBA;
			pixel_format = .RGBA;
		}
		case: {
			assert(false); // RGB or RGBA
		}
	}

	assert(mem.is_power_of_two(cast(uintptr)cast(int)width), "Non-power-of-two textures were crashing opengl"); // todo(josh): fix
	assert(mem.is_power_of_two(cast(uintptr)cast(int)height), "Non-power-of-two textures were crashing opengl"); // todo(josh): fix
	tex := create_texture(cast(int)width, cast(int)height, color_format, pixel_format, .Unsigned_Byte, pixel_data);
	return tex;
}

// todo(josh): check `channels` like we do above and don't hardcode the .RGB's passed to tex_image2d
update_texture_from_png_data :: proc(texture: Texture, png_data: []byte) {
	width, height, channels: i32;
	pixel_data := stb.load_from_memory(&png_data[0], cast(i32)len(png_data), &width, &height, &channels, 0);
	assert(pixel_data != nil);
	defer stb.image_free(pixel_data);

	gpu.bind_texture2d(texture.gpu_id);
	gpu.tex_image2d(.Texture2D, 0, .RGB, width, height, 0, .RGB, .Unsigned_Byte, pixel_data);
}



//
// Models
//

load_model_from_file :: proc(path: string, loc := #caller_location) -> Model {
	path_c := strings.clone_to_cstring(path);
	defer delete(path_c);

	scene := ai.import_file(path_c,
		cast(u32) ai.Post_Process_Steps.Calc_Tangent_Space |
		cast(u32) ai.Post_Process_Steps.Triangulate |
		cast(u32) ai.Post_Process_Steps.Join_Identical_Vertices |
		cast(u32) ai.Post_Process_Steps.Sort_By_PType |
		cast(u32) ai.Post_Process_Steps.Find_Invalid_Data |
		cast(u32) ai.Post_Process_Steps.Gen_UV_Coords |
		cast(u32) ai.Post_Process_Steps.Find_Degenerates |
		cast(u32) ai.Post_Process_Steps.Transform_UV_Coords |
		cast(u32) ai.Post_Process_Steps.Pre_Transform_Vertices |
		//cast(u32) ai.Post_Process_Steps.Flip_Winding_Order |
		cast(u32) ai.Post_Process_Steps.Flip_UVs);
	assert(scene != nil, tprint(ai.get_error_string()));
	defer ai.release_import(scene);

	model := _load_model_internal(scene);
	return model;
}

load_model_from_memory :: proc(data: []byte, loc := #caller_location) -> Model {
	hint := "fbx\x00";
	scene := ai.import_file_from_memory(&data[0], i32(len(data)),
		cast(u32) ai.Post_Process_Steps.Calc_Tangent_Space |
		cast(u32) ai.Post_Process_Steps.Triangulate |
		cast(u32) ai.Post_Process_Steps.Join_Identical_Vertices |
		cast(u32) ai.Post_Process_Steps.Sort_By_PType |
		cast(u32) ai.Post_Process_Steps.Find_Invalid_Data |
		cast(u32) ai.Post_Process_Steps.Gen_UV_Coords |
		cast(u32) ai.Post_Process_Steps.Find_Degenerates |
		cast(u32) ai.Post_Process_Steps.Transform_UV_Coords |
		cast(u32) ai.Post_Process_Steps.Pre_Transform_Vertices |
		//cast(u32) ai.Post_Process_Steps.Flip_Winding_Order |
		cast(u32) ai.Post_Process_Steps.Flip_UVs, &hint[0]);
	assert(scene != nil, tprint(ai.get_error_string()));
	defer ai.release_import(scene);

	model := _load_model_internal(scene);
	return model;
}



_load_model_internal :: proc(scene: ^ai.Scene, loc := #caller_location) -> Model {
	mesh_count := cast(int) scene.num_meshes;
	model: Model;
	model.meshes = make([dynamic]Mesh, 0, mesh_count, context.allocator, loc);

	meshes := mem.slice_ptr(scene^.meshes, cast(int) scene.num_meshes);
	for _, i in meshes {
		mesh := meshes[i];

		verts := mem.slice_ptr(mesh.vertices, cast(int) mesh.num_vertices);

		normals: []ai.Vector3D;
		if ai.has_normals(mesh) {
			assert(mesh.normals != nil);
			normals = mem.slice_ptr(mesh.normals, cast(int) mesh.num_vertices);
		}

		colors : []ai.Color4D;
		if ai.has_vertex_colors(mesh, 0) {
			assert(mesh.colors != nil);
			colors = mem.slice_ptr(mesh.colors[0], cast(int) mesh.num_vertices);
		}

		texture_coords : []ai.Vector3D;
		if ai.has_texture_coords(mesh, 0) {
			assert(mesh.texture_coords != nil);
			texture_coords = mem.slice_ptr(mesh.texture_coords[0], cast(int) mesh.num_vertices);
		}

		processed_verts := make([dynamic]Vertex3D, 0, mesh.num_vertices);
		defer delete(processed_verts);

		// process vertices into Vertex3D struct
		for i in 0..mesh.num_vertices-1 {
			position := verts[i];

			normal := ai.Vector3D{0, 0, 0};
			if normals != nil {
				normal = normals[i];
			}

			color := Colorf{1, 1, 1, 1};
			if colors != nil {
				color = transmute(Colorf)colors[i];
			}

			texture_coord := Vec3{0, 0, 0};
			if texture_coords != nil {
				texture_coord = Vec3{texture_coords[i].x, texture_coords[i].y, texture_coords[i].z};
			}

			vert := Vertex3D{
				Vec3{position.x, position.y, position.z},
				texture_coord,
				color,
				Vec3{normal.x, normal.y, normal.z}};

			append(&processed_verts, vert);
		}

		indices := make([dynamic]u32, 0, mesh.num_vertices);
		defer delete(indices);

		faces := mem.slice_ptr(mesh.faces, cast(int)mesh.num_faces);
		for face in faces {
			face_indices := mem.slice_ptr(face.indices, cast(int) face.num_indices);
			for face_index in face_indices {
				append(&indices, face_index);
			}
		}

		// create mesh
		add_mesh_to_model(&model,
			processed_verts[:],
			indices[:]
		);
	}

	return model;
}



//
// Texture Atlases
//

Texture_Atlas :: struct {
	texture: Texture,
	width: i32,
	height: i32,
	atlas_x: i32,
	atlas_y: i32,
	biggest_height: i32,
}

Sprite :: struct {
	uvs:    [4]Vec2,
	width:  f32,
	height: f32,
	id:     Texture,
}

create_atlas :: inline proc(width, height: int) -> Texture_Atlas {
	panic("I dont know if this works. I changed the create_texture API so if it breaks you'll have to fix it, sorry :^)");
	texture := create_texture(width, height, .RGBA, .RGBA, .Unsigned_Byte);
	data := Texture_Atlas{texture, cast(i32)width, cast(i32)height, 0, 0, 0};
	return data;
}

delete_atlas :: inline proc(atlas: Texture_Atlas) {
	delete_texture(atlas.texture);
}

add_sprite_to_atlas :: proc(atlas: ^Texture_Atlas, pixels_rgba: []byte, pixels_per_world_unit : f32 = 32) -> (Sprite, bool) {
	stb.set_flip_vertically_on_load(1);
	sprite_width, sprite_height, channels: i32;
	pixel_data := stb.load_from_memory(&pixels_rgba[0], cast(i32)len(pixels_rgba), &sprite_width, &sprite_height, &channels, 0);
	assert(pixel_data != nil);

	defer stb.image_free(pixel_data);

	gpu.bind_texture2d(atlas.texture.gpu_id);

	if atlas.atlas_x + sprite_width > atlas.width {
		atlas.atlas_y += atlas.biggest_height;
		atlas.biggest_height = 0;
		atlas.atlas_x = 0;
	}

	if sprite_height > atlas.biggest_height do atlas.biggest_height = sprite_height;
	gpu.tex_sub_image2d(.Texture2D, 0, atlas.atlas_x, atlas.atlas_y, sprite_width, sprite_height, .RGBA, .Unsigned_Byte, pixel_data);
	gpu.tex_parameteri(.Texture2D, .Wrap_S, .Mirrored_Repeat);
	gpu.tex_parameteri(.Texture2D, .Wrap_T, .Mirrored_Repeat);
	gpu.tex_parameteri(.Texture2D, .Min_Filter, .Nearest);
	gpu.tex_parameteri(.Texture2D, .Mag_Filter, .Nearest);
	bottom_left_x := cast(f32)atlas.atlas_x / cast(f32)atlas.width;
	bottom_left_y := cast(f32)atlas.atlas_y / cast(f32)atlas.height;

	width_fraction  := cast(f32)sprite_width  / cast(f32)atlas.width;
	height_fraction := cast(f32)sprite_height / cast(f32)atlas.height;

	coords := [4]Vec2 {
		{bottom_left_x,                  bottom_left_y},
		{bottom_left_x,                  bottom_left_y + height_fraction},
		{bottom_left_x + width_fraction, bottom_left_y + height_fraction},
		{bottom_left_x + width_fraction, bottom_left_y},
	};

	atlas.atlas_x += sprite_width;

	sprite := Sprite{coords, cast(f32)sprite_width / pixels_per_world_unit, cast(f32)sprite_height / pixels_per_world_unit, atlas.texture};
	return sprite, true;
}



//
// Fonts
//

Font :: struct {
	dim: int,
	pixel_height: f32,
	chars: []stb.Baked_Char,
	texture: Texture,
}

load_font :: proc(data: []byte, pixel_height: f32) -> Font {
	pixels: []u8;
	defer delete(pixels);

	chars:  []stb.Baked_Char;
	dim := 128;

	for {
		pixels = make([]u8, dim * dim);
		ret: int;
		chars, ret = stb.bake_font_bitmap(data, 0, pixel_height, pixels, dim, dim, 0, 128);
		if ret < 0 {
			delete(pixels);
			dim *= 2;
		}
		else {
			break;
		}
	}

	texture := create_texture(dim, dim, .RGBA, .Red, .Unsigned_Byte, &pixels[0]);

	font := Font{dim, pixel_height, chars, texture};
	return font;
}

delete_font :: proc(font: Font) {
	delete(font.chars);
	delete_texture(font.texture);
}

