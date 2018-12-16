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

PositionalVertex :: struct {
	position: Vec3,
}

Mesh :: struct {
	vertex_array: VAO,
	vertex_buffer: VBO,
	index_buffer: EBO,
	index_count : int,
	vertex_count : int,
	color: Colorf,
	name : string,
}

Model :: struct {
	meshes: []MeshID
}

MeshID :: int;
all_meshes: map[MeshID]Mesh;

buffer_model :: proc(data: Model_Data) -> Model {
	meshes := make([dynamic]MeshID, 0, len(data.meshes));

	for mesh in data.meshes {
		append(&meshes, buffer_mesh(mesh.vertices, mesh.indicies, mesh.name));
	}

	return Model{meshes[:]};
}

cur_mesh_id: int;
buffer_mesh :: proc(vertices: []Vertex3D, indicies: []u32, name: string) -> MeshID {

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

	id := MeshID(cur_mesh_id);
	cur_mesh_id += 1;

	mesh := Mesh{vertex_array, vertex_buffer, index_buffer, len(indicies), len(vertices), Colorf{1, 1, 1, 1}, name};
	all_meshes[id] = mesh;

	//logln(all_meshes);

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
	color    : Colorf,
}

push_mesh :: inline proc(id: MeshID,
				  position: Vec3,
				  scale: Vec3,
				  rotation: Vec3,
		          texture: Texture,
		          shader: Shader_Program,
		          color: Colorf)
{
	append(&im_buffered_meshes, Buffered_Mesh{id, position, scale, rotation, texture, shader, color});
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

	draw_mesh :: inline proc(mesh: Mesh) {
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

		// :MeshColor
		uniform4f(program, "mesh_color", mesh.color.r, mesh.color.g, mesh.color.b, mesh.color.a);
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
		// note(josh): once we have instancing that will break the current way we
		// do mesh colors at :MeshColor because that depends on setting the color
		// on a per-mesh-instance-in-the-world basis
		for queued_mesh in im_queued_meshes {
			mesh, ok := all_meshes[queued_mesh.id];
			if !ok {
				clear(&im_queued_meshes);
				return;
			}

			mesh.color = queued_mesh.color;

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

create_skybox :: proc(paths : []string) -> Skybox {
	vao := gen_vao();
	vbo := gen_vbo();

	bind_vao(vao);
	bind_buffer(vbo);
	buffer_vertices(create_cube_mesh()[:]);
	set_vertex_format(Vertex3D);
	
	bind_vao(VAO(0)); // release vertex array

	active_texture0();
	texture := load_cubemap(paths);

	return Skybox{vao, vbo, texture};
}

skybox_matrix : Mat4;

active_skybox : Skybox;
render_skybox :: proc() {
	using active_skybox;

	odingl.Disable(odingl.DEPTH_TEST);
	defer odingl.Enable(odingl.DEPTH_TEST);
	odingl.DepthMask(odingl.FALSE);
	defer odingl.DepthMask(odingl.TRUE);

	use_program(shader_rgba);
	active_texture0();
	bind_texture_cubemap(cubemap);
	bind_vao(vao);

	model_matrix_from_elements({0,0,0}, {1,1,1}, current_camera.rotation);
	rendermode_world();
	rotationalMVP : Mat4 = {
		{mvp_matrix[0][0], mvp_matrix[0][1], mvp_matrix[0][2], mvp_matrix[0][3]},
		{mvp_matrix[1][0], mvp_matrix[1][1], mvp_matrix[1][2], mvp_matrix[1][3]},
		{mvp_matrix[2][0], mvp_matrix[2][1], mvp_matrix[2][2], mvp_matrix[2][3]},
		{               0,                0,                0,  			  0}
	};

	uniform_matrix4fv(shader_rgba, "mvp_matrix", 1, false, &mvp_matrix[0][0]);
	
	odingl.DrawArrays(odingl.TRIANGLES, 0, 36);
	bind_vao(VAO(0)); // release vertex array
}

push_skybox :: proc(skybox : Skybox) {
	active_skybox = skybox;
}

// Mesh primitives

create_cube_mesh :: proc() -> [dynamic]Vertex3D {
	return [dynamic]Vertex3D {
	    {{-1.0,  1.0, -1.0,}, {0, 0, 0}, {0.5, 0.5, 0.5, 1}, {}},
	    {{-1.0, -1.0, -1.0,}, {0, 0, 0}, {0.5, 0.5, 0.5, 1}, {}},
	    {{ 1.0, -1.0, -1.0,}, {0, 0, 0}, {0.5, 0.5, 0.5, 1}, {}},
	    {{ 1.0, -1.0, -1.0,}, {0, 0, 0}, {0.5, 0.5, 0.5, 1}, {}},
	    {{ 1.0,  1.0, -1.0,}, {0, 0, 0}, {0.5, 0.5, 0.5, 1}, {}},
	    {{-1.0,  1.0, -1.0,}, {0, 0, 0}, {0.5, 0.5, 0.5, 1}, {}},//
	    {{-1.0, -1.0,  1.0,}, {0, 0, 0}, {0.5, 0.5, 0.5, 1}, {}},
	    {{-1.0, -1.0, -1.0,}, {0, 0, 0}, {0.5, 0.5, 0.5, 1}, {}},
	    {{-1.0,  1.0, -1.0,}, {0, 0, 0}, {0.5, 0.5, 0.5, 1}, {}},
	    {{-1.0,  1.0, -1.0,}, {0, 0, 0}, {0.5, 0.5, 0.5, 1}, {}},
	    {{-1.0,  1.0,  1.0,}, {0, 0, 0}, {0.5, 0.5, 0.5, 1}, {}},
	    {{-1.0, -1.0,  1.0,}, {0, 0, 0}, {0.5, 0.5, 0.5, 1}, {}},//
	    {{ 1.0, -1.0, -1.0,}, {0, 0, 0}, {0.5, 0.5, 0.5, 1}, {}},
	    {{ 1.0, -1.0,  1.0,}, {0, 0, 0}, {0.5, 0.5, 0.5, 1}, {}},
	    {{ 1.0,  1.0,  1.0,}, {0, 0, 0}, {0.5, 0.5, 0.5, 1}, {}},
	    {{ 1.0,  1.0,  1.0,}, {0, 0, 0}, {0.5, 0.5, 0.5, 1}, {}},
	    {{ 1.0,  1.0, -1.0,}, {0, 0, 0}, {0.5, 0.5, 0.5, 1}, {}},
	    {{ 1.0, -1.0, -1.0,}, {0, 0, 0}, {0.5, 0.5, 0.5, 1}, {}},//
	    {{-1.0, -1.0,  1.0,}, {0, 0, 0}, {0.5, 0.5, 0.5, 1}, {}},
	    {{-1.0,  1.0,  1.0,}, {0, 0, 0}, {0.5, 0.5, 0.5, 1}, {}},
	    {{ 1.0,  1.0,  1.0,}, {0, 0, 0}, {0.5, 0.5, 0.5, 1}, {}},
	    {{ 1.0,  1.0,  1.0,}, {0, 0, 0}, {0.5, 0.5, 0.5, 1}, {}},
	    {{ 1.0, -1.0,  1.0,}, {0, 0, 0}, {0.5, 0.5, 0.5, 1}, {}},
	    {{-1.0, -1.0,  1.0,}, {0, 0, 0}, {0.5, 0.5, 0.5, 1}, {}},//
	    {{-1.0,  1.0, -1.0,}, {0, 0, 0}, {0.5, 0.5, 0.5, 1}, {}},
	    {{ 1.0,  1.0, -1.0,}, {0, 0, 0}, {0.5, 0.5, 0.5, 1}, {}},
	    {{ 1.0,  1.0,  1.0,}, {0, 0, 0}, {0.5, 0.5, 0.5, 1}, {}},
	    {{ 1.0,  1.0,  1.0,}, {0, 0, 0}, {0.5, 0.5, 0.5, 1}, {}},
	    {{-1.0,  1.0,  1.0,}, {0, 0, 0}, {0.5, 0.5, 0.5, 1}, {}},
	    {{-1.0,  1.0, -1.0,}, {0, 0, 0}, {0.5, 0.5, 0.5, 1}, {}},//
	    {{-1.0, -1.0, -1.0,}, {0, 0, 0}, {0.5, 0.5, 0.5, 1}, {}},
	    {{-1.0, -1.0,  1.0,}, {0, 0, 0}, {0.5, 0.5, 0.5, 1}, {}},
	    {{ 1.0, -1.0, -1.0,}, {0, 0, 0}, {0.5, 0.5, 0.5, 1}, {}},
	    {{ 1.0, -1.0, -1.0,}, {0, 0, 0}, {0.5, 0.5, 0.5, 1}, {}},
	    {{-1.0, -1.0,  1.0,}, {0, 0, 0}, {0.5, 0.5, 0.5, 1}, {}},
	    {{ 1.0, -1.0,  1.0,}, {0, 0, 0}, {0.5, 0.5, 0.5, 1}, {}},
	};
}

Skybox :: struct {
	vao : VAO,
	vbo : VBO,
	cubemap  : Texture
}