package workbench

using import        "core:math"
using import        "core:fmt"
      import        "core:sort"
      import        "core:strings"
      import        "core:mem"
      import        "core:os"

      import odingl "shared:odin-gl"

      import stb    "shared:workbench/stb"
      import        "shared:workbench/glfw"
      import imgui  "shared:odin-imgui"
      import ai     "shared:odin-assimp"

Vertex3D :: struct {
	position: Vec3,
	tex_coord: Vec2,
	color: Colorf,
	normal: Vec3,
}

Mesh :: struct {
	verts: [dynamic]Vertex3D,
}

MeshID :: int;
all_meshes: map[MeshID]Mesh;

cur_mesh_id: int;
create_mesh :: proc(verts: [dynamic]Vertex3D) -> MeshID {
	id := cast(MeshID)cur_mesh_id;
	cur_mesh_id += 1;

	mesh := Mesh{verts};
	all_meshes[id] = mesh;

	return id;
}

load_asset :: proc(path: cstring) -> [dynamic]MeshID {
	scene := ai.import_file(path,
		cast(u32) ai.aiPostProcessSteps.CalcTangentSpace |
		cast(u32) ai.aiPostProcessSteps.Triangulate |
		//cast(u32) ai.aiPostProcessSteps.JoinIdenticalVertices |
		cast(u32) ai.aiPostProcessSteps.SortByPType |
		cast(u32) ai.aiPostProcessSteps.FlipWindingOrder);
	defer ai.release_import(scene);

	mesh_count := cast(int) scene.mNumMeshes;
	mesh_ids := make([dynamic]MeshID, mesh_count);

	meshes := mem.slice_ptr(scene^.mMeshes, cast(int) scene.mNumMeshes);
	for mesh in meshes
	{
		verts := mem.slice_ptr(mesh.mVertices, cast(int) mesh.mNumVertices);
		norms := mem.slice_ptr(mesh.mNormals, cast(int) mesh.mNumVertices);

		processedVerts := make([dynamic]Vertex3D, mesh.mNumVertices, mesh.mNumVertices);

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

		append(&mesh_ids, create_mesh(processedVerts));
	}

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
	draw_vertex_list(mesh.verts, odingl.TRIANGLES, loc);
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

	return create_mesh(verts);
}