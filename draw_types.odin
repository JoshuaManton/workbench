package workbench

using import "core:math"

using import "types"
import "gpu"

Draw_Command :: struct {
	render_order:  int,
	serial_number: int,

	rendermode:   Rendermode_Proc,
	shader:       gpu.Shader_Program,
	texture:      gpu.Texture,
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
	mesh: ^gpu.Mesh,
	position: Vec3,
	scale: Vec3,
	rotation: Quat,
	color: Colorf,
}