package workbench

using import "core:math"

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

MAX_LIGHTS :: 100;
light_positions:   [dynamic]Vec3;
light_colors:      [dynamic]Colorf;
light_intensities: [dynamic]f32;

push_light :: proc(position: Vec3, color: Colorf, intensity: f32) {
	if len(light_positions) >= MAX_LIGHTS {
		logln("Too many lights! The max is ", MAX_LIGHTS);
		return;
	}
	append(&light_positions,   position);
	append(&light_colors,      color);
	append(&light_intensities, intensity);
}

flush_lights_to_shader :: proc(program: gpu.Shader_Program) {
	num_lights := i32(len(light_positions));
	if num_lights > 0 {
		gpu.uniform3fv(program, "light_positions",   num_lights, &light_positions[0][0]);
		gpu.uniform4fv(program, "light_colors",      num_lights, &light_colors[0].r);
		gpu.uniform1fv(program, "light_intensities", num_lights, &light_intensities[0]);
		gpu.uniform1i(program, "num_lights", cast(i32)len(light_positions));
	}
}

set_current_material :: proc(program: gpu.Shader_Program, material: Material) {
	gpu.uniform_vec4 (program, "material.ambient",  transmute(Vec4)material.ambient);
	gpu.uniform_vec4 (program, "material.diffuse",  transmute(Vec4)material.diffuse);
	gpu.uniform_vec4 (program, "material.specular", transmute(Vec4)material.specular);
	gpu.uniform_float(program, "material.shine",    material.shine);
}

clear_lights :: proc() {
	clear(&light_positions);
	clear(&light_colors);
	clear(&light_intensities);
}