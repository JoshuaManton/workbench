package workbench

      import rt "core:runtime"

using import "math"
using import "types"
      import "gpu"

Debug_Draw_Call_Data :: struct {
    mesh_name: string,
    vertex_type: ^rt.Type_Info,
    position: Vec3,
    scale: Vec3,
    rotation: Quat,
    texture: Texture,
    color: Colorf,
}