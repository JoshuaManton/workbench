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
	tex_coord: Vec2,
	color: Colorf,
	normal: Vec3,
}

Mesh :: struct {
	vertex_array: VAO,
	vertex_buffer: VBO,
	index_buffer: EBO,
	index_count : int,
	vertex_count : int,
}

MeshID :: int;
all_meshes: map[MeshID]Mesh;

cur_mesh_id: int;
create_mesh :: proc(vertices: [dynamic]Vertex3D, indicies: [dynamic]u32) -> MeshID {

	vertex_array := gen_vao(); // genVertexArrays
	vertex_buffer := gen_vbo(); //genVertexBuffers
	index_buffer := gen_ebo(); // genIndexBuffers
	
	bind_vao(vertex_array); // bindVertexArrays

	bind_buffer(vertex_buffer); // bindVertexBuffer
	buffer_data(vertices); // bufferData to GPU

	bind_buffer(index_buffer); // bindIndexBuffer
	buffer_data(indicies); // bufferData to GPU

	set_vertex_format(Vertex3D); 
	// enabledAttribArray 0->3
	// attrib pointer -> pos, tex_coord, color, normal

	bind_vao(VAO(0)); // release vertex array

	id := cast(MeshID)cur_mesh_id;
	cur_mesh_id += 1;

	mesh := Mesh{vertex_array, vertex_buffer, index_buffer, len(indicies), len(vertices)};
	all_meshes[id] = mesh;

	return id;
}

load_asset :: proc(path: cstring) -> [dynamic]MeshID {
	scene := ai.import_file(path,
		cast(u32) ai.aiPostProcessSteps.CalcTangentSpace |
		cast(u32) ai.aiPostProcessSteps.Triangulate |
		cast(u32) ai.aiPostProcessSteps.JoinIdenticalVertices |
		cast(u32) ai.aiPostProcessSteps.SortByPType |
		cast(u32) ai.aiPostProcessSteps.FlipWindingOrder);
	defer ai.release_import(scene);

	mesh_count := cast(int) scene.mNumMeshes;
	mesh_ids := make([dynamic]MeshID, 0, mesh_count);

	meshes := mem.slice_ptr(scene^.mMeshes, cast(int) scene.mNumMeshes);
	for mesh in meshes // iterate meshes in scene
	{
		verts := mem.slice_ptr(mesh.mVertices, cast(int) mesh.mNumVertices);
		norms := mem.slice_ptr(mesh.mNormals, cast(int) mesh.mNumVertices);

		processedVerts := make([dynamic]Vertex3D, 0, mesh.mNumVertices);
		defer delete(processedVerts);

		// process vertices into Vertex3D struct
		// TODO (jake): support vertex colours and texture coords
		for i in 0 .. mesh.mNumVertices - 1 
		{
			normal := norms[i];
			position := verts[i];

			r : f32 = (cast(f32)i / cast(f32)len(verts)) * 0.75 + 0.25;
			g : f32 = 0;
			b : f32 = 0;

			vert := Vertex3D{
				Vec3{position.x, position.y, position.z},
				Vec2{0,0},
				Colorf{r, g, b, 1},
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
		append(&mesh_ids, create_mesh(processedVerts, indicies));
	}

	// return all created meshIds
	return mesh_ids;
}

get_mesh_shallow_copy :: proc(id: MeshID) -> Mesh {
	mesh, ok := all_meshes[id];
	assert(ok);
	return mesh;
}

model_matrix_position :: inline proc(position: Vec3) {
	model_matrix = translate(identity(Mat4), position);
}

draw_mesh :: proc(id: MeshID, position: Vec3, loc := #caller_location) {
	mesh, ok := all_meshes[id];
	assert(ok);
	model_matrix_position(position);
	rendermode_world();
	draw_mesh_raw(mesh);
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

	return create_mesh(verts, {});
}