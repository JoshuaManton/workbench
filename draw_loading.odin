package workbench

import "core:fmt"
import "core:os"
import rt "core:runtime"
import "core:strings"
import "core:mem"

import "logging"
import "gpu"

import "external/stb"
import ai "external/assimp"

//
// Textures
//

decode_png_data :: proc(png_data: []byte) -> (^byte, i32, i32, gpu.Pixel_Data_Format, gpu.Internal_Color_Format) {
	width, height, channels: i32;
	pixel_data := stb.load_from_memory(&png_data[0], cast(i32)len(png_data), &width, &height, &channels, 0);
	assert(pixel_data != nil);

	color_format : gpu.Internal_Color_Format;
	pixel_format : gpu.Pixel_Data_Format;
	switch channels {
		case 1: {
			color_format = .Depth_Stencil;
			pixel_format = .Depth_Stencil;
		}
		case 3: {
			color_format = .RGB16F;
			pixel_format = .RGB;
		}
		case 4: {
			color_format = .RGBA16F;
			pixel_format = .RGBA;
		}
		case: {
			logln("Invalid Number of channels for png file: ", channels); //assert(false); // RGB or RGBA
		}
	}

	return pixel_data, width, height, pixel_format, color_format;
}

delete_png_data :: proc(data: ^byte) {
	stb.image_free(data);
}

create_texture_from_png_data :: proc(png_data: []byte) -> Texture {
	pixel_data, width, height, data_format, gpu_format := decode_png_data(png_data);
	defer delete_png_data(pixel_data);

	// assert(mem.is_power_of_two(cast(uintptr)cast(int)width), "Non-power-of-two textures were crashing opengl"); // todo(josh): fix
	// assert(mem.is_power_of_two(cast(uintptr)cast(int)height), "Non-power-of-two textures were crashing opengl"); // todo(josh): fix
	tex := create_texture_2d(cast(int)width, cast(int)height, gpu_format, data_format, .Unsigned_Byte, pixel_data);
	return tex;
}

// todo(josh): check `channels` like we do above and don't hardcode the .RGB's passed to tex_image2d
update_texture_from_png_data :: proc(texture: Texture, png_data: []byte) {
	pixel_data, width, height, data_format, gpu_format := decode_png_data(png_data);
	defer delete_png_data(pixel_data);

	gpu.bind_texture_2d(texture.gpu_id);
	gpu.tex_image_2d(.Texture2D, 0, gpu_format, width, height, 0, data_format, .Unsigned_Byte, pixel_data);
}



//
// Models
//

load_model_from_file :: proc(path: string, name: string, loc := #caller_location) -> Model {
	path_c := strings.clone_to_cstring(path);
	defer delete(path_c);

	scene := ai.import_file(path_c,
                            // cast(u32) ai.Post_Process_Steps.Calc_Tangent_Space |
                            // cast(u32) ai.Post_Process_Steps.Join_Identical_Vertices |
                            // cast(u32) ai.Post_Process_Steps.Sort_By_PType |
                            // cast(u32) ai.Post_Process_Steps.Find_Invalid_Data |
                            // cast(u32) ai.Post_Process_Steps.Gen_UV_Coords |
                            // cast(u32) ai.Post_Process_Steps.Find_Degenerates |
                            // cast(u32) ai.Post_Process_Steps.Transform_UV_Coords |
                            // cast(u32) ai.Post_Process_Steps.Pre_Transform_Vertices |
                            // cast(u32) ai.Post_Process_Steps.Flip_Winding_Order |
                            cast(u32) ai.Post_Process_Steps.Triangulate |
                            cast(u32) ai.Post_Process_Steps.Gen_Smooth_Normals |
                            cast(u32) ai.Post_Process_Steps.Flip_UVs
                            );
	assert(scene != nil, tprint(ai.get_error_string()));
	defer ai.release_import(scene);

	model := _load_model_internal(scene, name);
	return model;
}

load_model_from_memory :: proc(data: []byte, name: string, _hint: string, loc := #caller_location) -> Model {
	hint := strings.clone_to_cstring(_hint); // note(josh): its important that this is a cstring
	defer delete(hint);

	scene := ai.import_file_from_memory(&data[0], i32(len(data)),
                                        // cast(u32) ai.Post_Process_Steps.Calc_Tangent_Space |
                                        // cast(u32) ai.Post_Process_Steps.Join_Identical_Vertices |
                                        // cast(u32) ai.Post_Process_Steps.Sort_By_PType |
                                        // cast(u32) ai.Post_Process_Steps.Find_Invalid_Data |
                                        // cast(u32) ai.Post_Process_Steps.Gen_UV_Coords |
                                        // cast(u32) ai.Post_Process_Steps.Find_Degenerates |
                                        // cast(u32) ai.Post_Process_Steps.Transform_UV_Coords |
                                        // cast(u32) ai.Post_Process_Steps.Pre_Transform_Vertices |
                                        // cast(u32) ai.Post_Process_Steps.Flip_Winding_Order |
			                            cast(u32) ai.Post_Process_Steps.Triangulate |
			                            cast(u32) ai.Post_Process_Steps.Gen_Smooth_Normals |
                                        cast(u32) ai.Post_Process_Steps.Flip_UVs, cast(^u8)hint);
	assert(scene != nil, tprint(ai.get_error_string()));
	defer ai.release_import(scene);

	model := _load_model_internal(scene, name);
	return model;
}



_load_model_internal :: proc(scene: ^ai.Scene, model_name: string, loc := #caller_location) -> Model {
	mesh_count := cast(int) scene.num_meshes;
	model: Model;
	model.meshes = make([dynamic]Mesh, 0, mesh_count, context.allocator, loc);
	base_vert := 0;

	load_animations_from_ai_scene(scene, model_name);

	meshes := mem.slice_ptr(scene^.meshes, cast(int) scene.num_meshes);
	for _, i in meshes {

		mesh := meshes[i];
		mesh_name := strings.string_from_ptr(&mesh.name.data[0], cast(int)mesh.name.length);
		verts := mem.slice_ptr(mesh.vertices, cast(int) mesh.num_vertices);

		mesh_transform := get_mesh_transform(scene.root_node, mesh_name);

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

		defer base_vert += int(mesh.num_vertices);

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

			pos := mul(mesh_transform, Vec4{position.x, position.y, position.z, 1});
			vert := Vertex3D{
				Vec3{pos.x, pos.y, pos.z},
				texture_coord,
				color,
				Vec3{normal.x, normal.y, normal.z}, {}, {}};

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

		skin : Skinned_Mesh;
		if mesh.num_bones > 0 {
			model.has_bones = true;

			// note(josh): freed in _internal_delete_mesh
			bone_mapping := make(map[string]int, cast(int)mesh.num_bones);
			bone_info := make([dynamic]Mesh_Bone, 0, cast(int)mesh.num_bones);

			num_bones := 0;
			bones := mem.slice_ptr(mesh.bones, cast(int)mesh.num_bones);
			for bone in bones {
				bone_name := strings.clone(strings.string_from_ptr(&bone.name.data[0], cast(int)bone.name.length));

				bone_index := 0;
				if bone_name in bone_mapping {
					bone_index = bone_mapping[bone_name];
				} else {
					bone_index = num_bones;
					bone_mapping[bone_name] = bone_index;
					num_bones += 1;
				}

				offset := ai_to_wb_mat4(bone.offset_matrix);
				append(&bone_info, Mesh_Bone{ offset, bone_name });

				if bone.num_weights == 0 do continue;

				weights := mem.slice_ptr(bone.weights, cast(int)bone.num_weights);
				for weight in weights {
					vertex_id := base_vert + int(weight.vertex_id);
					if len(processed_verts) <= vertex_id do continue;
					vert := processed_verts[vertex_id];
					for j := 0; j < BONES_PER_VERTEX; j += 1 {
						if vert.bone_weights[j] == 0 {
							vert.bone_weights[j] = weight.weight;
							vert.bone_indicies[j] = u32(bone_index);

							processed_verts[vertex_id] = vert;
							break;
						}
					}
				} // end weights
			} // end bones loop

			skin = Skinned_Mesh{
				bone_info[:],
				make([dynamic]Mesh_Node, 0, 50),
				bone_mapping,
				inverse(ai_to_wb(scene.root_node.transformation)),
				nil,
			};

		} // end bone if
		// create mesh
		idx := add_mesh_to_model(&model,
                                 processed_verts[:],
                                 indices[:],
                                 skin
                                 );

		read_node_hierarchy(&model.meshes[idx], scene.root_node, identity(Mat4), nil);
	}

	return model;
}

read_node_hierarchy :: proc(using mesh: ^Mesh, ai_node : ^ai.Node, parent_transform: Mat4, parent_node: ^Mesh_Node) {
	node_name := strings.clone(strings.string_from_ptr(&ai_node.name.data[0], cast(int)ai_node.name.length));

	node_transform := ai_to_wb(ai_node.transformation);
	global_transform := mul(parent_transform, node_transform);

	node := Mesh_Node {
        node_name,
        node_transform,
        parent_node,
        make([dynamic]^Mesh_Node, 0, cast(int)ai_node.num_children)
    };

	append(&skin.nodes, node);
	idx := len(skin.nodes) - 1;

	if skin.parent_node == nil {
		skin.parent_node = &skin.nodes[idx];
	}

	if parent_node != nil {
		append(&parent_node.children, &skin.nodes[idx]);
	}

	children := mem.slice_ptr(ai_node.children, cast(int)ai_node.num_children);
	for _, i in children {
		read_node_hierarchy(mesh, children[i], global_transform, &skin.nodes[idx]);
	}
}

get_mesh_transform :: proc(node: ^ai.Node, mesh_name: string) -> Mat4 {

	ret := identity(Mat4);

	children := mem.slice_ptr(node.children, cast(int)node.num_children);
	for _, i in children {
		child := children[i];

		child_name := strings.string_from_ptr(&child.name.data[0], cast(int)child.name.length);
		if child_name == mesh_name {
			return ai_to_wb(child.transformation);
		}

		ret = get_mesh_transform(child, mesh_name);
	}

	return ret;
}

ai_to_wb :: proc{ai_to_wb_vec3, ai_to_wb_quat, ai_to_wb_mat4};
ai_to_wb_vec3 :: proc(vec_in: ai.Vector3D) -> Vec3 {
    return Vec3{vec_in.x, vec_in.y, vec_in.z};
}

ai_to_wb_quat :: proc (quat_in: ai.Quaternion) -> Quat {
    return Quat{quat_in.x, quat_in.y, quat_in.z, quat_in.w};
}

ai_to_wb_mat4 :: proc (m : ai.Matrix4x4) -> Mat4 {
    return Mat4{
        {m.a1, m.b1, m.c1, m.d1},
        {m.a2, m.b2, m.c2, m.d2},
        {m.a3, m.b3, m.c3, m.d3},
        {m.a4, m.b4, m.c4, m.d4},
    };
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
	slice_info: Maybe(Slice_Info)
}

Slice_Info :: struct {
	uvs: [9][4]Vec2,
	slice_min, slice_max: Vec2,
}

create_atlas :: proc(width, height: int) -> Texture_Atlas {
	// panic("I dont know if this works. I changed the create_texture API so if it breaks you'll have to fix it, sorry :^)");
	texture := create_texture_2d(width, height, .RGBA);
	data := Texture_Atlas{texture, cast(i32)width, cast(i32)height, 0, 0, 0};
	return data;
}

delete_atlas :: proc(atlas: Texture_Atlas) {
	delete_texture(atlas.texture);
}

// todo(josh): handle case where it doesn't fit in the atlas
add_sprite_to_atlas :: proc(atlas: ^Texture_Atlas, pixels_rgba: []byte, pixels_per_world_unit : f32 = 32) -> (Sprite, bool) {
	pixel_data, sprite_width, sprite_height, data_format, gpu_format := decode_png_data(pixels_rgba);
	defer delete_png_data(pixel_data);

	gpu.bind_texture_2d(atlas.texture.gpu_id);

	if atlas.atlas_x + sprite_width > atlas.width {
		atlas.atlas_y += atlas.biggest_height;
		atlas.biggest_height = 0;
		atlas.atlas_x = 0;
	}

	if sprite_height > atlas.biggest_height do atlas.biggest_height = sprite_height;
	gpu.tex_sub_image2d(.Texture2D, 0, atlas.atlas_x, atlas.atlas_y, sprite_width, sprite_height, data_format, .Unsigned_Byte, pixel_data);
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
		{bottom_left_x + width_fraction, bottom_left_y},
		{bottom_left_x + width_fraction, bottom_left_y + height_fraction},
		{bottom_left_x,                  bottom_left_y + height_fraction},
	};

	atlas.atlas_x += sprite_width;

	sprite := Sprite{coords, cast(f32)sprite_width / pixels_per_world_unit, cast(f32)sprite_height / pixels_per_world_unit, atlas.texture, nil};
	return sprite, true;
}

add_sliced_sprite_to_atlas :: proc(atlas: ^Texture_Atlas, pixels_rgba: []byte, min, max: Vec2, pixels_per_world_unit : f32 = 32) -> (Sprite, bool) {
	pixel_data, sprite_width, sprite_height, data_format, gpu_format := decode_png_data(pixels_rgba);
	defer delete_png_data(pixel_data);

	gpu.bind_texture_2d(atlas.texture.gpu_id);

	if atlas.atlas_x + sprite_width > atlas.width {
		atlas.atlas_y += atlas.biggest_height;
		atlas.biggest_height = 0;
		atlas.atlas_x = 0;
	}

	if sprite_height > atlas.biggest_height do atlas.biggest_height = sprite_height;
	gpu.tex_sub_image2d(.Texture2D, 0, atlas.atlas_x, atlas.atlas_y, sprite_width, sprite_height, data_format, .Unsigned_Byte, pixel_data);
	gpu.tex_parameteri(.Texture2D, .Wrap_S, .Mirrored_Repeat);
	gpu.tex_parameteri(.Texture2D, .Wrap_T, .Mirrored_Repeat);
	gpu.tex_parameteri(.Texture2D, .Min_Filter, .Nearest);
	gpu.tex_parameteri(.Texture2D, .Mag_Filter, .Nearest);

	bottom_left_x := cast(f32)atlas.atlas_x / cast(f32)sprite_width;
	bottom_left_y := cast(f32)atlas.atlas_y / cast(f32)sprite_height;

	create_slice_cell :: proc(atlas: ^Texture_Atlas, cell_width, cell_height, pixel_x, pixel_y: f32) -> [4]Vec2 {
		width_fraction  := cast(f32)cell_width  / cast(f32)atlas.width;
		height_fraction := cast(f32)cell_height / cast(f32)atlas.height;
		cell_x := pixel_x / cast(f32)atlas.width;
		cell_y := pixel_y / cast(f32)atlas.height;
		return [4]Vec2 {
			{cell_x,                  cell_y},
			{cell_x + width_fraction, cell_y},
			{cell_x + width_fraction, cell_y + height_fraction},
			{cell_x,                  cell_y + height_fraction},
		};
	}

	uvs := [9][4]Vec2{};
	// bottom left
	uvs[0] = create_slice_cell(atlas, min.x, min.y, bottom_left_x, bottom_left_y);
	// middle left
	uvs[1] = create_slice_cell(atlas, min.x, f32(sprite_height) - min.y - max.y, bottom_left_x, bottom_left_y + min.y);
	// top left
	uvs[2] = create_slice_cell(atlas, min.x, max.y, bottom_left_x, bottom_left_y + f32(sprite_height) - max.y);
	// bottom middle
	uvs[3] = create_slice_cell(atlas, f32(sprite_width) - min.x - max.x, min.y, bottom_left_x + min.x,  bottom_left_y);
	// middle middle
	uvs[4] = create_slice_cell(atlas, f32(sprite_width) - min.x - max.x, f32(sprite_height) - min.y - max.y, bottom_left_x + min.x, bottom_left_y + min.y);
	// top middle
	uvs[5] = create_slice_cell(atlas, f32(sprite_width) - min.x - max.x, max.y, bottom_left_x + min.x, bottom_left_y + f32(sprite_height) - max.y);
	// bottom right
	uvs[6] = create_slice_cell(atlas, max.x, min.y, bottom_left_x + f32(sprite_width) - max.x, bottom_left_y);
	// middle right
	uvs[7] = create_slice_cell(atlas, max.x, f32(sprite_height) - min.y - max.y, bottom_left_x + f32(sprite_width) - max.x, bottom_left_y + min.y);
	// top right
	uvs[8] = create_slice_cell(atlas, max.x, max.y, bottom_left_x + f32(sprite_width) - max.x, bottom_left_y + f32(sprite_height) - max.y);

	atlas.atlas_x += sprite_width;

	bottom_left_x = cast(f32)atlas.atlas_x / cast(f32)atlas.width;
	bottom_left_y = cast(f32)atlas.atlas_y / cast(f32)atlas.height;
	width_fraction  := cast(f32)sprite_width  / cast(f32)atlas.width;
	height_fraction := cast(f32)sprite_height / cast(f32)atlas.height;

	coords := [4]Vec2 {
		{bottom_left_x,                  bottom_left_y},
		{bottom_left_x + width_fraction, bottom_left_y},
		{bottom_left_x + width_fraction, bottom_left_y + height_fraction},
		{bottom_left_x,                  bottom_left_y + height_fraction},
	};

	sprite := Sprite{coords, cast(f32)sprite_width / pixels_per_world_unit, cast(f32)sprite_height / pixels_per_world_unit, atlas.texture,  Slice_Info{ uvs, min, max }};
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

	texture := create_texture_2d(dim, dim, .RGBA, .Red, .Unsigned_Byte, &pixels[0]);

	font := Font{dim, pixel_height, chars, texture};
	return font;
}

delete_font :: proc(font: Font) {
	delete(font.chars);
	delete_texture(font.texture);
}

