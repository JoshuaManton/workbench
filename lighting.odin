package workbench

using import "math"
using import "basic"
using import "types"
using import "logging"

      import "gpu"

Material :: struct {
	ambient:  Colorf,
	diffuse:  Colorf,
	specular: Colorf,
	shine:    f32,
}

SHADOW_MAP_DIM :: 2048;
