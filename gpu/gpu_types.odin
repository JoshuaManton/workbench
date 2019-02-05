package gpu

using import "core:math"
      import rt "core:runtime"

using import "../types"

      import odingl "../external/gl"

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



Mesh_Info :: struct {
	name : string,

	vao: VAO,
	vbo: VBO,
	ibo: EBO,
	vertex_type: ^rt.Type_Info,

	index_count:  int,
	vertex_count: int,
}

MeshID :: distinct i64;

Draw_Mode :: enum u32 {
	Points    = odingl.POINTS,
	Lines     = odingl.LINES,
	Triangles = odingl.TRIANGLES,
}