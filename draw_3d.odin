package workbench

using import        "core:math"
using import        "core:fmt"
      import        "core:sort"
      import        "core:strings"
      import        "core:mem"
      import        "core:os"

      import odingl "external/gl"

      import stb    "external/stb"
      import        "external/glfw"
      import imgui  "external/imgui"
      import ai     "external/assimp"

Vertex3D :: struct {
	position: Vec3,
	tex_coord: Vec3,
	color: Colorf,
	normal: Vec3,
}

Mesh :: struct {
	vertex_array: VAO,
	vertex_buffer: VBO,
	index_buffer: EBO,
	index_count : int,
	vertex_count : int,
	name : string,
}

Model :: struct {
	meshes: []MeshID
}

MeshID :: int;
all_meshes: map[MeshID]Mesh;

cur_mesh_id: int;
create_mesh :: proc(vertices: []Vertex3D, indicies: []u32, name: string) -> MeshID {

	vertex_array := gen_vao(); // genVertexArrays
	vertex_buffer := gen_vbo(); //genVertexBuffers
	index_buffer := gen_ebo(); // genIndexBuffers

	bind_vao(vertex_array); // bindVertexArrays

	bind_buffer(vertex_buffer); // bindVertexBuffer
	buffer_vertices(vertices[:]); // bufferData to GPU

	bind_buffer(index_buffer); // bindIndexBuffer
	buffer_elements(indicies[:]); // bufferData to GPU

	set_vertex_format(Vertex3D);
	// enabledAttribArray 0->3
	// attrib pointer -> pos, tex_coord, color, normal

	bind_vao(VAO(0)); // release vertex array

	id := MeshID(cur_mesh_id);
	cur_mesh_id += 1;

	mesh := Mesh{vertex_array, vertex_buffer, index_buffer, len(indicies), len(vertices), name};
	all_meshes[id] = mesh;

	return id;
}

// TODO (jake): split up assimp model loading and pushing stuff to the gpu
load_asset_to_gpu :: proc(path: cstring) -> Model {
	scene := ai.import_file(path,
		cast(u32) ai.aiPostProcessSteps.CalcTangentSpace |
		cast(u32) ai.aiPostProcessSteps.Triangulate |
		cast(u32) ai.aiPostProcessSteps.JoinIdenticalVertices |
		cast(u32) ai.aiPostProcessSteps.SortByPType |
		cast(u32) ai.aiPostProcessSteps.FlipWindingOrder|
		cast(u32) ai.aiPostProcessSteps.FlipUVs);
	defer ai.release_import(scene);

	mesh_count := cast(int) scene.mNumMeshes;
	mesh_ids := make([dynamic]MeshID, 0, mesh_count);

	meshes := mem.slice_ptr(scene^.mMeshes, cast(int) scene.mNumMeshes);
	for mesh in meshes // iterate meshes in scene
	{
		verts := mem.slice_ptr(mesh.mVertices, cast(int) mesh.mNumVertices);
		norms := mem.slice_ptr(mesh.mNormals, cast(int) mesh.mNumVertices);

		colours : []ai.aiColor4D;
		if mesh.mColors[0] != nil do
			colours = mem.slice_ptr(mesh.mColors[0], cast(int) mesh.mNumVertices);

		texture_coords : []ai.aiVector3D;
		if mesh.mTextureCoords[0] != nil do
			texture_coords = mem.slice_ptr(mesh.mTextureCoords[0], cast(int) mesh.mNumVertices);

		processedVerts := make([dynamic]Vertex3D, 0, mesh.mNumVertices);
		defer delete(processedVerts);

		// process vertices into Vertex3D struct
		// TODO (jake): support vertex colours
		for i in 0 .. mesh.mNumVertices - 1
		{
			normal := norms[i];
			position := verts[i];

			colour: Colorf;
			if mesh.mColors[0] != nil do
				colour = Colorf(colours[i]);
			else
			{
				rnd := (cast(f32)i / cast(f32)len(verts)) * 0.75 + 0.25;
				colour = Colorf{rnd, 0, rnd, 1};
			}

			texture_coord: Vec3;
			if mesh.mTextureCoords[0] != nil do
				texture_coord = Vec3{texture_coords[i].x, texture_coords[i].y, texture_coords[i].z};
			else do
				texture_coord = Vec3{0, 0, 0};

			vert := Vertex3D{
				Vec3{position.x, position.y, position.z},
				texture_coord,
				colour,
				Vec3{normal.x, normal.y, normal.z}};

			append(&processedVerts, vert);
		}

		indicies := make([dynamic]u32, 0, mesh.mNumVertices);
		defer delete(indicies);

		faces := mem.slice_ptr(mesh.mFaces, cast(int) mesh.mNumFaces);
		// iterate all faces, build Index array
		for i in 0 .. mesh.mNumFaces-1
		{
			face := faces[i];
			faceIndicies := mem.slice_ptr(face.mIndices, cast(int) face.mNumIndices);
			for j in 0 .. face.mNumIndices-1
			{
				append(&indicies, faceIndicies[j]);
			}
		}

		// create mesh
		// TODO(jake): Why the fuck can't I take a pointer to mesh.mName.data
		append(&mesh_ids, create_mesh(
			processedVerts[:],
			indicies[:],
			""//cast(string)mem.slice_ptr(&mesh.mName.data, mesh.mName.length)
			));
	}

	// return all created meshIds
	return Model{mesh_ids[:]};
}

get_mesh_shallow_copy :: proc(id: MeshID) -> Mesh {
	mesh, ok := all_meshes[id];
	assert(ok);
	return mesh;
}

model_matrix_from_elements :: inline proc(position: Vec3, scale: Vec3, rotation: Vec3) {
	model_matrix = translate(identity(Mat4), position);
	model_matrix = math.scale(model_matrix, scale);

	orientation := degrees_to_quaternion(rotation);
	rotation_matrix := quat_to_mat4(orientation);
	model_matrix = math.mul(model_matrix, rotation_matrix);
}

// Rendering

im_buffered_meshes: [dynamic]Buffered_Mesh;
im_queued_meshes: [dynamic]Buffered_Mesh;

Buffered_Mesh :: struct {
	id       : MeshID,
	position : Vec3,
	scale    : Vec3,
	rotation : Vec3,
	texture  : Texture,
	shader   : Shader_Program,
}

push_mesh :: inline proc(id: MeshID,
				  position: Vec3,
				  scale: Vec3,
				  rotation: Vec3,
		          texture: Texture,
		          shader: Shader_Program)
{
	append(&im_buffered_meshes, Buffered_Mesh{id, position, scale, rotation, texture, shader});
}

flush_3d :: proc() {
	set_shader :: inline proc(program: Shader_Program) {
		current_shader = program;
		use_program(program);
	}

	set_texture :: inline proc(texture: Texture) {
		current_texture = texture;
		bind_texture2d(texture);
	}

	draw_mesh :: inline proc(mesh: Mesh)
	{
		when DEVELOPER {
			if debugging_rendering_max_draw_calls != -1 && num_draw_calls >= debugging_rendering_max_draw_calls {
				num_draw_calls += 1;
				return;
			}
		}

		bind_vao(mesh.vertex_array);
		bind_buffer(mesh.vertex_buffer);
		bind_buffer(mesh.index_buffer);

		program := get_current_shader();
		uniform_matrix4fv(program, "mvp_matrix", 1, false, &mvp_matrix[0][0]);

		num_draw_calls += 1;

		if debugging_rendering {
			odingl.DrawElements(odingl.LINES, i32(mesh.index_count), odingl.UNSIGNED_INT, nil);
		}
		else {
			odingl.DrawElements(odingl.TRIANGLES, i32(mesh.index_count), odingl.UNSIGNED_INT, nil);
		}
	}

	flush_queue :: inline proc() {
		for queued_mesh in im_queued_meshes {
			mesh, ok := all_meshes[queued_mesh.id];
			assert(ok);

			model_matrix_from_elements(queued_mesh.position, queued_mesh.scale, queued_mesh.rotation);
			rendermode_world();

			draw_mesh(mesh);
		}
		clear(&im_queued_meshes);
	}

	current_shader = 0;
	current_texture = 0;

	sort.quick_sort_proc(im_buffered_meshes[:], proc(a, b: Buffered_Mesh) -> int {
			if a.texture == b.texture && a.shader == b.shader do return 0;
			return int(a.texture - b.texture);
		});

	for buffered_mesh in im_buffered_meshes {
		using buffered_mesh;

		shader_mismatch  := shader != current_shader;
		texture_mismatch := texture != current_texture;

		if shader_mismatch || texture_mismatch {
			flush_queue();
		}

		if shader_mismatch  do set_shader(shader);
		if texture_mismatch do set_texture(texture);

		append(&im_queued_meshes, buffered_mesh);
	}

	flush_queue();
	clear(&im_buffered_meshes);
}

// Mesh primitives

create_cube_mesh :: proc() -> MeshID {
	verts := [dynamic]Vertex3D {
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

	return create_mesh(verts[:], {}, "");
}