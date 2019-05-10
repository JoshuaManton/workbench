package workbench

using import "core:math"
using import "logging"
using import "types"

Light_Source :: struct {
	id: LightID,
	position: Vec3,
	color: Colorf,
	intensity: f32,
}
LightID :: distinct i32;

all_lights: [dynamic]Light_Source;

create_light :: proc(position: Vec3, color: Colorf, intensity: f32) -> LightID {
	@static last_light_id : LightID = 0;
	last_light_id += 1;

	light := Light_Source{last_light_id, position, color, intensity};
	append(&all_lights, light);
	return last_light_id;
}

update_light_position :: proc(id: LightID, position: Vec3) {
	for _, idx in all_lights {
		l := &all_lights[idx];
		if l.id == id {
			l.position = position;
			return;
		}
	}
}