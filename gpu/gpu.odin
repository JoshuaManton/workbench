package gpu

using import "../logging"

all_meshes: map[MeshID]Mesh;

buffer_mesh :: proc(vertices: []Vertex3D, indicies: []u32, name: string) -> MeshID {
	static last_mesh_id: int;

	vertex_array := gen_vao(); // genVertexArrays
	vertex_buffer := gen_vbo(); //genVertexBuffers
	index_buffer := gen_ebo(); // genIndexBuffers

	bind_vao(vertex_array); // bindVertexArrays

	bind_buffer(vertex_buffer); // bindVertexBuffer
	buffer_vertices(vertices); // bufferData to GPU

	bind_buffer(index_buffer); // bindIndexBuffer
	buffer_elements(indicies); // bufferData to GPU

	set_vertex_format(Vertex3D);
	// enabledAttribArray 0->3
	// attrib pointer -> pos, tex_coord, color, normal

	bind_vao(VAO(0)); // release vertex array

	last_mesh_id += 1;
	id := MeshID(last_mesh_id);

	mesh := Mesh{vertex_array, vertex_buffer, index_buffer, len(indicies), len(vertices), name};
	all_meshes[id] = mesh;

	return id;
}

release_mesh :: proc(mesh_id: MeshID) {
	mesh, ok := all_meshes[mesh_id];
	assert(ok);
	delete_vao(mesh.vertex_array);
	delete_buffer(mesh.vertex_buffer);
	delete_buffer(mesh.index_buffer);
	delete_key(&all_meshes, mesh_id);
}

get_mesh :: proc(id: MeshID) -> (Mesh, bool) {
	mesh, ok := all_meshes[id];
	return mesh, ok;
}