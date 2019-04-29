package workbench

using import        "core:math"
using import        "core:fmt"
      import        "core:os"
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

create_texture :: proc(pixels_rgba: []byte) -> gpu.Texture {
	width, height, channels: i32;
	pixel_data := stb.load_from_memory(&pixels_rgba[0], cast(i32)len(pixels_rgba), &width, &height, &channels, 0);
	assert(pixel_data != nil);
	defer stb.image_free(pixel_data);

	tex := gpu.gen_texture();
	gpu.bind_texture2d(tex);
	gpu.tex_image2d(.Texture2D, 0, .RGB, width, height, 0, .RGB, .Unsigned_Byte, pixel_data);
	gpu.tex_parameteri(.Texture2D, .Min_Filter, .Nearest);
	gpu.tex_parameteri(.Texture2D, .Mag_Filter, .Nearest);

	return tex;
}

update_texture :: proc(texture: gpu.Texture, new_data: []byte) {
	width, height, channels: i32;
	pixel_data := stb.load_from_memory(&new_data[0], cast(i32)len(new_data), &width, &height, &channels, 0);
	assert(pixel_data != nil);
	defer stb.image_free(pixel_data);

	gpu.bind_texture2d(texture);
	gpu.tex_image2d(.Texture2D, 0, .RGB, width, height, 0, .RGB, .Unsigned_Byte, pixel_data);
}

delete_texture :: proc(texture: gpu.Texture) {
	gpu.delete_texture(texture);
}



//
// Texture Atlases
//

Texture_Atlas :: struct {
	id: gpu.Texture,
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
	id:     gpu.Texture,
}

create_atlas :: inline proc(width, height: int) -> Texture_Atlas {
	texture := gpu.gen_texture();
	gpu.bind_texture2d(texture);
	gpu.tex_image2d(.Texture2D, 0, .RGBA, cast(i32)width, cast(i32)height, 0, .RGBA, .Unsigned_Byte, nil);
	data := Texture_Atlas{texture, cast(i32)width, cast(i32)height, 0, 0, 0};
	return data;
}

delete_atlas :: inline proc(atlas: ^Texture_Atlas) {
	gpu.delete_texture(atlas.id);
	free(atlas);
}

add_sprite_to_atlas :: proc(texture: ^Texture_Atlas, pixels_rgba: []byte, pixels_per_world_unit : f32 = 32) -> (Sprite, bool) {
	stb.set_flip_vertically_on_load(1);
	sprite_width, sprite_height, channels: i32;
	pixel_data := stb.load_from_memory(&pixels_rgba[0], cast(i32)len(pixels_rgba), &sprite_width, &sprite_height, &channels, 0);
	assert(pixel_data != nil);

	defer stb.image_free(pixel_data);

	gpu.bind_texture2d(texture.id);

	if texture.atlas_x + sprite_width > texture.width {
		texture.atlas_y += texture.biggest_height;
		texture.biggest_height = 0;
		texture.atlas_x = 0;
	}

	if sprite_height > texture.biggest_height do texture.biggest_height = sprite_height;
	gpu.tex_sub_image2d(.Texture2D, 0, texture.atlas_x, texture.atlas_y, sprite_width, sprite_height, .RGBA, .Unsigned_Byte, pixel_data);
	gpu.tex_parameteri(.Texture2D, .Wrap_S, .Mirrored_Repeat);
	gpu.tex_parameteri(.Texture2D, .Wrap_T, .Mirrored_Repeat);
	gpu.tex_parameteri(.Texture2D, .Min_Filter, .Nearest);
	gpu.tex_parameteri(.Texture2D, .Mag_Filter, .Nearest);
	bottom_left_x := cast(f32)texture.atlas_x / cast(f32)texture.width;
	bottom_left_y := cast(f32)texture.atlas_y / cast(f32)texture.height;

	width_fraction  := cast(f32)sprite_width  / cast(f32)texture.width;
	height_fraction := cast(f32)sprite_height / cast(f32)texture.height;

	coords := [4]Vec2 {
		{bottom_left_x,                  bottom_left_y},
		{bottom_left_x,                  bottom_left_y + height_fraction},
		{bottom_left_x + width_fraction, bottom_left_y + height_fraction},
		{bottom_left_x + width_fraction, bottom_left_y},
	};

	texture.atlas_x += sprite_width;

	sprite := Sprite{coords, cast(f32)sprite_width / pixels_per_world_unit, cast(f32)sprite_height / pixels_per_world_unit, texture.id};
	return sprite, true;
}



//
// Meshes
//

Model :: struct {
	meshes: []Mesh,
	mesh_ids: []gpu.MeshID,
}

Mesh :: struct {
	vertices: []gpu.Vertex3D,
	indicies: []u32,
	name: string,
}

load_model_from_file :: proc(path: string) -> Model {
	path_c := strings.clone_to_cstring(path);
	defer delete(path_c);

	scene := ai.import_file(path_c,
		cast(u32) ai.Post_Process_Steps.Calc_Tangent_Space |
		cast(u32) ai.Post_Process_Steps.Triangulate |
		cast(u32) ai.Post_Process_Steps.Join_Identical_Vertices |
		cast(u32) ai.Post_Process_Steps.Sort_By_PType |
		cast(u32) ai.Post_Process_Steps.Flip_Winding_Order|
		cast(u32) ai.Post_Process_Steps.Flip_UVs);
	assert(scene != nil, tprint(ai.get_error_string()));
	defer ai.release_import(scene);

	meshes := _load_model_internal(scene);
	return Model{meshes, {}};
}

// todo(josh): test load_model_from_memory, not sure if it works
load_model_from_memory :: proc(data: []byte) -> Model {
	pHint : byte;
	scene := ai.import_file_from_memory(&data[0], i32(len(data)),
		cast(u32) ai.Post_Process_Steps.Calc_Tangent_Space |
		cast(u32) ai.Post_Process_Steps.Triangulate |
		cast(u32) ai.Post_Process_Steps.Join_Identical_Vertices |
		cast(u32) ai.Post_Process_Steps.Sort_By_PType |
		cast(u32) ai.Post_Process_Steps.Flip_Winding_Order|
		cast(u32) ai.Post_Process_Steps.Flip_UVs, &pHint);
	assert(scene != nil, tprint(ai.get_error_string()));
	defer ai.release_import(scene);

	meshes := _load_model_internal(scene);
	return Model{meshes, {}};
}

load_model_to_gpu :: proc(model: ^Model) {
	assert(model != nil);
	assert(model.mesh_ids == nil);
	ids := make([dynamic]gpu.MeshID, 0, len(model.meshes));
	for mesh in model.meshes {
		append(&ids, gpu.create_mesh(mesh.vertices, mesh.indicies, mesh.name));
	}
	model.mesh_ids = ids[:];
}

free_model_from_gpu :: proc(model: ^Model) {
	assert(model != nil);
	for id in model.mesh_ids {
		gpu.release_mesh(id);
	}
	delete(model.mesh_ids);
}

free_model_cpu_memory :: proc(model: ^Model) {
	assert(model != nil);
	for mesh in model.meshes {
		delete(mesh.vertices);
		delete(mesh.indicies);
		if mesh.name != "" do delete(mesh.name);
	}
	delete(model.meshes);
}

delete_model :: proc(model: Model) {
	free_model_from_gpu(&model);
	free_model_cpu_memory(&model);
}

load_textured_model :: proc(model_path: string, texture_path: string) -> (Model, gpu.Texture) {
	model := load_model_from_file(model_path);
	load_model_to_gpu(&model);

	texture_data, ok := os.read_entire_file(texture_path);
	assert(ok);
	defer delete(texture_data);
	texture := create_texture(texture_data);
	return model, texture;
}

_load_model_internal :: proc(scene: ^ai.Scene) -> []Mesh {
	mesh_count := cast(int) scene.num_meshes;
	meshes_processed := make([dynamic]Mesh, 0, mesh_count);

	meshes := mem.slice_ptr(scene^.meshes, cast(int) scene.num_meshes);
	for _, i in meshes {
		mesh := meshes[i];

		verts := mem.slice_ptr(mesh.vertices, cast(int) mesh.num_vertices);
		norms := mem.slice_ptr(mesh.normals, cast(int) mesh.num_vertices);

		colours : []ai.Color4D;
		if mesh.colors[0] != nil {
			colours = mem.slice_ptr(mesh.colors[0], cast(int) mesh.num_vertices);
		}

		texture_coords : []ai.Vector3D;
		if mesh.texture_coords[0] != nil {
			texture_coords = mem.slice_ptr(mesh.texture_coords[0], cast(int) mesh.num_vertices);
		}

		processedVerts := make([dynamic]gpu.Vertex3D, 0, mesh.num_vertices);

		// process vertices into Vertex3D struct
		// TODO (jake): support vertex colours
		for i in 0..mesh.num_vertices-1 {
			normal := norms[i];
			position := verts[i];

			colour: Colorf;
			if mesh.colors[0] != nil {
				colour = Colorf(colours[i]);
			}
			else {
				rnd := (cast(f32)i / cast(f32)len(verts)) * 0.75 + 0.25;
				colour = Colorf{rnd, 0, rnd, 1};
			}

			texture_coord: Vec3;
			if mesh.texture_coords[0] != nil {
				texture_coord = Vec3{texture_coords[i].x, texture_coords[i].y, texture_coords[i].z};
			}
			else {
				texture_coord = Vec3{0, 0, 0};
			}

			vert := gpu.Vertex3D{
				Vec3{position.x, position.y, position.z},
				texture_coord,
				colour,
				Vec3{normal.x, normal.y, normal.z}};

			append(&processedVerts, vert);
		}

		indices := make([dynamic]u32, 0, mesh.num_vertices);

		faces := mem.slice_ptr(mesh.faces, cast(int)mesh.num_faces);
		for i in 0..mesh.num_faces-1 {
			face := faces[i];
			faceIndicies := mem.slice_ptr(face.indices, cast(int) face.num_indices);
			for j in 0 .. face.num_indices-1 {
				append(&indices, faceIndicies[j]);
			}
		}

		// create mesh
		append(&meshes_processed, Mesh{
			processedVerts[:],
			indices[:],
			string(mesh.name.data[:mesh.name.length])
		});
	}

	// return all created meshIds
	return meshes_processed[:];
}

create_cube_mesh :: proc() -> gpu.MeshID {
	verts := [dynamic]gpu.Vertex3D {
		{{-0.5,-0.5,-0.5}, {}, Colorf{1, 1, 1, 1}, {}},
		{{-0.5,-0.5, 0.5}, {}, Colorf{1, 1, 1, 1}, {}},
		{{-0.5, 0.5, 0.5}, {}, Colorf{1, 1, 1, 1}, {}},
	    {{0.5, 0.5,-0.5},  {}, Colorf{1, 1, 1, 1}, {}},
	    {{-0.5,-0.5,-0.5}, {}, Colorf{1, 1, 1, 1}, {}},
	    {{-0.5, 0.5,-0.5}, {}, Colorf{1, 1, 1, 1}, {}},
	    {{0.5,-0.5, 0.5},  {}, Colorf{1, 1, 1, 1}, {}},
	    {{-0.5,-0.5,-0.5}, {}, Colorf{1, 1, 1, 1}, {}},
	    {{0.5,-0.5,-0.5},  {}, Colorf{1, 1, 1, 1}, {}},
	    {{0.5, 0.5,-0.5},  {}, Colorf{1, 1, 1, 1}, {}},
	    {{0.5,-0.5,-0.5},  {}, Colorf{1, 1, 1, 1}, {}},
	    {{-0.5,-0.5,-0.5}, {}, Colorf{1, 1, 1, 1}, {}},
	    {{-0.5,-0.5,-0.5}, {}, Colorf{1, 1, 1, 1}, {}},
	    {{-0.5, 0.5, 0.5}, {}, Colorf{1, 1, 1, 1}, {}},
	    {{-0.5, 0.5,-0.5}, {}, Colorf{1, 1, 1, 1}, {}},
	    {{0.5,-0.5, 0.5},  {}, Colorf{1, 1, 1, 1}, {}},
	    {{-0.5,-0.5, 0.5}, {}, Colorf{1, 1, 1, 1}, {}},
	    {{-0.5,-0.5,-0.5}, {}, Colorf{1, 1, 1, 1}, {}},
	    {{-0.5, 0.5, 0.5}, {}, Colorf{1, 1, 1, 1}, {}},
	    {{-0.5,-0.5, 0.5}, {}, Colorf{1, 1, 1, 1}, {}},
	    {{0.5,-0.5, 0.5},  {}, Colorf{1, 1, 1, 1}, {}},
	    {{0.5, 0.5, 0.5},  {}, Colorf{1, 1, 1, 1}, {}},
	    {{0.5,-0.5,-0.5},  {}, Colorf{1, 1, 1, 1}, {}},
	    {{0.5, 0.5,-0.5},  {}, Colorf{1, 1, 1, 1}, {}},
	    {{0.5,-0.5,-0.5},  {}, Colorf{1, 1, 1, 1}, {}},
	    {{0.5, 0.5, 0.5},  {}, Colorf{1, 1, 1, 1}, {}},
	    {{0.5,-0.5, 0.5},  {}, Colorf{1, 1, 1, 1}, {}},
	    {{0.5, 0.5, 0.5},  {}, Colorf{1, 1, 1, 1}, {}},
	    {{0.5, 0.5,-0.5},  {}, Colorf{1, 1, 1, 1}, {}},
	    {{-0.5, 0.5,-0.5}, {}, Colorf{1, 1, 1, 1}, {}},
	    {{0.5, 0.5, 0.5},  {}, Colorf{1, 1, 1, 1}, {}},
	    {{-0.5, 0.5,-0.5}, {}, Colorf{1, 1, 1, 1}, {}},
	    {{-0.5, 0.5, 0.5}, {}, Colorf{1, 1, 1, 1}, {}},
	    {{0.5, 0.5, 0.5},  {}, Colorf{1, 1, 1, 1}, {}},
	    {{-0.5, 0.5, 0.5}, {}, Colorf{1, 1, 1, 1}, {}},
	    {{0.5,-0.5, 0.5},  {}, Colorf{1, 1, 1, 1}, {}},
	};

	return gpu.create_mesh(verts[:], []u32{}, "");
}



//
// Fonts
//

Font :: struct {
	dim: int,
	pixel_height: f32,
	chars: []stb.Baked_Char,
	texture_id: gpu.Texture,
}

load_font :: proc(data: []byte, pixel_height: f32) -> Font {
	pixels: []u8;
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

	texture := gpu.gen_texture();
	gpu.bind_texture2d(texture);
	gpu.tex_parameteri(.Texture2D, .Min_Filter, .Linear);
	gpu.tex_parameteri(.Texture2D, .Mag_Filter, .Linear);
	gpu.tex_image2d(.Texture2D, 0, .RGBA, cast(i32)dim, cast(i32)dim, 0, .Red, .Unsigned_Byte, &pixels[0]);

	font := Font{dim, pixel_height, chars, texture};
	return font;
}

delete_font :: proc(font: Font) {
	delete(font.chars);
	gpu.delete_texture(font.texture_id);
}