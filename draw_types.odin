package workbench

using import "core:math"



// Vertex types

Vertex2D :: struct {
	position: Vec2,
	tex_coord: Vec2,
	color: Colorf,
}

Vertex3D :: struct {
	position: Vec3,
	tex_coord: Vec3,
	color: Colorf,
	normal: Vec3,
}



// Draw commands

Draw_Command :: struct {
	render_order:  int,
	serial_number: int,

	rendermode:   Rendermode_Proc,
	shader:       Shader_Program,
	texture:      Texture,
	scissor:      bool,
	scissor_rect: [4]int,

	derived: union {
		Draw_Quad_Command,
		Draw_Sprite_Command,
		Draw_Mesh_Command,
	},

}
Draw_Quad_Command :: struct {
	min, max: Vec2,
	color: Colorf,
}
Draw_Sprite_Command :: struct {
	min, max: Vec2,
	color: Colorf,
	uvs: [4]Vec2,
}
Draw_Mesh_Command :: struct {
	mesh_id: MeshID,
	position: Vec3,
	scale: Vec3,
	rotation: Vec3,
	color: Colorf,
}



// Mesh-related types

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

MeshID :: distinct int;