package workbench

using import "core:math"

using import "types"
import "gpu"

Draw_Command :: struct {
	render_order:  int,
	serial_number: int,

	rendermode:   gpu.Rendermode_Proc,
	shader:       gpu.Shader_Program,
	texture:      gpu.Texture,
	scissor:      bool,
	scissor_rect: [4]int,

	derived: union {
		Draw_Quad_Command,
		Draw_Sprite_Command,
		Draw_Model_Command,
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
Draw_Model_Command :: struct {
	model: ^gpu.Model,
	position: Vec3,
	scale: Vec3,
	rotation: Quat,
	color: Colorf,
}