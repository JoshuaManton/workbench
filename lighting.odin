package workbench

using import "core:math"
using import "logging"
using import "types"

Light_Source :: struct {
	position: Vec3,
	color: Colorf,
	intensity: f32,
}

all_lights: [dynamic]Light_Source;

push_light :: proc(light: Light_Source) {
	append(&all_lights, light);
}

clear_lights :: proc() {
	clear(&all_lights);
}