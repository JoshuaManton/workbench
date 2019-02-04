package workbench

using import "core:math"

using import "types"
using import "gpu"

// Asset types

Texture_Atlas_ID :: distinct i64;
Texture_Atlas :: struct {
	id: Texture,
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



Mesh_Data :: struct {
	vertices: []Vertex3D,
	indicies: []u32,
	name: string,
}

Model_Data :: struct {
	meshes: []Mesh_Data,
}

Model :: struct {
	meshes: []MeshID,
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